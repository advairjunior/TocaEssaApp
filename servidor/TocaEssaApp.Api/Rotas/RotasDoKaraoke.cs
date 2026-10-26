using TocaEssaApp.Api.Dominio;
using TocaEssaApp.Api.Infraestrutura;
using static TocaEssaApp.Api.Rotas.AuxiliaresDasRotas;

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

        MapearNoiteDeKaraoke(app);
    }

    // O dono configura, sorteia e corrige a ordem; a galera vê com a conta.
    private static void MapearNoiteDeKaraoke(WebApplication app)
    {
        const string Rota = "/api/apresentacoes/{id:guid}/karaoke";

        app.MapGet(Rota, (Guid id, HttpRequest http, RepositorioTocaEssa repositorio) =>
            Results.Ok(repositorio.ObterNoiteDeKaraoke(ObterToken(http) ?? string.Empty, id)));

        app.MapPut($"{Rota}/configuracao", (
            Guid id, ConfiguracaoDoKaraoke requisicao,
            HttpRequest http, RepositorioTocaEssa repositorio) =>
            Results.Ok(repositorio.ConfigurarKaraoke(ObterToken(http) ?? string.Empty, id, requisicao)));

        app.MapPost($"{Rota}/sorteio", (Guid id, HttpRequest http, RepositorioTocaEssa repositorio) =>
            Results.Ok(repositorio.SortearOrdemDoKaraoke(ObterToken(http) ?? string.Empty, id)));

        app.MapPost($"{Rota}/ordem/{{publicoId:guid}}/passar", (
            Guid id, Guid publicoId, HttpRequest http, RepositorioTocaEssa repositorio) =>
            Results.Ok(repositorio.PassarAVezNoKaraoke(ObterToken(http) ?? string.Empty, id, publicoId)));

        app.MapDelete($"{Rota}/ordem/{{publicoId:guid}}", (
            Guid id, Guid publicoId, HttpRequest http, RepositorioTocaEssa repositorio) =>
            Results.Ok(repositorio.TirarDaOrdemDoKaraoke(ObterToken(http) ?? string.Empty, id, publicoId)));

        app.MapPost($"{Rota}/ordem/{{publicoId:guid}}", (
            Guid id, Guid publicoId, HttpRequest http, RepositorioTocaEssa repositorio) =>
            Results.Ok(repositorio.DevolverAOrdemDoKaraoke(ObterToken(http) ?? string.Empty, id, publicoId)));

        app.MapGet("/api/publico/apresentacoes/{codigo}/karaoke", (
            string codigo, HttpRequest http, RepositorioTocaEssa repositorio) =>
            Results.Ok(repositorio.ObterNoiteDeKaraoke(codigo, ObterToken(http) ?? string.Empty)));
    }
}
