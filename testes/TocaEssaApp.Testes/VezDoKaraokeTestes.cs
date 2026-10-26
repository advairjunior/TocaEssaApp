using TocaEssaApp.Api.Dominio;

namespace TocaEssaApp.Testes;

/// Quem canta depois de quem e o que a roleta pode sortear.
public sealed class VezDoKaraokeTestes
{
    private static readonly Guid Ana = Guid.NewGuid();
    private static readonly Guid Bia = Guid.NewGuid();
    private static readonly Guid Caio = Guid.NewGuid();

    private static VezDoKaraoke Vez(Guid pessoa, int indice) =>
        new(pessoa, new MusicaDoKaraoke("Evidências", null), indice, DateTimeOffset.UtcNow);

    [Fact]
    public void ONoiteComecaPeloPrimeiroEDepoisDoUltimoVoltaAoPrimeiro()
    {
        Assert.Equal(Ana, RegrasDaVez.Proximo([Ana, Bia, Caio], null));
        Assert.Equal(Bia, RegrasDaVez.Proximo([Ana, Bia, Caio], Vez(Ana, 0)));
        Assert.Equal(Ana, RegrasDaVez.Proximo([Ana, Bia, Caio], Vez(Caio, 2)));
        Assert.Null(RegrasDaVez.Proximo([], null));
    }

    [Fact]
    public void QuemCantouESaiuDaOrdemPassaAVezParaQuemFicouNoLugarDele()
    {
        // Bia cantou na 2ª posição e saiu: Caio, que era o seguinte, sobe.
        Assert.Equal(Caio, RegrasDaVez.Proximo([Ana, Caio], Vez(Bia, 1)));
        Assert.Equal(Ana, RegrasDaVez.Proximo([Ana, Caio], Vez(Bia, 5)));
    }

    [Fact]
    public void ARoletaNaoRepeteAsCantadasNemAsJaMostradasParaAPessoa()
    {
        var playlist = new[]
        {
            new MusicaDoKaraoke("Evidências", "https://www.youtube.com/watch?v=a"),
            new MusicaDoKaraoke("Trem-Bala", "https://www.youtube.com/watch?v=b"),
            new MusicaDoKaraoke("Exagerado", "https://www.youtube.com/watch?v=c")
        };

        var sorteadas = Enumerable.Range(0, 30)
            .Select(semente => RegrasDaVez.SortearDaRoleta(playlist,
                cantadas: [playlist[0].Chave], mostradas: [playlist[1].Chave],
                new Random(semente)))
            .ToArray();

        Assert.All(sorteadas, musica => Assert.Equal("Exagerado", musica?.Titulo));
    }

    [Fact]
    public void QuandoJaViuTodasARoletaVoltaAMostrarMasNuncaAsCantadas()
    {
        var playlist = new[]
        {
            new MusicaDoKaraoke("Evidências", "https://www.youtube.com/watch?v=a"),
            new MusicaDoKaraoke("Trem-Bala", "https://www.youtube.com/watch?v=b")
        };

        var musica = RegrasDaVez.SortearDaRoleta(playlist,
            cantadas: [playlist[0].Chave], mostradas: [playlist[1].Chave], new Random(1));
        var acabou = RegrasDaVez.SortearDaRoleta(playlist,
            cantadas: [playlist[0].Chave, playlist[1].Chave], mostradas: [], new Random(1));

        Assert.Equal("Trem-Bala", musica?.Titulo);
        Assert.Null(acabou);
    }

    [Theory]
    [InlineData("https://www.youtube.com/watch?v=abc", true)]
    [InlineData("https://youtu.be/abc", true)]
    [InlineData("https://m.youtube.com/watch?v=abc", true)]
    [InlineData("https://exemplo.com/video", false)]
    [InlineData("youtube", false)]
    public void SoLinkDoYouTubeServeParaOutraMusica(string link, bool valido) =>
        Assert.Equal(valido, RegrasDaVez.EhLinkDoYouTube(link));
}
