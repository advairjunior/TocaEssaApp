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

/// As rotas do convite: todas privadas, a conta vem do token.
public sealed class MusicosDaNoiteApiTestes
{
    private const string Cifra = "A  E\nQuando eu digo";

    [Fact]
    public async Task DonoConvidaMusicoEntraESai()
    {
        var banco = Path.Combine(Path.GetTempPath(), $"tocaessa-api-musicos-{Guid.NewGuid():N}.db");
        await using var fabrica = CriarFabrica(banco);
        using var dono = await CriarClienteArtista(fabrica, "dono@teste.com", "Advair");
        using var bia = await CriarClienteArtista(fabrica, "bia@teste.com", "Bia");
        var resenha = await CriarResenha(dono);

        var gerado = await dono.PostAsync($"/api/apresentacoes/{resenha}/convite", null);
        gerado.EnsureSuccessStatusCode();
        var codigo = (await gerado.Content.ReadFromJsonAsync<JsonElement>()).GetProperty("codigo").GetString();

        var convite = await bia.GetFromJsonAsync<JsonElement>($"/api/convites/{codigo}");
        Assert.Equal("Resenha House", convite.GetProperty("evento").GetString());
        Assert.Equal("Advair", convite.GetProperty("dono").GetString());
        (await bia.PostAsync($"/api/convites/{codigo}", null)).EnsureSuccessStatusCode();

        var convites = await bia.GetFromJsonAsync<JsonElement>("/api/convites");
        Assert.Equal(resenha, convites[0].GetProperty("apresentacaoId").GetGuid());
        Assert.Equal("ResenhaEntreAmigos", convites[0].GetProperty("tipo").GetString());
        var musicos = await dono.GetFromJsonAsync<JsonElement>($"/api/apresentacoes/{resenha}/musicos");
        Assert.Equal(2, musicos.GetArrayLength());
        var idDaBia = musicos[1].GetProperty("artistaId").GetGuid();

        (await bia.DeleteAsync($"/api/apresentacoes/{resenha}/musicos/{idDaBia}")).EnsureSuccessStatusCode();
        Assert.Equal(0, (await bia.GetFromJsonAsync<JsonElement>("/api/convites")).GetArrayLength());
    }

    [Fact]
    public async Task ConvidadoLeACifraDaNoitePelaRotaDoEvento()
    {
        var banco = Path.Combine(Path.GetTempPath(), $"tocaessa-api-musicos-{Guid.NewGuid():N}.db");
        await using var fabrica = CriarFabrica(banco);
        using var dono = await CriarClienteArtista(fabrica, "dono@teste.com", "Advair");
        using var bia = await CriarClienteArtista(fabrica, "bia@teste.com", "Bia");
        var resenha = await CriarResenha(dono);
        (await dono.PutAsJsonAsync("/api/artista/cifras/texto",
            new { musica = "Evidências", texto = Cifra })).EnsureSuccessStatusCode();
        (await dono.PostAsJsonAsync($"/api/apresentacoes/{resenha}/setlist/avulsa",
            new { titulo = "Evidências" })).EnsureSuccessStatusCode();
        var codigo = (await (await dono.PostAsync($"/api/apresentacoes/{resenha}/convite", null))
            .Content.ReadFromJsonAsync<JsonElement>()).GetProperty("codigo").GetString();
        (await bia.PostAsync($"/api/convites/{codigo}", null)).EnsureSuccessStatusCode();

        var cifra = await bia.GetFromJsonAsync<JsonElement>(
            $"/api/apresentacoes/{resenha}/cifras?musica=Evid%C3%AAncias");

        Assert.Equal(Cifra, cifra.GetProperty("texto").GetString());
    }

    [Fact]
    public async Task ConviteErradoSemContaOuDeOutroRespondeSemRevelar()
    {
        var banco = Path.Combine(Path.GetTempPath(), $"tocaessa-api-musicos-{Guid.NewGuid():N}.db");
        await using var fabrica = CriarFabrica(banco);
        using var dono = await CriarClienteArtista(fabrica, "dono@teste.com", "Advair");
        using var bia = await CriarClienteArtista(fabrica, "bia@teste.com", "Bia");
        using var semConta = fabrica.CreateClient();
        var resenha = await CriarResenha(dono);

        var errado = await bia.GetAsync("/api/convites/NAOEXISTE");
        Assert.Equal(HttpStatusCode.NotFound, errado.StatusCode);
        Assert.Contains("Convite",
            (await errado.Content.ReadFromJsonAsync<JsonElement>()).GetProperty("mensagem").GetString());
        Assert.Equal(HttpStatusCode.Unauthorized, (await semConta.GetAsync("/api/convites")).StatusCode);
        Assert.Equal(HttpStatusCode.NotFound,
            (await bia.PostAsync($"/api/apresentacoes/{resenha}/convite", null)).StatusCode);
        Assert.Equal(HttpStatusCode.NotFound,
            (await bia.GetAsync($"/api/apresentacoes/{resenha}/musicos")).StatusCode);
    }

    private static async Task<Guid> CriarResenha(HttpClient dono)
    {
        var resposta = await dono.PostAsJsonAsync("/api/apresentacoes", new
        {
            nome = "Resenha House", data = "2026-10-30", local = "Casa", tipo = "ResenhaEntreAmigos"
        });
        resposta.EnsureSuccessStatusCode();
        return (await resposta.Content.ReadFromJsonAsync<JsonElement>())
            .GetProperty("apresentacao").GetProperty("id").GetGuid();
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
        WebApplicationFactory<Program> fabrica, string email, string nome)
    {
        var cliente = fabrica.CreateClient();
        var resposta = await cliente.PostAsJsonAsync(
            "/api/artista/contas", new { nome, email, senha = "senha123" });
        resposta.EnsureSuccessStatusCode();
        using var json = JsonDocument.Parse(await resposta.Content.ReadAsStringAsync());
        cliente.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue(
            "Bearer", json.RootElement.GetProperty("token").GetString());
        (await cliente.PutAsJsonAsync("/api/perfil-artistico", new { nomeArtistico = nome }))
            .EnsureSuccessStatusCode();
        return cliente;
    }
}
