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

/// Quem pede sem conta informa o nome, para o artista saber quem pediu.
public class NomeObrigatorioTestes
{
    [Theory]
    [InlineData(null)]
    [InlineData("")]
    [InlineData("   ")]
    [InlineData("a")]
    [InlineData(". .")]
    public void PedidoSemContaPrecisaDeNome(string? nome)
    {
        var (repo, show, _) = CriarCenario();

        Assert.Throws<NomeDoSolicitanteObrigatorioException>(() =>
            repo.CriarPedido(show.Codigo, "Evidências", null, nome));
        Assert.Throws<NomeDoSolicitanteObrigatorioException>(() =>
            repo.CriarPedido(show.Codigo, "", null, nome,
                tipo: TipoPedido.Alo, destinatarioAlo: "Bia"));
    }

    [Fact]
    public void PrimeiroNomeBasta()
    {
        var (repo, show, _) = CriarCenario();

        var pedido = repo.CriarPedido(show.Codigo, "Evidências", null, " Rui ");

        Assert.Equal("Rui", pedido.NomeSolicitante);
    }

    [Fact]
    public void ComContaONomeVemDoPerfil()
    {
        var (repo, show, _) = CriarCenario();
        var ana = repo.CriarPerfilPublico("Ana", "ana@teste.com", "senha123");

        var pedido = repo.CriarPedido(show.Codigo, "Evidências", null, null, ana.Token);

        Assert.Equal("Ana", pedido.NomeSolicitante);
    }

    [Fact]
    public async Task RotaPublicaRecusaPedidoSemNome()
    {
        var banco = Path.Combine(Path.GetTempPath(), $"tocaessa-api-nome-{Guid.NewGuid():N}.db");
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
            using var artista = fabrica.CreateClient();
            var conta = await artista.PostAsJsonAsync(
                "/api/artista/contas", new { nome = "Ana", email = "ana@teste.com", senha = "senha123" });
            using (var json = JsonDocument.Parse(await conta.Content.ReadAsStringAsync()))
                artista.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue(
                    "Bearer", json.RootElement.GetProperty("token").GetString());
            (await artista.PutAsJsonAsync("/api/perfil-artistico",
                new { nomeArtistico = "Duo Aurora" })).EnsureSuccessStatusCode();
            var criada = await artista.PostAsJsonAsync("/api/apresentacoes", new
            {
                nome = "Show", data = "2026-10-17", local = "Bar", tipo = "Publica"
            });
            using var jsonShow = JsonDocument.Parse(await criada.Content.ReadAsStringAsync());
            var codigo = jsonShow.RootElement.GetProperty("apresentacao").GetProperty("codigo").GetString();
            var rota = $"/api/publico/apresentacoes/{codigo}/pedidos";

            var semNome = await publico.PostAsJsonAsync(rota, new { musica = "Evidências" });
            Assert.Equal(HttpStatusCode.BadRequest, semNome.StatusCode);
            using (var json = JsonDocument.Parse(await semNome.Content.ReadAsStringAsync()))
                Assert.Equal("Informe seu nome.", json.RootElement.GetProperty("mensagem").GetString());

            var comNome = await publico.PostAsJsonAsync(
                rota, new { musica = "Evidências", nomeSolicitante = "Rui" });
            Assert.Equal(HttpStatusCode.Created, comNome.StatusCode);
        }
        finally
        {
            SqliteConnection.ClearAllPools();
            foreach (var arquivo in new[] { banco, $"{banco}-shm", $"{banco}-wal", $"{banco}.json" })
                if (File.Exists(arquivo)) File.Delete(arquivo);
        }
    }

    private static (RepositorioTocaEssa Repo, Apresentacao Show, string Token) CriarCenario()
    {
        var repo = new RepositorioTocaEssa();
        var token = repo.CriarContaArtista("Ana", "ana@artista.com", "senha").Token;
        repo.SalvarPerfilDaConta(token, new SalvarPerfilArtistico("Ana", null));
        var show = repo.CriarApresentacao(token, "Show", new DateOnly(2026, 10, 17), "Bar");
        return (repo, show, token);
    }
}
