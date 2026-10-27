namespace TocaEssaApp.Api.Dominio;

/// Uma linha do placar: quantas músicas, a média delas e quantos votos.
public sealed record LinhaDoPlacar(
    Guid PublicoId, string Nome, int Musicas, double? Media, int Votos, string? MelhorMusica);

/// A noite de karaokê na memória de quem cantou.
public sealed record KaraokeDoPublico(int Musicas, double? Media, bool VozDaNoite);

public static class PlacarDoKaraoke
{
    /// Com menos votos, uma nota alta de dois amigos não vira a Voz da noite.
    public const int VotosParaAVoz = 3;

    public static double? Media(IEnumerable<int> notas)
    {
        var lista = notas.ToArray();
        return lista.Length == 0 ? null : Math.Round(lista.Average(), 1);
    }

    /// Média de cada um é a média das suas músicas (cada música vale igual);
    /// sem voto, fica no fim. [Nome] fica vazio para quem monta preencher.
    public static IReadOnlyList<LinhaDoPlacar> Calcular(IEnumerable<VezDoKaraoke> vezes) =>
        vezes.GroupBy(vez => vez.PublicoId)
            .Select(Linha)
            .OrderByDescending(linha => linha.Media ?? -1)
            .ThenByDescending(linha => linha.Votos)
            .ToArray();

    /// Maior média contando só as músicas com votos suficientes; nulo sem
    /// nenhuma música assim.
    public static Guid? VozDaNoite(IEnumerable<VezDoKaraoke> vezes) =>
        Calcular(vezes.Where(vez => vez.Notas.Count >= VotosParaAVoz))
            .FirstOrDefault(linha => linha.Media is not null)?.PublicoId;

    private static LinhaDoPlacar Linha(IGrouping<Guid, VezDoKaraoke> vezes)
    {
        var medias = vezes.Where(vez => vez.Notas.Count > 0)
            .Select(vez => (vez.Musica.Titulo, Media: vez.Notas.Values.Average()))
            .ToArray();
        return new LinhaDoPlacar(
            vezes.Key,
            string.Empty,
            vezes.Count(),
            medias.Length == 0 ? null : Math.Round(medias.Average(item => item.Media), 1),
            vezes.Sum(vez => vez.Notas.Count),
            medias.Length == 0 ? null : medias.MaxBy(item => item.Media).Titulo);
    }
}
