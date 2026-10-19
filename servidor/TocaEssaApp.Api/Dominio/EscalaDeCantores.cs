using System.Globalization;
using System.Text;

namespace TocaEssaApp.Api.Dominio;

public sealed record HinoParaEscala(Guid ItemId, IReadOnlyList<ParteDoHino> Partes);

/// Quem fica com uma parte; [Cantores] vazio quer dizer Todos (ou a banda
/// toda, numa parte instrumental).
public sealed record EscolhaAMao(Guid ItemId, int Indice, IReadOnlyList<string> Cantores);

/// Quem toca os solos e o instrumento, como "José" e "sax tenor".
public sealed record Solista(string Nome, string Instrumento);

/// [Definida] falso: a parte ainda não foi escalada. Definida e sem
/// [Cantores] é de Todos.
public sealed record ParteEscalada(
    TipoDaParte Tipo,
    string Texto,
    IReadOnlyList<string> Cantores,
    bool Definida,
    string? Nome = null,
    int Vezes = 1);

public sealed record HinoEscalado(Guid ItemId, IReadOnlyList<ParteEscalada> Partes);

/// Cada estrofe ou coro cantado no microfone vale um ponto.
public sealed record PlacarDoCantor(string Nome, int Pontos);

public sealed record PlacarDoSolista(string Nome, int Solos);

public sealed record EscalaMontada(
    IReadOnlyList<HinoEscalado> Hinos,
    IReadOnlyList<PlacarDoCantor> Placar,
    IReadOnlyList<PlacarDoSolista> PlacarDosSolos);

/// Escala do louvor. Nada é escalado sozinho: cada hino é escalado pelo
/// botão do artista ([EscalarHino]) e pode ser trocado parte a parte.
public static class EscalaDeCantores
{
    /// As partes de cada hino com quem ficou com elas, e os placares: pontos
    /// (estrofes e coros cantados) e solos.
    public static EscalaMontada Montar(
        IReadOnlyList<HinoParaEscala> hinos,
        IReadOnlyList<string> cantores,
        IReadOnlyCollection<EscolhaAMao> escolhas,
        IReadOnlyList<Solista>? solistas = null)
    {
        solistas ??= [];
        var validas = EscolhasValidas(hinos, escolhas);
        var (pontos, solos) = Contar(hinos, cantores, solistas, validas.Values);
        var escalados = hinos.Select(hino => new HinoEscalado(hino.ItemId,
            hino.Partes.Select((parte, indice) =>
                validas.TryGetValue((hino.ItemId, indice), out var escolha)
                    ? new ParteEscalada(
                        parte.Tipo, parte.Texto, escolha.Cantores, true, parte.Nome, parte.Vezes)
                    : new ParteEscalada(
                        parte.Tipo, parte.Texto, [], false, parte.Nome, parte.Vezes))
                .ToList()))
            .ToList();
        return new EscalaMontada(
            escalados,
            cantores.Select(nome => new PlacarDoCantor(nome, pontos[nome])).ToList(),
            solos.Select(par => new PlacarDoSolista(par.Key, par.Value)).ToList());
    }

    /// Escala o hino inteiro, refazendo o que ele tinha. Só o coro final é
    /// de Todos; cada estrofe e coro vai para quem tem menos pontos nos
    /// outros hinos, depois para quem está há mais tempo sem cantar, depois
    /// pela ordem da lista, sem a mesma pessoa em duas partes seguidas. Cada
    /// solo vai, pelo mesmo critério, para quem toca o instrumento dele;
    /// introdução, interlúdio e final são da banda toda.
    public static IReadOnlyList<EscolhaAMao> EscalarHino(
        IReadOnlyList<HinoParaEscala> hinos,
        Guid itemId,
        IReadOnlyList<string> cantores,
        IReadOnlyCollection<EscolhaAMao> escolhas,
        IReadOnlyList<Solista>? solistas = null)
    {
        solistas ??= [];
        var hino = hinos.FirstOrDefault(hino => hino.ItemId == itemId);
        if (hino is null) return [];

        var posicoes = new Dictionary<(Guid, int), int>();
        foreach (var outro in hinos)
            for (var indice = 0; indice < outro.Partes.Count; indice++)
                posicoes[(outro.ItemId, indice)] = posicoes.Count + 1;

        var dosOutros = EscolhasValidas(hinos, escolhas).Values
            .Where(escolha => escolha.ItemId != itemId)
            .ToList();
        var (pontos, solos) = Contar(hinos, cantores, solistas, dosOutros);
        var ultimaVez = cantores.ToDictionary(nome => nome, _ => -1);
        var ultimoSolo = solos.Keys.ToDictionary(nome => nome, _ => -1);
        foreach (var escolha in dosOutros.OrderBy(escolha => posicoes[(escolha.ItemId, escolha.Indice)]))
        {
            var instrumental = hinos.First(outro => outro.ItemId == escolha.ItemId)
                .Partes[escolha.Indice].Tipo == TipoDaParte.Instrumental;
            var vezes = instrumental ? ultimoSolo : ultimaVez;
            foreach (var nome in escolha.Cantores)
                if (vezes.ContainsKey(nome)) vezes[nome] = posicoes[(escolha.ItemId, escolha.Indice)];
        }

        var coroFinal = hino.Partes.Select((parte, indice) => (parte, indice))
            .Where(item => item.parte.Tipo == TipoDaParte.Refrao)
            .Select(item => item.indice)
            .DefaultIfEmpty(-1)
            .Last();
        IReadOnlyList<string> anterior = [];
        var resultado = new List<EscolhaAMao>();
        for (var indice = 0; indice < hino.Partes.Count; indice++)
        {
            var parte = hino.Partes[indice];
            var posicao = posicoes[(itemId, indice)];
            IReadOnlyList<string> quem;
            if (parte.Tipo == TipoDaParte.Instrumental)
            {
                quem = InstrumentoDoSolo(parte.Nome) is { } instrumento &&
                       QuemTocaOSolo(solistas, instrumento) is { Count: > 0 } candidatos
                    ? [Escolher(candidatos, solos, ultimoSolo, [])]
                    : [];
                foreach (var nome in quem)
                {
                    solos[nome]++;
                    ultimoSolo[nome] = posicao;
                }
            }
            else if (indice == coroFinal || cantores.Count == 0)
                quem = [];
            else
            {
                var escolhido = Escolher(cantores, pontos, ultimaVez, anterior);
                pontos[escolhido]++;
                ultimaVez[escolhido] = posicao;
                quem = [escolhido];
                anterior = quem;
            }
            resultado.Add(new EscolhaAMao(itemId, indice, quem));
        }
        return resultado;
    }

    private static Dictionary<(Guid, int), EscolhaAMao> EscolhasValidas(
        IReadOnlyList<HinoParaEscala> hinos, IReadOnlyCollection<EscolhaAMao> escolhas)
    {
        var validas = new Dictionary<(Guid, int), EscolhaAMao>();
        foreach (var escolha in escolhas)
        {
            var hino = hinos.FirstOrDefault(hino => hino.ItemId == escolha.ItemId);
            if (hino is not null && escolha.Indice >= 0 && escolha.Indice < hino.Partes.Count)
                validas[(escolha.ItemId, escolha.Indice)] = escolha;
        }
        return validas;
    }

    // Pontos dos cantores (estrofes e coros) e solos dos solistas.
    private static (Dictionary<string, int> Pontos, Dictionary<string, int> Solos) Contar(
        IReadOnlyList<HinoParaEscala> hinos,
        IReadOnlyList<string> cantores,
        IReadOnlyList<Solista> solistas,
        IEnumerable<EscolhaAMao> escolhas)
    {
        var pontos = cantores.ToDictionary(nome => nome, _ => 0);
        var solos = solistas.Select(solista => solista.Nome).Distinct()
            .ToDictionary(nome => nome, _ => 0);
        foreach (var escolha in escolhas)
        {
            var parte = hinos.First(hino => hino.ItemId == escolha.ItemId).Partes[escolha.Indice];
            var placar = parte.Tipo == TipoDaParte.Instrumental ? solos : pontos;
            foreach (var nome in escolha.Cantores)
                if (placar.ContainsKey(nome)) placar[nome]++;
        }
        return (pontos, solos);
    }

    /// "Solo sax tenor" toca "sax tenor"; "Solo" sozinho, qualquer instrumento
    /// (vazio). Introdução, interlúdio e final não são solos: nulo.
    private static string? InstrumentoDoSolo(string? nome)
    {
        var normalizado = Normalizar(nome);
        if (normalizado == "solo") return "";
        return normalizado.StartsWith("solo ") ? normalizado["solo ".Length..] : null;
    }

    /// Quem toca exatamente o instrumento; sem ninguém, quem toca um parecido
    /// ("sax" serve para "sax tenor" e "sax alto").
    private static List<string> QuemTocaOSolo(IReadOnlyList<Solista> solistas, string instrumento)
    {
        if (instrumento.Length == 0)
            return solistas.Select(solista => solista.Nome).Distinct().ToList();
        var exatos = solistas
            .Where(solista => Normalizar(solista.Instrumento) == instrumento)
            .Select(solista => solista.Nome).Distinct().ToList();
        if (exatos.Count > 0) return exatos;
        return solistas
            .Where(solista => Normalizar(solista.Instrumento) is { Length: > 0 } toca &&
                              (toca.Contains(instrumento) || instrumento.Contains(toca)))
            .Select(solista => solista.Nome).Distinct().ToList();
    }

    private static string Escolher(
        IReadOnlyList<string> candidatos,
        Dictionary<string, int> contagem,
        Dictionary<string, int> ultimaVez,
        IReadOnlyList<string> anterior)
    {
        var disponiveis = candidatos.Where(nome => !anterior.Contains(nome)).ToList();
        if (disponiveis.Count == 0) disponiveis = candidatos.ToList();
        return disponiveis
            .OrderBy(nome => contagem[nome])
            .ThenBy(nome => ultimaVez[nome])
            .First();
    }

    private static string Normalizar(string? valor)
    {
        if (string.IsNullOrWhiteSpace(valor)) return "";
        var resultado = new StringBuilder();
        foreach (var caractere in valor.Normalize(NormalizationForm.FormD))
            if (CharUnicodeInfo.GetUnicodeCategory(caractere) != UnicodeCategory.NonSpacingMark)
                resultado.Append(char.ToLowerInvariant(caractere));
        return string.Join(' ', resultado.ToString()
            .Split(' ', StringSplitOptions.RemoveEmptyEntries));
    }
}
