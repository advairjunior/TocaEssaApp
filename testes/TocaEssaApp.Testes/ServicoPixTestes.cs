using System.Globalization;
using TocaEssaApp.Api.Dominio;

namespace TocaEssaApp.Testes;

public class ServicoPixTestes
{
    [Theory]
    [InlineData(1)]
    [InlineData(10)]
    [InlineData(1000)]
    public void PayloadPixTerminaComCrc16Valido(decimal valor)
    {
        var payload = ServicoPix.Gerar(
            "123e4567-e89b-12d3-a456-426614174000",
            "Duo Auróra",
            "São Paulo",
            valor);

        var valorFormatado = valor.ToString("0.00", CultureInfo.InvariantCulture);
        Assert.StartsWith("000201", payload);
        Assert.Contains($"54{valorFormatado.Length:00}{valorFormatado}", payload);
        Assert.Contains("DUO AURORA", payload);
        Assert.Contains("SAO PAULO", payload);
        Assert.Matches("6304[0-9A-F]{4}$", payload);
        Assert.True(ServicoPix.CrcEhValido(payload));
    }

    [Theory]
    [InlineData(0)]
    [InlineData(1000.01)]
    public void RejeitaValorForaDoIntervalo(decimal valor)
    {
        Assert.Throws<ValorApoioPixInvalidoException>(() =>
            ServicoPix.Gerar("chave", "ARTISTA", "RECIFE", valor));
    }

    [Fact]
    public void PayloadNaoContemMensagemDeAgradecimento()
    {
        var payload = ServicoPix.Gerar(
            "artista@pix.com", "DUO AURORA", "SAO PAULO", 10m);

        Assert.DoesNotContain("MUITO OBRIGADO", payload);
        Assert.True(ServicoPix.CrcEhValido(payload));
    }
}
