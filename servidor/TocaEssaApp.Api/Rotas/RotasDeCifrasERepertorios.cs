using TocaEssaApp.Api.Dominio;
using TocaEssaApp.Api.Infraestrutura;
using static TocaEssaApp.Api.Rotas.AuxiliaresDasRotas;

namespace TocaEssaApp.Api.Rotas;

/// Cifras e repertórios do artista, e o link público da cifra.
public static class RotasDeCifrasERepertorios
{
    public static void MapearRotasDeCifrasERepertorios(this WebApplication app)
    {
        app.MapGet("/api/artista/cifras/consulta", (
            string musica, string? artista, HttpRequest http,
            RepositorioTocaEssa repositorio) =>
            string.IsNullOrWhiteSpace(musica)
                ? Results.ValidationProblem(new Dictionary<string, string[]>
                {
                    ["musica"] = ["Informe a música."]
                })
                : Results.Ok(repositorio.ObterCifraDoArtista(
                    ObterToken(http) ?? string.Empty, musica, artista)));

        app.MapGet("/api/artista/cifras/compartilhar", (
            string musica, string? artista, HttpRequest http,
            RepositorioTocaEssa repositorio) =>
            Results.Ok(new
            {
                codigo = repositorio.CodigoParaCompartilharCifra(
                    ObterToken(http) ?? string.Empty, musica, artista)
            }));

        // Link público de uma cifra: o código é o id da cifra colada.
        app.MapGet("/api/publico/cifras/{codigo:guid}", (
            Guid codigo, RepositorioTocaEssa repositorio) =>
            repositorio.ObterCifraCompartilhada(codigo) is { } cifra
                ? Results.Ok(cifra)
                : Results.NotFound());

        app.MapGet("/api/artista/cifras", (
            HttpRequest http, RepositorioTocaEssa repositorio) =>
            Results.Ok(repositorio.ListarCifrasDoArtista(
                ObterToken(http) ?? string.Empty)));

        app.MapPut("/api/artista/cifras", (
            SalvarCifraDoArtista requisicao, HttpRequest http,
            RepositorioTocaEssa repositorio) =>
        {
            if (string.IsNullOrWhiteSpace(requisicao.Musica))
                return Results.ValidationProblem(new Dictionary<string, string[]>
                {
                    ["musica"] = ["Informe a música."]
                });
            return Results.Ok(repositorio.SalvarCifraDoArtista(
                ObterToken(http) ?? string.Empty, requisicao.Musica,
                requisicao.Artista, requisicao.Url));
        });

        app.MapPut("/api/artista/cifras/texto", (
            SalvarCifraEmTexto requisicao, HttpRequest http,
            RepositorioTocaEssa repositorio) =>
            string.IsNullOrWhiteSpace(requisicao.Musica)
                ? Results.ValidationProblem(new Dictionary<string, string[]>
                {
                    ["musica"] = ["Informe a música."]
                })
                : Results.Ok(repositorio.SalvarCifraEmTexto(
                    ObterToken(http) ?? string.Empty, requisicao.Musica,
                    requisicao.Artista, requisicao.Texto)));

        app.MapDelete("/api/artista/cifras/{id:guid}", (
            Guid id, HttpRequest http, RepositorioTocaEssa repositorio) =>
        {
            repositorio.RemoverCifraDoArtista(
                ObterToken(http) ?? string.Empty, id);
            return Results.NoContent();
        });

        // Repertórios do artista
        app.MapGet("/api/artista/repertorios", (
            HttpRequest http, RepositorioTocaEssa repositorio) =>
            Results.Ok(repositorio.ListarRepertorios(ObterToken(http) ?? string.Empty)));

        app.MapPost("/api/artista/repertorios", (
            CriarRepertorio requisicao, HttpRequest http, RepositorioTocaEssa repositorio) =>
        {
            if (string.IsNullOrWhiteSpace(requisicao.Nome))
                return Results.ValidationProblem(new Dictionary<string, string[]>
                    { ["nome"] = ["Informe o nome do repertório."] });
            return Results.Ok(repositorio.CriarRepertorio(ObterToken(http) ?? string.Empty,
                requisicao.Nome));
        });

        app.MapGet("/api/artista/repertorios/pedidas-fora", (
            HttpRequest http, RepositorioTocaEssa repositorio) =>
            Results.Ok(repositorio.ListarPedidasForaDoRepertorio(ObterToken(http) ?? string.Empty)));

        app.MapPost("/api/artista/repertorios/musicas", (
            AdicionarMusicasAoRepertorio requisicao, HttpRequest http, RepositorioTocaEssa repositorio) =>
        {
            var musicas = requisicao.Musicas ?? [];
            if (requisicao.RepertorioId is null == string.IsNullOrWhiteSpace(requisicao.NomeNovo))
                return Results.ValidationProblem(new Dictionary<string, string[]>
                    { ["repertorio"] = ["Escolha um repertório ou informe o nome do novo."] });
            if (musicas.Count == 0 || musicas.Any(m => string.IsNullOrWhiteSpace(m.Titulo)))
                return Results.ValidationProblem(new Dictionary<string, string[]>
                    { ["musicas"] = ["Informe o título de cada música."] });
            return Results.Ok(repositorio.AdicionarMusicasAoRepertorio(ObterToken(http) ?? string.Empty,
                requisicao.RepertorioId, requisicao.NomeNovo, musicas));
        });

        app.MapPut("/api/artista/repertorios/{id:guid}", (
            Guid id, RenomearRepertorio requisicao, HttpRequest http,
            RepositorioTocaEssa repositorio) =>
        {
            if (string.IsNullOrWhiteSpace(requisicao.Nome))
                return Results.ValidationProblem(new Dictionary<string, string[]>
                    { ["nome"] = ["Informe o nome do repertório."] });
            return Results.Ok(repositorio.RenomearRepertorio(
                ObterToken(http) ?? string.Empty, id, requisicao.Nome));
        });

        app.MapDelete("/api/artista/repertorios/{id:guid}", (
            Guid id, HttpRequest http, RepositorioTocaEssa repositorio) =>
        {
            repositorio.ExcluirRepertorio(ObterToken(http) ?? string.Empty, id);
            return Results.NoContent();
        });

        app.MapGet("/api/artista/repertorios/{id:guid}/cifras", (
            Guid id, HttpRequest http, RepositorioTocaEssa repositorio) =>
            Results.Ok(repositorio.ListarCifrasDoRepertorio(ObterToken(http) ?? string.Empty, id)));

        app.MapPost("/api/artista/repertorios/{id:guid}/musicas", (
            Guid id, AdicionarMusicaAoRepertorio requisicao,
            HttpRequest http, RepositorioTocaEssa repositorio) =>
        {
            if (string.IsNullOrWhiteSpace(requisicao.Titulo))
                return Results.ValidationProblem(new Dictionary<string, string[]>
                    { ["titulo"] = ["Informe o título da música."] });
            return Results.Ok(repositorio.AdicionarMusicaAoRepertorio(
                ObterToken(http) ?? string.Empty, id, requisicao.Titulo,
                requisicao.Artista, requisicao.Tom));
        });

        app.MapPut("/api/artista/repertorios/{repertorioId:guid}/musicas/{musicaId:guid}", (
            Guid repertorioId, Guid musicaId, EditarMusicaDoRepertorio requisicao,
            HttpRequest http, RepositorioTocaEssa repositorio) =>
        {
            if (string.IsNullOrWhiteSpace(requisicao.Titulo))
                return Results.ValidationProblem(new Dictionary<string, string[]>
                    { ["titulo"] = ["Informe o título da música."] });
            return Results.Ok(repositorio.EditarMusicaDoRepertorio(
                ObterToken(http) ?? string.Empty, repertorioId, musicaId,
                requisicao.Titulo, requisicao.Artista, requisicao.Tom));
        });

        app.MapPut("/api/artista/repertorios/{repertorioId:guid}/musicas/ordem", (
            Guid repertorioId, ReordenarMusicasDoRepertorio requisicao,
            HttpRequest http, RepositorioTocaEssa repositorio) =>
            Results.Ok(repositorio.ReordenarMusicasDoRepertorio(
                ObterToken(http) ?? string.Empty, repertorioId, requisicao.MusicaIds ?? [])));

        app.MapDelete("/api/artista/repertorios/{repertorioId:guid}/musicas/{musicaId:guid}", (
            Guid repertorioId, Guid musicaId, HttpRequest http, RepositorioTocaEssa repositorio) =>
        {
            repositorio.RemoverMusicaDoRepertorio(
                ObterToken(http) ?? string.Empty, repertorioId, musicaId);
            return Results.NoContent();
        });
    }
}
