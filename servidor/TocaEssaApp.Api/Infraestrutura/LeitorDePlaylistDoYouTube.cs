using System.Net;
using System.Text.Json;
using TocaEssaApp.Api.Dominio;

namespace TocaEssaApp.Api.Infraestrutura;

public interface ILeitorDePlaylist
{
    Task<PlaylistLida> LerAsync(string idDaPlaylist, CancellationToken cancelamento = default);
}

/// Lê a playlist pela API oficial do YouTube (Data API v3), de 50 em 50,
/// com a chave do servidor. Vídeo privado ou apagado fica de fora.
public sealed class LeitorDePlaylistDoYouTube(HttpClient cliente, string? chave) : ILeitorDePlaylist
{
    private const string Api = "https://www.googleapis.com/youtube/v3";

    public async Task<PlaylistLida> LerAsync(string idDaPlaylist, CancellationToken cancelamento = default)
    {
        if (string.IsNullOrWhiteSpace(chave)) throw new ImportacaoDePlaylistIndisponivelException();
        var titulo = await LerTituloAsync(idDaPlaylist, cancelamento);
        var musicas = new List<VideoDaPlaylist>();
        string? pagina = null;
        do
        {
            using var json = await LerJsonAsync(
                $"playlistItems?part=snippet,status&maxResults=50&playlistId={idDaPlaylist}" +
                (pagina is null ? "" : $"&pageToken={pagina}"), cancelamento);
            musicas.AddRange(json.RootElement.GetProperty("items").EnumerateArray()
                .Where(Disponivel).Select(ParaVideo));
            pagina = json.RootElement.TryGetProperty("nextPageToken", out var proxima)
                ? proxima.GetString()
                : null;
        } while (pagina is not null);
        return new PlaylistLida(titulo, musicas);
    }

    private async Task<string> LerTituloAsync(string idDaPlaylist, CancellationToken cancelamento)
    {
        using var json = await LerJsonAsync($"playlists?part=snippet&id={idDaPlaylist}", cancelamento);
        var itens = json.RootElement.GetProperty("items");
        if (itens.GetArrayLength() == 0) throw new PlaylistNaoEncontradaException();
        return itens[0].GetProperty("snippet").GetProperty("title").GetString() ?? string.Empty;
    }

    private async Task<JsonDocument> LerJsonAsync(string caminho, CancellationToken cancelamento)
    {
        using var resposta = await cliente.GetAsync($"{Api}/{caminho}&key={chave}", cancelamento);
        if (resposta.StatusCode is HttpStatusCode.NotFound or HttpStatusCode.Forbidden)
            throw new PlaylistNaoEncontradaException();
        resposta.EnsureSuccessStatusCode();
        return await JsonDocument.ParseAsync(
            await resposta.Content.ReadAsStreamAsync(cancelamento), cancellationToken: cancelamento);
    }

    private static bool Disponivel(JsonElement item) =>
        item.TryGetProperty("status", out var status) &&
        status.GetProperty("privacyStatus").GetString() is "public" or "unlisted";

    private static VideoDaPlaylist ParaVideo(JsonElement item)
    {
        var trecho = item.GetProperty("snippet");
        var id = trecho.GetProperty("resourceId").GetProperty("videoId").GetString()!;
        return new VideoDaPlaylist(
            TituloDeKaraoke.Limpar(trecho.GetProperty("title").GetString() ?? id),
            PlaylistDoYouTube.LinkDoVideo(id));
    }
}
