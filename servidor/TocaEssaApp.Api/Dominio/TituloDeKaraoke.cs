using System.Globalization;
using System.Text.RegularExpressions;

namespace TocaEssaApp.Api.Dominio;

/// Limpa o título de um vídeo de karaokê do YouTube para virar o nome da
/// música: tira emoji e o "karaokê/version/playback..." que os canais põem,
/// e trecho todo em maiúsculas vira Título. Música e cantor não são
/// separados: os vídeos vêm ora "Cantor - Música", ora "Música - Cantor".
public static partial class TituloDeKaraoke
{
    public static string Limpar(string titulo)
    {
        var original = titulo.Trim();
        var trechos = Trechos(SemEmoji(original))
            .Select(SemRuido)
            .Where(trecho => trecho.Length > 0)
            .Select(EmTitulo);
        var limpo = string.Join(" - ", SemRepetidos(trechos));
        return limpo.Length > 0 ? limpo : original;
    }

    private static string SemEmoji(string texto) =>
        Emoji().Replace(texto, " ");

    /// O que vem depois de " | " só fica se não for ruído ("| KaraFun");
    /// os trechos são separados por " - ", " • " ou " = ".
    private static IEnumerable<string> Trechos(string texto)
    {
        var partes = texto.Split(" | ");
        var principal = partes.Take(1).Concat(partes.Skip(1).Where(parte => !TemRuido(parte)));
        return principal.SelectMany(parte => Separador().Split(parte));
    }

    private static bool TemRuido(string texto) => Ruido().IsMatch(texto);

    /// Parênteses só com ruído saem; o ruído solto sai; sobra o nome.
    private static string SemRuido(string trecho)
    {
        var semParenteses = Parenteses().Replace(trecho, grupo => TemRuido(grupo.Value) ? " " : grupo.Value);
        var semRuido = Ruido().Replace(semParenteses, " ");
        return Espacos().Replace(semRuido, " ").Trim(' ', ',', '-', '/');
    }

    /// "XOTE DOS MILAGRES" → "Xote dos Milagres"; trecho com minúsculas fica.
    private static string EmTitulo(string trecho)
    {
        if (trecho != trecho.ToUpperInvariant() || !trecho.Any(char.IsLetter)) return trecho;
        var palavras = trecho.ToLower(Portugues).Split(' ');
        return string.Join(' ', palavras.Select((palavra, indice) =>
            indice > 0 && Ligacoes.Contains(palavra) ? palavra : Maiuscula(palavra)));
    }

    private static string Maiuscula(string palavra) =>
        palavra.Length == 0 ? palavra : char.ToUpper(palavra[0], Portugues) + palavra[1..];

    private static IEnumerable<string> SemRepetidos(IEnumerable<string> trechos)
    {
        string? anterior = null;
        foreach (var trecho in trechos)
        {
            if (!string.Equals(trecho, anterior, StringComparison.CurrentCultureIgnoreCase))
                yield return trecho;
            anterior = trecho;
        }
    }

    private static readonly CultureInfo Portugues = CultureInfo.GetCultureInfo("pt-BR");

    private static readonly HashSet<string> Ligacoes =
        ["a", "o", "e", "as", "os", "de", "da", "do", "das", "dos", "em", "na", "no", "nas", "nos",
         "pra", "por", "que", "com", "to", "of", "the", "and"];

    [GeneratedRegex(@"[\p{So}\p{Cs}️‍]")]
    private static partial Regex Emoji();

    [GeneratedRegex(@"\s+[-–•=]\s+")]
    private static partial Regex Separador();

    [GeneratedRegex(@"[\(\[][^\)\]]*[\)\]]")]
    private static partial Regex Parenteses();

    [GeneratedRegex(@"\s+")]
    private static partial Regex Espacos();

    /// Palavras e expressões que os canais de karaokê põem no título.
    [GeneratedRegex(
        @"\b(karaok[eê](\s+(de\s+arrocha|version|vers[aã]o|oficial|original|completo|com\s+2ª\s+voz))*" +
        @"|vers[aã]o\s+karaok[eê]|(karaok[eê]\s+)?version(\s+original)?|karafun|playback(\s+ac[uú]stico)?" +
        @"|(100%\s+)?instrumental|oficial|cover|com\s+letra|sem\s+vocal|(com\s+)?back(ing)?\s?vocal" +
        @"|\d+\s+tom\s+(abaixo|acima)|jazz\s+acoustic\s+with\s+lyrics|lyrics|male\s+key|female\s+key" +
        @"|cante\s+junto|melhor\s+karaok[eê]|hd)\b(?!\p{L})",
        RegexOptions.IgnoreCase)]
    private static partial Regex Ruido();
}
