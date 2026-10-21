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

/// Músicas da setlist, hinos ou pedidos vão de uma vez para um repertório,
/// novo ou já existente, sem repetir as que já estão nele.
public class AdicionarAoRepertorioTestes
{
    [Fact]
    public void AdicionaNoFimSemRepetirAsQueJaEstao()
    {
        var c = CriarCenario();

        var resultado = c.Repo.AdicionarMusicasAoRepertorio(c.Token, c.RomanticasId, null,
        [
            new("evidencias", null, null),
            new("Nova", "Banda", "G"),
            new(" nova ", null, null),
        ]);

        Assert.Equal(1, resultado.Adicionadas);
        Assert.Equal(2, resultado.JaEstavam);
        Assert.Equal(["Evidências", "Tempo Perdido", "Nova"],
            resultado.Repertorio.Musicas.Select(m => m.Titulo));
        var nova = resultado.Repertorio.Musicas.Last();
        Assert.Equal(("Banda", "G", 3), (nova.Artista, nova.Tom, nova.Ordem));
    }

    [Fact]
    public void MesmoTituloDeOutroCantorEntra()
    {
        var c = CriarCenario();

        var resultado = c.Repo.AdicionarMusicasAoRepertorio(c.Token, c.RomanticasId, null,
            [new("Evidências", "Outro cantor", null)]);

        Assert.Equal(1, resultado.Adicionadas);
    }

    [Fact]
    public void CriaRepertorioNovoComAsMusicas()
    {
        var c = CriarCenario();

        var resultado = c.Repo.AdicionarMusicasAoRepertorio(c.Token, null, " Show da firma ",
            [new("Macarena", null, null), new("Ragatanga", null, "A")]);

        Assert.Equal("Show da firma", resultado.Repertorio.Nome);
        Assert.Equal(["Macarena", "Ragatanga"], resultado.Repertorio.Musicas.Select(m => m.Titulo));
        Assert.Contains(c.Repo.ListarRepertorios(c.Token), r => r.Id == resultado.Repertorio.Id);
    }

    [Fact]
    public void AvulsaDaSetlistFicaLigadaAoRepertorio()
    {
        var c = CriarCenario();
        c.Repo.AdicionarMusicaAvulsaAoSetlist(c.Token, c.Show.Id, "Parabéns", null, null, null);

        var resultado = c.Repo.AdicionarMusicasAoRepertorio(c.Token, c.RomanticasId, null,
            [new("Parabéns", null, null)]);
        var musica = resultado.Repertorio.Musicas.Single(m => m.Titulo == "Parabéns");
        c.Repo.EditarMusicaDoRepertorio(c.Token, c.RomanticasId, musica.Id, "Parabéns a você", null, "C");

        var item = Assert.Single(c.Repo.ObterSetlist(c.Token, c.Show.Id));
        Assert.Equal(("Parabéns a você", "C"), (item.Titulo, item.Tom));
    }

    [Fact]
    public void RepertorioDeOutroArtistaNaoRecebeNemCriaNada()
    {
        var c = CriarCenario();
        var tokenBia = c.Repo.CriarContaArtista("Bia", "bia@artista.com", "senha").Token;

        Assert.Throws<RepertorioNaoEncontradoException>(() =>
            c.Repo.AdicionarMusicasAoRepertorio(tokenBia, c.RomanticasId, null,
                [new("Invasão", null, null)]));
        Assert.Empty(c.Repo.ListarRepertorios(tokenBia));
        Assert.Equal(2, c.Repo.ListarRepertorios(c.Token).Single(r => r.Id == c.RomanticasId).Musicas.Count);
    }

    [Fact]
    public async Task RotaEhSoDoDonoEValidaOPedido()
    {
        var banco = Path.Combine(Path.GetTempPath(), $"tocaessa-api-ao-repertorio-{Guid.NewGuid():N}.db");
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
            var repo = fabrica.Services.GetRequiredService<RepositorioTocaEssa>();
            var token = repo.CriarContaArtista("Ana", "ana@teste.com", "senha123").Token;
            var romanticas = repo.CriarRepertorio(token, "Românticas");
            var tokenBia = repo.CriarContaArtista("Bia", "bia@teste.com", "senha123").Token;
            using var ana = Cliente(fabrica, token);
            using var bia = Cliente(fabrica, tokenBia);
            using var publico = fabrica.CreateClient();
            const string rota = "/api/artista/repertorios/musicas";
            var musicas = new[] { new { titulo = "Evidências", artista = (string?)null, tom = "G" } };

            var resposta = await ana.PostAsJsonAsync(rota, new { repertorioId = romanticas.Id, musicas });
            Assert.Equal(HttpStatusCode.OK, resposta.StatusCode);
            using (var json = JsonDocument.Parse(await resposta.Content.ReadAsStringAsync()))
            {
                Assert.Equal(1, json.RootElement.GetProperty("adicionadas").GetInt32());
                Assert.Equal(0, json.RootElement.GetProperty("jaEstavam").GetInt32());
                Assert.Equal("Românticas", json.RootElement.GetProperty("repertorio").GetProperty("nome").GetString());
            }
            var novo = await ana.PostAsJsonAsync(rota, new { nomeNovo = "Pedidos do show", musicas });
            Assert.Equal(HttpStatusCode.OK, novo.StatusCode);

            // Destino ausente ou duplo, lista vazia e título em branco.
            foreach (var invalido in new object[]
                     {
                         new { musicas },
                         new { repertorioId = romanticas.Id, nomeNovo = "Outro", musicas },
                         new { nomeNovo = "  ", musicas },
                         new { repertorioId = romanticas.Id, musicas = Array.Empty<object>() },
                         new { repertorioId = romanticas.Id, musicas = new[] { new { titulo = " " } } },
                     })
                Assert.Equal(HttpStatusCode.BadRequest, (await ana.PostAsJsonAsync(rota, invalido)).StatusCode);

            Assert.Equal(HttpStatusCode.NotFound,
                (await bia.PostAsJsonAsync(rota, new { repertorioId = romanticas.Id, musicas })).StatusCode);
            Assert.Equal(HttpStatusCode.Unauthorized,
                (await publico.PostAsJsonAsync(rota, new { nomeNovo = "Invasão", musicas })).StatusCode);
            Assert.Equal(2, repo.ListarRepertorios(token).Count);
        }
        finally
        {
            SqliteConnection.ClearAllPools();
            foreach (var arquivo in new[] { banco, $"{banco}-shm", $"{banco}-wal", $"{banco}.json" })
                if (File.Exists(arquivo)) File.Delete(arquivo);
        }
    }

    private static HttpClient Cliente(WebApplicationFactory<Program> fabrica, string token)
    {
        var cliente = fabrica.CreateClient();
        cliente.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);
        return cliente;
    }

    private static Cenario CriarCenario()
    {
        var repo = new RepositorioTocaEssa();
        var token = repo.CriarContaArtista("Ana", "ana@artista.com", "senha").Token;
        repo.SalvarPerfilDaConta(token, new SalvarPerfilArtistico("Ana", null));
        var show = repo.CriarApresentacao(token, "Confraternização", new DateOnly(2026, 12, 12), "Salão");
        var romanticas = repo.CriarRepertorio(token, "Românticas");
        repo.AdicionarMusicaAoRepertorio(token, romanticas.Id, "Evidências", "Chitãozinho & Xororó");
        repo.AdicionarMusicaAoRepertorio(token, romanticas.Id, "Tempo Perdido", null);
        return new Cenario(repo, token, show, romanticas.Id);
    }

    private sealed record Cenario(RepositorioTocaEssa Repo, string Token, Apresentacao Show, Guid RomanticasId);
}
