using TocaEssaApp.Api.Dominio;
using TocaEssaApp.Api.Infraestrutura;

namespace TocaEssaApp.Testes;

/// A nota da galera na hora, o placar da noite e o karaokê em Meus encontros.
public sealed class NotaNoKaraokeTestes
{
    [Fact]
    public void AGaleraDaNotaNaHoraEVeAMediaEQuantosVotaram()
    {
        var cenario = CriarNoiteComAnaCantando();

        cenario.Repo.DarNotaNoKaraoke(cenario.Noite.Codigo, cenario.Bia.Token, 4);
        cenario.Repo.DarNotaNoKaraoke(cenario.Noite.Codigo, cenario.Caio.Token, 5);
        var mudou = cenario.Repo.DarNotaNoKaraoke(cenario.Noite.Codigo, cenario.Bia.Token, 5);

        Assert.Equal(5, mudou.Cantando?.Media);
        Assert.Equal(2, mudou.Cantando?.Votos);
        Assert.Equal(5, mudou.Cantando?.MinhaNota);
        var daAna = cenario.Repo.ObterNoiteDeKaraoke(cenario.Noite.Codigo, cenario.Ana.Token);
        Assert.Null(daAna.Cantando?.MinhaNota);
    }

    [Fact]
    public void NinguemVotaNaPropriaVezNemSemNinguemCantandoNemForaDe1A5()
    {
        var cenario = CriarNoiteComAnaCantando();

        Assert.Throws<NaoVotaNaPropriaVezException>(
            () => cenario.Repo.DarNotaNoKaraoke(cenario.Noite.Codigo, cenario.Ana.Token, 5));
        Assert.Throws<NotaDoKaraokeInvalidaException>(
            () => cenario.Repo.DarNotaNoKaraoke(cenario.Noite.Codigo, cenario.Bia.Token, 6));
        cenario.Repo.TerminarVezNoKaraoke(cenario.Noite.Codigo, cenario.Ana.Token);
        Assert.Throws<NinguemCantandoException>(
            () => cenario.Repo.DarNotaNoKaraoke(cenario.Noite.Codigo, cenario.Bia.Token, 5));
    }

    [Fact]
    public void OPlacarMostraQuemCantouEAVozDaNoiteSaiComTresVotos()
    {
        var cenario = CriarNoiteComAnaCantando();
        var davi = Entrar(cenario.Repo, cenario.Noite, "Davi");
        foreach (var quem in new[] { cenario.Bia, cenario.Caio, davi })
            cenario.Repo.DarNotaNoKaraoke(cenario.Noite.Codigo, quem.Token, 5);

        var noite = cenario.Repo.TerminarVezNoKaraoke(cenario.Noite.Codigo, cenario.Ana.Token);

        var linha = Assert.Single(noite.Placar);
        Assert.Equal(cenario.Ana.Perfil.Id, linha.PublicoId);
        Assert.Equal(1, linha.Musicas);
        Assert.Equal(5, linha.Media);
        Assert.Equal(cenario.Ana.Perfil.Id, noite.VozDaNoite);
    }

    [Fact]
    public void AsNotasFicamGuardadasEONoiteVaiParaMeusEncontros()
    {
        var arquivo = Path.Combine(Path.GetTempPath(), $"tocaessa-nota-{Guid.NewGuid():N}.db");
        try
        {
            var cenario = CriarNoiteComAnaCantando(arquivo);
            cenario.Repo.DarNotaNoKaraoke(cenario.Noite.Codigo, cenario.Bia.Token, 4);
            cenario.Repo.TerminarVezNoKaraoke(cenario.Noite.Codigo, cenario.Ana.Token);
            cenario.Repo.AlterarStatusApresentacao(
                cenario.Token, cenario.Noite.Id, StatusApresentacao.Encerrada);

            var reaberto = new RepositorioTocaEssa(arquivo);
            var encontro = Assert.Single(reaberto.ListarHistoricoDoPublico(cenario.Ana.Token));

            Assert.Equal(new KaraokeDoPublico(1, 4, false), encontro.NoKaraoke);
            Assert.Null(Assert.Single(reaberto.ListarHistoricoDoPublico(cenario.Bia.Token)).NoKaraoke?.Media);
        }
        finally
        {
            Microsoft.Data.Sqlite.SqliteConnection.ClearAllPools();
            File.Delete(arquivo);
        }
    }

    private static SessaoDoPublico Entrar(RepositorioTocaEssa repo, Apresentacao noite, string nome)
    {
        var sessao = repo.CriarPerfilPublico(
            nome, $"{nome.ToLowerInvariant()}-{Guid.NewGuid():N}@teste.com", "senha123");
        repo.RegistrarParticipacao(noite.Codigo, sessao.Token);
        return sessao;
    }

    /// Ana, Bia e Caio na galera; quem saiu primeiro no sorteio vira "Ana"
    /// para o teste e já está cantando.
    private static Cenario CriarNoiteComAnaCantando(string? arquivo = null)
    {
        var repo = new RepositorioTocaEssa(arquivo);
        var token = repo.CriarContaArtista(
            "Advair", $"advair-{Guid.NewGuid():N}@artista.com", "senha").Token;
        repo.SalvarPerfilDaConta(token, new SalvarPerfilArtistico("Advair", null));
        var noite = repo.CriarApresentacao(token, "Karaokê de sexta",
            new DateOnly(2026, 10, 30), "Casa", TipoApresentacao.Karaoke);
        var pessoas = new[] { "Ana", "Bia", "Caio" }.Select(nome => Entrar(repo, noite, nome)).ToList();
        var primeiro = repo.SortearOrdemDoKaraoke(token, noite.Id).Ordem[0].PublicoId;
        var ana = pessoas.Single(pessoa => pessoa.Perfil.Id == primeiro);
        var outros = pessoas.Where(pessoa => pessoa != ana).ToArray();
        repo.EscolherMusicaNoKaraoke(noite.Codigo, ana.Token,
            new EscolherMusicaDoKaraoke(null, "Evidências", null));
        repo.ComecarVezNoKaraoke(noite.Codigo, ana.Token);
        return new Cenario(repo, token, noite, ana, outros[0], outros[1]);
    }

    private sealed record Cenario(
        RepositorioTocaEssa Repo, string Token, Apresentacao Noite,
        SessaoDoPublico Ana, SessaoDoPublico Bia, SessaoDoPublico Caio);
}
