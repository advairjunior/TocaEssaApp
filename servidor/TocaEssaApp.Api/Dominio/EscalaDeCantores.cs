using System.Globalization;
using System.Text;

namespace TocaEssaApp.Api.Dominio;

public sealed record HinoParaEscala(Guid ItemId, IReadOnlyList<ParteDoHino> Partes);

/// [Cantores] vazio quer dizer Todos.
public sealed record EscolhaAMao(Guid ItemId, int Indice, IReadOnlyList<string> Cantores);

/// Quem toca os solos e o instrumento, como "José" e "sax tenor".
public sealed record Solista(string Nome, string Instrumento);

/// [Cantores] vazio quer dizer Todos (ou ninguém, numa parte instrumental).
public sealed record ParteEscalada(
    TipoDaParte Tipo,
    string Texto,
    IReadOnlyList<string> Cantores,
    bool EscolhidaAMao,
    string? Nome = null,
    int Vezes = 1);

public sealed record HinoEscalado(Guid ItemId, IReadOnlyList<ParteEscalada> Partes);

public sealed record PlacarDoCantor(string Nome, int Estrofes);

public sealed record PlacarDoSolista(string Nome, int Solos);

public sealed record EscalaMontada(
    IReadOnlyList<HinoEscalado> Hinos,
    IReadOnlyList<PlacarDoCantor> Placar,
    IReadOnlyList<PlacarDoSolista> PlacarDosSolos);

/// Escala quem canta cada estrofe e quem toca cada solo, para ninguém fazer
/// mais que ninguém. Refrão e última estrofe de cada hino são de Todos;
/// escolhas à mão ficam e contam desde o começo; cada estrofe restante vai
/// para quem tem menos estrofes, depois para quem está há mais tempo sem
/// cantar, depois pela ordem da lista, sem repetir quem cantou a anterior.
/// Cada solo vai, pelo mesmo critério, para quem toca o instrumento dele;
/// introdução, interlúdio e final são da banda toda.
public static class EscalaDeCantores
{
    public static EscalaMontada Montar(
        IReadOnlyList<HinoParaEscala> hinos,
        IReadOnlyList<string> cantores,
        IReadOnlyCollection<EscolhaAMao> escolhas,
        IReadOnlyList<Solista>? solistas = null)
    {
        solistas ??= [];
        var escolhaPorParte = new Dictionary<(Guid, int), EscolhaAMao>();
        foreach (var escolha in escolhas)
        {
            var hino = hinos.FirstOrDefault(hino => hino.ItemId == escolha.ItemId);
            if (hino is not null && escolha.Indice >= 0 && escolha.Indice < hino.Partes.Count)
                escolhaPorParte[(escolha.ItemId, escolha.Indice)] = escolha;
        }

        // Estrofes e solos têm placares separados.
        var estrofes = cantores.ToDictionary(nome => nome, _ => 0);
        var nomesDosSolistas = solistas.Select(solista => solista.Nome).Distinct().ToList();
        var solos = nomesDosSolistas.ToDictionary(nome => nome, _ => 0);
        foreach (var escolha in escolhaPorParte.Values)
        {
            var parte = hinos.First(hino => hino.ItemId == escolha.ItemId).Partes[escolha.Indice];
            var placar = parte.Tipo == TipoDaParte.Instrumental ? solos : estrofes;
            foreach (var nome in escolha.Cantores)
                if (placar.ContainsKey(nome)) placar[nome]++;
        }

        var ultimaVez = cantores.ToDictionary(nome => nome, _ => -1);
        var ultimoSolo = nomesDosSolistas.ToDictionary(nome => nome, _ => -1);
        var posicao = 0;
        IReadOnlyList<string> anterior = [];
        var escalados = new List<HinoEscalado>();
        foreach (var hino in hinos)
        {
            var ultimaEstrofe = hino.Partes.Select((parte, indice) => (parte, indice))
                .LastOrDefault(item => item.parte.Tipo == TipoDaParte.Estrofe).indice;
            var partes = new List<ParteEscalada>();
            for (var indice = 0; indice < hino.Partes.Count; indice++)
            {
                var parte = hino.Partes[indice];
                IReadOnlyList<string> quem;
                var aMao = escolhaPorParte.TryGetValue((hino.ItemId, indice), out var escolha);
                posicao++;
                if (aMao)
                    quem = escolha!.Cantores;
                else if (parte.Tipo == TipoDaParte.Instrumental)
                    quem = InstrumentoDoSolo(parte.Nome) is { } instrumento &&
                           QuemTocaOSolo(solistas, instrumento) is { Count: > 0 } candidatos
                        ? [Escolher(candidatos, solos, ultimoSolo, [])]
                        : [];
                else if (parte.Tipo == TipoDaParte.Refrao || indice == ultimaEstrofe ||
                         cantores.Count == 0)
                    quem = [];
                else
                    quem = [Escolher(cantores, estrofes, ultimaVez, anterior)];

                if (parte.Tipo == TipoDaParte.Instrumental)
                {
                    foreach (var nome in quem)
                        if (ultimoSolo.ContainsKey(nome)) ultimoSolo[nome] = posicao;
                    if (!aMao)
                        foreach (var nome in quem) solos[nome]++;
                }
                else if (quem.Count > 0)
                {
                    foreach (var nome in quem)
                        if (ultimaVez.ContainsKey(nome)) ultimaVez[nome] = posicao;
                    if (!aMao)
                        foreach (var nome in quem) estrofes[nome]++;
                    anterior = quem;
                }
                partes.Add(new ParteEscalada(
                    parte.Tipo, parte.Texto, quem, aMao, parte.Nome, parte.Vezes));
            }
            escalados.Add(new HinoEscalado(hino.ItemId, partes));
        }

        return new EscalaMontada(
            escalados,
            cantores.Select(nome => new PlacarDoCantor(nome, estrofes[nome])).ToList(),
            nomesDosSolistas.Select(nome => new PlacarDoSolista(nome, solos[nome])).ToList());
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
