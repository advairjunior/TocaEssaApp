using TocaEssaApp.Api.Dominio;
using TocaEssaApp.Api.Infraestrutura;

namespace TocaEssaApp.Testes;

/// O músico convidado toca junto naquela noite: lê a setlist, a fila e o
/// louvor do dono e marca o que tocou. O resto do evento continua do dono.
public sealed class MusicosNoPalcoTestes
{
    [Fact]
    public void ConvidadoLeASetlistDoDonoEMarcaTocada()
    {
        var (repo, dono, bia, resenha) = CriarNoite(TipoApresentacao.ResenhaEntreAmigos);
        repo.AdicionarMusicaAvulsaAoSetlist(dono, resenha.Id, "Evidências", null, "A", null);

        var setlist = repo.ObterSetlist(bia, resenha.Id);
        repo.MarcarItemDoSetlist(bia, resenha.Id, setlist.Single().Id, true);

        Assert.Equal("Evidências", setlist.Single().Titulo);
        Assert.True(repo.ObterSetlist(dono, resenha.Id).Single().Tocada);
    }

    [Fact]
    public void ConvidadoVeOsPedidosETocaUm()
    {
        var (repo, dono, bia, resenha) = CriarNoite(TipoApresentacao.ResenhaEntreAmigos);
        var pedido = repo.CriarPedido(resenha.Codigo, "Lua de São Jorge", null, null, Publico(repo, resenha));
        repo.ColocarPedidoASeguir(dono, resenha.Id, pedido.Id, false);

        Assert.Equal([pedido.Id], repo.ListarPedidosASeguir(bia, resenha.Id));
        Assert.Single(repo.ListarPedidosDoArtista(bia, resenha.Id));
        var grupo = repo.ListarGruposDePedidosDoArtista(bia, resenha.Id).Single();
        repo.AlterarStatusDoGrupo(bia, resenha.Id, grupo.PedidoRepresentativoId, StatusPedidoMusical.TocandoAgora);
        repo.AlterarStatusDoGrupo(bia, resenha.Id, grupo.PedidoRepresentativoId, StatusPedidoMusical.Finalizado);

        Assert.Equal(StatusPedidoMusical.Finalizado,
            repo.ListarPedidosDoArtista(dono, resenha.Id).Single().Status);
        // Recusar o pedido é decisão do dono.
        Assert.Throws<ApresentacaoNaoEncontradaException>(() => repo.AlterarStatusDoGrupo(
            bia, resenha.Id, grupo.PedidoRepresentativoId, StatusPedidoMusical.NaoConhecemos));
    }

    [Fact]
    public void ConvidadoVeOLouvor()
    {
        var (repo, dono, bia, louvor) = CriarNoite(TipoApresentacao.Louvor);
        repo.AdicionarMusicaAvulsaAoSetlist(dono, louvor.Id, "Porque Ele vive", null, null, null);

        Assert.Equal("Porque Ele vive", repo.ObterLouvor(bia, louvor.Id).Hinos.Single().Titulo);
    }

    [Fact]
    public void OQueEhDoDonoContinuaSoDoDono()
    {
        var (repo, _, bia, resenha) = CriarNoite(TipoApresentacao.ResenhaEntreAmigos);
        var pedido = repo.CriarPedido(resenha.Codigo, "Lua de São Jorge", null, null, Publico(repo, resenha));

        Assert.Throws<ApresentacaoNaoEncontradaException>(
            () => repo.AdicionarMusicaAvulsaAoSetlist(bia, resenha.Id, "Outra", null, null, null));
        Assert.Throws<ApresentacaoNaoEncontradaException>(() => repo.LimparSetlist(bia, resenha.Id));
        Assert.Throws<ApresentacaoNaoEncontradaException>(
            () => repo.ColocarPedidoASeguir(bia, resenha.Id, pedido.Id, false));
        Assert.Throws<ApresentacaoNaoEncontradaException>(
            () => repo.ObterEstatisticasDaApresentacao(bia, resenha.Id));
        Assert.Throws<ApresentacaoNaoEncontradaException>(
            () => repo.AlterarStatusApresentacao(bia, resenha.Id, StatusApresentacao.Encerrada));
    }

    [Fact]
    public void QuemNaoFoiConvidadoOuSaiuNaoVeNada()
    {
        var (repo, dono, bia, resenha) = CriarNoite(TipoApresentacao.ResenhaEntreAmigos);
        var zeca = CriarArtista(repo, "Zeca");
        var item = repo.AdicionarMusicaAvulsaAoSetlist(dono, resenha.Id, "Evidências", null, null, null).Single();
        var idDaBia = repo.ListarMusicos(dono, resenha.Id).Single(m => !m.Dono).ArtistaId;

        Assert.Throws<ApresentacaoNaoEncontradaException>(() => repo.ObterSetlist(zeca, resenha.Id));
        Assert.Throws<ItemDoSetlistNaoEncontradoException>(
            () => repo.MarcarItemDoSetlist(zeca, resenha.Id, item.Id, true));
        repo.TirarMusico(dono, resenha.Id, idDaBia);
        Assert.Throws<ApresentacaoNaoEncontradaException>(() => repo.ObterSetlist(bia, resenha.Id));
        Assert.Throws<ApresentacaoNaoEncontradaException>(
            () => repo.ListarGruposDePedidosDoArtista(bia, resenha.Id));
    }

    private static (RepositorioTocaEssa Repo, string Dono, string Convidado, Apresentacao Evento)
        CriarNoite(TipoApresentacao tipo)
    {
        var repo = new RepositorioTocaEssa();
        var dono = CriarArtista(repo, "Advair");
        var evento = repo.CriarApresentacao(dono, "Resenha House", new DateOnly(2026, 10, 30), "Casa", tipo);
        var bia = CriarArtista(repo, "Bia");
        repo.EntrarPeloConvite(bia, repo.GerarConvite(dono, evento.Id));
        return (repo, dono, bia, evento);
    }

    private static string Publico(RepositorioTocaEssa repo, Apresentacao resenha)
    {
        var carla = repo.CriarPerfilPublico("Carla", $"carla-{Guid.NewGuid():N}@publico.com", "senha123");
        repo.RegistrarParticipacao(resenha.Codigo, carla.Token);
        return carla.Token;
    }

    private static string CriarArtista(RepositorioTocaEssa repo, string nome)
    {
        var token = repo.CriarContaArtista(nome, $"{nome}-{Guid.NewGuid():N}@artista.com", "senha123").Token;
        repo.SalvarPerfilDaConta(token, new SalvarPerfilArtistico(nome, null));
        return token;
    }
}
