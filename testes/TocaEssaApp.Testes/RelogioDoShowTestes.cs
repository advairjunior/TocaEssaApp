using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.Data.Sqlite;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.DependencyInjection.Extensions;
using Microsoft.Extensions.Logging;
using TocaEssaApp.Api.Dominio;
using TocaEssaApp.Api.Infraestrutura;

namespace TocaEssaApp.Testes;

public class RelogioDoShowTestes
{
    private static readonly DateTimeOffset Inicio = new(2026, 10, 17, 21, 0, 0, TimeSpan.Zero);

    [Fact]
    public void ShowNovoNaoTemDuracaoNemInicio()
    {
        var cenario = CriarCenario();

        var relogio = cenario.Repo.ObterRelogio(cenario.Token, cenario.Show.Id);

        Assert.Null(relogio.DuracaoContratadaMinutos);
        Assert.False(relogio.IntervaloPausaRelogio);
        Assert.Null(relogio.IniciadaEm);
        Assert.Null(relogio.EmIntervaloDesde);
        Assert.Equal(0, relogio.SegundosEmIntervalo);
        Assert.Equal(Inicio, relogio.Agora);
    }

    [Fact]
    public void PrimeiroIniciarMarcaOInicioEReiniciarNaoZera()
    {
        var cenario = CriarCenario();

        cenario.Repo.AlterarStatusApresentacao(
            cenario.Token, cenario.Show.Id, StatusApresentacao.EmAndamento);
        cenario.Agora = Inicio.AddMinutes(30);
        cenario.Repo.AlterarStatusApresentacao(
            cenario.Token, cenario.Show.Id, StatusApresentacao.Agendada);
        cenario.Repo.AlterarStatusApresentacao(
            cenario.Token, cenario.Show.Id, StatusApresentacao.EmAndamento);

        Assert.Equal(Inicio, cenario.Repo.ObterRelogio(cenario.Token, cenario.Show.Id).IniciadaEm);
    }

    [Fact]
    public void ConfigurarGuardaDuracaoEOpcaoDePausa()
    {
        var cenario = CriarCenario();

        var relogio = cenario.Repo.ConfigurarRelogio(
            cenario.Token, cenario.Show.Id, 240, intervaloPausaRelogio: true);

        Assert.Equal(240, relogio.DuracaoContratadaMinutos);
        Assert.True(relogio.IntervaloPausaRelogio);
        Assert.Null(relogio.IniciadaEm);

        var semDuracao = cenario.Repo.ConfigurarRelogio(
            cenario.Token, cenario.Show.Id, null, intervaloPausaRelogio: false);
        Assert.Null(semDuracao.DuracaoContratadaMinutos);
        Assert.False(semDuracao.IntervaloPausaRelogio);
    }

    [Fact]
    public void IntervaloSomaOTempoParadoAoVoltar()
    {
        var cenario = CriarCenario();
        cenario.Repo.AlterarStatusApresentacao(
            cenario.Token, cenario.Show.Id, StatusApresentacao.EmAndamento);

        cenario.Agora = Inicio.AddMinutes(60);
        var emIntervalo = cenario.Repo.IniciarIntervalo(cenario.Token, cenario.Show.Id);
        Assert.Equal(Inicio.AddMinutes(60), emIntervalo.EmIntervaloDesde);

        // Tocar Intervalo de novo em outro aparelho não reinicia a pausa.
        cenario.Agora = Inicio.AddMinutes(65);
        cenario.Repo.IniciarIntervalo(cenario.Token, cenario.Show.Id);

        cenario.Agora = Inicio.AddMinutes(75);
        var voltou = cenario.Repo.EncerrarIntervalo(cenario.Token, cenario.Show.Id);
        Assert.Null(voltou.EmIntervaloDesde);
        Assert.Equal(15 * 60, voltou.SegundosEmIntervalo);

        // Voltar de novo sem intervalo não muda nada.
        cenario.Agora = Inicio.AddMinutes(80);
        Assert.Equal(15 * 60,
            cenario.Repo.EncerrarIntervalo(cenario.Token, cenario.Show.Id).SegundosEmIntervalo);
    }

    [Fact]
    public void IntervaloSoDepoisDeIniciarOShow()
    {
        var cenario = CriarCenario();

        Assert.Throws<ShowNaoIniciadoException>(() =>
            cenario.Repo.IniciarIntervalo(cenario.Token, cenario.Show.Id));
    }

    [Fact]
    public void EncerrarOShowDuranteOIntervaloFechaOIntervalo()
    {
        var cenario = CriarCenario();
        cenario.Repo.AlterarStatusApresentacao(
            cenario.Token, cenario.Show.Id, StatusApresentacao.EmAndamento);
        cenario.Agora = Inicio.AddMinutes(100);
        cenario.Repo.IniciarIntervalo(cenario.Token, cenario.Show.Id);

        cenario.Agora = Inicio.AddMinutes(110);
        cenario.Repo.AlterarStatusApresentacao(
            cenario.Token, cenario.Show.Id, StatusApresentacao.Encerrada);

        var relogio = cenario.Repo.ObterRelogio(cenario.Token, cenario.Show.Id);
        Assert.Null(relogio.EmIntervaloDesde);
        Assert.Equal(10 * 60, relogio.SegundosEmIntervalo);
    }

    [Fact]
    public void ContaMusicasComecadasEAsQueFaltamNaSequencia()
    {
        var cenario = CriarCenario();
        var repertorio = cenario.Repo.CriarRepertorio(cenario.Token, "Casamentos");
        foreach (var titulo in new[] { "Evidências", "Pense em Mim", "Tempo Perdido" })
            cenario.Repo.AdicionarMusicaAoRepertorio(cenario.Token, repertorio.Id, titulo, null);
        var setlist = cenario.Repo.ImportarRepertorioParaSetlist(
            cenario.Token, cenario.Show.Id, repertorio.Id).ToArray();
        cenario.Repo.MarcarItemDoSetlist(cenario.Token, cenario.Show.Id, setlist[0].Id, tocada: true);
        var tocando = cenario.Repo.CriarPedido(cenario.Show.Codigo, "Asa Branca", null, "Rui");
        var aSeguir = cenario.Repo.CriarPedido(cenario.Show.Codigo, "Garota de Ipanema", null, "Bia");
        cenario.Repo.CriarPedido(cenario.Show.Codigo, "Asa Branca", null, "Leo");
        cenario.Repo.AlterarStatusDoGrupo(
            cenario.Token, cenario.Show.Id, tocando.Id, StatusPedidoMusical.TocandoAgora);
        cenario.Repo.ColocarPedidoASeguir(cenario.Token, cenario.Show.Id, aSeguir.Id, noInicio: false);

        var relogio = cenario.Repo.ObterRelogio(cenario.Token, cenario.Show.Id);

        // Asa Branca pedida por dois conta uma vez só.
        Assert.Equal(2, relogio.MusicasComecadas);
        Assert.Equal(3, relogio.MusicasRestantes);
    }

    [Fact]
    public void PoutPourriContaCadaMusicaSeparadaPorBarra()
    {
        var cenario = CriarCenario();
        var repertorio = cenario.Repo.CriarRepertorio(cenario.Token, "Casamentos");
        foreach (var titulo in new[] { "Evidências / Página Virada", "Pense em Mim/Fio de Cabelo/Saudade", "24/7" })
            cenario.Repo.AdicionarMusicaAoRepertorio(cenario.Token, repertorio.Id, titulo, null);
        var setlist = cenario.Repo.ImportarRepertorioParaSetlist(
            cenario.Token, cenario.Show.Id, repertorio.Id).ToArray();
        cenario.Repo.MarcarItemDoSetlist(cenario.Token, cenario.Show.Id, setlist[0].Id, tocada: true);

        var relogio = cenario.Repo.ObterRelogio(cenario.Token, cenario.Show.Id);

        Assert.Equal(2, relogio.MusicasComecadas);
        Assert.Equal(4, relogio.MusicasRestantes);
    }

    [Fact]
    public void SemShowsEncerradosNaoHaRitmoMedio()
    {
        var cenario = CriarCenario();

        Assert.Null(cenario.Repo.ObterRelogio(cenario.Token, cenario.Show.Id).RitmoMedioSegundos);
    }

    [Fact]
    public void RitmoMedioVemDosShowsEncerradosDoProprioArtista()
    {
        var cenario = CriarCenario();
        // 50 min tocando (1h menos 10 min de intervalo) em 10 músicas.
        TocarShow(cenario, cenario.Token, musicas: 10, minutos: 60, minutosDeIntervalo: 10);
        // Poucas músicas para medir: não conta.
        TocarShow(cenario, cenario.Token, musicas: 2, minutos: 30);
        // Esquecido aberto: mais de 15 min por música não conta.
        TocarShow(cenario, cenario.Token, musicas: 3, minutos: 600);
        // 60 min em 20 músicas.
        TocarShow(cenario, cenario.Token, musicas: 20, minutos: 60);
        var tokenBia = cenario.Repo.CriarContaArtista("Bia", "bia@artista.com", "senha").Token;
        cenario.Repo.SalvarPerfilDaConta(tokenBia, new SalvarPerfilArtistico("Bia", null));
        TocarShow(cenario, tokenBia, musicas: 5, minutos: 60);

        var relogio = cenario.Repo.ObterRelogio(cenario.Token, cenario.Show.Id);

        // (50 + 60) min em 30 músicas = 220 s por música.
        Assert.Equal(220, relogio.RitmoMedioSegundos);
    }

    [Fact]
    public void EncerrarGuardaAHoraDoFim()
    {
        var cenario = CriarCenario();
        cenario.Repo.AlterarStatusApresentacao(
            cenario.Token, cenario.Show.Id, StatusApresentacao.EmAndamento);
        cenario.Agora = Inicio.AddHours(3);
        cenario.Repo.AlterarStatusApresentacao(
            cenario.Token, cenario.Show.Id, StatusApresentacao.Encerrada);

        Assert.Equal(Inicio.AddHours(3),
            cenario.Repo.ObterRelogio(cenario.Token, cenario.Show.Id).EncerradaEm);
    }

    [Fact]
    public void OutroArtistaNaoVeNemMexeNoRelogio()
    {
        var cenario = CriarCenario();
        var tokenBia = cenario.Repo.CriarContaArtista("Bia", "bia@artista.com", "senha").Token;

        Assert.Throws<ApresentacaoNaoEncontradaException>(() =>
            cenario.Repo.ObterRelogio(tokenBia, cenario.Show.Id));
        Assert.Throws<ApresentacaoNaoEncontradaException>(() =>
            cenario.Repo.ConfigurarRelogio(tokenBia, cenario.Show.Id, 60, false));
        Assert.Throws<ApresentacaoNaoEncontradaException>(() =>
            cenario.Repo.IniciarIntervalo(tokenBia, cenario.Show.Id));
        Assert.Throws<ApresentacaoNaoEncontradaException>(() =>
            cenario.Repo.EncerrarIntervalo(tokenBia, cenario.Show.Id));
    }

    [Fact]
    public void RelogioSobreviveAoReinicioDoServidor()
    {
        var arquivo = Path.Combine(Path.GetTempPath(), $"tocaessa-relogio-{Guid.NewGuid():N}.db");
        try
        {
            var cenario = CriarCenario(arquivo);
            cenario.Repo.ConfigurarRelogio(cenario.Token, cenario.Show.Id, 240, true);
            cenario.Repo.AlterarStatusApresentacao(
                cenario.Token, cenario.Show.Id, StatusApresentacao.EmAndamento);
            cenario.Agora = Inicio.AddMinutes(90);
            cenario.Repo.IniciarIntervalo(cenario.Token, cenario.Show.Id);

            var reiniciado = new RepositorioTocaEssa(arquivo);
            var relogio = reiniciado.ObterRelogio(cenario.Token, cenario.Show.Id);

            Assert.Equal(240, relogio.DuracaoContratadaMinutos);
            Assert.True(relogio.IntervaloPausaRelogio);
            Assert.Equal(Inicio, relogio.IniciadaEm);
            Assert.Equal(Inicio.AddMinutes(90), relogio.EmIntervaloDesde);
        }
        finally
        {
            ExcluirBanco(arquivo);
        }
    }

    [Fact]
    public void BancoAntigoGanhaORelogioSemPerderDadosEShowAoVivoComecaAoConfigurar()
    {
        var arquivo = Path.Combine(Path.GetTempPath(), $"tocaessa-relogio-legado-{Guid.NewGuid():N}.db");
        try
        {
            var cenario = CriarCenario(arquivo);
            cenario.Repo.CriarPedido(cenario.Show.Codigo, "Evidências", null, "Rui");
            cenario.Repo.AlterarStatusApresentacao(
                cenario.Token, cenario.Show.Id, StatusApresentacao.EmAndamento);
            using (var conexao = new SqliteConnection($"Data Source={arquivo};Pooling=False"))
            {
                conexao.Open();
                using var comando = conexao.CreateCommand();
                foreach (var coluna in new[]
                         {
                             "DuracaoContratadaMinutos", "IntervaloPausaRelogio", "IniciadaEm",
                             "EmIntervaloDesde", "SegundosEmIntervalo", "EncerradaEm"
                         })
                {
                    comando.CommandText = $"ALTER TABLE \"Apresentacoes\" DROP COLUMN \"{coluna}\"";
                    comando.ExecuteNonQuery();
                }
            }

            var migrado = new RepositorioTocaEssa(arquivo) { Agora = () => Inicio.AddMinutes(45) };
            Assert.Null(migrado.ObterRelogio(cenario.Token, cenario.Show.Id).IniciadaEm);
            var configurado = migrado.ConfigurarRelogio(cenario.Token, cenario.Show.Id, 180, false);

            Assert.Equal(Inicio.AddMinutes(45), configurado.IniciadaEm);
            var migradoDeNovo = new RepositorioTocaEssa(arquivo);
            Assert.Equal(180,
                migradoDeNovo.ObterRelogio(cenario.Token, cenario.Show.Id).DuracaoContratadaMinutos);
            Assert.Single(migradoDeNovo.ListarPedidosDoArtista(cenario.Token, cenario.Show.Id));
        }
        finally
        {
            ExcluirBanco(arquivo);
        }
    }

    [Fact]
    public async Task RotasDoRelogioSaoSoDoDonoEOPublicoNaoVeOTempo()
    {
        var banco = Path.Combine(Path.GetTempPath(), $"tocaessa-api-relogio-{Guid.NewGuid():N}.db");
        try
        {
            await using var fabrica = new WebApplicationFactory<Program>().WithWebHostBuilder(builder =>
            {
                builder.ConfigureLogging(logging => logging.ClearProviders());
                builder.ConfigureAppConfiguration((_, configuracao) =>
                    configuracao.AddInMemoryCollection(new Dictionary<string, string?>
                    {
                        ["ConnectionStrings:DefaultConnection"] = banco,
                        ["Aplicacao:ArquivoBanco"] = banco,
                        ["Aplicacao:ArquivoDados"] = $"{banco}.json"
                    }));
                builder.ConfigureServices(servicos =>
                {
                    servicos.RemoveAll<RepositorioTocaEssa>();
                    servicos.AddSingleton(new RepositorioTocaEssa(banco, $"{banco}.json"));
                });
            });
            using var publico = fabrica.CreateClient();
            using var ana = await CriarClienteArtista(fabrica, "ana@teste.com");
            using var bia = await CriarClienteArtista(fabrica, "bia@teste.com");
            (await ana.PutAsJsonAsync("/api/perfil-artistico",
                new { nomeArtistico = "Duo Aurora" })).EnsureSuccessStatusCode();
            var criada = await ana.PostAsJsonAsync("/api/apresentacoes", new
            {
                nome = "Casamento", data = "2026-10-17", local = "Salão", tipo = "Publica"
            });
            criada.EnsureSuccessStatusCode();
            using var jsonShow = JsonDocument.Parse(await criada.Content.ReadAsStringAsync());
            var show = jsonShow.RootElement.GetProperty("apresentacao");
            var showId = show.GetProperty("id").GetGuid();
            var codigo = show.GetProperty("codigo").GetString();
            var rota = $"/api/apresentacoes/{showId}/relogio";

            var configurado = await ana.PutAsJsonAsync(rota,
                new { duracaoContratadaMinutos = 240, intervaloPausaRelogio = true });
            Assert.Equal(HttpStatusCode.OK, configurado.StatusCode);
            using (var json = JsonDocument.Parse(await configurado.Content.ReadAsStringAsync()))
            {
                Assert.Equal(240, json.RootElement.GetProperty("duracaoContratadaMinutos").GetInt32());
                Assert.True(json.RootElement.GetProperty("intervaloPausaRelogio").GetBoolean());
            }
            foreach (var invalida in new[] { 0, 24 * 60 + 1 })
                Assert.Equal(HttpStatusCode.BadRequest,
                    (await ana.PutAsJsonAsync(rota, new { duracaoContratadaMinutos = invalida })).StatusCode);

            Assert.Equal(HttpStatusCode.Conflict,
                (await ana.PostAsync($"{rota}/intervalo", null)).StatusCode);
            (await ana.PatchAsJsonAsync($"/api/apresentacoes/{showId}/status",
                new { status = "EmAndamento" })).EnsureSuccessStatusCode();
            var intervalo = await ana.PostAsync($"{rota}/intervalo", null);
            Assert.Equal(HttpStatusCode.OK, intervalo.StatusCode);
            using (var json = JsonDocument.Parse(await intervalo.Content.ReadAsStringAsync()))
                Assert.NotEqual(JsonValueKind.Null,
                    json.RootElement.GetProperty("emIntervaloDesde").ValueKind);
            var voltou = await ana.DeleteAsync($"{rota}/intervalo");
            Assert.Equal(HttpStatusCode.OK, voltou.StatusCode);
            using (var json = JsonDocument.Parse(await ana.GetStringAsync(rota)))
            {
                Assert.Equal(JsonValueKind.Null, json.RootElement.GetProperty("emIntervaloDesde").ValueKind);
                Assert.NotEqual(JsonValueKind.Null, json.RootElement.GetProperty("iniciadaEm").ValueKind);
            }

            Assert.Equal(HttpStatusCode.NotFound, (await bia.GetAsync(rota)).StatusCode);
            Assert.Equal(HttpStatusCode.NotFound,
                (await bia.PutAsJsonAsync(rota, new { duracaoContratadaMinutos = 60 })).StatusCode);
            Assert.Equal(HttpStatusCode.NotFound, (await bia.PostAsync($"{rota}/intervalo", null)).StatusCode);
            Assert.Equal(HttpStatusCode.NotFound, (await bia.DeleteAsync($"{rota}/intervalo")).StatusCode);
            Assert.Equal(HttpStatusCode.Unauthorized, (await publico.GetAsync(rota)).StatusCode);

            var paginaPublica = await publico.GetAsync($"/api/publico/apresentacoes/{codigo}");
            Assert.Equal(HttpStatusCode.OK, paginaPublica.StatusCode);
            var corpoPublico = await paginaPublica.Content.ReadAsStringAsync();
            Assert.DoesNotContain("duracaoContratada", corpoPublico);
            Assert.DoesNotContain("iniciadaEm", corpoPublico);
            Assert.DoesNotContain("intervalo", corpoPublico, StringComparison.OrdinalIgnoreCase);
            Assert.Equal(HttpStatusCode.OK,
                (await publico.GetAsync($"/api/publico/apresentacoes/{codigo}/fila")).StatusCode);
        }
        finally
        {
            ExcluirBanco(banco);
        }
    }

    private static async Task<HttpClient> CriarClienteArtista(
        WebApplicationFactory<Program> fabrica, string email)
    {
        var cliente = fabrica.CreateClient();
        var resposta = await cliente.PostAsJsonAsync(
            "/api/artista/contas", new { nome = "Artista", email, senha = "senha123" });
        resposta.EnsureSuccessStatusCode();
        using var json = JsonDocument.Parse(await resposta.Content.ReadAsStringAsync());
        cliente.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue(
            "Bearer", json.RootElement.GetProperty("token").GetString());
        return cliente;
    }

    /// Cria, toca e encerra um show com [musicas] tocadas em [minutos].
    private static void TocarShow(
        Cenario cenario, string token, int musicas, int minutos, int minutosDeIntervalo = 0)
    {
        var repo = cenario.Repo;
        var show = repo.CriarApresentacao(token, "Anterior", new DateOnly(2026, 10, 1), "Bar");
        var repertorio = repo.CriarRepertorio(token, $"Show {show.Codigo}");
        for (var i = 0; i < musicas; i++)
            repo.AdicionarMusicaAoRepertorio(token, repertorio.Id, $"Música {i}", null);
        var itens = repo.ImportarRepertorioParaSetlist(token, show.Id, repertorio.Id);
        var inicio = cenario.Agora;
        repo.AlterarStatusApresentacao(token, show.Id, StatusApresentacao.EmAndamento);
        foreach (var item in itens)
            repo.MarcarItemDoSetlist(token, show.Id, item.Id, tocada: true);
        if (minutosDeIntervalo > 0)
        {
            repo.IniciarIntervalo(token, show.Id);
            cenario.Agora = inicio.AddMinutes(minutosDeIntervalo);
            repo.EncerrarIntervalo(token, show.Id);
        }
        cenario.Agora = inicio.AddMinutes(minutos);
        repo.AlterarStatusApresentacao(token, show.Id, StatusApresentacao.Encerrada);
        cenario.Agora = inicio;
    }

    private static Cenario CriarCenario(string? arquivo = null)
    {
        var repo = new RepositorioTocaEssa(arquivo);
        var token = repo.CriarContaArtista("Ana", "ana@artista.com", "senha").Token;
        repo.SalvarPerfilDaConta(token, new SalvarPerfilArtistico("Ana", null));
        var show = repo.CriarApresentacao(token, "Casamento", new DateOnly(2026, 10, 17), "Salão");
        var cenario = new Cenario(repo, token, show);
        repo.Agora = () => cenario.Agora;
        return cenario;
    }

    private static void ExcluirBanco(string caminho)
    {
        SqliteConnection.ClearAllPools();
        foreach (var arquivo in new[] { caminho, $"{caminho}-shm", $"{caminho}-wal", $"{caminho}.json" })
            if (File.Exists(arquivo)) File.Delete(arquivo);
    }

    private sealed class Cenario(RepositorioTocaEssa repo, string token, Apresentacao show)
    {
        public RepositorioTocaEssa Repo { get; } = repo;
        public string Token { get; } = token;
        public Apresentacao Show { get; } = show;
        public DateTimeOffset Agora { get; set; } = Inicio;
    }
}
