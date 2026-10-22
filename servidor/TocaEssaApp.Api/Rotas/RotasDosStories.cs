using TocaEssaApp.Api.Dominio;
using TocaEssaApp.Api.Infraestrutura;
using static TocaEssaApp.Api.Rotas.AuxiliaresDasRotas;

namespace TocaEssaApp.Api.Rotas;

/// Stories do show, e o armazenamento local quando não há R2.
public static class RotasDosStories
{
    public static void MapearRotasDosStories(this WebApplication app)
    {
        // Stories do show: o público envia e assiste sem conta; o arquivo vai
        // direto para o armazenamento por URL assinada.
        app.MapPost("/api/publico/apresentacoes/{codigo}/envios", async (
            string codigo, PedidoDeEnvio pedido, RepositorioTocaEssa repositorio,
            ArmazenamentoDeStories armazenamento) =>
        {
            armazenamento.GarantirDisponivel();
            var envio = repositorio.CriarEnvio(codigo, pedido);
            var (url, cabecalhos) = await armazenamento.UrlDeEnvio(envio.Chave, envio.TipoDeConteudo);
            return Results.Ok(new { id = envio.Id, urlDeEnvio = url, cabecalhos });
        });

        app.MapPost("/api/publico/apresentacoes/{codigo}/envios/{envioId:guid}/confirmar", async (
            string codigo, Guid envioId, RepositorioTocaEssa repositorio,
            ArmazenamentoDeStories armazenamento, CancellationToken cancelamento) =>
        {
            var chave = repositorio.ObterChaveDoEnvioPendente(codigo, envioId);
            var tamanho = await armazenamento.TamanhoGuardado(chave, cancelamento);
            StoryDoShow story;
            try
            {
                story = repositorio.ConfirmarEnvio(codigo, envioId, tamanho);
            }
            catch (EnvioInvalidoException)
            {
                if (tamanho is not null) await armazenamento.Apagar(chave, cancelamento);
                throw;
            }
            return Results.Ok(await ParaStoryPublico(story, armazenamento));
        });

        app.MapGet("/api/publico/apresentacoes/{codigo}/stories", async (
            string codigo, RepositorioTocaEssa repositorio, ArmazenamentoDeStories armazenamento) =>
        {
            var stories = repositorio.ListarStoriesDoShow(codigo);
            return Results.Ok(await Task.WhenAll(
                stories.Select(story => ParaStoryPublico(story, armazenamento))));
        });

        app.MapPost("/api/publico/apresentacoes/{codigo}/stories/{envioId:guid}/denuncia", (
            string codigo, Guid envioId, DenunciaDeStory denuncia, RepositorioTocaEssa repositorio) =>
        {
            repositorio.DenunciarStory(codigo, envioId, denuncia.Aparelho);
            return Results.NoContent();
        });

        app.MapGet("/api/apresentacoes/{apresentacaoId:guid}/envios", async (
            Guid apresentacaoId, HttpRequest http, RepositorioTocaEssa repositorio,
            ArmazenamentoDeStories armazenamento, CancellationToken cancelamento) =>
        {
            var lista = repositorio.ListarEnviosDoShow(ObterToken(http) ?? string.Empty, apresentacaoId);
            foreach (var chave in lista.ChavesExpiradas)
            {
                try
                {
                    await armazenamento.Apagar(chave, cancelamento);
                }
                catch (Exception)
                {
                    // A regra de 7 dias do armazenamento apaga depois.
                }
            }
            return Results.Ok(await Task.WhenAll(lista.Envios.Select(async envio => new
            {
                envio.Id,
                envio.Tipo,
                envio.Nome,
                envio.CriadoEm,
                envio.ExpiraEm,
                envio.Escondido,
                envio.TipoDeConteudo,
                envio.DoArtista,
                url = await armazenamento.UrlDeLeitura(envio.Chave)
            })));
        });

        app.MapPost("/api/apresentacoes/{apresentacaoId:guid}/envios", async (
            Guid apresentacaoId, PedidoDeEnvio pedido, HttpRequest http, RepositorioTocaEssa repositorio,
            ArmazenamentoDeStories armazenamento) =>
        {
            armazenamento.GarantirDisponivel();
            var envio = repositorio.CriarEnvioDoArtista(
                ObterToken(http) ?? string.Empty, apresentacaoId, pedido);
            var (url, cabecalhos) = await armazenamento.UrlDeEnvio(envio.Chave, envio.TipoDeConteudo);
            return Results.Ok(new { id = envio.Id, urlDeEnvio = url, cabecalhos });
        });

        app.MapPost("/api/apresentacoes/{apresentacaoId:guid}/envios/{envioId:guid}/confirmar", async (
            Guid apresentacaoId, Guid envioId, HttpRequest http, RepositorioTocaEssa repositorio,
            ArmazenamentoDeStories armazenamento, CancellationToken cancelamento) =>
        {
            var token = ObterToken(http) ?? string.Empty;
            var chave = repositorio.ObterChaveDoEnvioPendenteDoArtista(token, apresentacaoId, envioId);
            var tamanho = await armazenamento.TamanhoGuardado(chave, cancelamento);
            StoryDoShow story;
            try
            {
                story = repositorio.ConfirmarEnvioDoArtista(token, apresentacaoId, envioId, tamanho);
            }
            catch (EnvioInvalidoException)
            {
                if (tamanho is not null) await armazenamento.Apagar(chave, cancelamento);
                throw;
            }
            return Results.Ok(await ParaStoryPublico(story, armazenamento));
        });

        app.MapDelete("/api/apresentacoes/{apresentacaoId:guid}/envios/{envioId:guid}", async (
            Guid apresentacaoId, Guid envioId, HttpRequest http, RepositorioTocaEssa repositorio,
            ArmazenamentoDeStories armazenamento, CancellationToken cancelamento) =>
        {
            var chave = repositorio.ApagarEnvio(ObterToken(http) ?? string.Empty, apresentacaoId, envioId);
            await armazenamento.Apagar(chave, cancelamento);
            return Results.NoContent();
        });

        app.MapPost("/api/apresentacoes/{apresentacaoId:guid}/envios/{envioId:guid}/mostrar", (
            Guid apresentacaoId, Guid envioId, HttpRequest http, RepositorioTocaEssa repositorio) =>
        {
            repositorio.MostrarEnvio(ObterToken(http) ?? string.Empty, apresentacaoId, envioId);
            return Results.NoContent();
        });

        // Sem R2, fora de produção (local e testes): a própria API guarda e serve
        // os arquivos, só com a URL assinada por esta execução.
        var armazenamentoDeStories = app.Services.GetRequiredService<ArmazenamentoDeStories>();
        if (armazenamentoDeStories.UsaPastaLocal)
        {
            app.MapPut($"{ArmazenamentoDeStories.RotaLocal}/{{**chave}}", async (
                string chave, long expira, string? assinatura, HttpRequest http,
                ArmazenamentoDeStories armazenamento, CancellationToken cancelamento) =>
            {
                if (!armazenamento.AssinaturaLocalValida(chave, expira, assinatura))
                    return Results.StatusCode(StatusCodes.Status403Forbidden);
                var caminho = armazenamento.CaminhoLocal(chave);
                Directory.CreateDirectory(Path.GetDirectoryName(caminho)!);
                await using (var arquivo = File.Create(caminho))
                    await http.Body.CopyToAsync(arquivo, cancelamento);
                return Results.Ok();
            }).WithMetadata(new Microsoft.AspNetCore.Mvc.RequestSizeLimitAttribute(110L * 1024 * 1024));

            app.MapGet($"{ArmazenamentoDeStories.RotaLocal}/{{**chave}}", (
                string chave, long expira, string? assinatura, ArmazenamentoDeStories armazenamento) =>
            {
                if (!armazenamento.AssinaturaLocalValida(chave, expira, assinatura))
                    return Results.StatusCode(StatusCodes.Status403Forbidden);
                var caminho = armazenamento.CaminhoLocal(chave);
                new Microsoft.AspNetCore.StaticFiles.FileExtensionContentTypeProvider()
                    .TryGetContentType(caminho, out var tipo);
                return File.Exists(caminho)
                    ? Results.File(caminho, tipo ?? "application/octet-stream", enableRangeProcessing: true)
                    : Results.NotFound();
            });
        }
    }
}
