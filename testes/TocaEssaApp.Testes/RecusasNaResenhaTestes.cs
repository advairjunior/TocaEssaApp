using TocaEssaApp.Api.Dominio;
using TocaEssaApp.Api.Infraestrutura;

namespace TocaEssaApp.Testes;

public sealed class RecusasNaResenhaTestes
{
    [Fact]
    public void ParticipanteMostraQuantosPedidosOArtistaRecusou()
    {
        var (repositorio, sessao, resenha) = CriarResenha();
        var bia = EntrarNaResenha(repositorio, resenha, "Bia");
        var caio = EntrarNaResenha(repositorio, resenha, "Caio");
        var recusado = repositorio.CriarPedido(resenha.Codigo, "Macarena", null, null, bia);
        var naoSabe = repositorio.CriarPedido(resenha.Codigo, "Ragatanga", null, null, bia);
        var tocado = repositorio.CriarPedido(resenha.Codigo, "Evidências", null, null, caio);
        repositorio.AlterarStatus(sessao.Token, resenha.Id, recusado.Id,
            StatusPedidoMusical.NaoConhecemos);
        repositorio.AlterarStatus(sessao.Token, resenha.Id, naoSabe.Id,
            StatusPedidoMusical.AindaNaoSabemosTocar);
        repositorio.AlterarStatus(sessao.Token, resenha.Id, tocado.Id,
            StatusPedidoMusical.Finalizado);

        var participantes = repositorio.ListarParticipantesDaResenha(
            sessao.Token, resenha.Id);

        var participanteBia = participantes.Single(item => item.Nome == "Bia");
        Assert.Equal(2, participanteBia.PedidosRecusados);
        Assert.Equal(0, participanteBia.Pedidos);
        Assert.Equal(0, participantes.Single(item => item.Nome == "Caio").PedidosRecusados);
    }

    [Fact]
    public void EstatisticasListamAsMusicasRecusadasDaNoite()
    {
        var (repositorio, sessao, resenha) = CriarResenha();
        var bia = EntrarNaResenha(repositorio, resenha, "Bia");
        var caio = EntrarNaResenha(repositorio, resenha, "Caio");
        foreach (var token in new[] { bia, caio })
        {
            var pedido = repositorio.CriarPedido(
                resenha.Codigo, "Macarena", null, null, token);
            repositorio.AlterarStatus(sessao.Token, resenha.Id, pedido.Id,
                StatusPedidoMusical.NaoConhecemos);
        }
        repositorio.CriarPedido(resenha.Codigo, "Evidências", null, null, caio);

        var estatisticas = repositorio.ObterEstatisticasDaApresentacao(
            sessao.Token, resenha.Id);

        var polemica = Assert.Single(estatisticas.MusicasRecusadas!);
        Assert.Equal("Macarena", polemica.Musica);
        Assert.Equal(2, polemica.Quantidade);
    }

    private static (RepositorioTocaEssa, SessaoDoArtista, Apresentacao) CriarResenha()
    {
        var repositorio = new RepositorioTocaEssa();
        var sessao = repositorio.CriarContaArtista("Ana", "ana@artista.com", "senha123");
        repositorio.SalvarPerfilDaConta(sessao.Token,
            new SalvarPerfilArtistico("Duo Aurora", null));
        var resenha = repositorio.CriarApresentacao(sessao.Token, "Resenha",
            new DateOnly(2026, 10, 6), "Casa", TipoApresentacao.ResenhaEntreAmigos);
        return (repositorio, sessao, resenha);
    }

    private static string EntrarNaResenha(
        RepositorioTocaEssa repositorio, Apresentacao resenha, string nome)
    {
        var publico = repositorio.CriarPerfilPublico(
            nome, $"{nome}@publico.com", "senha123");
        repositorio.RegistrarParticipacaoNaResenha(resenha.Codigo, publico.Token);
        return publico.Token;
    }
}
