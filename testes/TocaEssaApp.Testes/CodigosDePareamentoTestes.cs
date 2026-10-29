using TocaEssaApp.Api.Infraestrutura;

namespace TocaEssaApp.Testes;

/// O código que a TV mostra vale por 10 minutos; depois a TV pede outro.
public sealed class CodigosDePareamentoTestes
{
    [Fact]
    public void CodigoVencidoNaoEncontraMaisATv()
    {
        var agora = new DateTimeOffset(2026, 10, 29, 20, 0, 0, TimeSpan.Zero);
        var codigos = new CodigosDePareamento(() => agora);
        var tv = Guid.NewGuid();
        var codigo = codigos.Gerar(tv);

        agora = agora.AddMinutes(9);
        Assert.Equal(codigo, codigos.CodigoDa(tv));

        agora = agora.AddMinutes(2);
        Assert.Null(codigos.CodigoDa(tv));
        Assert.Null(codigos.Usar(codigo));
    }

    [Fact]
    public void CodigoUsadoUmaVezSome()
    {
        var codigos = new CodigosDePareamento(() => DateTimeOffset.UtcNow);
        var tv = Guid.NewGuid();
        var codigo = codigos.Gerar(tv);

        Assert.Equal(tv, codigos.Usar(codigo));
        Assert.Null(codigos.Usar(codigo));
        Assert.Null(codigos.CodigoDa(tv));
    }

    [Fact]
    public void GerarDeNovoTrocaOCodigoAntigo()
    {
        var codigos = new CodigosDePareamento(() => DateTimeOffset.UtcNow);
        var tv = Guid.NewGuid();
        var antigo = codigos.Gerar(tv);
        string novo;
        do novo = codigos.Gerar(tv); while (novo == antigo);

        Assert.Null(codigos.Usar(antigo));
        Assert.Equal(tv, codigos.Usar(novo));
    }
}
