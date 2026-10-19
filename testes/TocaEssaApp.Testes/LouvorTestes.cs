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
    public void LouvorEscalaAsEstrofesDaLetraColadaNosHinosDaSetlist()
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
        Assert.Equal(["João"], primeiro.Partes[0].Cantores);
        Assert.Equal(["Ana"], primeiro.Partes[2].Cantores);
        Assert.Empty(primeiro.Partes[4].Cantores);
        var semLetra = louvor.Hinos[1];
        Assert.False(semLetra.TemLetra);
        Assert.Empty(semLetra.Partes);
        Assert.Equal(
            [new PlacarDoCantor("João", 1), new PlacarDoCantor("Ana", 1)],
            louvor.Placar);
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
    public void ParteEscolhidaAMaoFicaEAutomaticoDevolveAEscala()
    {
        var cenario = CriarCenario();
        cenario.Repo.DefinirCantoresDoLouvor(cenario.Token, cenario.Show.Id, ["João", "Ana"]);
        var hino = cenario.Hinos[0].Id;

        var escolhida = cenario.Repo.EscolherParteDoLouvor(
            cenario.Token, cenario.Show.Id, hino, 0, ["Ana"]);
        Assert.Equal(["Ana"], escolhida.Hinos[0].Partes[0].Cantores);
        Assert.True(escolhida.Hinos[0].Partes[0].EscolhidaAMao);
        Assert.Equal(["João"], escolhida.Hinos[0].Partes[2].Cantores);

        var todos = cenario.Repo.EscolherParteDoLouvor(
            cenario.Token, cenario.Show.Id, hino, 2, []);
        Assert.Empty(todos.Hinos[0].Partes[2].Cantores);
        Assert.True(todos.Hinos[0].Partes[2].EscolhidaAMao);

        var automatico = cenario.Repo.EscolherParteDoLouvor(
            cenario.Token, cenario.Show.Id, hino, 0, null);
        Assert.False(automatico.Hinos[0].Partes[0].EscolhidaAMao);
        Assert.Equal(["João"], automatico.Hinos[0].Partes[0].Cantores);
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
        Assert.True(louvor.Hinos[0].Partes[0].EscolhidaAMao);
        Assert.False(louvor.Hinos[0].Partes[2].EscolhidaAMao);
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
                    "ALTER TABLE \"Apresentacoes\" DROP COLUMN \"EscolhasDoLouvor\"";
                comando.ExecuteNonQuery();
            }

            var migrado = new RepositorioTocaEssa(arquivo);
            Assert.Empty(migrado.ObterLouvor(cenario.Token, cenario.Show.Id).Cantores);
            migrado.DefinirCantoresDoLouvor(cenario.Token, cenario.Show.Id, ["João", "Ana"]);
            migrado.EscolherParteDoLouvor(
                cenario.Token, cenario.Show.Id, cenario.Hinos[0].Id, 0, ["Ana"]);

            var reiniciado = new RepositorioTocaEssa(arquivo);
            var louvor = reiniciado.ObterLouvor(cenario.Token, cenario.Show.Id);

            Assert.Equal(["João", "Ana"], louvor.Cantores);
            Assert.Equal(["Ana"], louvor.Hinos[0].Partes[0].Cantores);
            Assert.True(louvor.Hinos[0].Partes[0].EscolhidaAMao);
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
