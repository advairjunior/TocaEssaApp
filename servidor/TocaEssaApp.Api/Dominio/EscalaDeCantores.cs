namespace TocaEssaApp.Api.Dominio;

public sealed record HinoParaEscala(Guid ItemId, IReadOnlyList<ParteDoHino> Partes);

/// [Cantores] vazio quer dizer Todos.
public sealed record EscolhaAMao(Guid ItemId, int Indice, IReadOnlyList<string> Cantores);

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

public sealed record EscalaMontada(
    IReadOnlyList<HinoEscalado> Hinos, IReadOnlyList<PlacarDoCantor> Placar);

/// Escala quem canta cada estrofe para ninguém cantar mais que ninguém.
/// Refrão e última estrofe de cada hino são de Todos; escolhas à mão ficam e
/// contam desde o começo; cada estrofe restante vai para quem tem menos
/// estrofes, depois para quem está há mais tempo sem cantar, depois pela
/// ordem da lista, sem repetir quem cantou a estrofe anterior.
public static class EscalaDeCantores
{
    public static EscalaMontada Montar(
        IReadOnlyList<HinoParaEscala> hinos,
        IReadOnlyList<string> cantores,
        IReadOnlyCollection<EscolhaAMao> escolhas)
    {
        var escolhaPorParte = new Dictionary<(Guid, int), EscolhaAMao>();
        foreach (var escolha in escolhas)
        {
            var hino = hinos.FirstOrDefault(hino => hino.ItemId == escolha.ItemId);
            if (hino is not null && escolha.Indice >= 0 && escolha.Indice < hino.Partes.Count)
                escolhaPorParte[(escolha.ItemId, escolha.Indice)] = escolha;
        }

        // O placar conta estrofes cantadas: solo com nome à mão não entra.
        var estrofes = cantores.ToDictionary(nome => nome, _ => 0);
        foreach (var escolha in escolhaPorParte.Values)
        {
            var parte = hinos.First(hino => hino.ItemId == escolha.ItemId).Partes[escolha.Indice];
            if (parte.Tipo == TipoDaParte.Instrumental) continue;
            foreach (var nome in escolha.Cantores)
                if (estrofes.ContainsKey(nome)) estrofes[nome]++;
        }

        var ultimaVez = cantores.ToDictionary(nome => nome, _ => -1);
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
                if (aMao)
                    quem = escolha!.Cantores;
                else if (parte.Tipo != TipoDaParte.Estrofe || indice == ultimaEstrofe ||
                         cantores.Count == 0)
                    quem = [];
                else
                {
                    var escolhido = Escolher(cantores, estrofes, ultimaVez, anterior);
                    estrofes[escolhido]++;
                    quem = [escolhido];
                }

                posicao++;
                if (quem.Count > 0 && parte.Tipo != TipoDaParte.Instrumental)
                {
                    foreach (var nome in quem)
                        if (ultimaVez.ContainsKey(nome)) ultimaVez[nome] = posicao;
                    anterior = quem;
                }
                partes.Add(new ParteEscalada(
                    parte.Tipo, parte.Texto, quem, aMao, parte.Nome, parte.Vezes));
            }
            escalados.Add(new HinoEscalado(hino.ItemId, partes));
        }

        return new EscalaMontada(
            escalados,
            cantores.Select(nome => new PlacarDoCantor(nome, estrofes[nome])).ToList());
    }

    private static string Escolher(
        IReadOnlyList<string> cantores,
        Dictionary<string, int> estrofes,
        Dictionary<string, int> ultimaVez,
        IReadOnlyList<string> anterior)
    {
        var candidatos = cantores.Where(nome => !anterior.Contains(nome)).ToList();
        if (candidatos.Count == 0) candidatos = cantores.ToList();
        return candidatos
            .OrderBy(nome => estrofes[nome])
            .ThenBy(nome => ultimaVez[nome])
            .First();
    }
}
