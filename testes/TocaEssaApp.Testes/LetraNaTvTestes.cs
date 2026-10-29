using TocaEssaApp.Api.Dominio;
using TocaEssaApp.Api.Infraestrutura;

namespace TocaEssaApp.Testes;

/// A TV abre o site, mostra um código e fica presa à conta que digitou o
/// código. O celular do dono manda a letra e a linha; a TV acompanha.
public sealed class LetraNaTvTestes
{
    private const string Cifra = "[Refrão]\nG        D\nCanta comigo\nninguém fica de fora";

    [Fact]
    public void TvNovaMostraCodigoAteSerPareada()
    {
        var repo = new RepositorioTocaEssa();

        var tv = repo.CriarTv();
        var estado = repo.ObterEstadoDaTv(tv.Token);

        Assert.Matches("^[A-HJ-NP-Z2-9]{4}$", tv.Codigo);
        Assert.False(estado.Pareada);
        Assert.Equal(tv.Codigo, estado.Codigo);
        Assert.Null(estado.Conteudo);
    }

    [Fact]
    public void CodigoDigitadoNoCelularPrendeATvNaConta()
    {
        var repo = new RepositorioTocaEssa();
        var token = CriarArtista(repo);
        var tv = repo.CriarTv();

        var pareada = repo.ParearTv(token, $" {tv.Codigo.ToLowerInvariant()} ");
        var estado = repo.ObterEstadoDaTv(tv.Token);

        Assert.Equal(tv.Id, pareada.Id);
        Assert.True(estado.Pareada);
        Assert.Null(estado.Codigo);
        Assert.Equal([tv.Id], repo.ListarTvs(token).Select(item => item.Id));
    }

    [Fact]
    public void CodigoErradoOuJaUsadoNaoPareia()
    {
        var repo = new RepositorioTocaEssa();
        var token = CriarArtista(repo);
        var tv = repo.CriarTv();
        repo.ParearTv(token, tv.Codigo);

        Assert.Throws<CodigoDaTvNaoEncontradoException>(() => repo.ParearTv(token, "ZZZZ"));
        Assert.Throws<CodigoDaTvNaoEncontradoException>(
            () => repo.ParearTv(CriarArtista(repo), tv.Codigo));
    }

    [Fact]
    public void TokenDesconhecidoNaoEhTv()
    {
        var repo = new RepositorioTocaEssa();

        Assert.Throws<TvNaoEncontradaException>(() => repo.ObterEstadoDaTv("nao-existe"));
    }

    [Fact]
    public void TvMostraALetraEALinhaDoCelularDoDono()
    {
        var repo = new RepositorioTocaEssa();
        var token = CriarArtista(repo);
        var tv = Parear(repo, token);

        repo.MostrarNaTv(token, new MostrarNaTv(
            "Fim de tarde", "Turma da Resenha", Cifra, "Lua de São Jorge", "RSN482", 0));
        repo.IrParaALinhaNaTv(token, 1);

        var conteudo = repo.ObterEstadoDaTv(tv.Token).Conteudo!;
        Assert.Equal("Fim de tarde", conteudo.Titulo);
        Assert.Equal("Turma da Resenha", conteudo.Subtitulo);
        Assert.Equal(Cifra, conteudo.Texto);
        Assert.Equal("Lua de São Jorge", conteudo.ASeguir);
        Assert.Equal("RSN482", conteudo.Codigo);
        Assert.Equal(1, conteudo.Linha);
        Assert.Equal(1, conteudo.Versao);
    }

    [Fact]
    public void CadaMusicaNovaMudaAVersaoEApagarLimpaATv()
    {
        var repo = new RepositorioTocaEssa();
        var token = CriarArtista(repo);
        var tv = Parear(repo, token);

        repo.MostrarNaTv(token, new MostrarNaTv("Uma", null, Cifra, null, null, 0));
        repo.MostrarNaTv(token, new MostrarNaTv("Outra", null, Cifra, null, null, 0));
        Assert.Equal(2, repo.ObterEstadoDaTv(tv.Token).Conteudo!.Versao);

        repo.LimparTv(token);
        Assert.Null(repo.ObterEstadoDaTv(tv.Token).Conteudo);
    }

    [Fact]
    public void LinhaSemMusicaNaTvPedeOConteudoDeNovo()
    {
        var repo = new RepositorioTocaEssa();
        var token = CriarArtista(repo);
        Parear(repo, token);

        Assert.Throws<TvSemMusicaException>(() => repo.IrParaALinhaNaTv(token, 3));
    }

    [Fact]
    public void ConteudoInvalidoNaoVaiParaATv()
    {
        var repo = new RepositorioTocaEssa();
        var token = CriarArtista(repo);

        Assert.Throws<ConteudoDaTvInvalidoException>(() => repo.MostrarNaTv(token,
            new MostrarNaTv(" ", null, Cifra, null, null, 0)));
        Assert.Throws<ConteudoDaTvInvalidoException>(() => repo.MostrarNaTv(token,
            new MostrarNaTv("Longa", null, new string('a', 20_001), null, null, 0)));
        Assert.Throws<ConteudoDaTvInvalidoException>(() => repo.MostrarNaTv(token,
            new MostrarNaTv("Linha", null, Cifra, null, null, -1)));
        Assert.Throws<ConteudoDaTvInvalidoException>(() => repo.IrParaALinhaNaTv(token, -1));
    }

    [Fact]
    public void TvDeOutraContaNaoVeALetraNemPodeSerDesconectada()
    {
        var repo = new RepositorioTocaEssa();
        var dono = CriarArtista(repo);
        var outro = CriarArtista(repo);
        var tvDoDono = Parear(repo, dono);
        var tvDoOutro = Parear(repo, outro);

        repo.MostrarNaTv(dono, new MostrarNaTv("Só do dono", null, Cifra, null, null, 0));

        Assert.Null(repo.ObterEstadoDaTv(tvDoOutro.Token).Conteudo);
        Assert.Throws<TvNaoEncontradaException>(() => repo.DesconectarTv(outro, tvDoDono.Id));
        Assert.DoesNotContain(repo.ListarTvs(outro), item => item.Id == tvDoDono.Id);
    }

    [Fact]
    public void DesconectarFazATvPedirCodigoDeNovo()
    {
        var repo = new RepositorioTocaEssa();
        var token = CriarArtista(repo);
        var tv = Parear(repo, token);

        repo.DesconectarTv(token, tv.Id);

        Assert.Empty(repo.ListarTvs(token));
        Assert.Throws<TvNaoEncontradaException>(() => repo.ObterEstadoDaTv(tv.Token));
    }

    [Fact]
    public void SemSessaoDeArtistaNadaVaiParaATv()
    {
        var repo = new RepositorioTocaEssa();
        var tv = repo.CriarTv();

        Assert.Throws<SessaoArtistaInvalidaException>(() => repo.ParearTv("token-falso", tv.Codigo));
        Assert.Throws<SessaoArtistaInvalidaException>(() => repo.MostrarNaTv("token-falso",
            new MostrarNaTv("Música", null, Cifra, null, null, 0)));
    }

    [Fact]
    public void TvPareadaContinuaPresaDepoisQueOServidorDorme()
    {
        var arquivo = Path.Combine(Path.GetTempPath(), $"tv-{Guid.NewGuid():N}.db");
        var repo = new RepositorioTocaEssa(arquivo);
        var token = CriarArtista(repo);
        var tv = Parear(repo, token);

        var acordado = new RepositorioTocaEssa(arquivo);

        Assert.True(acordado.ObterEstadoDaTv(tv.Token).Pareada);
        Assert.Equal([tv.Id], acordado.ListarTvs(token).Select(item => item.Id));
    }

    [Fact]
    public async Task ALinhaChegaSoNoCanalDasTvsDaConta()
    {
        var notificador = new NotificadorTempoReal();
        var repo = new RepositorioTocaEssa(notificador: notificador);
        var token = CriarArtista(repo);
        var tv = Parear(repo, token);
        using var cancelamento = new CancellationTokenSource(TimeSpan.FromSeconds(2));
        await using var eventos = notificador
            .Assinar(CanalDaTv.De(tv.Id), cancelamento.Token)
            .GetAsyncEnumerator(cancelamento.Token);
        Assert.True(await eventos.MoveNextAsync());

        repo.MostrarNaTv(token, new MostrarNaTv("Música", null, Cifra, null, null, 0));
        Assert.True(await eventos.MoveNextAsync());
        Assert.Equal("linha:1:0", eventos.Current);

        repo.IrParaALinhaNaTv(token, 1);
        Assert.True(await eventos.MoveNextAsync());
        Assert.Equal("linha:1:1", eventos.Current);
    }

    private static string CriarArtista(RepositorioTocaEssa repo) =>
        repo.CriarContaArtista("Advair", $"advair-{Guid.NewGuid():N}@artista.com", "senha").Token;

    private static (Guid Id, string Token) Parear(RepositorioTocaEssa repo, string token)
    {
        var tv = repo.CriarTv();
        repo.ParearTv(token, tv.Codigo);
        return (tv.Id, tv.Token);
    }
}
