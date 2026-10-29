using TocaEssaApp.Api.Dominio;
using TocaEssaApp.Api.Infraestrutura;

namespace TocaEssaApp.Testes;

/// O dono passa o comando da TV a um ajudante, sem conta: só ele mexe na
/// linha até o dono retomar. A música continua vindo do celular do dono.
public sealed class ComandoDaTvTestes
{
    private const string Cifra = "[Refrão]\nG        D\nCanta comigo\nninguém fica de fora";

    [Fact]
    public void AjudanteVeALetraDaTvEMandaALinha()
    {
        var repo = new RepositorioTocaEssa();
        var dono = CriarArtista(repo);
        var tv = Parear(repo, dono);
        repo.MostrarNaTv(dono, Musica("Fim de tarde"));

        var comando = repo.PassarComando(dono);
        var ajudante = repo.ObterComando(comando.Token);
        repo.IrParaALinhaPeloAjudante(comando.Token, 1);

        Assert.True(repo.EstadoDoComando(dono).Ativo);
        Assert.Equal("Fim de tarde", ajudante.Conteudo?.Titulo);
        Assert.Equal(comando.Id, ajudante.Canal);
        Assert.Equal(1, repo.ObterEstadoDaTv(tv).Conteudo?.Linha);
    }

    [Fact]
    public void ComAjudanteALinhaDoDonoNaoMexeNaTvMasAMusicaSim()
    {
        var repo = new RepositorioTocaEssa();
        var dono = CriarArtista(repo);
        var tv = Parear(repo, dono);
        repo.MostrarNaTv(dono, Musica("Fim de tarde"));
        var comando = repo.PassarComando(dono);
        repo.IrParaALinhaPeloAjudante(comando.Token, 1);

        repo.IrParaALinhaNaTv(dono, 0);
        Assert.Equal(1, repo.ObterEstadoDaTv(tv).Conteudo?.Linha);

        repo.MostrarNaTv(dono, Musica("Lua de São Jorge"));
        Assert.Equal("Lua de São Jorge", repo.ObterComando(comando.Token).Conteudo?.Titulo);
        Assert.Equal(0, repo.ObterEstadoDaTv(tv).Conteudo?.Linha);
    }

    [Fact]
    public void RetomarDesfazOLinkEODonoVoltaAMandar()
    {
        var repo = new RepositorioTocaEssa();
        var dono = CriarArtista(repo);
        var tv = Parear(repo, dono);
        repo.MostrarNaTv(dono, Musica("Fim de tarde"));
        var comando = repo.PassarComando(dono);

        repo.RetomarComando(dono);
        repo.IrParaALinhaNaTv(dono, 1);

        Assert.False(repo.EstadoDoComando(dono).Ativo);
        Assert.Equal(1, repo.ObterEstadoDaTv(tv).Conteudo?.Linha);
        Assert.Throws<ComandoNaoEncontradoException>(() => repo.ObterComando(comando.Token));
        Assert.Throws<ComandoNaoEncontradoException>(() => repo.IrParaALinhaPeloAjudante(comando.Token, 0));
    }

    [Fact]
    public void LinkNovoDesfazOAnteriorEOutraContaNaoServe()
    {
        var repo = new RepositorioTocaEssa();
        var dono = CriarArtista(repo);
        var antigo = repo.PassarComando(dono);

        var novo = repo.PassarComando(dono);

        Assert.Throws<ComandoNaoEncontradoException>(() => repo.ObterComando(antigo.Token));
        Assert.Null(repo.ObterComando(novo.Token).Conteudo);
        Assert.False(repo.EstadoDoComando(CriarArtista(repo)).Ativo);
        Assert.Throws<ComandoNaoEncontradoException>(() => repo.ObterComando("nao-existe"));
    }

    [Fact]
    public void AjudanteSemMusicaNaTvRecebeAviso()
    {
        var repo = new RepositorioTocaEssa();
        var dono = CriarArtista(repo);
        var comando = repo.PassarComando(dono);

        Assert.Throws<TvSemMusicaException>(() => repo.IrParaALinhaPeloAjudante(comando.Token, 0));
    }

    private static MostrarNaTv Musica(string titulo) => new(titulo, null, Cifra, null, null, 0);

    private static string CriarArtista(RepositorioTocaEssa repo) =>
        repo.CriarContaArtista("Advair", $"advair-{Guid.NewGuid():N}@artista.com", "senha").Token;

    private static string Parear(RepositorioTocaEssa repo, string token)
    {
        var tv = repo.CriarTv();
        repo.ParearTv(token, tv.Codigo);
        return tv.Token;
    }
}
