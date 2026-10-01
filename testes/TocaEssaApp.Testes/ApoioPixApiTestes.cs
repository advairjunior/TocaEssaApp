using System.Net;
using System.Net.Http.Json;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.DependencyInjection.Extensions;
using Microsoft.Extensions.Logging;
using TocaEssaApp.Api.Dominio;
using TocaEssaApp.Api.Infraestrutura;

namespace TocaEssaApp.Testes;

public class ApoioPixApiTestes
{
    [Fact]
    public async Task ApresentacaoPublicaGeraPayloadSemExporChave()
    {
        var banco = Path.Combine(
            Path.GetTempPath(), $"tocaessa-api-pix-{Guid.NewGuid()}.db");
        try
        {
            var repositorio = new RepositorioTocaEssa(banco, $"{banco}.json");
            var token = repositorio.CriarContaArtista("Duo Aurora", "duo@teste.com", "senha").Token;
            repositorio.SalvarPerfilDaConta(token, new SalvarPerfilArtistico(
                "Duo Aurora", null, null, false, null, false, true,
                "chave-pix-secreta", "DUO AURORA", "SAO PAULO", "Valeu!"));
            var apresentacao = repositorio.CriarApresentacao(token,
                "Noite acústica", new DateOnly(2026, 9, 20), "Café Central");

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
                        servicos.AddSingleton(repositorio);
                    });
                });
            using var cliente = fabrica.CreateClient();

            var resposta = await cliente.GetAsync(
                $"/api/publico/apresentacoes/{apresentacao.Codigo}/apoio-pix?valor=10.00");
            var corpo = await resposta.Content.ReadAsStringAsync();

            resposta.EnsureSuccessStatusCode();
            Assert.DoesNotContain("\"pixChave\"", corpo);
            var apoio = await resposta.Content.ReadFromJsonAsync<ApoioResposta>();
            Assert.Equal(10m, apoio!.Valor);
            Assert.True(ServicoPix.CrcEhValido(apoio.PixCopiaECola));
            Assert.Equal("Valeu!", apoio.Mensagem);
        }
        finally
        {
            ExcluirBanco(banco);
        }
    }

    [Fact]
    public async Task ApoioInativoNaoGeraPix()
    {
        var repositorio = new RepositorioTocaEssa();
        repositorio.SalvarPerfil("Duo Aurora", null);
        var apresentacao = repositorio.CriarApresentacao(
            "Noite acústica", new DateOnly(2026, 9, 20), "Café Central");

        await using var fabrica = new WebApplicationFactory<Program>()
            .WithWebHostBuilder(builder => builder.ConfigureServices(servicos =>
            {
                servicos.RemoveAll<RepositorioTocaEssa>();
                servicos.AddSingleton(repositorio);
            }));
        using var cliente = fabrica.CreateClient();

        var resposta = await cliente.GetAsync(
            $"/api/publico/apresentacoes/{apresentacao.Codigo}/apoio-pix?valor=10");

        Assert.Equal(HttpStatusCode.NotFound, resposta.StatusCode);
    }

    [Fact]
    public void PixIsolaChaveDoArtistaProprietario()
    {
        var banco = Path.Combine(
            Path.GetTempPath(), $"tocaessa-pix-isolamento-{Guid.NewGuid():N}.db");
        try
        {
            var repositorio = new RepositorioTocaEssa(banco, $"{banco}.json");

            var tokenAna = repositorio.CriarContaArtista("Ana", "ana@pix.com", "senha").Token;
            repositorio.SalvarPerfilDaConta(tokenAna, new SalvarPerfilArtistico(
                "Ana Música", null, null, false, null, false, true,
                "chave-exclusiva-ana", "ANA MUSICA", "SAO PAULO"));
            var showAna = repositorio.CriarApresentacao(tokenAna,
                "Show da Ana", new DateOnly(2026, 9, 20), "Bar A");

            var tokenBia = repositorio.CriarContaArtista("Bia", "bia@pix.com", "senha").Token;
            repositorio.SalvarPerfilDaConta(tokenBia, new SalvarPerfilArtistico(
                "Bia Música", null, null, false, null, false, true,
                "chave-exclusiva-bia", "BIA MUSICA", "SAO PAULO"));

            var pix = repositorio.GerarApoioPix(showAna.Codigo, 10m);

            Assert.Contains("chave-exclusiva-ana", pix.PixCopiaECola);
            Assert.DoesNotContain("chave-exclusiva-bia", pix.PixCopiaECola);
        }
        finally
        {
            ExcluirBanco(banco);
        }
    }

    private static void ExcluirBanco(string caminho)
    {
        foreach (var arquivo in new[] { caminho, $"{caminho}-shm", $"{caminho}-wal", $"{caminho}.json" })
            if (File.Exists(arquivo)) File.Delete(arquivo);
    }

    private sealed record ApoioResposta(
        decimal Valor, string PixCopiaECola, string Mensagem);
}
