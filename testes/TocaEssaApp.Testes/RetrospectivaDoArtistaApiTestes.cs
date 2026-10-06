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

public sealed class RetrospectivaDoArtistaApiTestes
{
    private static readonly byte[] CabecalhoPng =
        [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0, 0, 0, 0];

    [Theory]
    [InlineData("Publica")]
    [InlineData("ResenhaEntreAmigos")]
    public async Task ArtistaEnviaFotoDaRetrospectivaNosDoisTiposDeEvento(string tipo)
    {
        var banco = CriarCaminhoBanco();
        try
        {
            await using var fabrica = CriarFabrica(banco);
            using var artista = await CriarClienteArtista(fabrica);
            var (id, _) = await CriarApresentacao(artista, tipo);

            var resposta = await EnviarFoto(artista, id);

            Assert.Equal(HttpStatusCode.OK, resposta.StatusCode);
            using var json = JsonDocument.Parse(
                await resposta.Content.ReadAsStringAsync());
            Assert.False(string.IsNullOrWhiteSpace(json.RootElement
                .GetProperty("fotoRetrospectivaUrl").GetString()));
        }
        finally
        {
            ExcluirBanco(banco);
        }
    }

    [Fact]
    public async Task FotoDaRetrospectivaDeOutroArtistaContinuaNaoEncontrada()
    {
        var banco = CriarCaminhoBanco();
        try
        {
            await using var fabrica = CriarFabrica(banco);
            using var ana = await CriarClienteArtista(fabrica, "ana@teste.com");
            using var bia = await CriarClienteArtista(fabrica, "bia@teste.com");
            var (id, _) = await CriarApresentacao(ana, "Publica");

            var resposta = await EnviarFoto(bia, id);

            Assert.Equal(HttpStatusCode.NotFound, resposta.StatusCode);
        }
        finally
        {
            ExcluirBanco(banco);
        }
    }

    [Fact]
    public async Task AparelhoQueAbreOEventoEntraNoPublicoSemPrecisarDeConta()
    {
        var banco = CriarCaminhoBanco();
        try
        {
            await using var fabrica = CriarFabrica(banco);
            using var artista = await CriarClienteArtista(fabrica);
            using var publico = fabrica.CreateClient();
            var (id, codigo) = await CriarApresentacao(artista, "Publica");

            var primeiro = await publico.PostAsJsonAsync(
                $"/api/publico/apresentacoes/{codigo}/acessos",
                new { visitante = "aparelho-1" });
            var repetido = await publico.PostAsJsonAsync(
                $"/api/publico/apresentacoes/{codigo}/acessos",
                new { visitante = "aparelho-1" });
            var semVisitante = await publico.PostAsJsonAsync(
                $"/api/publico/apresentacoes/{codigo}/acessos",
                new { visitante = " " });
            var inexistente = await publico.PostAsJsonAsync(
                "/api/publico/apresentacoes/NAOEXISTE/acessos",
                new { visitante = "aparelho-1" });

            Assert.Equal(HttpStatusCode.NoContent, primeiro.StatusCode);
            Assert.Equal(HttpStatusCode.NoContent, repetido.StatusCode);
            Assert.Equal(HttpStatusCode.BadRequest, semVisitante.StatusCode);
            Assert.Equal(HttpStatusCode.NotFound, inexistente.StatusCode);
            Assert.Equal(HttpStatusCode.OK, (await publico.GetAsync(
                $"/api/publico/apresentacoes/{codigo}")).StatusCode);
            using var estatisticas = JsonDocument.Parse(await artista.GetStringAsync(
                $"/api/apresentacoes/{id}/estatisticas"));
            Assert.Equal(1, estatisticas.RootElement
                .GetProperty("pessoasNoEvento").GetInt32());
        }
        finally
        {
            ExcluirBanco(banco);
        }
    }

    private static async Task<HttpResponseMessage> EnviarFoto(
        HttpClient cliente, Guid apresentacaoId)
    {
        using var conteudo = new MultipartFormDataContent();
        var arquivo = new ByteArrayContent(CabecalhoPng);
        arquivo.Headers.ContentType = new MediaTypeHeaderValue("image/png");
        conteudo.Add(arquivo, "foto", "selfie.png");
        return await cliente.PostAsync(
            $"/api/apresentacoes/{apresentacaoId}/foto-retrospectiva", conteudo);
    }

    internal static WebApplicationFactory<Program> CriarFabrica(string banco) =>
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

    internal static async Task<HttpClient> CriarClienteArtista(
        WebApplicationFactory<Program> fabrica, string email = "ana@teste.com")
    {
        var cliente = fabrica.CreateClient();
        var resposta = await cliente.PostAsJsonAsync(
            "/api/artista/contas", new { nome = "Artista", email, senha = "senha123" });
        resposta.EnsureSuccessStatusCode();
        using var json = JsonDocument.Parse(await resposta.Content.ReadAsStringAsync());
        cliente.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue(
            "Bearer", json.RootElement.GetProperty("token").GetString());
        (await cliente.PutAsJsonAsync("/api/perfil-artistico", new
        {
            nomeArtistico = "Duo Aurora",
            descricao = (string?)null
        })).EnsureSuccessStatusCode();
        return cliente;
    }

    internal static async Task<(Guid Id, string Codigo)> CriarApresentacao(
        HttpClient cliente, string tipo)
    {
        var resposta = await cliente.PostAsJsonAsync("/api/apresentacoes", new
        {
            nome = "Noite Acústica",
            data = "2026-10-06",
            local = "Bar",
            tipo
        });
        resposta.EnsureSuccessStatusCode();
        using var json = JsonDocument.Parse(await resposta.Content.ReadAsStringAsync());
        var apresentacao = json.RootElement.GetProperty("apresentacao");
        return (apresentacao.GetProperty("id").GetGuid(),
            apresentacao.GetProperty("codigo").GetString()!);
    }

    internal static string CriarCaminhoBanco() =>
        Path.Combine(Path.GetTempPath(), $"tocaessa-retrospectiva-{Guid.NewGuid():N}.db");

    internal static void ExcluirBanco(string caminho)
    {
        foreach (var arquivo in new[]
                 {
                     caminho, $"{caminho}-shm", $"{caminho}-wal", $"{caminho}.json"
                 })
            if (File.Exists(arquivo)) File.Delete(arquivo);
    }
}
