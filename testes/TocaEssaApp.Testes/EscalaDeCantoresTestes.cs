using TocaEssaApp.Api.Dominio;

namespace TocaEssaApp.Testes;

public sealed class EscalaDeCantoresTestes
{
    private static readonly Guid HinoA = Guid.NewGuid();
    private static readonly Guid HinoB = Guid.NewGuid();

    [Fact]
    public void HinoSemEscolhasFicaSemNinguemDefinido()
    {
        var escala = EscalaDeCantores.Montar([Hino(HinoA, estrofes: 3)], ["João", "Ana"], []);

        Assert.All(escala.Hinos[0].Partes, parte =>
        {
            Assert.False(parte.Definida);
            Assert.Empty(parte.Cantores);
        });
        Assert.Equal(
            [new PlacarDoCantor("João", 0), new PlacarDoCantor("Ana", 0)],
            escala.Placar);
    }

    [Fact]
    public void EscolhasValemECadaParteCantadaValeUmPonto()
    {
        var escala = EscalaDeCantores.Montar(
            [Hino(HinoA, estrofes: 2)],
            ["João", "Ana"],
            [new EscolhaAMao(HinoA, 0, ["João"]),
             new EscolhaAMao(HinoA, 1, ["João", "Ana"]),
             new EscolhaAMao(HinoA, 3, [])]);

        var partes = escala.Hinos[0].Partes;
        Assert.Equal(["João"], partes[0].Cantores);
        Assert.Equal(["João", "Ana"], partes[1].Cantores);
        Assert.False(partes[2].Definida);
        Assert.True(partes[3].Definida);
        Assert.Empty(partes[3].Cantores);
        Assert.Equal(
            [new PlacarDoCantor("João", 2), new PlacarDoCantor("Ana", 1)],
            escala.Placar);
    }

    [Fact]
    public void EscalarHinoRevezaEstrofesECorosESoOCoroFinalEhDeTodos()
    {
        var escolhas = EscalaDeCantores.EscalarHino(
            [Hino(HinoA, estrofes: 3)], HinoA, ["João", "Ana", "Pedro"], []);

        Assert.Equal(
            ["João", "Ana", "Pedro", "João", "Ana", "Todos"],
            Quem(escolhas));
        Assert.Equal([0, 1, 2, 3, 4, 5], escolhas.Select(escolha => escolha.Indice));
        Assert.All(escolhas, escolha => Assert.Equal(HinoA, escolha.ItemId));
    }

    [Fact]
    public void EscalarHinoComecaPorQuemTemMenosPontosNosOutrosHinos()
    {
        var escolhas = EscalaDeCantores.EscalarHino(
            [Hino(HinoB, estrofes: 2), Hino(HinoA, estrofes: 2)],
            HinoA,
            ["João", "Ana", "Pedro"],
            [new EscolhaAMao(HinoB, 0, ["João"]),
             new EscolhaAMao(HinoB, 1, ["João"]),
             new EscolhaAMao(HinoB, 2, ["Ana"])]);

        Assert.Equal(["Pedro", "Ana", "Pedro", "Todos"], Quem(escolhas));
    }

    [Fact]
    public void EscalarHinoNaoDaDuasPartesSeguidasParaAMesmaPessoa()
    {
        var escolhas = EscalaDeCantores.EscalarHino(
            [Hino(HinoB, estrofes: 2), Hino(HinoA, estrofes: 3)],
            HinoA,
            ["Ana", "João"],
            [new EscolhaAMao(HinoB, 0, ["João"]),
             new EscolhaAMao(HinoB, 1, ["João"]),
             new EscolhaAMao(HinoB, 2, ["João"])]);

        Assert.Equal(["Ana", "João", "Ana", "João", "Ana", "Todos"], Quem(escolhas));
    }

    [Fact]
    public void EscalarHinoRefazOHinoInteiroSemContarOQueEleTinha()
    {
        var escolhas = EscalaDeCantores.EscalarHino(
            [Hino(HinoA, estrofes: 2)],
            HinoA,
            ["João", "Ana"],
            [new EscolhaAMao(HinoA, 0, ["Ana"]),
             new EscolhaAMao(HinoA, 1, ["Ana"])]);

        Assert.Equal(["João", "Ana", "João", "Todos"], Quem(escolhas));
    }

    [Fact]
    public void EscalarTodosVaiHinoAHinoNaOrdemERefazTudo()
    {
        var escolhas = EscalaDeCantores.EscalarTodos(
            [Hino(HinoA, estrofes: 2), new HinoParaEscala(Guid.NewGuid(), []), Hino(HinoB, estrofes: 2)],
            ["João", "Ana", "Pedro"],
            [new EscolhaAMao(HinoA, 0, ["Pedro"]), new EscolhaAMao(HinoB, 1, ["Pedro"])]);

        Assert.Equal(["João", "Ana", "Pedro", "Todos"],
            Quem(escolhas.Where(escolha => escolha.ItemId == HinoA)));
        Assert.Equal(["João", "Ana", "Pedro", "Todos"],
            Quem(escolhas.Where(escolha => escolha.ItemId == HinoB)));
        Assert.Equal(8, escolhas.Count);
    }

    [Fact]
    public void HinoSemCoroTemTodasAsEstrofesEscaladas()
    {
        var hino = new HinoParaEscala(HinoA,
        [
            new ParteDoHino(TipoDaParte.Estrofe, "a"),
            new ParteDoHino(TipoDaParte.Estrofe, "b"),
            new ParteDoHino(TipoDaParte.Estrofe, "c")
        ]);

        var escolhas = EscalaDeCantores.EscalarHino([hino], HinoA, ["Ana", "João"], []);

        Assert.Equal(["Ana", "João", "Ana"], Quem(escolhas));
    }

    [Fact]
    public void CoroFinalEhOUltimoCoroMesmoComFinalInstrumentalDepois()
    {
        var hino = new HinoParaEscala(HinoA,
        [
            new ParteDoHino(TipoDaParte.Estrofe, "a"),
            new ParteDoHino(TipoDaParte.Refrao, "r"),
            new ParteDoHino(TipoDaParte.Estrofe, "b"),
            new ParteDoHino(TipoDaParte.Refrao, "r"),
            new ParteDoHino(TipoDaParte.Instrumental, "G", "Final")
        ]);

        var escolhas = EscalaDeCantores.EscalarHino([hino], HinoA, ["Ana", "João"], []);

        Assert.Equal(["Ana", "João", "Ana", "Todos", "Todos"], Quem(escolhas));
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
        Solista[] solistas =
        [
            new Solista("José", "Sax tenor"),
            new Solista("Pedro", "trompete"),
            new Solista("Rui", "sax alto")
        ];

        var escolhas = EscalaDeCantores.EscalarHino([hino], HinoA, ["Ana"], [], solistas);
        var escala = EscalaDeCantores.Montar([hino], ["Ana"], escolhas, solistas);

        Assert.Equal(
            ["Todos", "Ana", "José", "Pedro", "Rui", "José", "Ana"],
            Quem(escolhas));
        Assert.Equal(
            [new PlacarDoSolista("José", 2), new PlacarDoSolista("Pedro", 1),
             new PlacarDoSolista("Rui", 1)],
            escala.PlacarDosSolos);
        Assert.Equal([new PlacarDoCantor("Ana", 2)], escala.Placar);
    }

    [Fact]
    public void SoloSemQuemTocaOInstrumentoFicaSemNinguem()
    {
        var hino = new HinoParaEscala(HinoA,
        [
            new ParteDoHino(TipoDaParte.Estrofe, "a"),
            new ParteDoHino(TipoDaParte.Instrumental, "", "Solo violino")
        ]);

        var escolhas = EscalaDeCantores.EscalarHino(
            [hino], HinoA, [], [], [new Solista("José", "sax tenor")]);

        Assert.Equal(["Todos", "Todos"], Quem(escolhas));
    }

    [Fact]
    public void SoloEscolhidoAMaoContaNoPlacarDosSolosENaoNosPontos()
    {
        var hino = new HinoParaEscala(HinoA,
        [
            new ParteDoHino(TipoDaParte.Estrofe, "a"),
            new ParteDoHino(TipoDaParte.Instrumental, "", "Solo sax")
        ]);

        var escala = EscalaDeCantores.Montar([hino], ["Rui"],
            [new EscolhaAMao(HinoA, 1, ["Rui"])],
            [new Solista("Rui", "sax")]);

        Assert.Equal([new PlacarDoSolista("Rui", 1)], escala.PlacarDosSolos);
        Assert.Equal([new PlacarDoCantor("Rui", 0)], escala.Placar);
    }

    [Fact]
    public void EscolhaDeParteQueNaoExisteMaisEhIgnorada()
    {
        var escala = EscalaDeCantores.Montar(
            [Hino(HinoA, estrofes: 2)],
            ["Ana"],
            [new EscolhaAMao(HinoA, 9, ["Ana"]), new EscolhaAMao(Guid.NewGuid(), 0, ["Ana"])]);

        Assert.All(escala.Hinos[0].Partes, parte => Assert.False(parte.Definida));
        Assert.Equal([new PlacarDoCantor("Ana", 0)], escala.Placar);
    }

    [Fact]
    public void SemCantoresEscalarDeixaAsPartesCantadasComTodos()
    {
        var escolhas = EscalaDeCantores.EscalarHino([Hino(HinoA, estrofes: 2)], HinoA, [], []);

        Assert.Equal(["Todos", "Todos", "Todos", "Todos"], Quem(escolhas));
    }

    private static HinoParaEscala Hino(Guid id, int estrofes) =>
        new(id, Enumerable.Range(1, estrofes)
            .SelectMany(numero => new[]
            {
                new ParteDoHino(TipoDaParte.Estrofe, $"estrofe {numero}"),
                new ParteDoHino(TipoDaParte.Refrao, "refrão")
            })
            .ToList());

    private static IEnumerable<string> Quem(IEnumerable<EscolhaAMao> escolhas) =>
        escolhas.OrderBy(escolha => escolha.Indice).Select(escolha =>
            escolha.Cantores.Count == 0 ? "Todos" : string.Join(" e ", escolha.Cantores));
}
