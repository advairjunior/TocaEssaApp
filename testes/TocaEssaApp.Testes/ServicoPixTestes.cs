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

    [Theory]
    [InlineData("62982170618", "+5562982170618")]
    [InlineData("(62) 98217-0618", "+5562982170618")]
    [InlineData("5562982170618", "+5562982170618")]
    [InlineData("+55 62 98217-0618", "+5562982170618")]
    [InlineData("529.982.247-25", "52998224725")]
    [InlineData("52998224725", "52998224725")]
    [InlineData("11.222.333/0001-81", "11222333000181")]
    [InlineData(" Artista@Pix.COM ", "artista@pix.com")]
    [InlineData("123E4567-E89B-12D3-A456-426614174000",
        "123e4567-e89b-12d3-a456-426614174000")]
    [InlineData("chave-livre", "chave-livre")]
    public void NormalizaChaveConformeOTipo(string chave, string esperada)
    {
        Assert.Equal(esperada, ServicoPix.NormalizarChave(chave));
    }

    [Fact]
    public void PayloadUsaCelularNoFormatoInternacional()
    {
        var payload = ServicoPix.Gerar(
            "62982170618", "MATEUS OLIVEIRA MARINHO", "GOIANIA", 1m);

        Assert.Contains("0114+5562982170618", payload);
        Assert.True(ServicoPix.CrcEhValido(payload));
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
