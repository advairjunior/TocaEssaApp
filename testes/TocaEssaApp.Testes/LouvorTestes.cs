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

public sealed class LouvorTestes
{
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
    public void HinoComecaSemNinguemEEscalarDistribuiPelosPontos()
    {
        var cenario = CriarCenario();

        var louvor = cenario.Repo.DefinirCantoresDoLouvor(
            cenario.Token, cenario.Show.Id, ["João", "Ana"]);

        Assert.Equal(["João", "Ana"], louvor.Cantores);
        var primeiro = louvor.Hinos[0];
        Assert.Equal("80 · Por Cristo, resgatado", primeiro.Titulo);
        Assert.Equal("G", primeiro.Tom);
        Assert.True(primeiro.TemLetra);
        Assert.Equal(6, primeiro.Partes.Count);
        Assert.All(primeiro.Partes, parte => Assert.False(parte.Definida));
        var semLetra = louvor.Hinos[1];
        Assert.False(semLetra.TemLetra);
        Assert.Empty(semLetra.Partes);

        var escalado = cenario.Repo.EscalarHinoDoLouvor(
            cenario.Token, cenario.Show.Id, cenario.Hinos[0].Id);

        Assert.Equal(
            ["João", "Ana", "João", "Ana", "João", "Todos"],
            escalado.Hinos[0].Partes.Select(parte =>
                parte.Cantores.Count == 0 ? "Todos" : string.Join(" e ", parte.Cantores)));
        Assert.All(escalado.Hinos[0].Partes, parte => Assert.True(parte.Definida));
        Assert.Equal(
            [new PlacarDoCantor("João", 3), new PlacarDoCantor("Ana", 2)],
            escalado.Placar);
        Assert.Throws<ItemDoSetlistNaoEncontradoException>(() =>
            cenario.Repo.EscalarHinoDoLouvor(cenario.Token, cenario.Show.Id, Guid.NewGuid()));
    }

    [Fact]
    public void HinoTrazOCantorDoItemParaColarALetraNoLugarCerto()
    {
        var cenario = CriarCenario();
        cenario.Repo.AdicionarMusicaAvulsaAoSetlist(
            cenario.Token, cenario.Show.Id, "5 · Hino da CCB", "CCB", null, null);
        cenario.Repo.SalvarCifraEmTexto(cenario.Token, "5 · Hino da CCB", "CCB", "Uma estrofe");

        var hino = cenario.Repo.ObterLouvor(cenario.Token, cenario.Show.Id).Hinos[2];

        Assert.Equal("CCB", hino.Artista);
        Assert.True(hino.TemLetra);
        Assert.Null(cenario.Repo.ObterLouvor(cenario.Token, cenario.Show.Id).Hinos[0].Artista);
    }

    [Fact]
    public void CantoresFicamSemNomeVazioNemRepetido()
    {
        var cenario = CriarCenario();

        var louvor = cenario.Repo.DefinirCantoresDoLouvor(
            cenario.Token, cenario.Show.Id, [" João ", "joão", "", "  ", "Ana"]);

        Assert.Equal(["João", "Ana"], louvor.Cantores);
        Assert.Equal(["João", "Ana"],
            cenario.Repo.ObterLouvor(cenario.Token, cenario.Show.Id).Cantores);
    }

    [Fact]
    public void ParteTrocadaAMaoFicaELimparDeixaSemNinguem()
    {
        var cenario = CriarCenario();
        cenario.Repo.DefinirCantoresDoLouvor(cenario.Token, cenario.Show.Id, ["João", "Ana"]);
        var hino = cenario.Hinos[0].Id;

        var escolhida = cenario.Repo.EscolherParteDoLouvor(
            cenario.Token, cenario.Show.Id, hino, 0, ["Ana"]);
        Assert.Equal(["Ana"], escolhida.Hinos[0].Partes[0].Cantores);
        Assert.True(escolhida.Hinos[0].Partes[0].Definida);
        Assert.False(escolhida.Hinos[0].Partes[2].Definida);

        var todos = cenario.Repo.EscolherParteDoLouvor(
            cenario.Token, cenario.Show.Id, hino, 2, []);
        Assert.Empty(todos.Hinos[0].Partes[2].Cantores);
        Assert.True(todos.Hinos[0].Partes[2].Definida);

        var limpa = cenario.Repo.EscolherParteDoLouvor(
            cenario.Token, cenario.Show.Id, hino, 0, null);
        Assert.False(limpa.Hinos[0].Partes[0].Definida);
        Assert.Empty(limpa.Hinos[0].Partes[0].Cantores);
    }

    [Fact]
    public void EscolhaInvalidaEhRecusada()
    {
        var cenario = CriarCenario();
        cenario.Repo.DefinirCantoresDoLouvor(cenario.Token, cenario.Show.Id, ["João", "Ana"]);
        var hino = cenario.Hinos[0].Id;

        Assert.Throws<EscolhaDoLouvorInvalidaException>(() =>
            cenario.Repo.EscolherParteDoLouvor(
                cenario.Token, cenario.Show.Id, hino, 0, ["Pedro"]));
        Assert.Throws<EscolhaDoLouvorInvalidaException>(() =>
            cenario.Repo.EscolherParteDoLouvor(
                cenario.Token, cenario.Show.Id, hino, 6, ["Ana"]));
        Assert.Throws<ItemDoSetlistNaoEncontradoException>(() =>
            cenario.Repo.EscolherParteDoLouvor(
                cenario.Token, cenario.Show.Id, Guid.NewGuid(), 0, ["Ana"]));
    }

    [Fact]
    public void TirarCantorDaListaDevolveAsPartesDeleAEscala()
    {
        var cenario = CriarCenario();
        cenario.Repo.DefinirCantoresDoLouvor(cenario.Token, cenario.Show.Id, ["João", "Ana"]);
        cenario.Repo.EscolherParteDoLouvor(
            cenario.Token, cenario.Show.Id, cenario.Hinos[0].Id, 0, ["Ana", "João"]);
        cenario.Repo.EscolherParteDoLouvor(
            cenario.Token, cenario.Show.Id, cenario.Hinos[0].Id, 2, ["Ana"]);

        var louvor = cenario.Repo.DefinirCantoresDoLouvor(
            cenario.Token, cenario.Show.Id, ["João"]);

        Assert.Equal(["João"], louvor.Hinos[0].Partes[0].Cantores);
        Assert.True(louvor.Hinos[0].Partes[0].Definida);
        Assert.False(louvor.Hinos[0].Partes[2].Definida);
    }

    [Fact]
    public void RoteiroPublicoMostraOHinoAtualSoNoLouvor()
    {
        var cenario = CriarCenario();
        cenario.Repo.DefinirCantoresDoLouvor(cenario.Token, cenario.Show.Id, ["João", "Ana"]);

        var antes = cenario.Repo.ObterRoteiroDoLouvor(cenario.Show.Codigo.ToLowerInvariant());
        Assert.Null(antes.HinoAtualId);
        Assert.Equal("Louvor de sábado", antes.Nome);
        Assert.Equal(["João", "Ana"], antes.Cantores);
        Assert.Equal(6, antes.Hinos[0].Partes.Count);

        cenario.Repo.MarcarItemDoSetlist(cenario.Token, cenario.Show.Id, cenario.Hinos[0].Id, true);
        Assert.Equal(cenario.Hinos[0].Id,
            cenario.Repo.ObterRoteiroDoLouvor(cenario.Show.Codigo).HinoAtualId);
        cenario.Repo.MarcarItemDoSetlist(cenario.Token, cenario.Show.Id, cenario.Hinos[1].Id, true);
        Assert.Equal(cenario.Hinos[1].Id,
            cenario.Repo.ObterRoteiroDoLouvor(cenario.Show.Codigo).HinoAtualId);

        var show = cenario.Repo.CriarApresentacao(
            cenario.Token, "Bar", new DateOnly(2026, 10, 25), "Bar");
        Assert.Throws<ApresentacaoNaoEncontradaException>(() =>
            cenario.Repo.ObterRoteiroDoLouvor(show.Codigo));
        Assert.Throws<ApresentacaoNaoEncontradaException>(() =>
            cenario.Repo.ObterRoteiroDoLouvor("NAOEXISTE"));
    }

    [Fact]
    public void SolistasTocamOsSolosDoInstrumentoDeles()
    {
        var cenario = CriarCenario();
        var hinos = cenario.Repo.AdicionarMusicaAvulsaAoSetlist(
            cenario.Token, cenario.Show.Id, "12 · Hino com solo", null, "G", null);
        var hinoComSolo = hinos.Single(item => item.Titulo == "12 · Hino com solo");
        cenario.Repo.SalvarCifraEmTexto(cenario.Token, "12 · Hino com solo", null,
            "(Estrofe 1)\nA1\n(Solo sax tenor)\nG   D\n(Estrofe 2)\nB1");

        var louvor = cenario.Repo.DefinirSolistasDoLouvor(cenario.Token, cenario.Show.Id,
        [
            new Solista(" José ", " sax tenor "),
            new Solista("josé", "trompete"),
            new Solista("  ", "sax"),
            new Solista("Pedro", "")
        ]);

        Assert.Equal([new Solista("José", "sax tenor"), new Solista("Pedro", "")],
            louvor.Solistas);
        Assert.False(louvor.Hinos.Single(hino => hino.ItemId == hinoComSolo.Id)
            .Partes[1].Definida);
        louvor = cenario.Repo.EscalarHinoDoLouvor(cenario.Token, cenario.Show.Id, hinoComSolo.Id);
        var solo = louvor.Hinos.Single(hino => hino.ItemId == hinoComSolo.Id).Partes[1];
        Assert.Equal(TipoDaParte.Instrumental, solo.Tipo);
        Assert.Equal(["José"], solo.Cantores);
        Assert.Equal(
            [new PlacarDoSolista("José", 1), new PlacarDoSolista("Pedro", 0)],
            louvor.PlacarDosSolos);
        Assert.Equal(louvor.Solistas,
            cenario.Repo.ObterRoteiroDoLouvor(cenario.Show.Codigo).Solistas);

        var aMao = cenario.Repo.EscolherParteDoLouvor(
            cenario.Token, cenario.Show.Id, hinoComSolo.Id, 1, ["Pedro"]);
        Assert.Equal(["Pedro"],
            aMao.Hinos.Single(hino => hino.ItemId == hinoComSolo.Id).Partes[1].Cantores);

        var semPedro = cenario.Repo.DefinirSolistasDoLouvor(
            cenario.Token, cenario.Show.Id, [new Solista("José", "sax tenor")]);
        var devolvido = semPedro.Hinos.Single(hino => hino.ItemId == hinoComSolo.Id).Partes[1];
        Assert.False(devolvido.Definida);
        Assert.Empty(devolvido.Cantores);
    }

    [Fact]
    public void OutroArtistaNaoMexeNosSolistas()
    {
        var cenario = CriarCenario();
        var tokenBia = cenario.Repo.CriarContaArtista("Bia", "bia@artista.com", "senha").Token;

        Assert.Throws<ApresentacaoNaoEncontradaException>(() =>
            cenario.Repo.DefinirSolistasDoLouvor(
                tokenBia, cenario.Show.Id, [new Solista("Bia", "sax")]));
        Assert.Empty(cenario.Repo.ObterLouvor(cenario.Token, cenario.Show.Id).Solistas);
    }

    [Fact]
    public void OutroArtistaNaoVeNemAlteraOLouvor()
    {
        var cenario = CriarCenario();
        var tokenBia = cenario.Repo.CriarContaArtista("Bia", "bia@artista.com", "senha").Token;

        Assert.Throws<ApresentacaoNaoEncontradaException>(() =>
            cenario.Repo.ObterLouvor(tokenBia, cenario.Show.Id));
        Assert.Throws<ApresentacaoNaoEncontradaException>(() =>
            cenario.Repo.DefinirCantoresDoLouvor(tokenBia, cenario.Show.Id, ["Bia"]));
        Assert.Throws<ApresentacaoNaoEncontradaException>(() =>
            cenario.Repo.EscolherParteDoLouvor(
                tokenBia, cenario.Show.Id, cenario.Hinos[0].Id, 0, []));
        Assert.Empty(cenario.Repo.ObterLouvor(cenario.Token, cenario.Show.Id).Cantores);
    }

    [Fact]
    public void LouvorSobreviveAoReinicioEBancoAntigoGanhaAsColunas()
    {
        var arquivo = Path.Combine(Path.GetTempPath(), $"tocaessa-louvor-{Guid.NewGuid():N}.db");
        try
        {
            var cenario = CriarCenario(arquivo);
            using (var conexao = new SqliteConnection($"Data Source={arquivo};Pooling=False"))
            {
                conexao.Open();
                using var comando = conexao.CreateCommand();
                comando.CommandText =
                    "ALTER TABLE \"Apresentacoes\" DROP COLUMN \"CantoresDoLouvor\";" +
                    "ALTER TABLE \"Apresentacoes\" DROP COLUMN \"EscolhasDoLouvor\";" +
                    "ALTER TABLE \"Apresentacoes\" DROP COLUMN \"SolistasDoLouvor\"";
                comando.ExecuteNonQuery();
            }

            var migrado = new RepositorioTocaEssa(arquivo);
            Assert.Empty(migrado.ObterLouvor(cenario.Token, cenario.Show.Id).Cantores);
            migrado.DefinirCantoresDoLouvor(cenario.Token, cenario.Show.Id, ["João", "Ana"]);
            migrado.DefinirSolistasDoLouvor(cenario.Token, cenario.Show.Id, [new Solista("José", "sax")]);
            migrado.EscolherParteDoLouvor(
                cenario.Token, cenario.Show.Id, cenario.Hinos[0].Id, 0, ["Ana"]);

            var reiniciado = new RepositorioTocaEssa(arquivo);
            var louvor = reiniciado.ObterLouvor(cenario.Token, cenario.Show.Id);

            Assert.Equal(["João", "Ana"], louvor.Cantores);
            Assert.Equal([new Solista("José", "sax")], louvor.Solistas);
            Assert.Equal(["Ana"], louvor.Hinos[0].Partes[0].Cantores);
            Assert.True(louvor.Hinos[0].Partes[0].Definida);
            Assert.Equal(TipoApresentacao.Louvor,
                reiniciado.ObterApresentacaoPublica(cenario.Show.Codigo)!.Tipo);
        }
        finally
        {
            ExcluirBanco(arquivo);
        }
    }

    [Fact]
    public async Task RotasDoLouvorExigemODonoEORoteiroEhPublico()
    {
        var banco = Path.Combine(Path.GetTempPath(), $"tocaessa-api-louvor-{Guid.NewGuid():N}.db");
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
            Assert.Equal("Louvor", show.GetProperty("tipo").GetString());
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

            var cantores = await ana.PutAsJsonAsync($"{rota}/cantores",
                new { nomes = new[] { "João", "Ana" } });
            Assert.Equal(HttpStatusCode.OK, cantores.StatusCode);
            var solistas = await ana.PutAsJsonAsync($"{rota}/solistas",
                new { solistas = new[] { new { nome = "José", instrumento = "sax" } } });
            Assert.Equal(HttpStatusCode.OK, solistas.StatusCode);
            Assert.Equal("sax", (await solistas.Content.ReadFromJsonAsync<JsonElement>())
                .GetProperty("solistas")[0].GetProperty("instrumento").GetString());
            Assert.Equal(HttpStatusCode.NotFound, (await bia.PutAsJsonAsync($"{rota}/solistas",
                new { solistas = new[] { new { nome = "Bia", instrumento = "sax" } } })).StatusCode);
            var escalado = await ana.PostAsync($"{rota}/hinos/{itemId}/escalar", null);
            Assert.Equal(HttpStatusCode.OK, escalado.StatusCode);
            Assert.True((await escalado.Content.ReadFromJsonAsync<JsonElement>())
                .GetProperty("hinos")[0].GetProperty("partes")[0].GetProperty("definida").GetBoolean());
            Assert.Equal(HttpStatusCode.NotFound,
                (await bia.PostAsync($"{rota}/hinos/{itemId}/escalar", null)).StatusCode);
            var escolha = await ana.PutAsJsonAsync($"{rota}/partes",
                new { itemId, indice = 0, cantores = new[] { "Ana" } });
            Assert.Equal(HttpStatusCode.OK, escolha.StatusCode);
            var louvor = await ana.GetFromJsonAsync<JsonElement>(rota);
            var parte = louvor.GetProperty("hinos")[0].GetProperty("partes")[0];
            Assert.Equal("Estrofe", parte.GetProperty("tipo").GetString());
            Assert.Equal("Ana", parte.GetProperty("cantores")[0].GetString());
            Assert.Equal(HttpStatusCode.BadRequest, (await ana.PutAsJsonAsync($"{rota}/partes",
                new { itemId, indice = 0, cantores = new[] { "Pedro" } })).StatusCode);

            Assert.Equal(HttpStatusCode.NotFound, (await bia.GetAsync(rota)).StatusCode);
            Assert.Equal(HttpStatusCode.NotFound, (await bia.PutAsJsonAsync($"{rota}/cantores",
                new { nomes = new[] { "Bia" } })).StatusCode);
            Assert.Equal(HttpStatusCode.Unauthorized, (await publico.GetAsync(rota)).StatusCode);

            var roteiro = await publico.GetFromJsonAsync<JsonElement>(
                $"/api/publico/apresentacoes/{codigo}/roteiro");
            Assert.Equal("Ana", roteiro.GetProperty("hinos")[0].GetProperty("partes")[0]
                .GetProperty("cantores")[0].GetString());
            Assert.StartsWith("Cristo Jesus", roteiro.GetProperty("hinos")[0]
                .GetProperty("partes")[0].GetProperty("texto").GetString());

            Assert.Equal(HttpStatusCode.OK,
                (await publico.GetAsync($"/api/publico/apresentacoes/{codigo}")).StatusCode);
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

    private static Cenario CriarCenario(string? arquivo = null)
    {
        var repo = new RepositorioTocaEssa(arquivo);
        var token = repo.CriarContaArtista("Advair", "advair@artista.com", "senha").Token;
        repo.SalvarPerfilDaConta(token, new SalvarPerfilArtistico("Advair", null));
        var show = repo.CriarApresentacao(
            token, "Louvor de sábado", new DateOnly(2026, 10, 24), "Casa da Bia",
            TipoApresentacao.Louvor);
        repo.AdicionarMusicaAvulsaAoSetlist(
            token, show.Id, "80 · Por Cristo, resgatado", null, "G", null);
        var hinos = repo.AdicionarMusicaAvulsaAoSetlist(
            token, show.Id, "234 · O meu ser entrego a Cristo", null, "A", null).ToArray();
        repo.SalvarCifraEmTexto(token, "80 · Por Cristo, resgatado", null, PorCristoResgatado);
        return new Cenario(repo, token, show, hinos);
    }

    private static void ExcluirBanco(string caminho)
    {
        SqliteConnection.ClearAllPools();
        foreach (var arquivo in new[] { caminho, $"{caminho}-shm", $"{caminho}-wal", $"{caminho}.json" })
            if (File.Exists(arquivo)) File.Delete(arquivo);
    }

    private sealed record Cenario(
        RepositorioTocaEssa Repo, string Token, Apresentacao Show, ItemDoSetlist[] Hinos);
}
