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

public class PedidosASeguirTestes
{
    [Fact]
    public void PedidosEntramNaSequenciaNoFimOuNoInicioESaem()
    {
        var cenario = CriarCenario();

        cenario.Repo.ColocarPedidoASeguir(cenario.Token, cenario.Show.Id, cenario.Pedidos[0].Id, noInicio: false);
        cenario.Repo.ColocarPedidoASeguir(cenario.Token, cenario.Show.Id, cenario.Pedidos[1].Id, noInicio: false);
        var comPrimeiroNoInicio = cenario.Repo.ColocarPedidoASeguir(
            cenario.Token, cenario.Show.Id, cenario.Pedidos[2].Id, noInicio: true);

        Assert.Equal(
            [cenario.Pedidos[2].Id, cenario.Pedidos[0].Id, cenario.Pedidos[1].Id],
            comPrimeiroNoInicio);

        var semOPrimeiro = cenario.Repo.TirarPedidoASeguir(
            cenario.Token, cenario.Show.Id, cenario.Pedidos[0].Id);

        Assert.Equal([cenario.Pedidos[2].Id, cenario.Pedidos[1].Id], semOPrimeiro);
        Assert.Equal(semOPrimeiro,
            cenario.Repo.ListarPedidosASeguir(cenario.Token, cenario.Show.Id));
    }

    [Fact]
    public void ColocarDeNovoMoveSemDuplicarETirarAusenteNaoFalha()
    {
        var cenario = CriarCenario();
        cenario.Repo.ColocarPedidoASeguir(cenario.Token, cenario.Show.Id, cenario.Pedidos[0].Id, noInicio: false);
        cenario.Repo.ColocarPedidoASeguir(cenario.Token, cenario.Show.Id, cenario.Pedidos[1].Id, noInicio: false);

        var movido = cenario.Repo.ColocarPedidoASeguir(
            cenario.Token, cenario.Show.Id, cenario.Pedidos[1].Id, noInicio: true);
        Assert.Equal([cenario.Pedidos[1].Id, cenario.Pedidos[0].Id], movido);

        var mesmo = cenario.Repo.TirarPedidoASeguir(
            cenario.Token, cenario.Show.Id, cenario.Pedidos[2].Id);
        Assert.Equal(movido, mesmo);
    }

    [Fact]
    public void PedidoDeOutraApresentacaoNaoEntraNaSequencia()
    {
        var cenario = CriarCenario();
        var outroShow = cenario.Repo.CriarApresentacao(
            cenario.Token, "Outro", new DateOnly(2026, 10, 11), "Bar");
        var pedidoDeOutroShow = cenario.Repo.CriarPedido(outroShow.Codigo, "Outra", null, "Rui");

        Assert.Throws<PedidoMusicalNaoEncontradoException>(() =>
            cenario.Repo.ColocarPedidoASeguir(
                cenario.Token, cenario.Show.Id, pedidoDeOutroShow.Id, noInicio: false));
        Assert.Empty(cenario.Repo.ListarPedidosASeguir(cenario.Token, cenario.Show.Id));
    }

    [Fact]
    public void OutroArtistaNaoVeNemAlteraASequencia()
    {
        var cenario = CriarCenario();
        var tokenBia = cenario.Repo.CriarContaArtista("Bia", "bia@artista.com", "senha").Token;

        Assert.Throws<ApresentacaoNaoEncontradaException>(() =>
            cenario.Repo.ListarPedidosASeguir(tokenBia, cenario.Show.Id));
        Assert.Throws<ApresentacaoNaoEncontradaException>(() =>
            cenario.Repo.ColocarPedidoASeguir(
                tokenBia, cenario.Show.Id, cenario.Pedidos[0].Id, noInicio: false));
        Assert.Throws<ApresentacaoNaoEncontradaException>(() =>
            cenario.Repo.TirarPedidoASeguir(tokenBia, cenario.Show.Id, cenario.Pedidos[0].Id));
    }

    [Fact]
    public void SequenciaSobreviveAoReinicioDoServidor()
    {
        var arquivo = Path.Combine(Path.GetTempPath(), $"tocaessa-a-seguir-{Guid.NewGuid():N}.db");
        try
        {
            var cenario = CriarCenario(arquivo);
            cenario.Repo.ColocarPedidoASeguir(cenario.Token, cenario.Show.Id, cenario.Pedidos[1].Id, noInicio: false);
            cenario.Repo.ColocarPedidoASeguir(cenario.Token, cenario.Show.Id, cenario.Pedidos[0].Id, noInicio: false);

            var reiniciado = new RepositorioTocaEssa(arquivo);

            Assert.Equal([cenario.Pedidos[1].Id, cenario.Pedidos[0].Id],
                reiniciado.ListarPedidosASeguir(cenario.Token, cenario.Show.Id));
        }
        finally
        {
            ExcluirBanco(arquivo);
        }
    }

    [Fact]
    public void BancoAntigoSemAColunaGanhaASequenciaSemPerderDados()
    {
        var arquivo = Path.Combine(Path.GetTempPath(), $"tocaessa-a-seguir-legado-{Guid.NewGuid():N}.db");
        try
        {
            var cenario = CriarCenario(arquivo);
            using (var conexao = new SqliteConnection($"Data Source={arquivo};Pooling=False"))
            {
                conexao.Open();
                using var comando = conexao.CreateCommand();
                comando.CommandText =
                    "ALTER TABLE \"Apresentacoes\" DROP COLUMN \"PedidosASeguir\"";
                comando.ExecuteNonQuery();
            }

            var migrado = new RepositorioTocaEssa(arquivo);
            Assert.Empty(migrado.ListarPedidosASeguir(cenario.Token, cenario.Show.Id));
            migrado.ColocarPedidoASeguir(cenario.Token, cenario.Show.Id, cenario.Pedidos[0].Id, noInicio: false);
            var migradoDeNovo = new RepositorioTocaEssa(arquivo);

            Assert.Equal([cenario.Pedidos[0].Id],
                migradoDeNovo.ListarPedidosASeguir(cenario.Token, cenario.Show.Id));
            Assert.Equal(3, migradoDeNovo.ListarPedidosDoArtista(cenario.Token, cenario.Show.Id).Count);
        }
        finally
        {
            ExcluirBanco(arquivo);
        }
    }

    [Fact]
    public async Task RotasDaSequenciaExigemODonoEMantemAsRotasPublicas()
    {
        var banco = Path.Combine(Path.GetTempPath(), $"tocaessa-api-a-seguir-{Guid.NewGuid():N}.db");
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
            using var publico = fabrica.CreateClient();
            using var ana = await CriarClienteArtista(fabrica, "ana@teste.com");
            using var bia = await CriarClienteArtista(fabrica, "bia@teste.com");
            (await ana.PutAsJsonAsync("/api/perfil-artistico",
                new { nomeArtistico = "Duo Aurora" })).EnsureSuccessStatusCode();
            var criada = await ana.PostAsJsonAsync("/api/apresentacoes", new
            {
                nome = "Casamento", data = "2026-10-10", local = "Salão", tipo = "Publica"
            });
            criada.EnsureSuccessStatusCode();
            using var jsonShow = JsonDocument.Parse(await criada.Content.ReadAsStringAsync());
            var show = jsonShow.RootElement.GetProperty("apresentacao");
            var showId = show.GetProperty("id").GetGuid();
            var codigo = show.GetProperty("codigo").GetString();
            var pedidoCriado = await publico.PostAsJsonAsync(
                $"/api/publico/apresentacoes/{codigo}/pedidos",
                new { musica = "Evidências", nomeSolicitante = "Rui" });
            pedidoCriado.EnsureSuccessStatusCode();
            using var jsonPedido = JsonDocument.Parse(await pedidoCriado.Content.ReadAsStringAsync());
            var pedidoId = jsonPedido.RootElement.GetProperty("id").GetGuid();
            var rota = $"/api/apresentacoes/{showId}/pedidos-a-seguir";

            var colocado = await ana.PutAsync($"{rota}/{pedidoId}", null);
            Assert.Equal(HttpStatusCode.OK, colocado.StatusCode);
            Assert.Equal([pedidoId], (await colocado.Content.ReadFromJsonAsync<Guid[]>())!);
            Assert.Equal([pedidoId], (await ana.GetFromJsonAsync<Guid[]>(rota))!);

            Assert.Equal(HttpStatusCode.NotFound, (await bia.GetAsync(rota)).StatusCode);
            Assert.Equal(HttpStatusCode.NotFound,
                (await bia.PutAsync($"{rota}/{pedidoId}?noInicio=true", null)).StatusCode);
            Assert.Equal(HttpStatusCode.NotFound,
                (await bia.DeleteAsync($"{rota}/{pedidoId}")).StatusCode);
            Assert.Equal(HttpStatusCode.Unauthorized, (await publico.GetAsync(rota)).StatusCode);

            var tirado = await ana.DeleteAsync($"{rota}/{pedidoId}");
            Assert.Equal(HttpStatusCode.OK, tirado.StatusCode);
            Assert.Empty((await tirado.Content.ReadFromJsonAsync<Guid[]>())!);

            Assert.Equal(HttpStatusCode.OK,
                (await publico.GetAsync($"/api/publico/apresentacoes/{codigo}")).StatusCode);
            Assert.Equal(HttpStatusCode.OK,
                (await publico.GetAsync($"/api/publico/apresentacoes/{codigo}/fila")).StatusCode);
        }
        finally
        {
            ExcluirBanco(banco);
        }
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

    private static Cenario CriarCenario(string? arquivo = null)
    {
        var repo = new RepositorioTocaEssa(arquivo);
        var token = repo.CriarContaArtista("Ana", "ana@artista.com", "senha").Token;
        repo.SalvarPerfilDaConta(token, new SalvarPerfilArtistico("Ana", null));
        var show = repo.CriarApresentacao(token, "Casamento", new DateOnly(2026, 10, 10), "Salão");
        var pedidos = new[] { "Evidências", "Pense em Mim", "Tempo Perdido" }
            .Select(musica => repo.CriarPedido(show.Codigo, musica, null, "Convidado"))
            .ToArray();
        return new Cenario(repo, token, show, pedidos);
    }

    private static void ExcluirBanco(string caminho)
    {
        SqliteConnection.ClearAllPools();
        foreach (var arquivo in new[] { caminho, $"{caminho}-shm", $"{caminho}-wal", $"{caminho}.json" })
            if (File.Exists(arquivo)) File.Delete(arquivo);
    }

    private sealed record Cenario(
        RepositorioTocaEssa Repo, string Token, Apresentacao Show, PedidoMusical[] Pedidos);
}
