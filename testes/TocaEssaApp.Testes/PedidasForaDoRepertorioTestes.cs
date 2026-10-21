using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
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

/// Músicas pedidas pelo público em todos os shows do artista que ainda não
/// estão em nenhum repertório, as mais pedidas primeiro.
public class PedidasForaDoRepertorioTestes
{
    [Fact]
    public void JuntaOsShowsEDeixaDeForaOQueJaEstaNoAcervo()
    {
        var repo = new RepositorioTocaEssa();
        var token = CriarArtista(repo, "ana@artista.com");
        var bar = repo.CriarApresentacao(token, "Bar", new DateOnly(2026, 10, 1), "Bar");
        var festa = repo.CriarApresentacao(token, "Festa", new DateOnly(2026, 10, 8), "Salão");
        var acervo = repo.CriarRepertorio(token, "Barzinho");
        repo.AdicionarMusicaAoRepertorio(token, acervo.Id, "Evidências", null);

        repo.CriarPedido(bar.Codigo, "Garçom", "Reginaldo Rossi", "Ana");
        repo.CriarPedido(bar.Codigo, "garcom", null, "Bia");
        repo.CriarPedido(festa.Codigo, "Garçom", null, "Caio");
        repo.CriarPedido(festa.Codigo, "Trem-Bala", null, "Duda");
        repo.CriarPedido(festa.Codigo, "EVIDENCIAS", null, "Edu");
        repo.CriarPedido(festa.Codigo, "Fim", null, "Fê", tipo: TipoPedido.Alo, destinatarioAlo: "Noivos");
        var desistiu = repo.CriarPedido(festa.Codigo, "Desistiu", null, "Gil");
        repo.CancelarPedidoPeloPublico(festa.Codigo, desistiu.Id);

        var pedidas = repo.ListarPedidasForaDoRepertorio(token);

        Assert.Equal(
            [("Garçom", "Reginaldo Rossi", 3, 2), ("Trem-Bala", (string?)null, 1, 1)],
            pedidas.Select(p => (p.Musica, p.Artista, p.Vezes, p.Shows)));
    }

    [Fact]
    public void PedidosDosShowsDeOutroArtistaNaoEntram()
    {
        var repo = new RepositorioTocaEssa();
        var tokenAna = CriarArtista(repo, "ana@artista.com");
        var tokenBia = CriarArtista(repo, "bia@artista.com");
        var showDaBia = repo.CriarApresentacao(tokenBia, "Bia ao vivo", new DateOnly(2026, 10, 1), "Bar");
        repo.CriarPedido(showDaBia.Codigo, "Segredo", null, "Caio");

        Assert.Empty(repo.ListarPedidasForaDoRepertorio(tokenAna));
        Assert.Single(repo.ListarPedidasForaDoRepertorio(tokenBia));
    }

    [Fact]
    public async Task RotaExigeOToken()
    {
        var banco = Path.Combine(Path.GetTempPath(), $"tocaessa-api-pedidas-{Guid.NewGuid():N}.db");
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
            var token = CriarArtista(repo, "ana@teste.com");
            var show = repo.CriarApresentacao(token, "Bar", new DateOnly(2026, 10, 1), "Bar");
            repo.CriarPedido(show.Codigo, "Garçom", null, "Ana");
            using var ana = fabrica.CreateClient();
            ana.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);
            using var publico = fabrica.CreateClient();
            const string rota = "/api/artista/repertorios/pedidas-fora";

            var pedidas = await ana.GetFromJsonAsync<PedidaForaDoRepertorio[]>(rota);
            Assert.Equal("Garçom", Assert.Single(pedidas!).Musica);
            Assert.Equal(HttpStatusCode.Unauthorized, (await publico.GetAsync(rota)).StatusCode);
        }
        finally
        {
            SqliteConnection.ClearAllPools();
            foreach (var arquivo in new[] { banco, $"{banco}-shm", $"{banco}-wal", $"{banco}.json" })
                if (File.Exists(arquivo)) File.Delete(arquivo);
        }
    }

    private static string CriarArtista(RepositorioTocaEssa repo, string email)
    {
        var token = repo.CriarContaArtista("Artista", email, "senha123").Token;
        repo.SalvarPerfilDaConta(token, new SalvarPerfilArtistico("Artista", null));
        return token;
    }
}
