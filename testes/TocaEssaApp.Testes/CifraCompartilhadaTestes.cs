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

/// Link de uma música fora do louvor: quem recebe vê a cifra pelo código,
/// sem conta, sempre na versão mais nova.
public class CifraCompartilhadaTestes
{
    [Fact]
    public void LinkVivoMostraACifraAtualDoArtista()
    {
        var repo = new RepositorioTocaEssa();
        var token = CriarArtista(repo, "ana@artista.com", "Duo Aurora");
        repo.SalvarCifraEmTexto(token, "Evidências", "Chitãozinho & Xororó", "Tom: A\nA    E\nQuando eu digo");

        var codigo = repo.CodigoParaCompartilharCifra(token, "evidencias", null);
        repo.SalvarCifraEmTexto(token, "Evidências", "Chitãozinho & Xororó", "Tom: G\nG    D\nQuando eu digo");
        var cifra = repo.ObterCifraCompartilhada(codigo);

        // Corrigir a cifra não muda o link: o amigo vê a versão nova.
        Assert.Equal(codigo, repo.CodigoParaCompartilharCifra(token, "Evidências", "Chitãozinho & Xororó"));
        Assert.NotNull(cifra);
        Assert.Equal(("Evidências", "Chitãozinho & Xororó", "G", "Duo Aurora"),
            (cifra.Musica, cifra.Artista, cifra.Tom, cifra.NomeArtistico));
        Assert.StartsWith("Tom: G", cifra.Texto);
    }

    [Fact]
    public void SemCifraColadaNaoHaLinkECodigoDesconhecidoNaoAcha()
    {
        var repo = new RepositorioTocaEssa();
        var token = CriarArtista(repo, "ana@artista.com", "Duo Aurora");
        var tokenBia = CriarArtista(repo, "bia@artista.com", "Bia");
        repo.SalvarCifraEmTexto(tokenBia, "Segredo", null, "C   G\nSegredo");

        Assert.Throws<CifraDoArtistaNaoEncontradaException>(() =>
            repo.CodigoParaCompartilharCifra(token, "Segredo", null));
        Assert.Null(repo.ObterCifraCompartilhada(Guid.NewGuid()));
    }

    [Fact]
    public async Task RotaPrivadaGeraOLinkEAPublicaAbreSemConta()
    {
        var banco = Path.Combine(Path.GetTempPath(), $"tocaessa-api-cifra-link-{Guid.NewGuid():N}.db");
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
            var token = CriarArtista(repo, "ana@teste.com", "Duo Aurora");
            repo.SalvarCifraEmTexto(token, "Evidências", null, "Tom: A\nA    E\nQuando eu digo");
            using var ana = fabrica.CreateClient();
            ana.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);
            using var publico = fabrica.CreateClient();
            const string rotaPrivada = "/api/artista/cifras/compartilhar?musica=Evid%C3%AAncias";

            Assert.Equal(HttpStatusCode.Unauthorized, (await publico.GetAsync(rotaPrivada)).StatusCode);
            Assert.Equal(HttpStatusCode.NotFound,
                (await ana.GetAsync("/api/artista/cifras/compartilhar?musica=Outra")).StatusCode);
            var gerado = await ana.GetFromJsonAsync<JsonElement>(rotaPrivada);
            var codigo = gerado.GetProperty("codigo").GetGuid();

            var cifra = await publico.GetFromJsonAsync<JsonElement>($"/api/publico/cifras/{codigo}");
            Assert.Equal("Evidências", cifra.GetProperty("musica").GetString());
            Assert.Equal("A", cifra.GetProperty("tom").GetString());
            Assert.Equal("Duo Aurora", cifra.GetProperty("nomeArtistico").GetString());
            Assert.Equal(HttpStatusCode.NotFound,
                (await publico.GetAsync($"/api/publico/cifras/{Guid.NewGuid()}")).StatusCode);
        }
        finally
        {
            SqliteConnection.ClearAllPools();
            foreach (var arquivo in new[] { banco, $"{banco}-shm", $"{banco}-wal", $"{banco}.json" })
                if (File.Exists(arquivo)) File.Delete(arquivo);
        }
    }

    private static string CriarArtista(RepositorioTocaEssa repo, string email, string nome)
    {
        var token = repo.CriarContaArtista("Artista", email, "senha123").Token;
        repo.SalvarPerfilDaConta(token, new SalvarPerfilArtistico(nome, null));
        return token;
    }
}
