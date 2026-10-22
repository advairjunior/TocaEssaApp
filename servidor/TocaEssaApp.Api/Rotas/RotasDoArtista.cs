using TocaEssaApp.Api.Dominio;
using TocaEssaApp.Api.Infraestrutura;
using static TocaEssaApp.Api.Rotas.AuxiliaresDasRotas;

namespace TocaEssaApp.Api.Rotas;

/// Saúde, tempo real, conta e perfil artístico.
public static class RotasDoArtista
{
    public static void MapearRotasDoArtista(this WebApplication app)
    {
        app.MapGet("/api/arquivos/{**chave}", async Task<IResult> (
            string chave, ArmazenamentoDeImagens armazenamento, CancellationToken cancelamento) =>
        {
            var arquivo = await armazenamento.Abrir(chave, cancelamento);
            return arquivo is null
                ? Results.NotFound()
                : Results.File(arquivo.Value.Conteudo, arquivo.Value.TipoDeConteudo);
        });

        app.MapGet("/api/saude", () => Results.Ok(new { status = "ok" }));

        app.MapGet("/api/tempo-real/{codigo}", async Task (
            string codigo,
            HttpResponse resposta,
            NotificadorTempoReal notificador,
            CancellationToken cancelamento) =>
        {
            resposta.ContentType = "text/event-stream";
            resposta.Headers.CacheControl = "no-cache";
            resposta.Headers.Append("X-Accel-Buffering", "no");
            await foreach (var evento in notificador.Assinar(codigo, cancelamento))
            {
                var mensagem = evento == "pulso" ? ": pulso\n\n" : $"data: {evento}\n\n";
                await resposta.WriteAsync(mensagem, cancelamento);
                await resposta.Body.FlushAsync(cancelamento);
            }
        });

        app.MapPost("/api/artista/contas", (
            CriarContaArtista requisicao, RepositorioTocaEssa repositorio) =>
        {
            var erros = ValidarConta(requisicao.Nome, requisicao.Email, requisicao.Senha);
            if (erros.Count > 0) return Results.ValidationProblem(erros);
            var sessao = repositorio.CriarContaArtista(
                requisicao.Nome.Trim(), requisicao.Email.Trim(), requisicao.Senha);
            return Results.Created("/api/artista/conta", sessao);
        });

        app.MapPost("/api/artista/sessoes", (
            EntrarContaArtista requisicao, RepositorioTocaEssa repositorio) =>
        {
            if (string.IsNullOrWhiteSpace(requisicao.Email) ||
                string.IsNullOrWhiteSpace(requisicao.Senha))
                return Results.ValidationProblem(new Dictionary<string, string[]>
                {
                    ["credenciais"] = ["Informe o e-mail e a senha."]
                });
            return Results.Ok(repositorio.EntrarContaArtista(requisicao.Email, requisicao.Senha));
        });

        app.MapGet("/api/artista/conta", (HttpRequest http, RepositorioTocaEssa repositorio) =>
            Results.Ok(repositorio.ObterContaArtista(ObterToken(http) ?? string.Empty)));

        app.MapDelete("/api/artista/sessoes/atual", (
            HttpRequest http, RepositorioTocaEssa repositorio) =>
        {
            repositorio.EncerrarSessaoArtista(ObterToken(http) ?? string.Empty);
            return Results.NoContent();
        });

        app.MapGet("/api/perfil-artistico", (
            HttpRequest http, RepositorioTocaEssa repositorio) =>
            repositorio.ObterConfiguracaoPerfil(
                ObterToken(http) ?? string.Empty) is { } perfil
                ? Results.Ok(perfil)
                : Results.NotFound());

        app.MapPut("/api/perfil-artistico", (
            SalvarPerfilArtistico requisicao, HttpRequest http,
            RepositorioTocaEssa repositorio) =>
        {
            if (string.IsNullOrWhiteSpace(requisicao.NomeArtistico))
            {
                return Results.ValidationProblem(new Dictionary<string, string[]>
                {
                    ["nomeArtistico"] = ["Informe o nome artístico."]
                });
            }

            var token = ObterToken(http) ?? string.Empty;
            repositorio.SalvarPerfilDaConta(token, requisicao);
            return Results.Ok(repositorio.ObterConfiguracaoPerfil(token));
        });

        app.MapPost("/api/perfil-artistico/foto", async Task<IResult> (
            HttpRequest http, IFormFile foto, RepositorioTocaEssa repositorio,
            ArmazenamentoDeImagens armazenamento, CancellationToken cancelamento) =>
        {
            const long limite = 5 * 1024 * 1024;
            if (foto.Length == 0 || foto.Length > limite)
                return Results.ValidationProblem(new Dictionary<string, string[]>
                {
                    ["foto"] = ["Escolha uma imagem de até 5 MB."]
                });

            await using var memoria = new MemoryStream();
            await foto.CopyToAsync(memoria);
            var imagem = DetectarImagem(memoria.ToArray());
            if (imagem is null)
                return Results.ValidationProblem(new Dictionary<string, string[]>
                {
                    ["foto"] = ["Use uma imagem JPG, PNG ou WebP válida."]
                });

            var token = ObterToken(http) ?? string.Empty;
            var perfil = repositorio.ObterPerfil(token)
                ?? throw new PerfilArtisticoNaoCadastradoException();
            var nomeArquivo = $"perfil-{perfil.Id}{imagem.Value.Extensao}";
            var url = await armazenamento.Salvar(
                nomeArquivo, imagem.Value.Tipo, memoria.ToArray(), cancelamento);
            return Results.Ok(repositorio.AtualizarFotoPerfil(token, url));
        }).DisableAntiforgery();
    }
}
