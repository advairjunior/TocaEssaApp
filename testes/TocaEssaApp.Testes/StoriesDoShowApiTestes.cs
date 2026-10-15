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
using TocaEssaApp.Api.Infraestrutura;

namespace TocaEssaApp.Testes;

/// Rotas dos stories: o público envia e assiste sem token; só o artista
/// dono lista, apaga e mostra de novo. Sem R2, o arquivo fica numa pasta
/// local com URL assinada pela própria API.
public class StoriesDoShowApiTestes
{
    private static readonly byte[] Foto = [0xFF, 0xD8, 0xFF, 0xE0, 1, 2, 3, 4, 5, 6];

    [Fact]
    public async Task PublicoEnviaEAssisteSemTokenEOArtistaDonoGerencia()
    {
        await using var ambiente = await Ambiente.Criar();
        var publico = ambiente.Publico;

        // Pede o envio e manda o arquivo direto para a URL assinada.
        var pedido = await publico.PostAsJsonAsync(
            $"/api/publico/apresentacoes/{ambiente.Codigo}/envios", new
            {
                tipo = "Foto", tipoDeConteudo = "image/jpeg", tamanho = Foto.Length,
                nome = "Ana", aparelho = "aparelho-1"
            });
        Assert.Equal(HttpStatusCode.OK, pedido.StatusCode);
        using var envio = JsonDocument.Parse(await pedido.Content.ReadAsStringAsync());
        var id = envio.RootElement.GetProperty("id").GetGuid();
        var urlDeEnvio = envio.RootElement.GetProperty("urlDeEnvio").GetString()!;
        Assert.Equal("image/jpeg", envio.RootElement.GetProperty("cabecalhos")
            .GetProperty("Content-Type").GetString());

        var arquivo = new ByteArrayContent(Foto);
        arquivo.Headers.ContentType = new MediaTypeHeaderValue("image/jpeg");
        Assert.Equal(HttpStatusCode.OK, (await publico.PutAsync(urlDeEnvio, arquivo)).StatusCode);

        // Antes de confirmar, ninguém vê.
        Assert.Equal("[]", await publico.GetStringAsync(
            $"/api/publico/apresentacoes/{ambiente.Codigo}/stories"));
        var confirmado = await publico.PostAsync(
            $"/api/publico/apresentacoes/{ambiente.Codigo}/envios/{id}/confirmar", null);
        Assert.Equal(HttpStatusCode.OK, confirmado.StatusCode);

        // Público assiste sem token, sem dado do aparelho nem chave.
        var stories = await publico.GetStringAsync(
            $"/api/publico/apresentacoes/{ambiente.Codigo}/stories");
        Assert.DoesNotContain("aparelho", stories, StringComparison.OrdinalIgnoreCase);
        Assert.DoesNotContain("chave", stories, StringComparison.OrdinalIgnoreCase);
        using var lista = JsonDocument.Parse(stories);
        var story = Assert.Single(lista.RootElement.EnumerateArray());
        Assert.Equal("Ana", story.GetProperty("nome").GetString());
        Assert.Equal("Foto", story.GetProperty("tipo").GetString());
        Assert.Equal(Foto, await publico.GetByteArrayAsync(story.GetProperty("url").GetString()));

        // Outro artista: não encontrado, sem revelar nada.
        var rotaDoArtista = $"/api/apresentacoes/{ambiente.ShowId}/envios";
        Assert.Equal(HttpStatusCode.NotFound, (await ambiente.Bia.GetAsync(rotaDoArtista)).StatusCode);
        Assert.Equal(HttpStatusCode.NotFound,
            (await ambiente.Bia.DeleteAsync($"{rotaDoArtista}/{id}")).StatusCode);
        Assert.Equal(HttpStatusCode.Unauthorized, (await publico.GetAsync(rotaDoArtista)).StatusCode);

        // Dono vê, com validade e situação.
        using var envios = JsonDocument.Parse(await ambiente.Ana.GetStringAsync(rotaDoArtista));
        var doArtista = Assert.Single(envios.RootElement.EnumerateArray());
        Assert.False(doArtista.GetProperty("escondido").GetBoolean());
        Assert.True(doArtista.TryGetProperty("expiraEm", out _));

        // Apagar some para todos e remove o arquivo.
        var urlDoArquivo = doArtista.GetProperty("url").GetString()!;
        Assert.Equal(HttpStatusCode.NoContent,
            (await ambiente.Ana.DeleteAsync($"{rotaDoArtista}/{id}")).StatusCode);
        Assert.Equal("[]", await publico.GetStringAsync(
            $"/api/publico/apresentacoes/{ambiente.Codigo}/stories"));
        Assert.Equal(HttpStatusCode.NotFound, (await publico.GetAsync(urlDoArquivo)).StatusCode);
    }

    [Fact]
    public async Task ArtistaDonoPostaStoryEOPublicoVeComDestaque()
    {
        await using var ambiente = await Ambiente.Criar();
        var rota = $"/api/apresentacoes/{ambiente.ShowId}/envios";
        var corpo = new { tipo = "Foto", tipoDeConteudo = "image/jpeg", tamanho = Foto.Length };

        Assert.Equal(HttpStatusCode.NotFound, (await ambiente.Bia.PostAsJsonAsync(rota, corpo)).StatusCode);
        Assert.Equal(HttpStatusCode.Unauthorized, (await ambiente.Publico.PostAsJsonAsync(rota, corpo)).StatusCode);

        var pedido = await ambiente.Ana.PostAsJsonAsync(rota, corpo);
        Assert.Equal(HttpStatusCode.OK, pedido.StatusCode);
        using var envio = JsonDocument.Parse(await pedido.Content.ReadAsStringAsync());
        var id = envio.RootElement.GetProperty("id").GetGuid();
        var arquivo = new ByteArrayContent(Foto);
        arquivo.Headers.ContentType = new MediaTypeHeaderValue("image/jpeg");
        await ambiente.Publico.PutAsync(envio.RootElement.GetProperty("urlDeEnvio").GetString(), arquivo);
        Assert.Equal(HttpStatusCode.NotFound,
            (await ambiente.Bia.PostAsync($"{rota}/{id}/confirmar", null)).StatusCode);
        Assert.Equal(HttpStatusCode.OK,
            (await ambiente.Ana.PostAsync($"{rota}/{id}/confirmar", null)).StatusCode);

        using var lista = JsonDocument.Parse(await ambiente.Publico.GetStringAsync(
            $"/api/publico/apresentacoes/{ambiente.Codigo}/stories"));
        var story = Assert.Single(lista.RootElement.EnumerateArray());
        Assert.True(story.GetProperty("doArtista").GetBoolean());
        Assert.Equal("Duo Aurora", story.GetProperty("nome").GetString());
    }

    [Fact]
    public async Task ArquivoDiferenteDoDeclaradoERecusadoNaConfirmacao()
    {
        await using var ambiente = await Ambiente.Criar();
        var (id, url) = await ambiente.PedirEnvio(Foto.Length);
        var maior = new ByteArrayContent([.. Foto, .. Foto]);
        maior.Headers.ContentType = new MediaTypeHeaderValue("image/jpeg");
        await ambiente.Publico.PutAsync(url, maior);

        var confirmado = await ambiente.Publico.PostAsync(
            $"/api/publico/apresentacoes/{ambiente.Codigo}/envios/{id}/confirmar", null);

        Assert.Equal(HttpStatusCode.BadRequest, confirmado.StatusCode);
        Assert.Equal("[]", await ambiente.Publico.GetStringAsync(
            $"/api/publico/apresentacoes/{ambiente.Codigo}/stories"));
    }

    [Fact]
    public async Task UrlDeEnvioAdulteradaNaoGravaNada()
    {
        await using var ambiente = await Ambiente.Criar();
        var (_, url) = await ambiente.PedirEnvio(Foto.Length);
        var arquivo = new ByteArrayContent(Foto);
        arquivo.Headers.ContentType = new MediaTypeHeaderValue("image/jpeg");

        var adulterada = url.Replace("assinatura=", "assinatura=x");
        var outraChave = url.Replace("/envios/", "/envios/0");

        Assert.Equal(HttpStatusCode.Forbidden,
            (await ambiente.Publico.PutAsync(adulterada, arquivo)).StatusCode);
        Assert.NotEqual(HttpStatusCode.OK,
            (await ambiente.Publico.PutAsync(outraChave, arquivo)).StatusCode);
    }

    [Fact]
    public async Task DenunciaSemTokenEErrosComMensagem()
    {
        await using var ambiente = await Ambiente.Criar();
        var (id, url) = await ambiente.PedirEnvio(Foto.Length);
        var arquivo = new ByteArrayContent(Foto);
        arquivo.Headers.ContentType = new MediaTypeHeaderValue("image/jpeg");
        await ambiente.Publico.PutAsync(url, arquivo);
        await ambiente.Publico.PostAsync(
            $"/api/publico/apresentacoes/{ambiente.Codigo}/envios/{id}/confirmar", null);

        for (var i = 1; i <= 3; i++)
            Assert.Equal(HttpStatusCode.NoContent, (await ambiente.Publico.PostAsJsonAsync(
                $"/api/publico/apresentacoes/{ambiente.Codigo}/stories/{id}/denuncia",
                new { aparelho = $"denuncia-{i}" })).StatusCode);
        Assert.Equal("[]", await ambiente.Publico.GetStringAsync(
            $"/api/publico/apresentacoes/{ambiente.Codigo}/stories"));

        Assert.Equal(HttpStatusCode.NoContent, (await ambiente.Ana.PostAsync(
            $"/api/apresentacoes/{ambiente.ShowId}/envios/{id}/mostrar", null)).StatusCode);
        Assert.NotEqual("[]", await ambiente.Publico.GetStringAsync(
            $"/api/publico/apresentacoes/{ambiente.Codigo}/stories"));

        var grande = await ambiente.Publico.PostAsJsonAsync(
            $"/api/publico/apresentacoes/{ambiente.Codigo}/envios", new
            {
                tipo = "Video", tipoDeConteudo = "video/mp4", tamanho = 200L * 1024 * 1024,
                aparelho = "aparelho-1"
            });
        Assert.Equal(HttpStatusCode.BadRequest, grande.StatusCode);
        Assert.Contains("100 MB", await grande.Content.ReadAsStringAsync());
        Assert.Equal(HttpStatusCode.BadRequest, (await ambiente.Publico.PostAsJsonAsync(
            $"/api/publico/apresentacoes/{ambiente.Codigo}/envios",
            new { tipo = "Foto", tipoDeConteudo = "image/jpeg", tamanho = 10 })).StatusCode);
        Assert.Equal(HttpStatusCode.NotFound, (await ambiente.Publico.GetAsync(
            "/api/publico/apresentacoes/ZZZZZZ/stories")).StatusCode);
    }

    /// Em produção o disco do servidor é apagado a cada reinício: sem R2, o
    /// envio é recusado em vez de guardar um arquivo que vai sumir.
    [Fact]
    public async Task EmProducaoSemR2OEnvioERecusadoEAssistirContinua()
    {
        await using var ambiente = await Ambiente.Criar(exigeR2: true);

        var publico = await ambiente.Publico.PostAsJsonAsync(
            $"/api/publico/apresentacoes/{ambiente.Codigo}/envios", new
            {
                tipo = "Foto", tipoDeConteudo = "image/jpeg", tamanho = Foto.Length,
                aparelho = "aparelho-1"
            });
        Assert.Equal(HttpStatusCode.ServiceUnavailable, publico.StatusCode);
        Assert.Contains("Stories indisponíveis no momento.",
            await publico.Content.ReadAsStringAsync());

        var doArtista = await ambiente.Ana.PostAsJsonAsync(
            $"/api/apresentacoes/{ambiente.ShowId}/envios", new
            {
                tipo = "Foto", tipoDeConteudo = "image/jpeg", tamanho = Foto.Length
            });
        Assert.Equal(HttpStatusCode.ServiceUnavailable, doArtista.StatusCode);

        // Nenhum envio pela metade ficou registrado.
        Assert.Equal("[]", await ambiente.Ana.GetStringAsync(
            $"/api/apresentacoes/{ambiente.ShowId}/envios"));
        // Rota pública de assistir continua respondendo sem token.
        Assert.Equal("[]", await ambiente.Publico.GetStringAsync(
            $"/api/publico/apresentacoes/{ambiente.Codigo}/stories"));
        // A pasta local não existe em produção.
        var local = await ambiente.Publico.GetAsync(
            "/api/stories-locais/envios/00000000-0000-0000-0000-000000000000/" +
            "00000000-0000-0000-0000-000000000000.jpg?expira=1&assinatura=x");
        Assert.Equal(HttpStatusCode.NotFound, local.StatusCode);
    }

    private sealed class Ambiente : IAsyncDisposable
    {
        private readonly string _banco;
        private readonly WebApplicationFactory<Program> _fabrica;

        private Ambiente(string banco, WebApplicationFactory<Program> fabrica)
        {
            _banco = banco;
            _fabrica = fabrica;
            Publico = fabrica.CreateClient();
        }

        public HttpClient Publico { get; }
        public HttpClient Ana { get; private set; } = null!;
        public HttpClient Bia { get; private set; } = null!;
        public Guid ShowId { get; private set; }
        public string Codigo { get; private set; } = string.Empty;

        public static async Task<Ambiente> Criar(bool exigeR2 = false)
        {
            var banco = Path.Combine(Path.GetTempPath(), $"tocaessa-api-stories-{Guid.NewGuid():N}.db");
            var fabrica = new WebApplicationFactory<Program>().WithWebHostBuilder(builder =>
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
                    servicos.RemoveAll<ArmazenamentoDeStories>();
                    servicos.AddSingleton(new ArmazenamentoDeStories(
                        new ConfigurationBuilder().Build(), $"{banco}-stories", exigeR2));
                });
            });
            var ambiente = new Ambiente(banco, fabrica);
            ambiente.Ana = await CriarClienteArtista(fabrica, "ana@teste.com");
            ambiente.Bia = await CriarClienteArtista(fabrica, "bia@teste.com");
            (await ambiente.Ana.PutAsJsonAsync("/api/perfil-artistico",
                new { nomeArtistico = "Duo Aurora" })).EnsureSuccessStatusCode();
            var criada = await ambiente.Ana.PostAsJsonAsync("/api/apresentacoes", new
            {
                nome = "Noite Acústica", data = "2026-10-17", local = "Bar", tipo = "Publica"
            });
            criada.EnsureSuccessStatusCode();
            using var json = JsonDocument.Parse(await criada.Content.ReadAsStringAsync());
            var show = json.RootElement.GetProperty("apresentacao");
            ambiente.ShowId = show.GetProperty("id").GetGuid();
            ambiente.Codigo = show.GetProperty("codigo").GetString()!;
            (await ambiente.Ana.PatchAsJsonAsync($"/api/apresentacoes/{ambiente.ShowId}/status",
                new { status = "EmAndamento" })).EnsureSuccessStatusCode();
            return ambiente;
        }

        public async Task<(Guid Id, string Url)> PedirEnvio(long tamanho)
        {
            var pedido = await Publico.PostAsJsonAsync(
                $"/api/publico/apresentacoes/{Codigo}/envios", new
                {
                    tipo = "Foto", tipoDeConteudo = "image/jpeg", tamanho, aparelho = "aparelho-1"
                });
            pedido.EnsureSuccessStatusCode();
            using var envio = JsonDocument.Parse(await pedido.Content.ReadAsStringAsync());
            return (envio.RootElement.GetProperty("id").GetGuid(),
                envio.RootElement.GetProperty("urlDeEnvio").GetString()!);
        }

        public async ValueTask DisposeAsync()
        {
            Publico.Dispose();
            Ana?.Dispose();
            Bia?.Dispose();
            await _fabrica.DisposeAsync();
            SqliteConnection.ClearAllPools();
            foreach (var caminho in new[] { _banco, $"{_banco}-shm", $"{_banco}-wal", $"{_banco}.json" })
                if (File.Exists(caminho)) File.Delete(caminho);
            if (Directory.Exists($"{_banco}-stories"))
                Directory.Delete($"{_banco}-stories", recursive: true);
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
    }
}
