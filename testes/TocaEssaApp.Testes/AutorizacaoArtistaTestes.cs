using TocaEssaApp.Api.Dominio;
using TocaEssaApp.Api.Infraestrutura;

namespace TocaEssaApp.Testes;

public sealed class AutorizacaoArtistaTestes
{
    [Fact]
    public void ArtistaNaoConsultaDadosPrivadosDaApresentacaoDeOutro()
    {
        var cenario = CriarCenario();

        Assert.Throws<ApresentacaoNaoEncontradaException>(() =>
            cenario.Repositorio.ListarPedidosDoArtista(
                cenario.Bia.Token, cenario.Resenha.Id));
        Assert.Throws<ApresentacaoNaoEncontradaException>(() =>
            cenario.Repositorio.ListarGruposDePedidosDoArtista(
                cenario.Bia.Token, cenario.Resenha.Id));
        Assert.Throws<ApresentacaoNaoEncontradaException>(() =>
            cenario.Repositorio.ObterEstatisticasDaApresentacao(
                cenario.Bia.Token, cenario.Resenha.Id));
        Assert.Throws<ApresentacaoNaoEncontradaException>(() =>
            cenario.Repositorio.ListarParticipantesDaResenha(
                cenario.Bia.Token, cenario.Resenha.Id));
    }

    [Fact]
    public void ArtistaNaoGerenciaPedidoNemConfiguracaoDeOutro()
    {
        var cenario = CriarCenario();

        Assert.Throws<ApresentacaoNaoEncontradaException>(() =>
            cenario.Repositorio.AlterarStatus(
                cenario.Bia.Token, cenario.Resenha.Id, cenario.Pedido.Id,
                StatusPedidoMusical.Aceito));
        Assert.Throws<ApresentacaoNaoEncontradaException>(() =>
            cenario.Repositorio.AlterarStatusDoGrupo(
                cenario.Bia.Token, cenario.Resenha.Id, cenario.Pedido.Id,
                StatusPedidoMusical.Aceito));
        Assert.Throws<ApresentacaoNaoEncontradaException>(() =>
            cenario.Repositorio.AlterarPedidos(
                cenario.Bia.Token, cenario.Resenha.Id, false));

        var preservada = cenario.Repositorio.ObterPedidoPublico(
            cenario.Resenha.Codigo, cenario.Pedido.Id, cenario.Publico.Token);
        Assert.NotNull(preservada);
        Assert.Equal(StatusPedidoMusical.Aguardando, preservada.Status);
        Assert.True(cenario.Repositorio
            .ObterApresentacaoPublica(cenario.Resenha.Codigo)!.PedidosAbertos);
    }

    [Fact]
    public void ArtistaNaoReordenaFilaDeOutro()
    {
        var cenario = CriarCenario();
        cenario.Repositorio.AlterarStatus(
            cenario.Ana.Token, cenario.Resenha.Id, cenario.Pedido.Id,
            StatusPedidoMusical.Aceito);

        Assert.Throws<ApresentacaoNaoEncontradaException>(() =>
            cenario.Repositorio.ReordenarFila(
                cenario.Bia.Token, cenario.Resenha.Id, [cenario.Pedido.Id]));
        Assert.Throws<ApresentacaoNaoEncontradaException>(() =>
            cenario.Repositorio.ReordenarGruposDaFila(
                cenario.Bia.Token, cenario.Resenha.Id, [cenario.Pedido.Id]));

        var fila = cenario.Repositorio.ListarPedidosDoArtista(
            cenario.Ana.Token, cenario.Resenha.Id);
        Assert.Equal(cenario.Pedido.Id, Assert.Single(fila).Id);
        Assert.Equal(1, Assert.Single(fila).Posicao);
    }

    private static Cenario CriarCenario()
    {
        var repositorio = new RepositorioTocaEssa();
        var ana = repositorio.CriarContaArtista(
            "Ana", "ana@artista.com", "senha123");
        var bia = repositorio.CriarContaArtista(
            "Bia", "bia@artista.com", "outrasenha");
        repositorio.SalvarPerfilDaConta(
            ana.Token, new SalvarPerfilArtistico("Duo Aurora", null));
        repositorio.SalvarPerfilDaConta(
            bia.Token, new SalvarPerfilArtistico("Banda Horizonte", null));
        var resenha = repositorio.CriarApresentacao(
            ana.Token, "Resenha da Ana", new DateOnly(2026, 9, 30),
            "Bar", TipoApresentacao.ResenhaEntreAmigos);
        var publico = repositorio.CriarPerfilPublico(
            "Clara", "clara@publico.com", "senha123");
        repositorio.RegistrarParticipacaoNaResenha(
            resenha.Codigo, publico.Token);
        var pedido = repositorio.CriarPedido(
            resenha.Codigo, "Evidências", "Chitãozinho & Xororó", null,
            publico.Token);
        return new Cenario(repositorio, ana, bia, publico, resenha, pedido);
    }

    private sealed record Cenario(
        RepositorioTocaEssa Repositorio,
        SessaoDoArtista Ana,
        SessaoDoArtista Bia,
        SessaoDoPublico Publico,
        Apresentacao Resenha,
        PedidoMusical Pedido);
}
