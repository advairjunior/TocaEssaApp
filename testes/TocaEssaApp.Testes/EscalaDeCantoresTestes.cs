using TocaEssaApp.Api.Dominio;

namespace TocaEssaApp.Testes;

public sealed class EscalaDeCantoresTestes
{
    private static readonly Guid HinoA = Guid.NewGuid();
    private static readonly Guid HinoB = Guid.NewGuid();

    [Fact]
    public void RefraoEUltimaEstrofeSaoDeTodosEAsOutrasRevezam()
    {
        var escala = EscalaDeCantores.Montar(
            [Hino(HinoA, estrofes: 3), Hino(HinoB, estrofes: 3)],
            ["João", "Ana", "Pedro"],
            []);

        Assert.Equal(
            ["João", "Todos", "Ana", "Todos", "Todos", "Todos"],
            Quem(escala.Hinos[0]));
        Assert.Equal(
            ["Pedro", "Todos", "João", "Todos", "Todos", "Todos"],
            Quem(escala.Hinos[1]));
        Assert.Equal(
            [new PlacarDoCantor("João", 2), new PlacarDoCantor("Ana", 1),
             new PlacarDoCantor("Pedro", 1)],
            escala.Placar);
    }

    [Fact]
    public void NinguemCantaDuasEstrofesSeguidasSeHouverOutroCantor()
    {
        var escala = EscalaDeCantores.Montar(
            [Hino(HinoA, estrofes: 4), Hino(HinoB, estrofes: 3)],
            ["Ana", "João"],
            [new EscolhaAMao(HinoB, 0, ["João"]), new EscolhaAMao(HinoB, 2, ["João"])]);

        Assert.Equal(
            ["Ana", "Todos", "João", "Todos", "Ana", "Todos", "Todos", "Todos"],
            Quem(escala.Hinos[0]));
    }

    [Fact]
    public void EscolhaAMaoFicaEContaNoPlacar()
    {
        var escala = EscalaDeCantores.Montar(
            [Hino(HinoA, estrofes: 3)],
            ["Ana", "João"],
            [new EscolhaAMao(HinoA, 0, ["Ana", "João"]),
             new EscolhaAMao(HinoA, 2, []),
             new EscolhaAMao(HinoA, 4, ["João"])]);

        var partes = escala.Hinos[0].Partes;
        Assert.Equal(["Ana", "João"], partes[0].Cantores);
        Assert.True(partes[0].EscolhidaAMao);
        Assert.Empty(partes[2].Cantores);
        Assert.True(partes[2].EscolhidaAMao);
        Assert.Equal(["João"], partes[4].Cantores);
        Assert.False(partes[1].EscolhidaAMao);
        Assert.Equal(
            [new PlacarDoCantor("Ana", 1), new PlacarDoCantor("João", 2)],
            escala.Placar);
    }

    [Fact]
    public void EscolhaDeParteQueNaoExisteMaisEhIgnorada()
    {
        var escala = EscalaDeCantores.Montar(
            [Hino(HinoA, estrofes: 2)],
            ["Ana"],
            [new EscolhaAMao(HinoA, 9, ["Ana"]), new EscolhaAMao(Guid.NewGuid(), 0, ["Ana"])]);

        Assert.Equal(["Ana", "Todos", "Todos", "Todos"], Quem(escala.Hinos[0]));
        Assert.Equal([new PlacarDoCantor("Ana", 1)], escala.Placar);
    }

    [Fact]
    public void SemCantoresTudoEhDeTodos()
    {
        var escala = EscalaDeCantores.Montar([Hino(HinoA, estrofes: 3)], [], []);

        Assert.All(escala.Hinos[0].Partes, parte => Assert.Empty(parte.Cantores));
        Assert.Empty(escala.Placar);
    }

    [Fact]
    public void HinoSemRefraoTambemDeixaAUltimaEstrofeParaTodos()
    {
        var hino = new HinoParaEscala(HinoA,
        [
            new ParteDoHino(TipoDaParte.Estrofe, "a"),
            new ParteDoHino(TipoDaParte.Estrofe, "b"),
            new ParteDoHino(TipoDaParte.Estrofe, "c")
        ]);

        var escala = EscalaDeCantores.Montar([hino], ["Ana", "João"], []);

        Assert.Equal(["Ana", "João", "Todos"], Quem(escala.Hinos[0]));
    }

    [Fact]
    public void SoloNaoEhEscaladoNemContaNoPlacarMesmoComNomeAMao()
    {
        var hino = new HinoParaEscala(HinoA,
        [
            new ParteDoHino(TipoDaParte.Estrofe, "a"),
            new ParteDoHino(TipoDaParte.Refrao, "r"),
            new ParteDoHino(TipoDaParte.Instrumental, "G D", "Solo sax", 2),
            new ParteDoHino(TipoDaParte.Estrofe, "b"),
            new ParteDoHino(TipoDaParte.Refrao, "r")
        ]);

        var automatica = EscalaDeCantores.Montar([hino], ["Ana", "João"], []);
        Assert.Equal(["Ana", "Todos", "Todos", "Todos", "Todos"], Quem(automatica.Hinos[0]));
        Assert.Equal("Solo sax", automatica.Hinos[0].Partes[2].Nome);
        Assert.Equal(2, automatica.Hinos[0].Partes[2].Vezes);

        var comSolista = EscalaDeCantores.Montar(
            [hino], ["Ana", "João"], [new EscolhaAMao(HinoA, 2, ["João"])]);
        Assert.Equal(["João"], comSolista.Hinos[0].Partes[2].Cantores);
        Assert.Equal(
            [new PlacarDoCantor("Ana", 1), new PlacarDoCantor("João", 0)],
            comSolista.Placar);
    }

    [Fact]
    public void SolosVaoParaQuemTocaOInstrumentoERevezam()
    {
        var hino = new HinoParaEscala(HinoA,
        [
            new ParteDoHino(TipoDaParte.Instrumental, "", "Introdução"),
            new ParteDoHino(TipoDaParte.Estrofe, "a"),
            new ParteDoHino(TipoDaParte.Instrumental, "", "Solo sax tenor"),
            new ParteDoHino(TipoDaParte.Instrumental, "", "Solo Trompete"),
            new ParteDoHino(TipoDaParte.Instrumental, "", "Solo sax"),
            new ParteDoHino(TipoDaParte.Instrumental, "", "Solo"),
            new ParteDoHino(TipoDaParte.Estrofe, "b")
        ]);

        var escala = EscalaDeCantores.Montar([hino], ["Ana"], [],
        [
            new Solista("José", "Sax tenor"),
            new Solista("Pedro", "trompete"),
            new Solista("Rui", "sax alto")
        ]);

        Assert.Equal(
            ["Todos", "Ana", "José", "Pedro", "Rui", "José", "Todos"],
            Quem(escala.Hinos[0]));
        Assert.Equal(
            [new PlacarDoSolista("José", 2), new PlacarDoSolista("Pedro", 1),
             new PlacarDoSolista("Rui", 1)],
            escala.PlacarDosSolos);
        Assert.Equal([new PlacarDoCantor("Ana", 1)], escala.Placar);
    }

    [Fact]
    public void SoloSemQuemTocaOInstrumentoFicaSemNinguem()
    {
        var hino = new HinoParaEscala(HinoA,
        [
            new ParteDoHino(TipoDaParte.Estrofe, "a"),
            new ParteDoHino(TipoDaParte.Instrumental, "", "Solo violino")
        ]);

        var escala = EscalaDeCantores.Montar([hino], [], [],
            [new Solista("José", "sax tenor")]);

        Assert.Empty(escala.Hinos[0].Partes[1].Cantores);
        Assert.Equal([new PlacarDoSolista("José", 0)], escala.PlacarDosSolos);
    }

    [Fact]
    public void SoloEscolhidoAMaoContaNoPlacarDosSolos()
    {
        var hino = new HinoParaEscala(HinoA,
        [
            new ParteDoHino(TipoDaParte.Estrofe, "a"),
            new ParteDoHino(TipoDaParte.Instrumental, "", "Solo sax"),
            new ParteDoHino(TipoDaParte.Instrumental, "", "Solo sax")
        ]);

        var escala = EscalaDeCantores.Montar([hino], [],
            [new EscolhaAMao(HinoA, 1, ["Rui"])],
            [new Solista("José", "sax"), new Solista("Rui", "sax")]);

        Assert.Equal(["Todos", "Rui", "José"], Quem(escala.Hinos[0]));
        Assert.Equal(
            [new PlacarDoSolista("José", 1), new PlacarDoSolista("Rui", 1)],
            escala.PlacarDosSolos);
    }

    private static HinoParaEscala Hino(Guid id, int estrofes) =>
        new(id, Enumerable.Range(1, estrofes)
            .SelectMany(numero => new[]
            {
                new ParteDoHino(TipoDaParte.Estrofe, $"estrofe {numero}"),
                new ParteDoHino(TipoDaParte.Refrao, "refrão")
            })
            .ToList());

    private static IEnumerable<string> Quem(HinoEscalado hino) =>
        hino.Partes.Select(parte =>
            parte.Cantores.Count == 0 ? "Todos" : string.Join(" e ", parte.Cantores));
}
