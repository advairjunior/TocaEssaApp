using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.DependencyInjection.Extensions;
using Microsoft.Extensions.Logging;
using TocaEssaApp.Api.Infraestrutura;

namespace TocaEssaApp.Testes;

public class CifrasApiTestes
{
    [Fact]
    public async Task RotasExigemArtistaESalvamCifra()
    {
        var banco = Path.Combine(Path.GetTempPath(),
            $"tocaessa-api-cifras-{Guid.NewGuid()}.db");
        try
        {
            await using var fabrica = new WebApplicationFactory<Program>()
                .WithWebHostBuilder(builder =>
                {
                    builder.ConfigureLogging(logging => logging.ClearProviders());
                    builder.ConfigureAppConfiguration((_, configuracao) =>
                        configuracao.AddInMemoryCollection(
                            new Dictionary<string, string?>
                            {
                                ["ConnectionStrings:DefaultConnection"] = banco,
                                ["Aplicacao:ArquivoBanco"] = banco,
                                ["Aplicacao:ArquivoDados"] = $"{banco}.json"
                            }));
                    builder.ConfigureServices(servicos =>
                    {
                        servicos.RemoveAll<RepositorioTocaEssa>();
                        servicos.AddSingleton(new RepositorioTocaEssa(
                            banco, $"{banco}.json"));
                    });
                });
            using var cliente = fabrica.CreateClient();

            var semSessao = await cliente.GetAsync(
                "/api/artista/cifras/consulta?musica=Evidencias");
            Assert.Equal(HttpStatusCode.Unauthorized, semSessao.StatusCode);

            var cadastro = await cliente.PostAsJsonAsync("/api/artista/contas", new
            {
                nome = "Ana",
                email = "ana@teste.com",
                senha = "senha123"
            });
            cadastro.EnsureSuccessStatusCode();
            var sessao = await cadastro.Content.ReadFromJsonAsync<SessaoResposta>();
            Assert.False(string.IsNullOrWhiteSpace(sessao?.Token));
            cliente.DefaultRequestHeaders.Authorization =
                new AuthenticationHeaderValue("Bearer", sessao!.Token);

            var consulta = await cliente.GetFromJsonAsync<ConsultaResposta>(
                "/api/artista/cifras/consulta?musica=Evidencias&artista=Chitaozinho");
            Assert.Null(consulta!.Cifra);
            Assert.Contains("cifraclub.com.br", consulta.UrlSugerida);

            var salvar = await cliente.PutAsJsonAsync("/api/artista/cifras", new
            {
                musica = "Evidencias",
                artista = "Chitaozinho",
                url = "https://www.cifraclub.com.br/chitaozinho/evidencias/"
            });
            salvar.EnsureSuccessStatusCode();
            var cifra = await salvar.Content.ReadFromJsonAsync<CifraResposta>();

            var lista = await cliente.GetFromJsonAsync<List<CifraResposta>>(
                "/api/artista/cifras");
            Assert.Equal(cifra!.Id, Assert.Single(lista!).Id);

            var excluir = await cliente.DeleteAsync($"/api/artista/cifras/{cifra.Id}");
            Assert.Equal(HttpStatusCode.NoContent, excluir.StatusCode);
        }
        finally
        {
            foreach (var arquivo in new[] { banco, $"{banco}-shm", $"{banco}-wal" })
                if (File.Exists(arquivo)) File.Delete(arquivo);
        }
    }

    private sealed record SessaoResposta(string Token);
    private sealed record ConsultaResposta(
        CifraResposta? Cifra, string? UrlSugerida, string UrlPesquisa);
    private sealed record CifraResposta(Guid Id, string Url);
}
