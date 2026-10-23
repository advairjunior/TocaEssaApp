using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.DependencyInjection.Extensions;
using Microsoft.Extensions.Logging;
using TocaEssaApp.Api.Infraestrutura;

namespace TocaEssaApp.Testes;

/// O navegador precisa conferir o app a cada abertura (para não ficar preso
/// numa versão velha) e pode guardar fontes, ícones e imagens por um dia.
public class CacheDosArquivosDoAppTestes
{
    [Theory]
    [InlineData("/")]
    [InlineData("/index.html")]
    [InlineData("/flutter_bootstrap.js")]
    [InlineData("/main.dart.js")]
    [InlineData("/manifest.json")]
    [InlineData("/evento/ABC123")]
    public async Task ArquivosDoAppSaoConferidosACadaAbertura(string caminho)
    {
        var resposta = await Obter(caminho);

        resposta.EnsureSuccessStatusCode();
        Assert.Equal("no-cache", resposta.Headers.CacheControl?.ToString());
    }

    [Theory]
    [InlineData("/assets/assets/fontes/Fonte.ttf")]
    [InlineData("/icons/Icon-192.png")]
    [InlineData("/favicon.png")]
    public async Task FontesIconesEImagensFicamGuardadosPorUmDia(string caminho)
    {
        var resposta = await Obter(caminho);

        resposta.EnsureSuccessStatusCode();
        Assert.Equal("public, max-age=86400", resposta.Headers.CacheControl?.ToString());
    }

    private static async Task<HttpResponseMessage> Obter(string caminho)
    {
        var pasta = Path.Combine(Path.GetTempPath(), $"tocaessa-cache-{Guid.NewGuid()}");
        var banco = Path.Combine(pasta, "tocaessa.db");
        var raizWeb = Path.Combine(pasta, "wwwroot");
        foreach (var arquivo in new[]
        {
            "index.html", "flutter_bootstrap.js", "main.dart.js", "manifest.json",
            "favicon.png", "icons/Icon-192.png", "assets/assets/fontes/Fonte.ttf"
        })
        {
            var completo = Path.Combine(raizWeb, arquivo);
            Directory.CreateDirectory(Path.GetDirectoryName(completo)!);
            File.WriteAllText(completo, "conteudo");
        }

        await using var fabrica = new WebApplicationFactory<Program>()
            .WithWebHostBuilder(builder =>
            {
                builder.UseSetting(WebHostDefaults.WebRootKey, raizWeb);
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
                    servicos.AddSingleton(new RepositorioTocaEssa(banco, $"{banco}.json"));
                });
            });
        using var cliente = fabrica.CreateClient();
        var resposta = await cliente.GetAsync(caminho);
        await resposta.Content.LoadIntoBufferAsync();
        return resposta;
    }
}
