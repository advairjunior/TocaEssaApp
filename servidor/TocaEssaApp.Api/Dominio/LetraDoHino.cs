using System.Globalization;
using System.Text;
using System.Text.RegularExpressions;

namespace TocaEssaApp.Api.Dominio;

public enum TipoDaParte
{
    Estrofe,
    Refrao,
    Instrumental
}

/// [Nome] é o da parte instrumental, como "Solo sax tenor"; [Vezes] vem de
/// marcações como "(Coro 2x)".
public sealed record ParteDoHino(
    TipoDaParte Tipo, string Texto, string? Nome = null, int Vezes = 1);

/// Separa a letra (ou cifra) colada de um hino em estrofes, refrão e partes
/// instrumentais. Com marcadores como "(Estrofe 1)", "(Coro)" e "(Solo sax)",
/// eles mandam; sem eles, o app separa pelas linhas em branco e pelo tamanho
/// da primeira estrofe. A linha "Tom:" nunca vira parte, e os espaços que
/// alinham os acordes ficam. O hino com refrão é sempre cantado estrofe +
/// refrão, então o refrão entra depois de toda estrofe (antes de um solo,
/// inclusive) mesmo que a letra não o repita.
public static partial class LetraDoHino
{
    private enum TipoDoPedaco
    {
        Texto,
        Refrao,
        RepeteRefrao,
        Instrumental
    }

    private sealed record Pedaco(
        TipoDoPedaco Tipo, List<string> Linhas, string? Nome = null, int Vezes = 1);

    private sealed record Marcador(TipoDoPedaco Tipo, string Nome, int Vezes);

    public static IReadOnlyList<ParteDoHino> Separar(string? texto)
    {
        if (string.IsNullOrWhiteSpace(texto)) return [];
        var linhas = texto.Replace("\r\n", "\n").Replace('\r', '\n')
            .Split('\n')
            .Select(linha => linha.TrimEnd())
            .Where(linha => !LinhaDoTom().IsMatch(SemAcento(linha.Trim())))
            .ToList();
        if (linhas.Any(linha => LerMarcador(linha) is
                { Tipo: TipoDoPedaco.Texto or TipoDoPedaco.Instrumental }))
            return Montar(PicarPelosMarcadores(linhas));
        var pedacos = Picar(linhas);
        if (!TemLinhaEmBrancoNoMeio(linhas))
            pedacos = CortarPeloTamanhoDaEstrofe(pedacos);
        return Montar(pedacos);
    }

    /// A letra marca as estrofes ("(Estrofe 1)"…): dá para escalar sem
    /// adivinhar onde cada parte começa.
    public static bool TemMarcacaoDeEstrofe(string? texto) =>
        !string.IsNullOrWhiteSpace(texto) &&
        texto.Split('\n').Any(linha => LerMarcador(linha) is { Tipo: TipoDoPedaco.Texto });

    /// "(Estrofe 1)", "[Coro 2x]", "Solo sax tenor:", "(Introdução)"... ou
    /// nulo se a linha é letra ou acorde.
    private static Marcador? LerMarcador(string linha)
    {
        var original = Regex.Match(linha.Trim(), FormatoDoMarcador, RegexOptions.IgnoreCase);
        if (!original.Success) return null;
        var corpo = SemAcento(original.Groups["corpo"].Value);
        var vezes = int.TryParse(original.Groups["vezes"].Value, out var numero) && numero > 1
            ? numero
            : 1;
        TipoDoPedaco? tipo = corpo switch
        {
            _ when NomeDaEstrofe().IsMatch(corpo) => TipoDoPedaco.Texto,
            _ when NomeDoRefrao().IsMatch(corpo) => TipoDoPedaco.Refrao,
            _ when NomeInstrumental().IsMatch(corpo) => TipoDoPedaco.Instrumental,
            _ => null
        };
        return tipo is { } encontrado
            ? new Marcador(encontrado, original.Groups["corpo"].Value, vezes)
            : null;
    }

    /// Cada marcador começa uma parte; o que vem antes do primeiro (título)
    /// não é cantado. Refrão marcado sem texto é a repetição.
    private static List<Pedaco> PicarPelosMarcadores(List<string> linhas)
    {
        var pedacos = new List<Pedaco>();
        Pedaco? atual = null;
        void Fechar()
        {
            if (atual is null) return;
            var linhasDaParte = atual.Linhas
                .SkipWhile(linha => linha.Length == 0)
                .Reverse().SkipWhile(linha => linha.Length == 0).Reverse()
                .ToList();
            if (linhasDaParte.Count > 0 || atual.Tipo == TipoDoPedaco.Instrumental)
                pedacos.Add(atual with { Linhas = linhasDaParte });
            else if (atual.Tipo == TipoDoPedaco.Refrao)
                pedacos.Add(atual with { Tipo = TipoDoPedaco.RepeteRefrao });
            atual = null;
        }

        foreach (var linha in linhas)
        {
            if (LerMarcador(linha) is { } marcador)
            {
                Fechar();
                atual = new Pedaco(marcador.Tipo, [],
                    marcador.Tipo == TipoDoPedaco.Instrumental ? marcador.Nome : null,
                    marcador.Vezes);
            }
            else if (MarcadorDoRefrao().Match(SemAcento(linha.Trim())) is
                     { Success: true } refrao && refrao.Groups["resto"].Success)
            {
                Fechar();
                var resto = linha.Trim()[(linha.Trim().IndexOf(':') + 1)..].Trim();
                atual = new Pedaco(TipoDoPedaco.Refrao, [resto]);
            }
            else
            {
                atual?.Linhas.Add(linha);
            }
        }
        Fechar();
        return pedacos;
    }

    private static List<Pedaco> Picar(List<string> linhas)
    {
        var pedacos = new List<Pedaco>();
        Pedaco? atual = null;
        void Fechar()
        {
            if (atual is { Linhas.Count: > 0 }) pedacos.Add(atual);
            atual = null;
        }

        foreach (var linhaOriginal in linhas)
        {
            var linha = linhaOriginal.Trim();
            var marcador = SemAcento(linha);
            if (linha.Length == 0)
            {
                // "Refrão:" seguido de linha em branco: o refrão vem depois.
                if (atual is { Tipo: TipoDoPedaco.Refrao, Linhas.Count: 0 }) continue;
                Fechar();
            }
            else if (RepeticaoDoRefrao().IsMatch(marcador))
            {
                Fechar();
                pedacos.Add(new Pedaco(TipoDoPedaco.RepeteRefrao, []));
            }
            else if (CabecalhoDoRefrao().IsMatch(marcador))
            {
                Fechar();
                var resto = linha.Contains(':') ? linha[(linha.IndexOf(':') + 1)..].Trim() : "";
                atual = new Pedaco(TipoDoPedaco.Refrao, resto.Length > 0 ? [resto] : []);
            }
            else
            {
                atual ??= new Pedaco(TipoDoPedaco.Texto, []);
                atual.Linhas.Add(linhaOriginal);
            }
        }
        Fechar();
        return pedacos;
    }

    /// Sem linha em branco, o tamanho da estrofe é o da primeira, antes do
    /// refrão: o que vem colado ao refrão é cortado em estrofes desse tamanho.
    private static List<Pedaco> CortarPeloTamanhoDaEstrofe(List<Pedaco> pedacos)
    {
        var primeiroRefrao = pedacos.FindIndex(pedaco => pedaco.Tipo == TipoDoPedaco.Refrao);
        if (primeiroRefrao < 1 || pedacos[primeiroRefrao - 1].Tipo != TipoDoPedaco.Texto)
            return pedacos;
        var tamanho = pedacos[primeiroRefrao - 1].Linhas.Count;

        var resultado = new List<Pedaco>();
        for (var indice = 0; indice < pedacos.Count; indice++)
        {
            var pedaco = pedacos[indice];
            if (indice < primeiroRefrao || pedaco.Tipo == TipoDoPedaco.RepeteRefrao)
            {
                resultado.Add(pedaco);
                continue;
            }

            var linhas = pedaco.Linhas;
            if (pedaco.Tipo == TipoDoPedaco.Refrao)
            {
                var seguidoDeRepeticao = indice + 1 < pedacos.Count &&
                    pedacos[indice + 1].Tipo == TipoDoPedaco.RepeteRefrao;
                var linhasDoRefrao = seguidoDeRepeticao
                    ? (linhas.Count > tamanho ? linhas.Count - tamanho : linhas.Count)
                    : Math.Min(tamanho, linhas.Count);
                resultado.Add(new Pedaco(TipoDoPedaco.Refrao, linhas[..linhasDoRefrao]));
                linhas = linhas[linhasDoRefrao..];
            }

            for (var inicio = 0; inicio < linhas.Count; inicio += tamanho)
                resultado.Add(new Pedaco(TipoDoPedaco.Texto,
                    linhas.Skip(inicio).Take(tamanho).ToList()));
        }
        return resultado;
    }

    private static List<ParteDoHino> Montar(List<Pedaco> pedacos)
    {
        var primeiro = pedacos.FirstOrDefault(pedaco => pedaco.Tipo == TipoDoPedaco.Refrao);
        var refrao = primeiro is null ? null : string.Join('\n', primeiro.Linhas);
        var vezesDoRefrao = primeiro?.Vezes ?? 1;

        var partes = new List<ParteDoHino>();
        // Estrofe sem refrão logo depois ganha o refrão antes da próxima parte.
        void FecharEstrofe()
        {
            if (refrao is not null && partes is [.., { Tipo: TipoDaParte.Estrofe }])
                partes.Add(new ParteDoHino(TipoDaParte.Refrao, refrao, Vezes: vezesDoRefrao));
        }

        foreach (var pedaco in pedacos)
        {
            switch (pedaco.Tipo)
            {
                case TipoDoPedaco.Texto:
                    FecharEstrofe();
                    partes.Add(new ParteDoHino(
                        TipoDaParte.Estrofe, string.Join('\n', pedaco.Linhas), Vezes: pedaco.Vezes));
                    break;
                case TipoDoPedaco.Instrumental:
                    FecharEstrofe();
                    partes.Add(new ParteDoHino(TipoDaParte.Instrumental,
                        string.Join('\n', pedaco.Linhas), pedaco.Nome, pedaco.Vezes));
                    break;
                case TipoDoPedaco.Refrao:
                    partes.Add(new ParteDoHino(
                        TipoDaParte.Refrao, string.Join('\n', pedaco.Linhas), Vezes: pedaco.Vezes));
                    break;
                case TipoDoPedaco.RepeteRefrao when refrao is not null &&
                    partes is not [.., { Tipo: TipoDaParte.Refrao }]:
                    partes.Add(new ParteDoHino(TipoDaParte.Refrao, refrao,
                        Vezes: pedaco.Vezes > 1 ? pedaco.Vezes : vezesDoRefrao));
                    break;
            }
        }
        FecharEstrofe();
        return partes;
    }

    private static bool TemLinhaEmBrancoNoMeio(List<string> linhas)
    {
        var primeira = linhas.FindIndex(linha => linha.Length > 0);
        var ultima = linhas.FindLastIndex(linha => linha.Length > 0);
        return linhas.Skip(primeira).Take(ultima - primeira + 1).Any(linha => linha.Length == 0);
    }

    private static string SemAcento(string valor)
    {
        var resultado = new StringBuilder();
        foreach (var caractere in valor.Normalize(NormalizationForm.FormD))
            if (CharUnicodeInfo.GetUnicodeCategory(caractere) != UnicodeCategory.NonSpacingMark)
                resultado.Append(char.ToLowerInvariant(caractere));
        return resultado.ToString();
    }

    [GeneratedRegex(@"^(refrao|coro)\s*(:.*)?$")]
    private static partial Regex CabecalhoDoRefrao();

    [GeneratedRegex(@"^\(\s*(refrao|coro)\s*\)$")]
    private static partial Regex RepeticaoDoRefrao();

    [GeneratedRegex(@"^tom\s*:")]
    private static partial Regex LinhaDoTom();

    // Linha que pode ser marcação: entre parênteses, colchetes ou com dois
    // pontos no fim, com "2x" opcional para repetir.
    private const string FormatoDoMarcador =
        @"^[\(\[]?\s*(?<corpo>[^\(\)\[\]:]*?)\s*(?:(?<vezes>\d+)\s*x)?\s*[\)\]]?\s*:?$";

    // "Estrofe 1", "Estrofe", "1ª estrofe", "2a Estrofe".
    [GeneratedRegex(@"^(estrofe\s*\d*|\d+\s*[aªoº]?\s*estrofe)$")]
    private static partial Regex NomeDaEstrofe();

    [GeneratedRegex(@"^(refrao|coro)$")]
    private static partial Regex NomeDoRefrao();

    // "Solo", "Solo sax tenor", "Introdução", "Intro", "Interlúdio", "Final".
    [GeneratedRegex(@"^(solo\b.*|introducao|intro|interludio|final)$")]
    private static partial Regex NomeInstrumental();

    // "Refrão: primeira linha", com a letra na mesma linha da marcação.
    [GeneratedRegex(@"^[\(\[]?\s*(refrao|coro)\s*[\)\]]?\s*(:(?<resto>.*\S.*)|:)?$")]
    private static partial Regex MarcadorDoRefrao();
}
