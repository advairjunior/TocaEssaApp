using TocaEssaApp.Api.Infraestrutura;
using static TocaEssaApp.Api.Rotas.AuxiliaresDasRotas;

namespace TocaEssaApp.Api.Rotas;

/// Convite dos músicos para o evento da noite. Todas privadas: a conta vem
/// do token; o público continua entrando pelo código do evento.
public static class RotasDosMusicosDaNoite
{
    public static void MapearRotasDosMusicosDaNoite(this WebApplication app)
    {
        app.MapPost("/api/apresentacoes/{id:guid}/convite", (
            Guid id, HttpRequest http, RepositorioTocaEssa repositorio) =>
            Results.Ok(new { codigo = repositorio.GerarConvite(ObterToken(http) ?? string.Empty, id) }));

        app.MapGet("/api/apresentacoes/{id:guid}/musicos", (
            Guid id, HttpRequest http, RepositorioTocaEssa repositorio) =>
            Results.Ok(repositorio.ListarMusicos(ObterToken(http) ?? string.Empty, id)));

        app.MapDelete("/api/apresentacoes/{id:guid}/musicos/{artistaId:guid}", (
            Guid id, Guid artistaId, HttpRequest http, RepositorioTocaEssa repositorio) =>
        {
            repositorio.TirarMusico(ObterToken(http) ?? string.Empty, id, artistaId);
            return Results.NoContent();
        });

        app.MapGet("/api/convites", (HttpRequest http, RepositorioTocaEssa repositorio) =>
            Results.Ok(repositorio.ListarConvites(ObterToken(http) ?? string.Empty)));

        app.MapGet("/api/convites/{codigo}", (
            string codigo, HttpRequest http, RepositorioTocaEssa repositorio) =>
            Results.Ok(repositorio.VerConvite(ObterToken(http) ?? string.Empty, codigo)));

        app.MapPost("/api/convites/{codigo}", (
            string codigo, HttpRequest http, RepositorioTocaEssa repositorio) =>
        {
            repositorio.EntrarPeloConvite(ObterToken(http) ?? string.Empty, codigo);
            return Results.NoContent();
        });
    }
}
