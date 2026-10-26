using TocaEssaApp.Api.Dominio;

namespace TocaEssaApp.Testes;

/// A ordem de quem canta: o sorteio, quem chega depois e as correções.
public sealed class OrdemDoKaraokeTestes
{
    private static readonly Guid Ana = Guid.NewGuid();
    private static readonly Guid Bia = Guid.NewGuid();
    private static readonly Guid Caio = Guid.NewGuid();
    private static readonly Guid Davi = Guid.NewGuid();

    [Fact]
    public void SortearEmbaralhaTodaAGaleraSemRepetirNemPerderNinguem()
    {
        var galera = new[] { Ana, Bia, Caio, Davi };

        var ordens = Enumerable.Range(0, 50)
            .Select(semente => OrdemDoKaraoke.Sortear(galera, new Random(semente)))
            .ToArray();

        Assert.All(ordens, ordem => Assert.Equal(galera.Order(), ordem.Order()));
        Assert.Contains(ordens, ordem => !ordem.SequenceEqual(galera));
    }

    [Fact]
    public void QuemChegaDepoisDoSorteioEntraNoFimPelaOrdemDeChegada()
    {
        var ordem = OrdemDoKaraoke.Montar(
            sorteados: [Caio, Ana],
            galeraPorChegada: [Ana, Caio, Davi, Bia],
            retirados: []);

        Assert.Equal([Caio, Ana, Davi, Bia], ordem);
    }

    [Fact]
    public void QuemFoiTiradoOuSaiuDaGaleraNaoFicaNaOrdem()
    {
        var ordem = OrdemDoKaraoke.Montar(
            sorteados: [Caio, Ana, Bia],
            galeraPorChegada: [Ana, Bia, Davi],
            retirados: [Bia]);

        Assert.Equal([Ana, Davi], ordem);
    }

    [Fact]
    public void PassarAVezTrocaComOSeguinteEOUltimoFicaOndeEsta()
    {
        Assert.Equal([Bia, Ana, Caio], OrdemDoKaraoke.PassarAVez([Ana, Bia, Caio], Ana));
        Assert.Equal([Ana, Bia, Caio], OrdemDoKaraoke.PassarAVez([Ana, Bia, Caio], Caio));
        Assert.Equal([Ana, Bia], OrdemDoKaraoke.PassarAVez([Ana, Bia], Davi));
    }
}
