using TocaEssaApp.Api.Dominio;
using TocaEssaApp.Api.Infraestrutura;

namespace TocaEssaApp.Testes;

/// Cada um escolhe a música no próprio celular, começa a vez no Tocar na TV
/// e a vez passa para o próximo da ordem.
public sealed class VezNoKaraokeTestes
{
    [Fact]
    public void NoModoLivreEscolheDaPlaylistEAGaleraVeAMusica()
    {
        var cenario = CriarKaraoke();
        var ana = Entrar(cenario, "Ana");
        var evidencias = cenario.Playlist.Musicas.First(musica => musica.Titulo == "Evidências");

        var noite = cenario.Repo.EscolherMusicaNoKaraoke(cenario.Noite.Codigo, ana.Token,
            new EscolherMusicaDoKaraoke(evidencias.Id, null, null));

        var musica = noite.Ordem.Single().Musica;
        Assert.Equal("Evidências", musica?.Titulo);
        Assert.Equal("https://www.youtube.com/watch?v=abc", musica?.LinkDoVideo);
    }

    [Fact]
    public void OutraMusicaComLinkDoYouTubeOuSemLink()
    {
        var cenario = CriarKaraoke();
        var ana = Entrar(cenario, "Ana");

        var comLink = cenario.Repo.EscolherMusicaNoKaraoke(cenario.Noite.Codigo, ana.Token,
            new EscolherMusicaDoKaraoke(null, "  Anunciação ", "https://youtu.be/xyz"));
        Assert.Equal(new MusicaDoKaraoke("Anunciação", "https://youtu.be/xyz"),
            comLink.Ordem.Single().Musica);

        var semLink = cenario.Repo.EscolherMusicaNoKaraoke(cenario.Noite.Codigo, ana.Token,
            new EscolherMusicaDoKaraoke(null, "Tempo Perdido", null));
        Assert.Null(semLink.Ordem.Single().Musica?.LinkDoVideo);

        Assert.Throws<MusicaDoKaraokeInvalidaException>(() => cenario.Repo.EscolherMusicaNoKaraoke(
            cenario.Noite.Codigo, ana.Token, new EscolherMusicaDoKaraoke(null, "Tempo", "https://exemplo.com")));
        Assert.Throws<MusicaDoKaraokeInvalidaException>(() => cenario.Repo.EscolherMusicaNoKaraoke(
            cenario.Noite.Codigo, ana.Token, new EscolherMusicaDoKaraoke(null, " ", null)));
    }

    [Fact]
    public void SoQuemEstaNaGaleraEscolhe()
    {
        var cenario = CriarKaraoke();
        var deFora = cenario.Repo.CriarPerfilPublico("Zé", "ze@teste.com", "senha123");

        Assert.Throws<ForaDaGaleraDoKaraokeException>(() => cenario.Repo.EscolherMusicaNoKaraoke(
            cenario.Noite.Codigo, deFora.Token, new EscolherMusicaDoKaraoke(null, "Evidências", null)));
    }

    [Fact]
    public void SoOProximoComecaEPrecisaTerAMusica()
    {
        var cenario = CriarKaraoke();
        var ana = Entrar(cenario, "Ana");
        var bia = Entrar(cenario, "Bia");

        Assert.Throws<EscolhaAMusicaAntesException>(
            () => cenario.Repo.ComecarVezNoKaraoke(cenario.Noite.Codigo, ana.Token));
        Escolher(cenario, bia, "Trem-Bala");
        Assert.Throws<AindaNaoEhSuaVezException>(
            () => cenario.Repo.ComecarVezNoKaraoke(cenario.Noite.Codigo, bia.Token));
    }

    [Fact]
    public void ComecarAVezMostraQuemCantaOProximoEFechaOSorteio()
    {
        var cenario = CriarKaraoke();
        var ana = Entrar(cenario, "Ana");
        var bia = Entrar(cenario, "Bia");
        Escolher(cenario, ana, "Evidências");

        var noite = cenario.Repo.ComecarVezNoKaraoke(cenario.Noite.Codigo, ana.Token);

        Assert.Equal(ana.Perfil.Id, noite.Cantando?.PublicoId);
        Assert.Equal("Evidências", noite.Cantando?.Musica.Titulo);
        Assert.Equal(bia.Perfil.Id, noite.Proximo);
        Assert.False(noite.PodeSortearDeNovo);
        // A música escolhida foi usada: para a próxima rodada, escolhe de novo.
        Assert.Null(noite.Ordem.First().Musica);
        Assert.Throws<KaraokeJaComecouException>(
            () => cenario.Repo.SortearOrdemDoKaraoke(cenario.Token, cenario.Noite.Id));
    }

    [Fact]
    public void OProximoComecarEncerraAVezDeQuemCantavaEAOrdemDaAVolta()
    {
        var cenario = CriarKaraoke();
        var ana = Entrar(cenario, "Ana");
        var bia = Entrar(cenario, "Bia");
        Escolher(cenario, ana, "Evidências");
        cenario.Repo.ComecarVezNoKaraoke(cenario.Noite.Codigo, ana.Token);
        Escolher(cenario, bia, "Trem-Bala");

        var vezDaBia = cenario.Repo.ComecarVezNoKaraoke(cenario.Noite.Codigo, bia.Token);
        Assert.Equal(bia.Perfil.Id, vezDaBia.Cantando?.PublicoId);
        Assert.Equal(ana.Perfil.Id, vezDaBia.Proximo);

        var terminou = cenario.Repo.TerminarVezNoKaraoke(cenario.Noite.Codigo, bia.Token);
        Assert.Null(terminou.Cantando);
        Assert.Equal(ana.Perfil.Id, terminou.Proximo);
    }

    [Fact]
    public void TocarNaTvDeNovoNaPropriaVezNaoCriaOutraVez()
    {
        var cenario = CriarKaraoke();
        var ana = Entrar(cenario, "Ana");
        Entrar(cenario, "Bia");
        Escolher(cenario, ana, "Evidências");
        var primeira = cenario.Repo.ComecarVezNoKaraoke(cenario.Noite.Codigo, ana.Token);

        var denovo = cenario.Repo.ComecarVezNoKaraoke(cenario.Noite.Codigo, ana.Token);

        Assert.Equal(primeira.Cantando, denovo.Cantando);
    }

    [Fact]
    public void SoQuemCantaTerminaAVezEODonoDestravaQualquerUma()
    {
        var cenario = CriarKaraoke();
        var ana = Entrar(cenario, "Ana");
        var bia = Entrar(cenario, "Bia");
        Escolher(cenario, ana, "Evidências");
        cenario.Repo.ComecarVezNoKaraoke(cenario.Noite.Codigo, ana.Token);

        Assert.Throws<AindaNaoEhSuaVezException>(
            () => cenario.Repo.TerminarVezNoKaraoke(cenario.Noite.Codigo, bia.Token));
        var destravada = cenario.Repo.TerminarVezNoKaraoke(cenario.Token, cenario.Noite.Id);

        Assert.Null(destravada.Cantando);
        Assert.Equal(bia.Perfil.Id, destravada.Proximo);
    }

    [Fact]
    public void NaRoletaOAppSorteiaDaPlaylistEOutroModoNaoVale()
    {
        var cenario = CriarKaraoke();
        var ana = Entrar(cenario, "Ana");
        Assert.Throws<KaraokeEmOutroModoException>(
            () => cenario.Repo.GirarRoletaDoKaraoke(cenario.Noite.Codigo, ana.Token));
        cenario.Repo.ConfigurarKaraoke(cenario.Token, cenario.Noite.Id,
            new ConfiguracaoDoKaraoke(null, ModoDasMusicas.Roleta));

        var primeira = cenario.Repo.GirarRoletaDoKaraoke(cenario.Noite.Codigo, ana.Token)
            .Ordem.Single().Musica;
        var segunda = cenario.Repo.GirarRoletaDoKaraoke(cenario.Noite.Codigo, ana.Token)
            .Ordem.Single().Musica;

        Assert.Contains(primeira?.Titulo, new[] { "Evidências", "Trem-Bala" });
        Assert.NotEqual(primeira, segunda);
        Assert.Throws<KaraokeEmOutroModoException>(() => cenario.Repo.EscolherMusicaNoKaraoke(
            cenario.Noite.Codigo, ana.Token, new EscolherMusicaDoKaraoke(null, "Outra", null)));
    }

    [Fact]
    public void AGaleraVeSoAsMusicasComVideoDaPlaylist()
    {
        var cenario = CriarKaraoke();
        var ana = Entrar(cenario, "Ana");

        var playlist = cenario.Repo.ListarPlaylistDoKaraoke(cenario.Noite.Codigo, ana.Token);

        Assert.Equal(["Evidências", "Trem-Bala"], playlist.Select(musica => musica.Titulo).Order());
    }

    [Fact]
    public void AVezEAEscolhaFicamGuardadasNoBanco()
    {
        var arquivo = Path.Combine(Path.GetTempPath(), $"tocaessa-vez-{Guid.NewGuid():N}.db");
        try
        {
            var cenario = CriarKaraoke(arquivo);
            var ana = Entrar(cenario, "Ana");
            var bia = Entrar(cenario, "Bia");
            Escolher(cenario, ana, "Evidências");
            cenario.Repo.ComecarVezNoKaraoke(cenario.Noite.Codigo, ana.Token);
            Escolher(cenario, bia, "Trem-Bala");

            var noite = new RepositorioTocaEssa(arquivo)
                .ObterNoiteDeKaraoke(cenario.Token, cenario.Noite.Id);

            Assert.Equal(ana.Perfil.Id, noite.Cantando?.PublicoId);
            Assert.Equal("Trem-Bala", noite.Ordem[1].Musica?.Titulo);
            Assert.False(noite.PodeSortearDeNovo);
        }
        finally
        {
            Microsoft.Data.Sqlite.SqliteConnection.ClearAllPools();
            File.Delete(arquivo);
        }
    }

    private static void Escolher(Cenario cenario, SessaoDoPublico pessoa, string titulo) =>
        cenario.Repo.EscolherMusicaNoKaraoke(cenario.Noite.Codigo, pessoa.Token,
            new EscolherMusicaDoKaraoke(null, titulo, null));

    private static SessaoDoPublico Entrar(Cenario cenario, string nome)
    {
        var sessao = cenario.Repo.CriarPerfilPublico(
            nome, $"{nome.ToLowerInvariant()}-{Guid.NewGuid():N}@teste.com", "senha123");
        cenario.Repo.RegistrarParticipacao(cenario.Noite.Codigo, sessao.Token);
        return sessao;
    }

    private static Cenario CriarKaraoke(string? arquivo = null)
    {
        var repo = new RepositorioTocaEssa(arquivo);
        var token = repo.CriarContaArtista(
            "Advair", $"advair-{Guid.NewGuid():N}@artista.com", "senha").Token;
        repo.SalvarPerfilDaConta(token, new SalvarPerfilArtistico("Advair", null));
        var noite = repo.CriarApresentacao(token, "Karaokê de sexta",
            new DateOnly(2026, 10, 30), "Casa", TipoApresentacao.Karaoke);
        var playlist = repo.AdicionarMusicasAoRepertorio(token, null, "Karaokê",
        [
            new AdicionarMusicaAoRepertorio("Evidências", null,
                LinkDoVideo: "https://www.youtube.com/watch?v=abc"),
            new AdicionarMusicaAoRepertorio("Trem-Bala", null,
                LinkDoVideo: "https://www.youtube.com/watch?v=def")
        ]).Repertorio;
        repo.AdicionarMusicaAoRepertorio(token, playlist.Id, "Sem vídeo", null);
        return new Cenario(repo, token, noite, playlist);
    }

    private sealed record Cenario(
        RepositorioTocaEssa Repo, string Token, Apresentacao Noite, Repertorio Playlist);
}
