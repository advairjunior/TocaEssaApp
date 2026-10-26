namespace TocaEssaApp.Api.Dominio;

/// Livre: cada um escolhe a música da playlist (ou outra). Roleta: o app
/// sorteia a música da playlist para a pessoa.
public enum ModoDasMusicas
{
    Livre,
    Roleta
}

/// Sem repertório escolhido, vale o que tem mais vídeos.
public sealed record ConfiguracaoDoKaraoke(
    Guid? RepertorioId = null, ModoDasMusicas Modo = ModoDasMusicas.Livre);

public sealed record PessoaDoKaraoke(Guid PublicoId, string Nome, string? FotoUrl);

/// O que o dono e a galera veem da noite. Antes do sorteio, a ordem é a de
/// chegada; [ForaDaOrdem] é quem o dono tirou (saiu da festa).
public sealed record NoiteDeKaraoke(
    Guid? RepertorioId,
    ModoDasMusicas Modo,
    bool Sorteada,
    bool PodeSortearDeNovo,
    IReadOnlyList<PessoaDoKaraoke> Ordem,
    IReadOnlyList<PessoaDoKaraoke> ForaDaOrdem);

/// A ordem de quem canta, sem banco: o servidor guarda só os sorteados e os
/// tirados; quem chega depois entra no fim, pela ordem de chegada.
public static class OrdemDoKaraoke
{
    public static IReadOnlyList<Guid> Sortear(IReadOnlyList<Guid> galera, Random aleatorio)
    {
        var ordem = galera.ToArray();
        aleatorio.Shuffle(ordem);
        return ordem;
    }

    public static IReadOnlyList<Guid> Montar(
        IReadOnlyList<Guid> sorteados,
        IReadOnlyList<Guid> galeraPorChegada,
        IReadOnlyCollection<Guid> retirados)
    {
        var naGalera = galeraPorChegada.ToHashSet();
        return sorteados.Where(naGalera.Contains)
            .Concat(galeraPorChegada.Where(pessoa => !sorteados.Contains(pessoa)))
            .Where(pessoa => !retirados.Contains(pessoa))
            .Distinct()
            .ToArray();
    }

    /// A pessoa vai para depois da seguinte; a última fica onde está.
    public static IReadOnlyList<Guid> PassarAVez(IReadOnlyList<Guid> ordem, Guid pessoa)
    {
        var nova = ordem.ToArray();
        var indice = Array.IndexOf(nova, pessoa);
        if (indice < 0 || indice == nova.Length - 1) return nova;
        (nova[indice], nova[indice + 1]) = (nova[indice + 1], nova[indice]);
        return nova;
    }
}
