using System.Globalization;
using System.Text;

namespace TocaEssaApp.Api.Dominio;

public static class ServicoPix
{
    public static string Gerar(
        string chave,
        string nomeBeneficiario,
        string cidadeBeneficiario,
        decimal valor,
        string? mensagem)
    {
        if (valor is < 1m or > 1000m)
            throw new ValorApoioPixInvalidoException();

        var chaveNormalizada = chave.Trim();
        if (chaveNormalizada.Length is 0 or > 77)
            throw new ConfiguracaoPixInvalidaException();

        var contaPix = Campo("00", "BR.GOV.BCB.PIX") +
                       Campo("01", chaveNormalizada);
        var descricao = NormalizarTexto(mensagem, 40);
        if (descricao.Length > 0) contaPix += Campo("02", descricao);

        var valorFormatado = valor.ToString("0.00", CultureInfo.InvariantCulture);
        var payload =
            Campo("00", "01") +
            Campo("01", "11") +
            Campo("26", contaPix) +
            Campo("52", "0000") +
            Campo("53", "986") +
            Campo("54", valorFormatado) +
            Campo("58", "BR") +
            Campo("59", NormalizarTexto(nomeBeneficiario, 25)) +
            Campo("60", NormalizarTexto(cidadeBeneficiario, 15)) +
            Campo("62", Campo("05", "***")) +
            "6304";

        if (payload.Contains("5900", StringComparison.Ordinal) ||
            payload.Contains("6000", StringComparison.Ordinal))
            throw new ConfiguracaoPixInvalidaException();

        return payload + CalcularCrc(payload).ToString("X4");
    }

    public static bool CrcEhValido(string payload)
    {
        if (payload.Length < 8 || !payload[^8..^4].Equals(
                "6304", StringComparison.Ordinal))
            return false;
        return payload[^4..].Equals(
            CalcularCrc(payload[..^4]).ToString("X4"),
            StringComparison.OrdinalIgnoreCase);
    }

    private static string Campo(string id, string valor)
    {
        var tamanho = Encoding.UTF8.GetByteCount(valor);
        if (tamanho > 99) throw new ConfiguracaoPixInvalidaException();
        return $"{id}{tamanho:00}{valor}";
    }

    private static string NormalizarTexto(string? valor, int limite)
    {
        if (string.IsNullOrWhiteSpace(valor)) return string.Empty;
        var decomposto = valor.Trim().ToUpperInvariant()
            .Normalize(NormalizationForm.FormD);
        var texto = new string(decomposto
            .Where(caractere => CharUnicodeInfo.GetUnicodeCategory(caractere) !=
                                UnicodeCategory.NonSpacingMark)
            .Select(caractere => caractere is >= 'A' and <= 'Z' or >= '0' and <= '9'
                or ' ' or '.' or ',' or '/' or '-' or '+'
                ? caractere
                : ' ')
            .ToArray());
        texto = string.Join(' ', texto.Split(' ',
            StringSplitOptions.RemoveEmptyEntries));
        return texto.Length <= limite ? texto : texto[..limite].TrimEnd();
    }

    private static ushort CalcularCrc(string texto)
    {
        ushort crc = 0xFFFF;
        foreach (var byteAtual in Encoding.UTF8.GetBytes(texto))
        {
            crc ^= (ushort)(byteAtual << 8);
            for (var bit = 0; bit < 8; bit++)
                crc = (ushort)((crc & 0x8000) != 0
                    ? (crc << 1) ^ 0x1021
                    : crc << 1);
        }
        return crc;
    }
}

public sealed class ValorApoioPixInvalidoException : Exception;
public sealed class ConfiguracaoPixInvalidaException : Exception;
