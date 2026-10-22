using TocaEssaApp.Api.Dominio;
using TocaEssaApp.Api.Infraestrutura;
using static TocaEssaApp.Api.Rotas.AuxiliaresDasRotas;

namespace TocaEssaApp.Api.Rotas;

/// Apresentações do artista: cadastro, pedidos, relógio e fila.
public static class RotasDasApresentacoes
{
    public static void MapearRotasDasApresentacoes(this WebApplication app)
    {
        app.MapGet("/api/apresentacoes", (
            HttpRequest http, RepositorioTocaEssa repositorio) =>
            Results.Ok(repositorio.ListarApresentacoes(
                ObterToken(http) ?? string.Empty)));

        app.MapPost("/api/apresentacoes", (CriarApresentacao requisicao, HttpRequest http, RepositorioTocaEssa repositorio) =>
        {
            var erros = new Dictionary<string, string[]>();
            if (string.IsNullOrWhiteSpace(requisicao.Nome)) erros["nome"] = ["Informe o nome da apresentação."];
            if (string.IsNullOrWhiteSpace(requisicao.Local)) erros["local"] = ["Informe o local."];
            if (requisicao.Data == default) erros["data"] = ["Informe a data."];
            if (erros.Count > 0) return Results.ValidationProblem(erros);

            var apresentacao = repositorio.CriarApresentacao(
                ObterToken(http) ?? string.Empty, requisicao.Nome.Trim(),
                requisicao.Data, requisicao.Local.Trim(), requisicao.Tipo);
            var enderecoConfigurado = app.Configuration["Aplicacao:EnderecoPublico"]?.TrimEnd('/');
            var enderecoPublico = string.IsNullOrWhiteSpace(enderecoConfigurado)
                ? $"{http.Scheme}://{http.Host}"
                : enderecoConfigurado;
            var linkPublico = $"{enderecoPublico}/#/publico/{apresentacao.Codigo}";

            return Results.Created($"/api/apresentacoes/{apresentacao.Id}",
                new ApresentacaoCriada(apresentacao, linkPublico));
        });

        app.MapPut("/api/apresentacoes/{apresentacaoId:guid}", (
            Guid apresentacaoId, EditarApresentacao requisicao, HttpRequest http,
            RepositorioTocaEssa repositorio) =>
        {
            var erros = new Dictionary<string, string[]>();
            if (string.IsNullOrWhiteSpace(requisicao.Nome)) erros["nome"] = ["Informe o nome da apresentação."];
            if (string.IsNullOrWhiteSpace(requisicao.Local)) erros["local"] = ["Informe o local."];
            if (requisicao.Data == default) erros["data"] = ["Informe a data."];
            if (erros.Count > 0) return Results.ValidationProblem(erros);

            return Results.Ok(repositorio.EditarApresentacao(
                ObterToken(http) ?? string.Empty, apresentacaoId,
                requisicao.Nome.Trim(), requisicao.Data,
                requisicao.Local.Trim(), requisicao.Tipo));
        });

        app.MapDelete("/api/apresentacoes/{apresentacaoId:guid}", (
            Guid apresentacaoId, HttpRequest http, RepositorioTocaEssa repositorio) =>
        {
            repositorio.ExcluirApresentacao(
                ObterToken(http) ?? string.Empty, apresentacaoId);
            return Results.NoContent();
        });

        app.MapPatch("/api/apresentacoes/{apresentacaoId:guid}/status", (
            Guid apresentacaoId, AlterarStatusApresentacao requisicao, HttpRequest http,
            RepositorioTocaEssa repositorio) =>
            Results.Ok(repositorio.AlterarStatusApresentacao(
                ObterToken(http) ?? string.Empty, apresentacaoId, requisicao.Status)));

        app.MapGet("/api/apresentacoes/{apresentacaoId:guid}/pedidos", (
            Guid apresentacaoId, HttpRequest http, RepositorioTocaEssa repositorio) =>
            Results.Ok(repositorio.ListarPedidosDoArtista(
                ObterToken(http) ?? string.Empty, apresentacaoId)));

        app.MapGet("/api/apresentacoes/{apresentacaoId:guid}/grupos-pedidos", (
            Guid apresentacaoId, HttpRequest http, RepositorioTocaEssa repositorio) =>
            Results.Ok(repositorio.ListarGruposDePedidosDoArtista(
                ObterToken(http) ?? string.Empty, apresentacaoId)));

        app.MapGet("/api/apresentacoes/{apresentacaoId:guid}/estatisticas", (
            Guid apresentacaoId, HttpRequest http, RepositorioTocaEssa repositorio) =>
            Results.Ok(repositorio.ObterEstatisticasDaApresentacao(
                ObterToken(http) ?? string.Empty, apresentacaoId)));

        app.MapGet("/api/apresentacoes/{apresentacaoId:guid}/participantes", (
            Guid apresentacaoId, HttpRequest http, RepositorioTocaEssa repositorio) =>
            Results.Ok(repositorio.ListarParticipantesDaResenha(
                ObterToken(http) ?? string.Empty, apresentacaoId)));

        app.MapPost("/api/apresentacoes/{apresentacaoId:guid}/foto-retrospectiva", async Task<IResult> (
            Guid apresentacaoId, HttpRequest http, IFormFile foto,
            RepositorioTocaEssa repositorio,
            ArmazenamentoDeImagens armazenamento, CancellationToken cancelamento) =>
        {
            const long limite = 8 * 1024 * 1024;
            var token = ObterToken(http) ?? string.Empty;
            // Show público ou resenha: a foto (ou selfie) ilustra a retrospectiva.
            _ = repositorio.ObterApresentacaoDoArtista(token, apresentacaoId);
            if (foto.Length == 0 || foto.Length > limite)
                return Results.ValidationProblem(new Dictionary<string, string[]>
                {
                    ["foto"] = ["Escolha uma imagem de até 8 MB."]
                });

            await using var memoria = new MemoryStream();
            await foto.CopyToAsync(memoria);
            var imagem = DetectarImagem(memoria.ToArray());
            if (imagem is null)
                return Results.ValidationProblem(new Dictionary<string, string[]>
                {
                    ["foto"] = ["Use uma imagem JPG, PNG ou WebP válida."]
                });

            var nomeArquivo = $"resenha-{apresentacaoId}{imagem.Value.Extensao}";
            var url = await armazenamento.Salvar(
                nomeArquivo, imagem.Value.Tipo, memoria.ToArray(), cancelamento);
            return Results.Ok(repositorio.AtualizarFotoRetrospectiva(
                token, apresentacaoId, url));
        }).DisableAntiforgery();

        app.MapPatch("/api/apresentacoes/{apresentacaoId:guid}/pedidos/{pedidoId:guid}/status", (
            Guid apresentacaoId, Guid pedidoId, AlterarStatusPedidoMusical requisicao,
            HttpRequest http, RepositorioTocaEssa repositorio) =>
            Results.Ok(repositorio.AlterarStatus(
                ObterToken(http) ?? string.Empty, apresentacaoId,
                pedidoId, requisicao.Status)));

        app.MapPatch("/api/apresentacoes/{apresentacaoId:guid}/grupos-pedidos/{representanteId:guid}/status", (
            Guid apresentacaoId, Guid representanteId,
            AlterarStatusPedidoMusical requisicao, HttpRequest http,
            RepositorioTocaEssa repositorio) =>
            Results.Ok(repositorio.AlterarStatusDoGrupo(
                ObterToken(http) ?? string.Empty, apresentacaoId,
                representanteId, requisicao.Status)));

        app.MapGet("/api/apresentacoes/{apresentacaoId:guid}/relogio", (
            Guid apresentacaoId, HttpRequest http, RepositorioTocaEssa repositorio) =>
            Results.Ok(repositorio.ObterRelogio(ObterToken(http) ?? string.Empty, apresentacaoId)));

        app.MapPut("/api/apresentacoes/{apresentacaoId:guid}/relogio", (
            Guid apresentacaoId, ConfigurarRelogioDoShow requisicao, HttpRequest http,
            RepositorioTocaEssa repositorio) =>
            requisicao.DuracaoContratadaMinutos is < 1 or > 24 * 60
                ? Results.ValidationProblem(new Dictionary<string, string[]>
                {
                    ["duracaoContratadaMinutos"] = ["Informe uma duração entre 1 minuto e 24 horas."]
                })
                : Results.Ok(repositorio.ConfigurarRelogio(
                    ObterToken(http) ?? string.Empty, apresentacaoId,
                    requisicao.DuracaoContratadaMinutos, requisicao.IntervaloPausaRelogio)));

        app.MapPost("/api/apresentacoes/{apresentacaoId:guid}/relogio/intervalo", (
            Guid apresentacaoId, HttpRequest http, RepositorioTocaEssa repositorio) =>
            Results.Ok(repositorio.IniciarIntervalo(ObterToken(http) ?? string.Empty, apresentacaoId)));

        app.MapDelete("/api/apresentacoes/{apresentacaoId:guid}/relogio/intervalo", (
            Guid apresentacaoId, HttpRequest http, RepositorioTocaEssa repositorio) =>
            Results.Ok(repositorio.EncerrarIntervalo(ObterToken(http) ?? string.Empty, apresentacaoId)));

        app.MapGet("/api/apresentacoes/{apresentacaoId:guid}/pedidos-a-seguir", (
            Guid apresentacaoId, HttpRequest http, RepositorioTocaEssa repositorio) =>
            Results.Ok(repositorio.ListarPedidosASeguir(
                ObterToken(http) ?? string.Empty, apresentacaoId)));

        app.MapPut("/api/apresentacoes/{apresentacaoId:guid}/pedidos-a-seguir/{pedidoId:guid}", (
            Guid apresentacaoId, Guid pedidoId, bool? noInicio, HttpRequest http,
            RepositorioTocaEssa repositorio) =>
            Results.Ok(repositorio.ColocarPedidoASeguir(
                ObterToken(http) ?? string.Empty, apresentacaoId, pedidoId,
                noInicio ?? false)));

        app.MapDelete("/api/apresentacoes/{apresentacaoId:guid}/pedidos-a-seguir/{pedidoId:guid}", (
            Guid apresentacaoId, Guid pedidoId, HttpRequest http,
            RepositorioTocaEssa repositorio) =>
            Results.Ok(repositorio.TirarPedidoASeguir(
                ObterToken(http) ?? string.Empty, apresentacaoId, pedidoId)));

        app.MapPut("/api/apresentacoes/{apresentacaoId:guid}/fila", (
            Guid apresentacaoId, ReordenarFilaMusical requisicao, HttpRequest http,
            RepositorioTocaEssa repositorio) =>
            Results.Ok(repositorio.ReordenarFila(
                ObterToken(http) ?? string.Empty, apresentacaoId, requisicao.Pedidos)));

        app.MapPut("/api/apresentacoes/{apresentacaoId:guid}/fila-agrupada", (
            Guid apresentacaoId, ReordenarFilaMusical requisicao,
            HttpRequest http, RepositorioTocaEssa repositorio) =>
            Results.Ok(repositorio.ReordenarGruposDaFila(
                ObterToken(http) ?? string.Empty, apresentacaoId, requisicao.Pedidos)));

        app.MapPatch("/api/apresentacoes/{apresentacaoId:guid}/pedidos", (
            Guid apresentacaoId, AlterarPedidosDaApresentacao requisicao,
            HttpRequest http, RepositorioTocaEssa repositorio) =>
            Results.Ok(repositorio.AlterarPedidos(
                ObterToken(http) ?? string.Empty, apresentacaoId, requisicao.Abertos)));
    }
}
