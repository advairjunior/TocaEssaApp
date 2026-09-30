using TocaEssaApp.Api.Dominio;
using TocaEssaApp.Api.Infraestrutura;

namespace TocaEssaApp.Testes;

public sealed class ApresentacoesMultiartistaTestes
{
    [Fact]
    public void ArtistasCriamEListamSomenteAsPropriasApresentacoes()
    {
        var (repositorio, ana, bia) = CriarRepositorioComDoisArtistas();

        var showAna = CriarApresentacao(
            repositorio, ana, "Show da Ana", TipoApresentacao.Publica);
        var showBia = CriarApresentacao(
            repositorio, bia, "Show da Bia", TipoApresentacao.Publica);

        Assert.Equal(ana.Conta.Id, showAna.ArtistaId);
        Assert.Equal(bia.Conta.Id, showBia.ArtistaId);
        Assert.Equal(showAna.Id, Assert.Single(
            ListarApresentacoes(repositorio, ana.Token)).Id);
        Assert.Equal(showBia.Id, Assert.Single(
            ListarApresentacoes(repositorio, bia.Token)).Id);
        Assert.Equal(showAna.Id,
            repositorio.ObterApresentacaoPublica(showAna.Codigo)?.Id);
        Assert.Equal(showBia.Id,
            repositorio.ObterApresentacaoPublica(showBia.Codigo)?.Id);
    }

    [Fact]
    public void ArtistaNaoAlteraApresentacaoDeOutraConta()
    {
        var (repositorio, ana, bia) = CriarRepositorioComDoisArtistas();
        var resenha = CriarApresentacao(
            repositorio, ana, "Resenha da Ana", TipoApresentacao.ResenhaEntreAmigos);

        Assert.Throws<ApresentacaoNaoEncontradaException>(() =>
            repositorio.EditarApresentacao(
                bia.Token, resenha.Id, "Invadida", resenha.Data,
                "Outro local", resenha.Tipo));
        Assert.Throws<ApresentacaoNaoEncontradaException>(() =>
            repositorio.AlterarStatusApresentacao(
                bia.Token, resenha.Id, StatusApresentacao.Encerrada));
        Assert.Throws<ApresentacaoNaoEncontradaException>(() =>
            repositorio.AtualizarFotoRetrospectiva(
                bia.Token, resenha.Id, "/arquivos/invasao.jpg"));
        Assert.Throws<ApresentacaoNaoEncontradaException>(() =>
            repositorio.ExcluirApresentacao(bia.Token, resenha.Id));

        var preservada = repositorio.ObterApresentacaoPublica(resenha.Codigo);
        Assert.NotNull(preservada);
        Assert.Equal("Resenha da Ana", preservada.Nome);
        Assert.Equal(StatusApresentacao.Agendada, preservada.Status);
        Assert.Null(preservada.FotoRetrospectivaUrl);
    }

    private static (RepositorioTocaEssa Repositorio, SessaoDoArtista Ana,
        SessaoDoArtista Bia) CriarRepositorioComDoisArtistas()
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
        return (repositorio, ana, bia);
    }

    private static Apresentacao CriarApresentacao(
        RepositorioTocaEssa repositorio,
        SessaoDoArtista sessao,
        string nome,
        TipoApresentacao tipo)
    {
        return repositorio.CriarApresentacao(
            sessao.Token, nome, new DateOnly(2026, 9, 30), "Bar", tipo);
    }

    private static IReadOnlyCollection<Apresentacao> ListarApresentacoes(
        RepositorioTocaEssa repositorio, string token)
    {
        return repositorio.ListarApresentacoes(token);
    }
}
