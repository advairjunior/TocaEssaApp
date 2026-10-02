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
using TocaEssaApp.Api.Dominio;
using TocaEssaApp.Api.Infraestrutura;

namespace TocaEssaApp.Testes;

public class HistoricoPublicoTestes
{
    [Fact]
    public void HistoricoIncluiPresencaSemPedidoEEncontroEncerradoSemMisturarContas()
    {
        var repo = new RepositorioTocaEssa();
        repo.SalvarPerfil("Duo", null);
        var resenha = repo.CriarApresentacao("Entre amigos", new DateOnly(2026, 9, 1),
            "Casa", TipoApresentacao.ResenhaEntreAmigos);
        var show = repo.CriarApresentacao("Show", new DateOnly(2026, 9, 2), "Praça");
        var ana = repo.CriarPerfilPublico("Ana", "ana@teste.com", "senha123");
        var bia = repo.CriarPerfilPublico("Bia", "bia@teste.com", "senha123");
        repo.RegistrarParticipacaoNaResenha(resenha.Codigo, ana.Token);
        repo.CriarPedido(show.Codigo, "Evidências", null, null, bia.Token);
        repo.AlterarStatusApresentacao(resenha.Id, StatusApresentacao.Encerrada);

        var memoria = Assert.Single(repo.ListarApresentacoesDoPublico(ana.Token));
        Assert.Equal(resenha.Id, memoria.Id);
        Assert.Equal(StatusApresentacao.Encerrada, memoria.Status);
        Assert.Equal(show.Id, Assert.Single(repo.ListarApresentacoesDoPublico(bia.Token)).Id);
        Assert.Throws<SessaoPublicaInvalidaException>(() =>
            repo.ListarApresentacoesDoPublico("token-invalido"));
    }

    [Fact]
    public void HistoricoResumeCadaEncontroComMeusPedidosEMinhaCompanhiaNaResenha()
    {
        var repo = new RepositorioTocaEssa();
        repo.SalvarPerfil("Duo", null);
        var resenha = repo.CriarApresentacao("Roda", new DateOnly(2026, 9, 1),
            "Casa", TipoApresentacao.ResenhaEntreAmigos);
        var show = repo.CriarApresentacao("Show", new DateOnly(2026, 9, 20), "Praça");
        var ana = repo.CriarPerfilPublico("Ana", "ana@teste.com", "senha123");
        var bia = repo.CriarPerfilPublico("Bia", "bia@teste.com", "senha123");
        var caio = repo.CriarPerfilPublico("Caio", "caio@teste.com", "senha123");
        var davi = repo.CriarPerfilPublico("Davi", "davi@teste.com", "senha123");
        repo.RegistrarParticipacaoNaResenha(resenha.Codigo, ana.Token);
        repo.RegistrarParticipacaoNaResenha(resenha.Codigo, caio.Token);
        repo.CriarPedido(resenha.Codigo, "Garota", null, null, bia.Token);
        var tocada = repo.CriarPedido(resenha.Codigo, "Evidências", null, null, ana.Token);
        repo.CriarPedido(resenha.Codigo, "evidências", null, null, ana.Token);
        repo.CriarPedido(resenha.Codigo, "Trem-bala", null, null, ana.Token);
        var cancelado = repo.CriarPedido(resenha.Codigo, "Desisti", null, null, ana.Token);
        repo.CancelarPedidoPeloPublico(resenha.Codigo, cancelado.Id, ana.Token);
        repo.AlterarStatus(resenha.Id, tocada.Id, StatusPedidoMusical.Finalizado);
        repo.CriarPedido(show.Codigo, "Anunciação", null, null, ana.Token);
        repo.CriarPedido(show.Codigo, "Outra", null, null, davi.Token);

        var historico = repo.ListarHistoricoDoPublico(ana.Token).ToArray();

        Assert.Equal([show.Id, resenha.Id], historico.Select(item => item.Apresentacao.Id));
        var noShow = historico[0];
        Assert.Equal(1, noShow.Pedidos);
        Assert.Equal("Anunciação", Assert.Single(noShow.MinhasMusicas).Musica);
        // Em apresentação pública o público não é exposto a desconhecidos.
        Assert.Empty(noShow.Companhia);

        var naResenha = historico[1];
        Assert.Equal(3, naResenha.Pedidos);
        Assert.Equal(1, naResenha.PedidosTocados);
        var minhaMusica = naResenha.MinhasMusicas.First();
        Assert.Equal("evidências", minhaMusica.Musica, ignoreCase: true);
        Assert.Equal(2, minhaMusica.Quantidade);
        Assert.Equal(["Bia", "Caio"], naResenha.Companhia.Select(pessoa => pessoa.Nome));
        Assert.DoesNotContain(naResenha.Companhia, pessoa => pessoa.Nome == "Ana");

        var daBia = Assert.Single(repo.ListarHistoricoDoPublico(bia.Token));
        Assert.Equal(1, daBia.Pedidos);
        Assert.Equal(["Ana", "Caio"], daBia.Companhia.Select(pessoa => pessoa.Nome));
        Assert.Throws<SessaoPublicaInvalidaException>(() =>
            repo.ListarHistoricoDoPublico("token-invalido"));
    }

    [Fact]
    public async Task RotaDeHistoricoExigeSessaoDoPublicoEDevolveResumo()
    {
        var banco = Path.Combine(Path.GetTempPath(),
            $"tocaessa-historico-publico-{Guid.NewGuid():N}.db");
        try
        {
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
                        servicos.AddSingleton(new RepositorioTocaEssa(
                            banco, $"{banco}.json"));
                    });
                });
            using var cliente = fabrica.CreateClient();

            var semToken = await cliente.GetAsync("/api/publico/historico");
            Assert.Equal(HttpStatusCode.Unauthorized, semToken.StatusCode);

            var conta = await cliente.PostAsJsonAsync("/api/publico/contas",
                new { nome = "Ana", email = "ana@teste.com", senha = "senha123" });
            conta.EnsureSuccessStatusCode();
            using var sessao = JsonDocument.Parse(await conta.Content.ReadAsStringAsync());
            cliente.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue(
                "Bearer", sessao.RootElement.GetProperty("token").GetString());

            var resposta = await cliente.GetAsync("/api/publico/historico");
            Assert.Equal(HttpStatusCode.OK, resposta.StatusCode);
            using var json = JsonDocument.Parse(await resposta.Content.ReadAsStringAsync());
            Assert.Equal(JsonValueKind.Array, json.RootElement.ValueKind);
        }
        finally
        {
            foreach (var arquivo in new[] { banco, $"{banco}.json", $"{banco}-wal", $"{banco}-shm" })
                if (File.Exists(arquivo)) File.Delete(arquivo);
        }
    }
}
