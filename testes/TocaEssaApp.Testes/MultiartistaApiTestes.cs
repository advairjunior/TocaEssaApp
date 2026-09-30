using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.DependencyInjection.Extensions;
using Microsoft.Extensions.Logging;
using TocaEssaApp.Api.Infraestrutura;

namespace TocaEssaApp.Testes;

public sealed class MultiartistaApiTestes
{
    [Fact]
    public async Task ApiIsolaPerfisAgendasERecursosPrivadosPorArtista()
    {
        var banco = Path.Combine(Path.GetTempPath(),
            $"tocaessa-api-multiartista-{Guid.NewGuid():N}.db");
        try
        {
            await using var fabrica = CriarFabrica(banco);
            using var publico = fabrica.CreateClient();
            using var ana = await CriarClienteArtista(
                fabrica, "Ana", "ana@teste.com", "senha123");
            using var bia = await CriarClienteArtista(
                fabrica, "Bia", "bia@teste.com", "outrasenha");

            await SalvarPerfil(ana, "Duo Aurora");
            await SalvarPerfil(bia, "Banda Horizonte");
            var showAna = await CriarApresentacao(ana, "Show da Ana");
            var showBia = await CriarApresentacao(bia, "Show da Bia");

            Assert.Equal("Duo Aurora", await ObterNomeDoPerfil(ana));
            Assert.Equal("Banda Horizonte", await ObterNomeDoPerfil(bia));
            Assert.Equal(showAna.Id, Assert.Single(
                await ListarApresentacoes(ana)).Id);
            Assert.Equal(showBia.Id, Assert.Single(
                await ListarApresentacoes(bia)).Id);

            Assert.Equal(HttpStatusCode.NotFound,
                (await bia.GetAsync(
                    $"/api/apresentacoes/{showAna.Id}/pedidos")).StatusCode);
            Assert.Equal(HttpStatusCode.NotFound,
                (await bia.PutAsJsonAsync(
                    $"/api/apresentacoes/{showAna.Id}", new
                    {
                        nome = "Invadido",
                        data = "2026-10-01",
                        local = "Outro local",
                        tipo = "Publica"
                    })).StatusCode);

            Assert.Equal(HttpStatusCode.OK,
                (await publico.GetAsync(
                    $"/api/publico/apresentacoes/{showAna.Codigo}")).StatusCode);
            Assert.Equal(HttpStatusCode.OK,
                (await publico.GetAsync(
                    $"/api/publico/apresentacoes/{showBia.Codigo}")).StatusCode);

            var duplicado = await publico.PostAsJsonAsync(
                "/api/artista/contas", new
                {
                    nome = "Outra Ana",
                    email = " ANA@TESTE.COM ",
                    senha = "senha456"
                });
            Assert.Equal(HttpStatusCode.Conflict, duplicado.StatusCode);

            using var invalido = fabrica.CreateClient();
            invalido.DefaultRequestHeaders.Authorization =
                new AuthenticationHeaderValue("Bearer", "token-invalido");
            Assert.Equal(HttpStatusCode.Unauthorized,
                (await invalido.GetAsync("/api/apresentacoes")).StatusCode);
        }
        finally
        {
            ExcluirBanco(banco);
        }
    }

    private static WebApplicationFactory<Program> CriarFabrica(string banco) =>
        new WebApplicationFactory<Program>().WithWebHostBuilder(builder =>
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

    private static async Task<HttpClient> CriarClienteArtista(
        WebApplicationFactory<Program> fabrica,
        string nome,
        string email,
        string senha)
    {
        var cliente = fabrica.CreateClient();
        var resposta = await cliente.PostAsJsonAsync(
            "/api/artista/contas", new { nome, email, senha });
        resposta.EnsureSuccessStatusCode();
        using var json = JsonDocument.Parse(await resposta.Content.ReadAsStringAsync());
        var token = json.RootElement.GetProperty("token").GetString();
        cliente.DefaultRequestHeaders.Authorization =
            new AuthenticationHeaderValue("Bearer", token);
        return cliente;
    }

    private static async Task SalvarPerfil(HttpClient cliente, string nome)
    {
        var resposta = await cliente.PutAsJsonAsync(
            "/api/perfil-artistico", new
            {
                nomeArtistico = nome,
                descricao = (string?)null
            });
        resposta.EnsureSuccessStatusCode();
    }

    private static async Task<string> ObterNomeDoPerfil(HttpClient cliente)
    {
        using var json = JsonDocument.Parse(
            await cliente.GetStringAsync("/api/perfil-artistico"));
        return json.RootElement.GetProperty("perfil")
            .GetProperty("nomeArtistico").GetString()!;
    }

    private static async Task<ApresentacaoResposta> CriarApresentacao(
        HttpClient cliente, string nome)
    {
        var resposta = await cliente.PostAsJsonAsync(
            "/api/apresentacoes", new
            {
                nome,
                data = "2026-10-01",
                local = "Bar",
                tipo = "Publica"
            });
        resposta.EnsureSuccessStatusCode();
        using var json = JsonDocument.Parse(await resposta.Content.ReadAsStringAsync());
        var apresentacao = json.RootElement.GetProperty("apresentacao");
        return new ApresentacaoResposta(
            apresentacao.GetProperty("id").GetGuid(),
            apresentacao.GetProperty("codigo").GetString()!);
    }

    private static async Task<IReadOnlyList<ApresentacaoResposta>>
        ListarApresentacoes(HttpClient cliente)
    {
        using var json = JsonDocument.Parse(
            await cliente.GetStringAsync("/api/apresentacoes"));
        return json.RootElement.EnumerateArray()
            .Select(item => new ApresentacaoResposta(
                item.GetProperty("id").GetGuid(),
                item.GetProperty("codigo").GetString()!))
            .ToArray();
    }

    private static void ExcluirBanco(string caminho)
    {
        foreach (var arquivo in new[]
                 {
                     caminho, $"{caminho}-shm", $"{caminho}-wal",
                     $"{caminho}.json"
                 })
            if (File.Exists(arquivo)) File.Delete(arquivo);
    }

    private sealed record ApresentacaoResposta(Guid Id, string Codigo);
}
