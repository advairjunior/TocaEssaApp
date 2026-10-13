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

/// Letra e cifra coladas pelo artista, separadas do link da cifra.
public class CifraEmTextoTestes
{
    private const string Cifra = "   G              D\nQuando eu digo que deixei de te amar\n   Em         C\nÉ porque eu te amo";

    [Fact]
    public void TextoSalvoVoltaNaConsultaDaMusica()
    {
        var (repo, token) = CriarConta();

        repo.SalvarCifraEmTexto(token, "Evidências", "Chitãozinho & Xororó", Cifra);
        var resultado = repo.ObterCifraDoArtista(token, "evidencias", "chitaozinho e xororo");

        Assert.Equal(Cifra, resultado.Texto);
        Assert.Null(resultado.Cifra);
    }

    [Fact]
    public void TextoGuardaOsEspacosDosAcordesELimpaSoAsBordas()
    {
        var (repo, token) = CriarConta();

        repo.SalvarCifraEmTexto(token, "Evidências", null,
            "\r\n\r\n   G              D\r\nQuando eu digo   \r\n\r\n\r\n");

        Assert.Equal("   G              D\nQuando eu digo",
            repo.ObterCifraDoArtista(token, "Evidências", null).Texto);
    }

    [Fact]
    public void TextoVazioApaga()
    {
        var (repo, token) = CriarConta();
        repo.SalvarCifraEmTexto(token, "Evidências", null, Cifra);

        var resultado = repo.SalvarCifraEmTexto(token, "Evidências", null, "  \n ");

        Assert.Null(resultado.Texto);
        Assert.Null(repo.ObterCifraDoArtista(token, "Evidências", null).Texto);
    }

    [Fact]
    public void TextoGrandeDemaisERecusado()
    {
        var (repo, token) = CriarConta();

        Assert.Throws<DadosDeCifraInvalidosException>(() =>
            repo.SalvarCifraEmTexto(token, "Evidências", null, new string('a', 20_001)));
    }

    [Fact]
    public void LinkETextoSaoIndependentes()
    {
        var (repo, token) = CriarConta();
        var link = repo.SalvarCifraDoArtista(
            token, "Evidências", null, "https://www.cifraclub.com.br/chitaozinho/evidencias/");
        repo.SalvarCifraEmTexto(token, "Evidências", null, Cifra);

        repo.RemoverCifraDoArtista(token, link.Id);
        var resultado = repo.ObterCifraDoArtista(token, "Evidências", null);

        Assert.Null(resultado.Cifra);
        Assert.Equal(Cifra, resultado.Texto);
    }

    [Fact]
    public void OutroArtistaNaoVeOTexto()
    {
        var (repo, token) = CriarConta();
        repo.SalvarCifraEmTexto(token, "Evidências", null, Cifra);
        var tokenBia = repo.CriarContaArtista("Bia", "bia@artista.com", "senha").Token;

        Assert.Null(repo.ObterCifraDoArtista(tokenBia, "Evidências", null).Texto);
    }

    [Fact]
    public void TextoSobreviveAoReinicioEBancoAntigoGanhaATabela()
    {
        var arquivo = Path.Combine(Path.GetTempPath(), $"tocaessa-cifra-texto-{Guid.NewGuid():N}.db");
        try
        {
            var (repo, token) = CriarConta(arquivo);
            repo.SalvarCifraDoArtista(token, "Evidências", null, "https://www.cifraclub.com.br/x/y/");
            repo.SalvarCifraEmTexto(token, "Evidências", null, Cifra);
            Assert.Equal(Cifra, new RepositorioTocaEssa(arquivo)
                .ObterCifraDoArtista(token, "Evidências", null).Texto);

            using (var conexao = new SqliteConnection($"Data Source={arquivo};Pooling=False"))
            {
                conexao.Open();
                using var comando = conexao.CreateCommand();
                comando.CommandText = "DROP TABLE \"CifrasEmTexto\"";
                comando.ExecuteNonQuery();
            }
            var migrado = new RepositorioTocaEssa(arquivo);
            Assert.NotNull(migrado.ObterCifraDoArtista(token, "Evidências", null).Cifra);
            migrado.SalvarCifraEmTexto(token, "Evidências", null, "Nova");
            Assert.Equal("Nova", new RepositorioTocaEssa(arquivo)
                .ObterCifraDoArtista(token, "Evidências", null).Texto);
        }
        finally
        {
            SqliteConnection.ClearAllPools();
            foreach (var caminho in new[] { arquivo, $"{arquivo}-shm", $"{arquivo}-wal" })
                if (File.Exists(caminho)) File.Delete(caminho);
        }
    }

    [Fact]
    public async Task RotaDoTextoESoDoArtista()
    {
        var banco = Path.Combine(Path.GetTempPath(), $"tocaessa-api-cifra-texto-{Guid.NewGuid():N}.db");
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
            var token = repo.CriarContaArtista("Ana", "ana@teste.com", "senha123").Token;
            using var ana = fabrica.CreateClient();
            ana.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);
            using var publico = fabrica.CreateClient();
            var corpo = new { musica = "Evidências", artista = (string?)null, texto = Cifra };

            Assert.Equal(HttpStatusCode.Unauthorized,
                (await publico.PutAsJsonAsync("/api/artista/cifras/texto", corpo)).StatusCode);
            var salvo = await ana.PutAsJsonAsync("/api/artista/cifras/texto", corpo);
            Assert.Equal(HttpStatusCode.OK, salvo.StatusCode);

            using var json = JsonDocument.Parse(await ana.GetStringAsync(
                "/api/artista/cifras/consulta?musica=Evid%C3%AAncias"));
            Assert.Equal(Cifra, json.RootElement.GetProperty("texto").GetString());
            Assert.Equal(HttpStatusCode.BadRequest,
                (await ana.PutAsJsonAsync("/api/artista/cifras/texto",
                    new { musica = "", texto = Cifra })).StatusCode);
        }
        finally
        {
            SqliteConnection.ClearAllPools();
            foreach (var arquivo in new[] { banco, $"{banco}-shm", $"{banco}-wal", $"{banco}.json" })
                if (File.Exists(arquivo)) File.Delete(arquivo);
        }
    }

    private static (RepositorioTocaEssa Repo, string Token) CriarConta(string? arquivo = null)
    {
        var repo = new RepositorioTocaEssa(arquivo);
        return (repo, repo.CriarContaArtista("Ana", "ana@artista.com", "senha").Token);
    }
}
