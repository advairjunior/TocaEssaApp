using TocaEssaApp.Api.Dominio;
using TocaEssaApp.Api.Infraestrutura;
using static TocaEssaApp.Api.Rotas.AuxiliaresDasRotas;

namespace TocaEssaApp.Api.Rotas;

public static class RotasDaTv
{
    public static void MapearRotasDaTv(this WebApplication app)
    {
        MapearTv(app);
        MapearCelularDoDono(app);
    }

    // A TV abre sem conta: o token dela vem no cabeçalho, como o de uma sessão.
    private static void MapearTv(WebApplication app)
    {
        app.MapPost("/api/publico/telas", (RepositorioTocaEssa repositorio) =>
            Results.Ok(repositorio.CriarTv()));

        app.MapGet("/api/publico/telas/eu", (HttpRequest http, RepositorioTocaEssa repositorio) =>
            Results.Ok(repositorio.ObterEstadoDaTv(ObterToken(http) ?? string.Empty)));

        // O EventSource não manda cabeçalho; o canal só leva números de linha.
        app.MapGet("/api/publico/telas/{id:guid}/tempo-real", async Task (
            Guid id, HttpResponse resposta, NotificadorTempoReal notificador,
            CancellationToken cancelamento) =>
        {
            resposta.ContentType = "text/event-stream";
            resposta.Headers.CacheControl = "no-cache";
            resposta.Headers.Append("X-Accel-Buffering", "no");
            await foreach (var evento in notificador.Assinar(CanalDaTv.De(id), cancelamento))
            {
                var mensagem = evento == "pulso" ? ": pulso\n\n" : $"data: {evento}\n\n";
                await resposta.WriteAsync(mensagem, cancelamento);
                await resposta.Body.FlushAsync(cancelamento);
            }
        });
    }

    private static void MapearCelularDoDono(WebApplication app)
    {
        const string Rota = "/api/artista/telas";

        app.MapGet(Rota, (HttpRequest http, RepositorioTocaEssa repositorio) =>
            Results.Ok(repositorio.ListarTvs(ObterToken(http) ?? string.Empty)));

        app.MapPost($"{Rota}/pareamento", (
            ParearTv requisicao, HttpRequest http, RepositorioTocaEssa repositorio) =>
            Results.Ok(repositorio.ParearTv(ObterToken(http) ?? string.Empty, requisicao.Codigo)));

        app.MapDelete($"{Rota}/{{id:guid}}", (Guid id, HttpRequest http, RepositorioTocaEssa repositorio) =>
        {
            repositorio.DesconectarTv(ObterToken(http) ?? string.Empty, id);
            return Results.NoContent();
        });

        app.MapPut($"{Rota}/conteudo", (
            MostrarNaTv requisicao, HttpRequest http, RepositorioTocaEssa repositorio) =>
        {
            repositorio.MostrarNaTv(ObterToken(http) ?? string.Empty, requisicao);
            return Results.NoContent();
        });

        app.MapPut($"{Rota}/conteudo/linha", (
            IrParaALinha requisicao, HttpRequest http, RepositorioTocaEssa repositorio) =>
        {
            repositorio.IrParaALinhaNaTv(ObterToken(http) ?? string.Empty, requisicao.Linha);
            return Results.NoContent();
        });

        app.MapDelete($"{Rota}/conteudo", (HttpRequest http, RepositorioTocaEssa repositorio) =>
        {
            repositorio.LimparTv(ObterToken(http) ?? string.Empty);
            return Results.NoContent();
        });
    }
}

public sealed record ParearTv(string Codigo);

public sealed record IrParaALinha(int Linha);
