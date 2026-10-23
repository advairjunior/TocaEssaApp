using TocaEssaApp.Api.Dominio;
using TocaEssaApp.Api.Infraestrutura;
using static TocaEssaApp.Api.Rotas.AuxiliaresDasRotas;

namespace TocaEssaApp.Api.Rotas;

/// Setlist da apresentação e a escala de quem canta no louvor.
public static class RotasDaSetlistEDoLouvor
{
    public static void MapearRotasDaSetlistEDoLouvor(this WebApplication app)
    {
        // Setlist da apresentação
        app.MapGet("/api/apresentacoes/{id:guid}/setlist", (
            Guid id, HttpRequest http, RepositorioTocaEssa repositorio) =>
            Results.Ok(repositorio.ObterSetlist(ObterToken(http) ?? string.Empty, id)));

        app.MapPost("/api/apresentacoes/{id:guid}/setlist/importar", (
            Guid id, ImportarRepertorio requisicao,
            HttpRequest http, RepositorioTocaEssa repositorio) =>
            Results.Ok(repositorio.ImportarRepertorioParaSetlist(
                ObterToken(http) ?? string.Empty, id, requisicao.RepertorioId)));

        app.MapPost("/api/apresentacoes/{id:guid}/setlist/musicas", (
            Guid id, AdicionarMusicasAoSetlist requisicao,
            HttpRequest http, RepositorioTocaEssa repositorio) =>
            Results.Ok(repositorio.AdicionarMusicasAoSetlist(
                ObterToken(http) ?? string.Empty, id, requisicao.MusicaIds ?? [])));

        app.MapPost("/api/apresentacoes/{id:guid}/setlist/avulsa", (
            Guid id, AdicionarMusicaAvulsa requisicao,
            HttpRequest http, RepositorioTocaEssa repositorio) =>
            string.IsNullOrWhiteSpace(requisicao.Titulo)
                ? Results.ValidationProblem(new Dictionary<string, string[]>
                    { ["titulo"] = ["Informe o título da música."] })
                : Results.Ok(repositorio.AdicionarMusicaAvulsaAoSetlist(
                    ObterToken(http) ?? string.Empty, id, requisicao.Titulo,
                    requisicao.Artista, requisicao.Tom, requisicao.RepertorioId)));

        app.MapPut("/api/apresentacoes/{id:guid}/setlist/ordem", (
            Guid id, ReordenarSetlist requisicao,
            HttpRequest http, RepositorioTocaEssa repositorio) =>
            Results.Ok(repositorio.ReordenarSetlist(
                ObterToken(http) ?? string.Empty, id, requisicao.ItemIds ?? [])));

        app.MapDelete("/api/apresentacoes/{apresentacaoId:guid}/setlist/{itemId:guid}", (
            Guid apresentacaoId, Guid itemId, HttpRequest http, RepositorioTocaEssa repositorio) =>
            Results.Ok(repositorio.RemoverItemDoSetlist(
                ObterToken(http) ?? string.Empty, apresentacaoId, itemId)));

        app.MapPatch("/api/apresentacoes/{apresentacaoId:guid}/setlist/{itemId:guid}/tocada", (
            Guid apresentacaoId, Guid itemId, MarcarItemDoSetlist requisicao,
            HttpRequest http, RepositorioTocaEssa repositorio) =>
            Results.Ok(repositorio.MarcarItemDoSetlist(
                ObterToken(http) ?? string.Empty, apresentacaoId, itemId, requisicao.Tocada)));

        app.MapDelete("/api/apresentacoes/{id:guid}/setlist", (
            Guid id, HttpRequest http, RepositorioTocaEssa repositorio) =>
        {
            repositorio.LimparSetlist(ObterToken(http) ?? string.Empty, id);
            return Results.NoContent();
        });

        // Louvor: quem canta cada parte dos hinos da setlist
        app.MapGet("/api/apresentacoes/{id:guid}/louvor", (
            Guid id, HttpRequest http, RepositorioTocaEssa repositorio) =>
            Results.Ok(repositorio.ObterLouvor(ObterToken(http) ?? string.Empty, id)));

        app.MapPut("/api/apresentacoes/{id:guid}/louvor/cantores", (
            Guid id, DefinirCantoresDoLouvor requisicao,
            HttpRequest http, RepositorioTocaEssa repositorio) =>
            Results.Ok(repositorio.DefinirCantoresDoLouvor(
                ObterToken(http) ?? string.Empty, id, requisicao.Nomes)));

        app.MapPut("/api/apresentacoes/{id:guid}/louvor/solistas", (
            Guid id, DefinirSolistasDoLouvor requisicao,
            HttpRequest http, RepositorioTocaEssa repositorio) =>
            Results.Ok(repositorio.DefinirSolistasDoLouvor(
                ObterToken(http) ?? string.Empty, id, requisicao.Solistas)));

        app.MapPut("/api/apresentacoes/{id:guid}/louvor/configuracao", (
            Guid id, ConfiguracaoDaEscala requisicao,
            HttpRequest http, RepositorioTocaEssa repositorio) =>
            Results.Ok(repositorio.DefinirConfiguracaoDoLouvor(
                ObterToken(http) ?? string.Empty, id, requisicao)));

        app.MapPost("/api/apresentacoes/{id:guid}/louvor/escalar", (
            Guid id, EscalarHinosDoLouvor? requisicao,
            HttpRequest http, RepositorioTocaEssa repositorio) =>
            Results.Ok(repositorio.EscalarTodosOsHinosDoLouvor(
                ObterToken(http) ?? string.Empty, id, requisicao?.Itens)));

        app.MapDelete("/api/apresentacoes/{id:guid}/louvor/escala", (
            Guid id, HttpRequest http, RepositorioTocaEssa repositorio) =>
            Results.Ok(repositorio.LimparEscalaDoLouvor(ObterToken(http) ?? string.Empty, id)));

        app.MapPost("/api/apresentacoes/{id:guid}/louvor/hinos/{itemId:guid}/escalar", (
            Guid id, Guid itemId, HttpRequest http, RepositorioTocaEssa repositorio) =>
            Results.Ok(repositorio.EscalarHinoDoLouvor(
                ObterToken(http) ?? string.Empty, id, itemId)));

        app.MapPut("/api/apresentacoes/{id:guid}/louvor/partes", (
            Guid id, EscolherParteDoLouvor requisicao,
            HttpRequest http, RepositorioTocaEssa repositorio) =>
            Results.Ok(repositorio.EscolherParteDoLouvor(
                ObterToken(http) ?? string.Empty, id, requisicao.ItemId,
                requisicao.Indice, requisicao.Cantores)));

        app.MapPut("/api/apresentacoes/{id:guid}/louvor/coral", (
            Guid id, MarcarCoralDoLouvor requisicao,
            HttpRequest http, RepositorioTocaEssa repositorio) =>
            Results.Ok(repositorio.MarcarCoralDoLouvor(
                ObterToken(http) ?? string.Empty, id, requisicao.ItemId,
                requisicao.Indice, requisicao.Coral)));
    }
}
