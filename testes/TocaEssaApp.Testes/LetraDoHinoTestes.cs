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

    [Theory]
    [InlineData(null)]
    [InlineData("")]
    [InlineData("  \n \n")]
    public void LetraVaziaNaoTemPartes(string? texto)
    {
        Assert.Empty(LetraDoHino.Separar(texto));
    }
}
