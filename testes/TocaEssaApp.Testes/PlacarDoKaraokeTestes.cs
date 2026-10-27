using TocaEssaApp.Api.Dominio;

namespace TocaEssaApp.Testes;

/// O placar: média das músicas de cada um e a Voz da noite, que só conta
/// música com votos suficientes.
public sealed class PlacarDoKaraokeTestes
{
    private static readonly Guid Ana = Guid.NewGuid();
    private static readonly Guid Bia = Guid.NewGuid();
    private static readonly Guid Caio = Guid.NewGuid();

    private static VezDoKaraoke Vez(Guid pessoa, string musica, params int[] notas) =>
        new(pessoa, new MusicaDoKaraoke(musica, null), 0, DateTimeOffset.UtcNow, DateTimeOffset.UtcNow)
        {
            Notas = notas.Select((nota, indice) => (nota, indice))
                .ToDictionary(item => Guid.NewGuid(), item => item.nota)
        };

    [Fact]
    public void AMediaDeCadaUmEAMediaDasMusicasQueCantou()
    {
        var placar = PlacarDoKaraoke.Calcular(
        [
            Vez(Ana, "Evidências", 5, 5, 4, 4),
            Vez(Ana, "Exagerado", 3, 3, 3),
            Vez(Bia, "Trem-Bala", 4, 5, 5)
        ]);

        var ana = placar.Single(linha => linha.PublicoId == Ana);
        Assert.Equal(2, ana.Musicas);
        Assert.Equal(3.8, ana.Media); // (4,5 + 3) / 2, arredondado
        Assert.Equal(7, ana.Votos);
        Assert.Equal("Evidências", ana.MelhorMusica);
        Assert.Equal(Bia, placar[0].PublicoId); // 4,7 na frente
    }

    [Fact]
    public void QuemCantouSemVotoFicaNoFimSemMedia()
    {
        var placar = PlacarDoKaraoke.Calcular([Vez(Caio, "Tempo Perdido"), Vez(Ana, "Evidências", 2)]);

        Assert.Equal([Ana, Caio], placar.Select(linha => linha.PublicoId));
        Assert.Null(placar[1].Media);
    }

    [Fact]
    public void AVozDaNoiteSoContaMusicaComPeloMenosTresVotos()
    {
        var vezes = new[]
        {
            Vez(Ana, "Evidências", 5, 5),        // nota alta, mas só 2 votos
            Vez(Bia, "Trem-Bala", 4, 4, 5),
            Vez(Caio, "Exagerado", 3, 3, 3, 3)
        };

        Assert.Equal(Bia, PlacarDoKaraoke.VozDaNoite(vezes));
        Assert.Null(PlacarDoKaraoke.VozDaNoite([Vez(Ana, "Evidências", 5, 5)]));
    }
}
