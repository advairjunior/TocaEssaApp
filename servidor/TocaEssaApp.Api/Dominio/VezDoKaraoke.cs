using System.Text.RegularExpressions;

namespace TocaEssaApp.Api.Dominio;

/// A música de uma vez: da playlist (com vídeo) ou outra, com ou sem link.
public sealed record MusicaDoKaraoke(string Titulo, string? LinkDoVideo)
{
    /// O que identifica a música na noite: o vídeo, ou o título sem link.
    public string Chave => LinkDoVideo ?? Titulo.Trim().ToUpperInvariant();
}

/// Uma vez de cantar. [Indice] é a posição na ordem quando começou, para a
/// vez seguir certa mesmo se a pessoa sair.
public sealed record VezDoKaraoke(
    Guid PublicoId,
    MusicaDoKaraoke Musica,
    int Indice,
    DateTimeOffset ComecouEm,
    DateTimeOffset? TerminouEm = null);

/// Quem está cantando agora, como a galera vê.
public sealed record CantandoNoKaraoke(
    Guid PublicoId, string Nome, MusicaDoKaraoke Musica, DateTimeOffset ComecouEm);

/// [MusicaId] é da playlist da noite; sem ele, [Titulo] e o link opcional.
public sealed record EscolherMusicaDoKaraoke(Guid? MusicaId, string? Titulo, string? LinkDoVideo);

public sealed record MusicaDaPlaylistDoKaraoke(Guid Id, string Titulo);

public static partial class RegrasDaVez
{
    /// Depois de quem cantou por último; se a pessoa saiu da ordem, quem
    /// ficou no lugar dela (era a última: volta ao primeiro). Sem ninguém
    /// cantado ainda, o primeiro.
    public static Guid? Proximo(IReadOnlyList<Guid> ordem, VezDoKaraoke? ultima)
    {
        if (ordem.Count == 0) return null;
        if (ultima is null) return ordem[0];
        var indice = IndiceDe(ordem, ultima.PublicoId);
        return indice >= 0
            ? ordem[(indice + 1) % ordem.Count]
            : ordem[ultima.Indice < ordem.Count ? ultima.Indice : 0];
    }

    public static int IndiceDe(IReadOnlyList<Guid> ordem, Guid pessoa)
    {
        for (var indice = 0; indice < ordem.Count; indice++)
            if (ordem[indice] == pessoa) return indice;
        return -1;
    }

    /// Nunca uma já cantada na noite; de preferência uma que a pessoa ainda
    /// não viu. Nulo quando todas já foram cantadas.
    public static MusicaDoKaraoke? SortearDaRoleta(
        IReadOnlyList<MusicaDoKaraoke> playlist,
        IReadOnlyCollection<string> cantadas,
        IReadOnlyCollection<string> mostradas,
        Random aleatorio)
    {
        var naoCantadas = playlist.Where(musica => !cantadas.Contains(musica.Chave)).ToArray();
        var novas = naoCantadas.Where(musica => !mostradas.Contains(musica.Chave)).ToArray();
        var candidatas = novas.Length > 0 ? novas : naoCantadas;
        return candidatas.Length == 0 ? null : candidatas[aleatorio.Next(candidatas.Length)];
    }

    public static bool EhLinkDoYouTube(string? link) =>
        link is not null && LinkDoYouTube().IsMatch(link.Trim());

    [GeneratedRegex(@"^https?://((www|m)\.)?(youtube\.com|youtu\.be)/\S+$", RegexOptions.IgnoreCase)]
    private static partial Regex LinkDoYouTube();
}
