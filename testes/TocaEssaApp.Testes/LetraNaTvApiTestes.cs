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

/// As rotas da TV: a TV abre sem conta e com o token dela; o celular do dono
/// conecta, manda a letra e a linha com o token do artista.
public sealed class LetraNaTvApiTestes
{
    [Fact]
    public async Task TvAbreSemContaEMostraALetraDoDono()
    {
        var banco = Path.Combine(Path.GetTempPath(), $"tocaessa-api-tv-{Guid.NewGuid():N}.db");
        await using var fabrica = CriarFabrica(banco);
        using var dono = await CriarClienteArtista(fabrica, "dono@teste.com");
        using var tv = fabrica.CreateClient();

        var criada = await tv.PostAsync("/api/publico/telas", null);
        criada.EnsureSuccessStatusCode();
        var novaTv = await criada.Content.ReadFromJsonAsync<JsonElement>();
        tv.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue(
            "Bearer", novaTv.GetProperty("token").GetString());
        var esperando = await tv.GetFromJsonAsync<JsonElement>("/api/publico/telas/eu");
        Assert.False(esperando.GetProperty("pareada").GetBoolean());

        (await dono.PostAsJsonAsync("/api/artista/telas/pareamento",
            new { codigo = esperando.GetProperty("codigo").GetString() })).EnsureSuccessStatusCode();
        (await dono.PutAsJsonAsync("/api/artista/telas/conteudo", new
        {
            titulo = "Fim de tarde", texto = "Canta comigo", linha = 0
        })).EnsureSuccessStatusCode();
        (await dono.PutAsJsonAsync("/api/artista/telas/conteudo/linha", new { linha = 2 }))
            .EnsureSuccessStatusCode();

        var mostrando = await tv.GetFromJsonAsync<JsonElement>("/api/publico/telas/eu");
        Assert.True(mostrando.GetProperty("pareada").GetBoolean());
        var conteudo = mostrando.GetProperty("conteudo");
        Assert.Equal("Fim de tarde", conteudo.GetProperty("titulo").GetString());
        Assert.Equal(2, conteudo.GetProperty("linha").GetInt32());

        var lista = await dono.GetFromJsonAsync<JsonElement>("/api/artista/telas");
        Assert.Equal(novaTv.GetProperty("id").GetGuid(), lista[0].GetProperty("id").GetGuid());
        (await dono.DeleteAsync("/api/artista/telas/conteudo")).EnsureSuccessStatusCode();
        (await dono.DeleteAsync($"/api/artista/telas/{lista[0].GetProperty("id").GetGuid()}"))
            .EnsureSuccessStatusCode();
        Assert.Equal(HttpStatusCode.NotFound, (await tv.GetAsync("/api/publico/telas/eu")).StatusCode);
    }

    [Fact]
    public async Task EnderecoCurtoDaTvLevaParaATelaDaTv()
    {
        var banco = Path.Combine(Path.GetTempPath(), $"tocaessa-api-tv-{Guid.NewGuid():N}.db");
        await using var fabrica = CriarFabrica(banco);
        using var tv = fabrica.CreateClient(new WebApplicationFactoryClientOptions
        {
            AllowAutoRedirect = false
        });

        var resposta = await tv.GetAsync("/tv");

        Assert.Equal(HttpStatusCode.Redirect, resposta.StatusCode);
        Assert.Equal("/#/tv", resposta.Headers.Location?.OriginalString);
    }

    [Fact]
    public async Task ErrosDaTvTemStatusEMensagem()
    {
        var banco = Path.Combine(Path.GetTempPath(), $"tocaessa-api-tv-{Guid.NewGuid():N}.db");
        await using var fabrica = CriarFabrica(banco);
        using var dono = await CriarClienteArtista(fabrica, "dono@teste.com");
        using var semConta = fabrica.CreateClient();

        var codigoErrado = await dono.PostAsJsonAsync("/api/artista/telas/pareamento", new { codigo = "ZZZZ" });
        Assert.Equal(HttpStatusCode.NotFound, codigoErrado.StatusCode);
        Assert.Contains("código",
            (await codigoErrado.Content.ReadFromJsonAsync<JsonElement>()).GetProperty("mensagem").GetString());

        var semMusica = await dono.PutAsJsonAsync("/api/artista/telas/conteudo/linha", new { linha = 1 });
        Assert.Equal(HttpStatusCode.Conflict, semMusica.StatusCode);

        Assert.Equal(HttpStatusCode.NotFound, (await semConta.GetAsync("/api/publico/telas/eu")).StatusCode);
        Assert.Equal(HttpStatusCode.Unauthorized, (await semConta.PutAsJsonAsync(
            "/api/artista/telas/conteudo", new { titulo = "X", texto = "Y", linha = 0 })).StatusCode);
    }

    [Fact]
    public async Task AjudanteSemContaComandaALinhaAteODonoRetomar()
    {
        var banco = Path.Combine(Path.GetTempPath(), $"tocaessa-api-tv-{Guid.NewGuid():N}.db");
        await using var fabrica = CriarFabrica(banco);
        using var dono = await CriarClienteArtista(fabrica, "dono@teste.com");
        using var ajudante = fabrica.CreateClient();
        (await dono.PutAsJsonAsync("/api/artista/telas/conteudo", new
        {
            titulo = "Fim de tarde", texto = "Canta comigo", linha = 0
        })).EnsureSuccessStatusCode();

        var passado = await dono.PostAsync("/api/artista/telas/comando", null);
        passado.EnsureSuccessStatusCode();
        var comando = await passado.Content.ReadFromJsonAsync<JsonElement>();
        ajudante.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue(
            "Bearer", comando.GetProperty("token").GetString());
        var estado = await dono.GetFromJsonAsync<JsonElement>("/api/artista/telas/comando");
        Assert.True(estado.GetProperty("ativo").GetBoolean());

        var visto = await ajudante.GetFromJsonAsync<JsonElement>("/api/publico/comando");
        Assert.Equal("Fim de tarde", visto.GetProperty("conteudo").GetProperty("titulo").GetString());
        Assert.Equal(comando.GetProperty("id").GetGuid(), visto.GetProperty("canal").GetGuid());
        (await ajudante.PutAsJsonAsync("/api/publico/comando/linha", new { linha = 1 }))
            .EnsureSuccessStatusCode();

        (await dono.DeleteAsync("/api/artista/telas/comando")).EnsureSuccessStatusCode();
        var depois = await ajudante.GetAsync("/api/publico/comando");
        Assert.Equal(HttpStatusCode.NotFound, depois.StatusCode);
        Assert.Contains("comando",
            (await depois.Content.ReadFromJsonAsync<JsonElement>()).GetProperty("mensagem").GetString());
    }

    private static WebApplicationFactory<Program> CriarFabrica(string banco) =>
        new WebApplicationFactory<Program>().WithWebHostBuilder(builder =>
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
