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

/// O coral canta junto de quem faz a primeira voz, só nas partes marcadas.
public sealed class CoralDoLouvorTestes
{
    // Estrofe 1, Refrão, Estrofe 2, Refrão, Estrofe 3, Refrão.
    private const string PorCristoResgatado = """
        Cristo Jesus, o santo Cordeiro
        Deu Sua vida sobre o madeiro
        Com o Seu sangue me resgatou
        D'Ele agora sou
        Refrão:
        Por Cristo, resgatado
        Sirvo ao grande Deus
        Para a Ele pertencer
        Junto aos santos Seus
        Preso estava na iniquidade
        Cristo me trouxe a liberdade
        Por Sua graça me resgatou
        D'Ele agora sou
        (Refrão)
        Tem minha alma grande alegria
        Sem esperança sempre vivia
        Glória a Jesus que me resgatou
        D'Ele agora sou
        (Refrão)
        """;

    [Fact]
    public void CoralFicaJuntoDoCantorDaParte()
    {
        var cenario = CriarCenario();
        var hino = cenario.Hinos[0].Id;
        cenario.Repo.EscolherParteDoLouvor(cenario.Token, cenario.Show.Id, hino, 0, ["Ana"]);

        var louvor = cenario.Repo.MarcarCoralDoLouvor(
            cenario.Token, cenario.Show.Id, hino, 0, true);

        var partes = louvor.Hinos[0].Partes;
        Assert.Equal(["Ana"], partes[0].Cantores);
        Assert.True(partes[0].Coral);
        Assert.All(partes.Skip(1), parte => Assert.False(parte.Coral));

        var desmarcado = cenario.Repo.MarcarCoralDoLouvor(
            cenario.Token, cenario.Show.Id, hino, 0, false);
        Assert.False(desmarcado.Hinos[0].Partes[0].Coral);
        Assert.Equal(["Ana"], desmarcado.Hinos[0].Partes[0].Cantores);
    }

    [Fact]
    public void EscalarDeNovoNaoApagaOCoralMarcado()
    {
        var cenario = CriarCenario();
        var hino = cenario.Hinos[0].Id;
        cenario.Repo.MarcarCoralDoLouvor(cenario.Token, cenario.Show.Id, hino, 2, true);

        cenario.Repo.EscalarHinoDoLouvor(cenario.Token, cenario.Show.Id, hino);
        var louvor = cenario.Repo.EscalarTodosOsHinosDoLouvor(cenario.Token, cenario.Show.Id);

        Assert.True(louvor.Hinos[0].Partes[2].Definida);
        Assert.True(louvor.Hinos[0].Partes[2].Coral);
        Assert.False(louvor.Hinos[0].Partes[0].Coral);
    }

    [Fact]
    public void ComCoralNosRefroesEscalarMarcaOCoralEmTodoRefrao()
    {
        var cenario = CriarCenario();
        var hino = cenario.Hinos[0].Id;
        cenario.Repo.DefinirConfiguracaoDoLouvor(cenario.Token, cenario.Show.Id,
            new ConfiguracaoDaEscala(CoralNosRefroes: true));

        var louvor = cenario.Repo.EscalarHinoDoLouvor(cenario.Token, cenario.Show.Id, hino);

        Assert.Equal(
            [false, true, false, true, false, true],
            louvor.Hinos[0].Partes.Select(parte => parte.Coral));
        Assert.True(louvor.Configuracao.CoralNosRefroes);
    }

    [Fact]
    public void SemCoralNosRefroesEscalarNaoMarcaOCoral()
    {
        var cenario = CriarCenario();

        var louvor = cenario.Repo.EscalarTodosOsHinosDoLouvor(cenario.Token, cenario.Show.Id);

        Assert.All(louvor.Hinos[0].Partes, parte => Assert.False(parte.Coral));
    }

    [Fact]
    public void LetraNovaEscaladaSozinhaJaMarcaOCoralNosRefroes()
    {
        var cenario = CriarCenario(comLetra: false);
        cenario.Repo.DefinirConfiguracaoDoLouvor(cenario.Token, cenario.Show.Id,
            new ConfiguracaoDaEscala(CoralNosRefroes: true));

        cenario.Repo.SalvarCifraEmTexto(cenario.Token, "80 · Por Cristo, resgatado", null,
            "(Estrofe 1)\n" + PorCristoResgatado);

        var partes = cenario.Repo.ObterLouvor(cenario.Token, cenario.Show.Id).Hinos[0].Partes;
        Assert.True(partes[0].Definida);
        Assert.True(partes[1].Coral);
        Assert.False(partes[0].Coral);
    }

    [Fact]
    public void CoralSoNumaParteQueExiste()
    {
        var cenario = CriarCenario();
        var outro = CriarCenario();

        Assert.Throws<EscolhaDoLouvorInvalidaException>(() => cenario.Repo.MarcarCoralDoLouvor(
            cenario.Token, cenario.Show.Id, cenario.Hinos[0].Id, 6, true));
        Assert.Throws<ItemDoSetlistNaoEncontradoException>(() => cenario.Repo.MarcarCoralDoLouvor(
            cenario.Token, cenario.Show.Id, outro.Hinos[0].Id, 0, true));
    }

    [Fact]
    public void CoralSobreviveAoReinicioEBancoAntigoGanhaAColuna()
    {
        var arquivo = Path.Combine(Path.GetTempPath(), $"tocaessa-coral-{Guid.NewGuid():N}.db");
        try
        {
            var cenario = CriarCenario(arquivo: arquivo);
            using (var conexao = new SqliteConnection($"Data Source={arquivo};Pooling=False"))
            {
                conexao.Open();
                using var comando = conexao.CreateCommand();
                comando.CommandText = "ALTER TABLE \"Apresentacoes\" DROP COLUMN \"CoralDoLouvor\"";
                comando.ExecuteNonQuery();
            }

            var migrado = new RepositorioTocaEssa(arquivo);
            migrado.MarcarCoralDoLouvor(cenario.Token, cenario.Show.Id, cenario.Hinos[0].Id, 3, true);
            migrado.DefinirConfiguracaoDoLouvor(cenario.Token, cenario.Show.Id,
                new ConfiguracaoDaEscala(CoralNosRefroes: true));
            // Abrir de novo não muda nada: a coluna já existe.
            _ = new RepositorioTocaEssa(arquivo);

            var louvor = new RepositorioTocaEssa(arquivo).ObterLouvor(cenario.Token, cenario.Show.Id);
            Assert.True(louvor.Hinos[0].Partes[3].Coral);
            Assert.False(louvor.Hinos[0].Partes[1].Coral);
            Assert.True(louvor.Configuracao.CoralNosRefroes);
        }
        finally
        {
            SqliteConnection.ClearAllPools();
            foreach (var arquivoDoBanco in new[] { arquivo, $"{arquivo}-shm", $"{arquivo}-wal", $"{arquivo}.json" })
                if (File.Exists(arquivoDoBanco)) File.Delete(arquivoDoBanco);
        }
    }

    [Fact]
    public async Task RotaDoCoralExigeODonoEORoteiroPublicoMostraOCoral()
    {
        var banco = Path.Combine(Path.GetTempPath(), $"tocaessa-api-coral-{Guid.NewGuid():N}.db");
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
                new { nomeArtistico = "Advair" })).EnsureSuccessStatusCode();
            var criada = await ana.PostAsJsonAsync("/api/apresentacoes", new
            {
                nome = "Louvor", data = "2026-10-24", local = "Casa da Bia", tipo = "Louvor"
            });
            criada.EnsureSuccessStatusCode();
            using var jsonShow = JsonDocument.Parse(await criada.Content.ReadAsStringAsync());
            var show = jsonShow.RootElement.GetProperty("apresentacao");
            var showId = show.GetProperty("id").GetGuid();
            var codigo = show.GetProperty("codigo").GetString();
            var setlist = await ana.PostAsJsonAsync(
                $"/api/apresentacoes/{showId}/setlist/avulsa",
                new { titulo = "80 · Por Cristo, resgatado", tom = "G" });
            setlist.EnsureSuccessStatusCode();
            var itemId = (await setlist.Content.ReadFromJsonAsync<JsonElement>())[0]
                .GetProperty("id").GetGuid();
            (await ana.PutAsJsonAsync("/api/artista/cifras/texto", new
            {
                musica = "80 · Por Cristo, resgatado", texto = PorCristoResgatado
            })).EnsureSuccessStatusCode();
            var rota = $"/api/apresentacoes/{showId}/louvor";

            var marcado = await ana.PutAsJsonAsync($"{rota}/coral",
                new { itemId, indice = 0, coral = true });
            Assert.Equal(HttpStatusCode.OK, marcado.StatusCode);
            Assert.True((await marcado.Content.ReadFromJsonAsync<JsonElement>())
                .GetProperty("hinos")[0].GetProperty("partes")[0].GetProperty("coral").GetBoolean());
            Assert.Equal(HttpStatusCode.NotFound, (await bia.PutAsJsonAsync($"{rota}/coral",
                new { itemId, indice = 1, coral = true })).StatusCode);
            Assert.Equal(HttpStatusCode.Unauthorized, (await publico.PutAsJsonAsync($"{rota}/coral",
                new { itemId, indice = 1, coral = true })).StatusCode);
            Assert.Equal(HttpStatusCode.BadRequest, (await ana.PutAsJsonAsync($"{rota}/coral",
                new { itemId, indice = 99, coral = true })).StatusCode);
            var configuracao = await ana.PutAsJsonAsync($"{rota}/configuracao",
                new { coralNosRefroes = true });
            Assert.True((await configuracao.Content.ReadFromJsonAsync<JsonElement>())
                .GetProperty("configuracao").GetProperty("coralNosRefroes").GetBoolean());

            var roteiro = await publico.GetFromJsonAsync<JsonElement>(
                $"/api/publico/apresentacoes/{codigo}/roteiro");
            var partes = roteiro.GetProperty("hinos")[0].GetProperty("partes");
            Assert.True(partes[0].GetProperty("coral").GetBoolean());
            Assert.False(partes[1].GetProperty("coral").GetBoolean());
            Assert.StartsWith("Cristo Jesus", partes[0].GetProperty("texto").GetString());
        }
        finally
        {
            SqliteConnection.ClearAllPools();
            foreach (var arquivo in new[] { banco, $"{banco}-shm", $"{banco}-wal", $"{banco}.json" })
                if (File.Exists(arquivo)) File.Delete(arquivo);
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

    private static Cenario CriarCenario(bool comLetra = true, string? arquivo = null)
    {
        var repo = new RepositorioTocaEssa(arquivo);
        var email = $"advair-{Guid.NewGuid():N}@artista.com";
        var token = repo.CriarContaArtista("Advair", email, "senha").Token;
        repo.SalvarPerfilDaConta(token, new SalvarPerfilArtistico("Advair", null));
        var show = repo.CriarApresentacao(
            token, "Louvor de sábado", new DateOnly(2026, 10, 24), "Casa da Bia",
            TipoApresentacao.Louvor);
        var hinos = repo.AdicionarMusicaAvulsaAoSetlist(
            token, show.Id, "80 · Por Cristo, resgatado", null, "G", null).ToArray();
        repo.DefinirCantoresDoLouvor(token, show.Id, ["João", "Ana"]);
        if (comLetra)
            repo.SalvarCifraEmTexto(token, "80 · Por Cristo, resgatado", null, PorCristoResgatado);
        return new Cenario(repo, token, show, hinos);
    }

    private sealed record Cenario(
        RepositorioTocaEssa Repo, string Token, Apresentacao Show, ItemDoSetlist[] Hinos);
}
