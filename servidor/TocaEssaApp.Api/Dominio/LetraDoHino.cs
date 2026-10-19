using System.Globalization;
using System.Text;
using System.Text.RegularExpressions;

namespace TocaEssaApp.Api.Dominio;

public enum TipoDaParte
{
    Estrofe,
    Refrao
}

public sealed record ParteDoHino(TipoDaParte Tipo, string Texto);

/// Separa a letra (ou cifra) colada de um hino em estrofes e refrão. Com
/// marcadores como "(Estrofe 1)" e "(Coro)", eles mandam; sem eles, o app
/// separa pelas linhas em branco e pelo tamanho da primeira estrofe. A linha
/// "Tom:" nunca vira parte, e os espaços que alinham os acordes ficam. O hino
/// com refrão é sempre cantado estrofe + refrão, então o refrão entra depois
/// de toda estrofe mesmo que a letra não o repita.
public static partial class LetraDoHino
{
    private enum TipoDoPedaco
    {
        Texto,
        Refrao,
        RepeteRefrao
    }

    private sealed record Pedaco(TipoDoPedaco Tipo, List<string> Linhas);

    public static IReadOnlyList<ParteDoHino> Separar(string? texto)
    {
        if (string.IsNullOrWhiteSpace(texto)) return [];
        var linhas = texto.Replace("\r\n", "\n").Replace('\r', '\n')
            .Split('\n')
            .Select(linha => linha.TrimEnd())
            .Where(linha => !LinhaDoTom().IsMatch(SemAcento(linha.Trim())))
            .ToList();
        if (linhas.Any(linha => MarcadorDeEstrofe().IsMatch(SemAcento(linha.Trim()))))
            return Montar(PicarPelosMarcadores(linhas));
        var pedacos = Picar(linhas);
        if (!TemLinhaEmBrancoNoMeio(linhas))
            pedacos = CortarPeloTamanhoDaEstrofe(pedacos);
        return Montar(pedacos);
    }

    /// Cada marcador começa uma parte; o que vem antes do primeiro (título,
    /// introdução) não é cantado. Refrão marcado sem texto é a repetição.
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
            if (linhasDaParte.Count > 0)
                pedacos.Add(atual with { Linhas = linhasDaParte });
            else if (atual.Tipo == TipoDoPedaco.Refrao)
                pedacos.Add(new Pedaco(TipoDoPedaco.RepeteRefrao, []));
            atual = null;
        }

        foreach (var linha in linhas)
        {
            var marcador = SemAcento(linha.Trim());
            if (MarcadorDeEstrofe().IsMatch(marcador))
            {
                Fechar();
                atual = new Pedaco(TipoDoPedaco.Texto, []);
            }
            else if (MarcadorDoRefrao().Match(marcador) is { Success: true } refrao)
            {
                Fechar();
                var resto = refrao.Groups["resto"].Success
                    ? linha.Trim()[(linha.Trim().IndexOf(':') + 1)..].Trim()
                    : "";
                atual = new Pedaco(TipoDoPedaco.Refrao, resto.Length > 0 ? [resto] : []);
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
        var refrao = pedacos.FirstOrDefault(pedaco => pedaco.Tipo == TipoDoPedaco.Refrao)
            is { } primeiro ? string.Join('\n', primeiro.Linhas) : null;

        var partes = new List<ParteDoHino>();
        foreach (var pedaco in pedacos)
        {
            switch (pedaco.Tipo)
            {
                case TipoDoPedaco.Texto:
                    if (refrao is not null && partes is [.., { Tipo: TipoDaParte.Estrofe }])
                        partes.Add(new ParteDoHino(TipoDaParte.Refrao, refrao));
                    partes.Add(new ParteDoHino(TipoDaParte.Estrofe, string.Join('\n', pedaco.Linhas)));
                    break;
                case TipoDoPedaco.Refrao:
                    partes.Add(new ParteDoHino(TipoDaParte.Refrao, string.Join('\n', pedaco.Linhas)));
                    break;
                case TipoDoPedaco.RepeteRefrao when refrao is not null &&
                    partes is not [.., { Tipo: TipoDaParte.Refrao }]:
                    partes.Add(new ParteDoHino(TipoDaParte.Refrao, refrao));
                    break;
            }
        }
        if (refrao is not null && partes is [.., { Tipo: TipoDaParte.Estrofe }])
            partes.Add(new ParteDoHino(TipoDaParte.Refrao, refrao));
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

    // "(Estrofe 1)", "[Estrofe 2]", "Estrofe 3:", "1ª estrofe", "2a Estrofe".
    [GeneratedRegex(@"^[\(\[]?\s*(estrofe\s*\d*|\d+\s*[aªoº]?\s*estrofe)\s*[\)\]]?\s*:?$")]
    private static partial Regex MarcadorDeEstrofe();

    // "(Coro)", "[Refrão]", "Refrão:", "CORO" e "Refrão: primeira linha".
    [GeneratedRegex(@"^[\(\[]?\s*(refrao|coro)\s*[\)\]]?\s*(:(?<resto>.*\S.*)|:)?$")]
    private static partial Regex MarcadorDoRefrao();
}
