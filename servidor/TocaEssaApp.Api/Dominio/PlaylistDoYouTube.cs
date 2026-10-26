using System.Text.RegularExpressions;

namespace TocaEssaApp.Api.Dominio;

/// Um vídeo da playlist já com o título limpo e o link para abrir no YouTube.
public sealed record VideoDaPlaylist(string Titulo, string LinkDoVideo);

/// O nome da playlist (sugestão para o repertório) e os vídeos dela.
public sealed record PlaylistLida(string Titulo, IReadOnlyList<VideoDaPlaylist> Musicas);

public sealed record LerPlaylistDoYouTube(string? Link);

public sealed class PlaylistNaoEncontradaException : Exception { }

/// Sem a chave da API do YouTube configurada no servidor.
public sealed class ImportacaoDePlaylistIndisponivelException : Exception { }

public static partial class PlaylistDoYouTube
{
    /// O "list=" de um link do YouTube (youtube.com, youtu.be, music...), ou o
    /// próprio id colado sozinho; nulo se não houver playlist.
    public static string? IdDaPlaylist(string? link)
    {
        var texto = link?.Trim() ?? string.Empty;
        if (IdSozinho().IsMatch(texto)) return texto;
        if (!Uri.TryCreate(texto, UriKind.Absolute, out var endereco) ||
            !endereco.Host.EndsWith("youtube.com") && !endereco.Host.EndsWith("youtu.be"))
            return null;
        var lista = System.Web.HttpUtility.ParseQueryString(endereco.Query)["list"];
        return lista is not null && IdSozinho().IsMatch(lista) ? lista : null;
    }

    public static string LinkDoVideo(string idDoVideo) =>
        $"https://www.youtube.com/watch?v={idDoVideo}";

    [GeneratedRegex(@"^(PL|UU|LL|FL|OL|RD)[A-Za-z0-9_-]+$")]
    private static partial Regex IdSozinho();
}
