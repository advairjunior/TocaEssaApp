using TocaEssaApp.Api.Dominio;

namespace TocaEssaApp.Testes;

public sealed class LetraDoHinoTestes
{
    private const string PorCristoResgatado = """
        Cristo Jesus, o santo Cordeiro
        Deu Sua vida sobre o madeiro
        Com o Seu sangue me resgatou
        D'Ele agora sou
        Refrão:
        Por Cristo, resgatado
        Sirvo ao grande Deus
        Para a Ele pertencer
        Junto aos santos Seus
        Preso estava na iniquidade
        Cristo me trouxe a liberdade
        Por Sua graça me resgatou
        D'Ele agora sou
        (Refrão)
        Tem minha alma grande alegria
        Sem esperança sempre vivia
        Glória a Jesus que me resgatou
        D'Ele agora sou
        (Refrão)
        """;

    private const string Refrao = """
        Por Cristo, resgatado
        Sirvo ao grande Deus
        Para a Ele pertencer
        Junto aos santos Seus
        """;

    [Fact]
    public void HinoColadoSemLinhaEmBrancoViraEstrofeERefraoAlternados()
    {
        var partes = LetraDoHino.Separar(PorCristoResgatado);

        Assert.Equal(
            [TipoDaParte.Estrofe, TipoDaParte.Refrao, TipoDaParte.Estrofe,
             TipoDaParte.Refrao, TipoDaParte.Estrofe, TipoDaParte.Refrao],
            partes.Select(parte => parte.Tipo));
        Assert.StartsWith("Cristo Jesus, o santo Cordeiro", partes[0].Texto);
        Assert.EndsWith("D'Ele agora sou", partes[0].Texto);
        Assert.Equal(Refrao, partes[1].Texto);
        Assert.StartsWith("Preso estava na iniquidade", partes[2].Texto);
        Assert.Equal(Refrao, partes[3].Texto);
        Assert.StartsWith("Tem minha alma grande alegria", partes[4].Texto);
        Assert.Equal(Refrao, partes[5].Texto);
    }

    [Fact]
    public void LinhaEmBrancoSempreSeparaPartes()
    {
        var partes = LetraDoHino.Separar("""
            Primeira linha
            Segunda linha

            CORO:
            Coro um
            Coro dois
            Coro três

            Estrofe dois

            (coro)
            """);

        Assert.Equal(
            [TipoDaParte.Estrofe, TipoDaParte.Refrao,
             TipoDaParte.Estrofe, TipoDaParte.Refrao],
            partes.Select(parte => parte.Tipo));
        Assert.Equal("Primeira linha\nSegunda linha", partes[0].Texto);
        Assert.Equal("Coro um\nCoro dois\nCoro três", partes[1].Texto);
        Assert.Equal("Estrofe dois", partes[2].Texto);
        Assert.Equal(partes[1].Texto, partes[3].Texto);
    }

    [Fact]
    public void RefraoEntraDepoisDeTodaEstrofeMesmoSemMarcador()
    {
        var partes = LetraDoHino.Separar("""
            A1
            A2
            Refrao:
            R1
            R2
            B1
            B2
            C1
            C2
            """);

        Assert.Equal(
            [TipoDaParte.Estrofe, TipoDaParte.Refrao, TipoDaParte.Estrofe,
             TipoDaParte.Refrao, TipoDaParte.Estrofe, TipoDaParte.Refrao],
            partes.Select(parte => parte.Tipo));
        Assert.Equal("R1\nR2", partes[1].Texto);
        Assert.Equal("B1\nB2", partes[2].Texto);
        Assert.Equal("C1\nC2", partes[4].Texto);
        Assert.Equal("R1\nR2", partes[5].Texto);
    }

    [Fact]
    public void HinoSemRefraoSeparaSoPelasLinhasEmBranco()
    {
        var partes = LetraDoHino.Separar("A1\nA2\n\nB1\nB2\n\n\nC1");

        Assert.Equal(3, partes.Count);
        Assert.All(partes, parte => Assert.Equal(TipoDaParte.Estrofe, parte.Tipo));
        Assert.Equal("C1", partes[2].Texto);
    }

    [Fact]
    public void TextoSemMarcadorNemLinhaEmBrancoFicaNumaParteSo()
    {
        var partes = LetraDoHino.Separar("A1\r\nA2\r\nA3");

        var parte = Assert.Single(partes);
        Assert.Equal("A1\nA2\nA3", parte.Texto);
    }

    private const string CifraComMarcadores = """
        Tom:  G

        (Estrofe 1)
        G        Bm    Am       D7
        Cristo Jesus, o santo Cordeiro
        G        Bm    Am       D7
        Deu Sua vida sobre o madeiro
        Bm       Em    Am      D7
        Com o Seu sangue me resgatou
        Em   A7    D7
        D'ele agora sou

        (Coro)
        G           Bm Am D7
        Por Cristo, resgatado
                         G
        Sirvo ao grande Deus
        Bm         C    Cm
        Para a Ele pertencer
        G          D7      G
        Junto aos santos Seus

        (Estrofe 2)
        G      Bm  Am       D7
        Preso estava na iniquidade
        G         Bm   Am     D7
        Cristo me trouxe a liberdade
        Bm     Em  Am      D7
        Por Sua graça me resgatou
        Em   A7    D7
        D'ele agora sou

        (Estrofe 3)
        G        Bm   Am        D7
        Tem minha alma grande alegria
        G       Bm   Am      D7
        Sem esperança sempre vivia
        Bm        Em    Am     D7
        Glória a Jesus que me regatou
        Em   A7    D7
        D'ele agora sou
        """;

    [Fact]
    public void MarcadoresDeEstrofeECoroSeparamACifraSemOTom()
    {
        var partes = LetraDoHino.Separar(CifraComMarcadores);

        Assert.Equal(
            [TipoDaParte.Estrofe, TipoDaParte.Refrao, TipoDaParte.Estrofe,
             TipoDaParte.Refrao, TipoDaParte.Estrofe, TipoDaParte.Refrao],
            partes.Select(parte => parte.Tipo));
        Assert.Equal("G        Bm    Am       D7\nCristo Jesus, o santo Cordeiro",
            string.Join('\n', partes[0].Texto.Split('\n').Take(2)));
        Assert.EndsWith("D'ele agora sou", partes[0].Texto);
        Assert.Contains("                 G\nSirvo ao grande Deus", partes[1].Texto);
        Assert.StartsWith("G      Bm  Am       D7\nPreso estava", partes[2].Texto);
        Assert.Equal(partes[1].Texto, partes[3].Texto);
        Assert.StartsWith("G        Bm   Am        D7\nTem minha alma", partes[4].Texto);
        Assert.Equal(partes[1].Texto, partes[5].Texto);
        Assert.DoesNotContain(partes, parte => parte.Texto.Contains("Tom"));
    }

    [Theory]
    [InlineData("[Estrofe 1]", "[Refrão]")]
    [InlineData("Estrofe 1:", "Coro:")]
    [InlineData("1ª estrofe", "REFRÃO")]
    [InlineData("1a Estrofe", "(refrao)")]
    public void MarcadoresEscritosDeJeitosDiferentes(string estrofe, string refrao)
    {
        var partes = LetraDoHino.Separar(
            $"Título do hino\n{estrofe}\nA1\nA2\n{refrao}\nR1\n{estrofe.Replace('1', '2')}\nB1");

        Assert.Equal(
            [TipoDaParte.Estrofe, TipoDaParte.Refrao,
             TipoDaParte.Estrofe, TipoDaParte.Refrao],
            partes.Select(parte => parte.Tipo));
        Assert.Equal("A1\nA2", partes[0].Texto);
        Assert.Equal("R1", partes[1].Texto);
        Assert.Equal("B1", partes[2].Texto);
    }

    [Fact]
    public void SolosEPartesInstrumentaisEntramDepoisDeEstrofeECoro()
    {
        var partes = LetraDoHino.Separar("""
            Tom: G
            (Introdução)
            G   D
            (Estrofe 1)
            A1
            (Coro)
            R1
            (Solo sax tenor 2x)
            G   Bm
            (Estrofe 2)
            B1
            [Interlúdio]
            C   D
            Final:
            G
            """);

        Assert.Equal(
            [TipoDaParte.Instrumental, TipoDaParte.Estrofe, TipoDaParte.Refrao,
             TipoDaParte.Instrumental, TipoDaParte.Estrofe, TipoDaParte.Refrao,
             TipoDaParte.Instrumental, TipoDaParte.Instrumental],
            partes.Select(parte => parte.Tipo));
        Assert.Equal(
            ["Introdução", null, null, "Solo sax tenor", null, null, "Interlúdio", "Final"],
            partes.Select(parte => parte.Nome));
        Assert.Equal("G   D", partes[0].Texto);
        Assert.Equal(2, partes[3].Vezes);
        Assert.Equal("G   Bm", partes[3].Texto);
        Assert.Equal("R1", partes[5].Texto);
        Assert.All(partes.Where(parte => parte != partes[3]),
            parte => Assert.Equal(1, parte.Vezes));
    }

    [Theory]
    [InlineData("(Solo trompete)", "Solo trompete")]
    [InlineData("(SOLO SAX)", "SOLO SAX")]
    [InlineData("(Intro)", "Intro")]
    [InlineData("Solo:", "Solo")]
    public void MarcacoesInstrumentaisEscritasDeJeitosDiferentes(string marcador, string nome)
    {
        var partes = LetraDoHino.Separar($"(Estrofe 1)\nA1\n{marcador}\nG   D");

        Assert.Equal(TipoDaParte.Instrumental, partes[^1].Tipo);
        Assert.Equal(nome, partes[^1].Nome);
    }

    [Fact]
    public void CoroComRepeticaoDefineOCoroEGuardaQuantasVezes()
    {
        var partes = LetraDoHino.Separar("(Estrofe 1)\nA1\n(Coro 2x)\nR1\n(Estrofe 2)\nB1");

        Assert.Equal(
            [TipoDaParte.Estrofe, TipoDaParte.Refrao,
             TipoDaParte.Estrofe, TipoDaParte.Refrao],
            partes.Select(parte => parte.Tipo));
        Assert.Equal(2, partes[1].Vezes);
        Assert.Equal("R1", partes[3].Texto);
    }

    [Fact]
    public void LinhaDoTomNuncaViraEstrofeMesmoSemMarcadores()
    {
        var partes = LetraDoHino.Separar("Tom: G\n\nA1\nA2\n\nB1");

        Assert.Equal(["A1\nA2", "B1"], partes.Select(parte => parte.Texto));
    }

    [Theory]
    [InlineData(null)]
    [InlineData("")]
    [InlineData("  \n \n")]
    public void LetraVaziaNaoTemPartes(string? texto)
    {
        Assert.Empty(LetraDoHino.Separar(texto));
    }
}
