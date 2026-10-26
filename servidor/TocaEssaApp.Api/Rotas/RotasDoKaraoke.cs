using TocaEssaApp.Api.Dominio;
using TocaEssaApp.Api.Infraestrutura;

namespace TocaEssaApp.Api.Rotas;

public static class RotasDoKaraoke
{
    public static void MapearRotasDoKaraoke(this WebApplication app)
    {
        // Prévia da playlist do YouTube: títulos limpos e links, para o
        // artista conferir antes de levar ao repertório. A sessão do artista
        // é validada pelo caminho /api/artista/repertorios.
        app.MapPost("/api/artista/repertorios/playlist", async (
            LerPlaylistDoYouTube requisicao, ILeitorDePlaylist leitor,
            CancellationToken cancelamento) =>
        {
            if (PlaylistDoYouTube.IdDaPlaylist(requisicao.Link) is not { } id)
                return Results.ValidationProblem(new Dictionary<string, string[]>
                    { ["link"] = ["Cole o link de uma playlist do YouTube."] });
            try
            {
                return Results.Ok(await leitor.LerAsync(id, cancelamento));
            }
            catch (PlaylistNaoEncontradaException)
            {
                return Results.NotFound(new
                {
                    mensagem = "Playlist não encontrada. Ela precisa ser pública ou não listada."
                });
            }
            catch (ImportacaoDePlaylistIndisponivelException)
            {
                return Results.Json(new { mensagem = "A importação do YouTube ainda não foi configurada." },
                    statusCode: StatusCodes.Status503ServiceUnavailable);
            }
        });
    }
}
