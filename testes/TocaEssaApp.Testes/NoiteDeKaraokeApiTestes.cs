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

/// As rotas da noite: o dono configura, sorteia e corrige a ordem; a galera
/// vê a ordem com a conta; ninguém de fora mexe.
public sealed class NoiteDeKaraokeApiTestes
{
    [Fact]
    public async Task DonoSorteiaEAGaleraVeAMesmaOrdem()
    {
        var banco = Path.Combine(Path.GetTempPath(), $"tocaessa-api-karaoke-{Guid.NewGuid():N}.db");
        try
        {
            await using var fabrica = CriarFabrica(banco);
            using var dono = await CriarClienteArtista(fabrica, "dono@teste.com");
            using var outro = await CriarClienteArtista(fabrica, "outro@teste.com");
            using var semConta = fabrica.CreateClient();
            (await dono.PutAsJsonAsync("/api/perfil-artistico",
                new { nomeArtistico = "Advair" })).EnsureSuccessStatusCode();
            var criada = await dono.PostAsJsonAsync("/api/apresentacoes", new
            {
                nome = "Karaokê de sexta", data = "2026-10-30", local = "Casa", tipo = "Karaoke"
            });
            criada.EnsureSuccessStatusCode();
            using var jsonNoite = JsonDocument.Parse(await criada.Content.ReadAsStringAsync());
            var noite = jsonNoite.RootElement.GetProperty("apresentacao");
            Assert.Equal("Karaoke", noite.GetProperty("tipo").GetString());
            var id = noite.GetProperty("id").GetGuid();
            var codigo = noite.GetProperty("codigo").GetString();
            using var ana = await EntrarNaGalera(fabrica, codigo!, "ana@teste.com");
            using var bia = await EntrarNaGalera(fabrica, codigo!, "bia@teste.com");
            var rota = $"/api/apresentacoes/{id}/karaoke";

            var configurada = await dono.PutAsJsonAsync($"{rota}/configuracao", new { modo = "Roleta" });
            configurada.EnsureSuccessStatusCode();
            Assert.Equal("Roleta",
                (await configurada.Content.ReadFromJsonAsync<JsonElement>()).GetProperty("modo").GetString());

            var sorteio = await dono.PostAsync($"{rota}/sorteio", null);
            sorteio.EnsureSuccessStatusCode();
            var sorteada = await sorteio.Content.ReadFromJsonAsync<JsonElement>();
            Assert.True(sorteada.GetProperty("sorteada").GetBoolean());
            var primeiro = sorteada.GetProperty("ordem")[0].GetProperty("publicoId").GetGuid();

            var naGalera = await ana.GetFromJsonAsync<JsonElement>(
                $"/api/publico/apresentacoes/{codigo}/karaoke");
            Assert.Equal(sorteada.GetProperty("ordem").ToString(), naGalera.GetProperty("ordem").ToString());

            var passada = await dono.PostAsync($"{rota}/ordem/{primeiro}/passar", null);
            passada.EnsureSuccessStatusCode();
            Assert.NotEqual(primeiro, (await passada.Content.ReadFromJsonAsync<JsonElement>())
                .GetProperty("ordem")[0].GetProperty("publicoId").GetGuid());

            var tirada = await dono.DeleteAsync($"{rota}/ordem/{primeiro}");
            tirada.EnsureSuccessStatusCode();
            Assert.Equal(1, (await tirada.Content.ReadFromJsonAsync<JsonElement>())
                .GetProperty("ordem").GetArrayLength());
            (await dono.PostAsync($"{rota}/ordem/{primeiro}", null)).EnsureSuccessStatusCode();

            Assert.Equal(HttpStatusCode.NotFound, (await outro.PostAsync($"{rota}/sorteio", null)).StatusCode);
            Assert.Equal(HttpStatusCode.Unauthorized, (await semConta.GetAsync(rota)).StatusCode);
            Assert.Equal(HttpStatusCode.Unauthorized,
                (await semConta.GetAsync($"/api/publico/apresentacoes/{codigo}/karaoke")).StatusCode);
        }
        finally
        {
            Microsoft.Data.Sqlite.SqliteConnection.ClearAllPools();
            File.Delete(banco);
            File.Delete($"{banco}.json");
        }
    }

    [Fact]
    public async Task AGaleraEscolheComecaETerminaAVezPeloCelular()
    {
        var banco = Path.Combine(Path.GetTempPath(), $"tocaessa-api-vez-{Guid.NewGuid():N}.db");
        try
        {
            await using var fabrica = CriarFabrica(banco);
            using var dono = await CriarClienteArtista(fabrica, "dono@teste.com");
            (await dono.PutAsJsonAsync("/api/perfil-artistico",
                new { nomeArtistico = "Advair" })).EnsureSuccessStatusCode();
            var criada = await dono.PostAsJsonAsync("/api/apresentacoes", new
            {
                nome = "Karaokê", data = "2026-10-30", local = "Casa", tipo = "Karaoke"
            });
            using var jsonNoite = JsonDocument.Parse(await criada.Content.ReadAsStringAsync());
            var id = jsonNoite.RootElement.GetProperty("apresentacao").GetProperty("id").GetGuid();
            var codigo = jsonNoite.RootElement.GetProperty("apresentacao").GetProperty("codigo").GetString();
            using var ana = await EntrarNaGalera(fabrica, codigo!, "ana@teste.com");
            using var bia = await EntrarNaGalera(fabrica, codigo!, "bia@teste.com");
            var rota = $"/api/publico/apresentacoes/{codigo}/karaoke";

            var cedo = await bia.PostAsync($"{rota}/vez", null);
            Assert.Equal(HttpStatusCode.Conflict, cedo.StatusCode);
            Assert.Equal("Ainda não é a sua vez.", (await cedo.Content.ReadFromJsonAsync<JsonElement>())
                .GetProperty("mensagem").GetString());
            Assert.Equal(HttpStatusCode.BadRequest, (await ana.PostAsJsonAsync($"{rota}/musica",
                new { titulo = "Evidências", linkDoVideo = "https://exemplo.com" })).StatusCode);

            (await ana.PostAsJsonAsync($"{rota}/musica", new { titulo = "Evidências" }))
                .EnsureSuccessStatusCode();
            var comecou = await ana.PostAsync($"{rota}/vez", null);
            comecou.EnsureSuccessStatusCode();
            var cantando = (await comecou.Content.ReadFromJsonAsync<JsonElement>()).GetProperty("cantando");
            Assert.Equal("Evidências", cantando.GetProperty("musica").GetProperty("titulo").GetString());
            Assert.Equal(HttpStatusCode.OK, (await bia.GetAsync($"{rota}/playlist")).StatusCode);

            (await ana.PostAsync($"{rota}/vez/fim", null)).EnsureSuccessStatusCode();
            (await dono.PostAsync($"/api/apresentacoes/{id}/karaoke/vez/fim", null)).EnsureSuccessStatusCode();
            var noite = await bia.GetFromJsonAsync<JsonElement>(rota);
            Assert.Equal(JsonValueKind.Null, noite.GetProperty("cantando").ValueKind);
        }
        finally
        {
            Microsoft.Data.Sqlite.SqliteConnection.ClearAllPools();
            File.Delete(banco);
            File.Delete($"{banco}.json");
        }
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

    private static async Task<HttpClient> EntrarNaGalera(
        WebApplicationFactory<Program> fabrica, string codigo, string email)
    {
        var cliente = fabrica.CreateClient();
        var resposta = await cliente.PostAsJsonAsync(
            "/api/publico/contas", new { nome = email.Split('@')[0], email, senha = "senha123" });
        resposta.EnsureSuccessStatusCode();
        using var json = JsonDocument.Parse(await resposta.Content.ReadAsStringAsync());
        cliente.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue(
            "Bearer", json.RootElement.GetProperty("token").GetString());
        (await cliente.PostAsync($"/api/publico/apresentacoes/{codigo}/participacoes", null))
            .EnsureSuccessStatusCode();
        return cliente;
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
