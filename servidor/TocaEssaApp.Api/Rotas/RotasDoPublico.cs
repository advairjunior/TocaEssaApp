using TocaEssaApp.Api.Dominio;
using TocaEssaApp.Api.Infraestrutura;
using static TocaEssaApp.Api.Rotas.AuxiliaresDasRotas;

namespace TocaEssaApp.Api.Rotas;

/// Conta do público e o que ele faz no show pelo código.
public static class RotasDoPublico
{
    public static void MapearRotasDoPublico(this WebApplication app)
    {
        app.MapPost("/api/publico/contas", (
            CriarPerfilPublico requisicao, RepositorioTocaEssa repositorio) =>
        {
            var erros = ValidarPerfilPublico(requisicao.Nome, requisicao.Email, requisicao.Senha);
            if (erros.Count > 0) return Results.ValidationProblem(erros);
            var sessao = repositorio.CriarPerfilPublico(
                requisicao.Nome.Trim(), requisicao.Email.Trim(), requisicao.Senha);
            return Results.Created("/api/publico/perfil", sessao);
        });

        app.MapPost("/api/publico/sessoes", (
            EntrarPerfilPublico requisicao, RepositorioTocaEssa repositorio) =>
        {
            if (string.IsNullOrWhiteSpace(requisicao.Email) ||
                string.IsNullOrWhiteSpace(requisicao.Senha))
                return Results.ValidationProblem(new Dictionary<string, string[]>
                {
                    ["credenciais"] = ["Informe o e-mail e a senha."]
                });
            return Results.Ok(repositorio.EntrarPerfilPublico(requisicao.Email, requisicao.Senha));
        });

        app.MapGet("/api/publico/perfil", (HttpRequest http, RepositorioTocaEssa repositorio) =>
            Results.Ok(repositorio.ObterPerfilPublico(ObterToken(http) ?? string.Empty)));

        app.MapGet("/api/publico/estatisticas", (
            HttpRequest http, RepositorioTocaEssa repositorio) =>
            Results.Ok(repositorio.ObterEstatisticasDoPublico(
                ObterToken(http) ?? string.Empty)));

        app.MapGet("/api/publico/apresentacoes", (
            HttpRequest http, RepositorioTocaEssa repositorio) =>
            Results.Ok(repositorio.ListarApresentacoesDoPublico(ObterToken(http) ?? string.Empty)));

        app.MapGet("/api/publico/historico", (
            HttpRequest http, RepositorioTocaEssa repositorio) =>
            Results.Ok(repositorio.ListarHistoricoDoPublico(ObterToken(http) ?? string.Empty)));

        app.MapGet("/api/publico/apresentacoes/{codigo}/apoio-pix", (
            string codigo, decimal valor, RepositorioTocaEssa repositorio) =>
            Results.Ok(repositorio.GerarApoioPix(codigo, valor)));

        app.MapDelete("/api/publico/sessoes/atual", (
            HttpRequest http, RepositorioTocaEssa repositorio) =>
        {
            repositorio.EncerrarSessaoPublica(ObterToken(http) ?? string.Empty);
            return Results.NoContent();
        });

        app.MapPost("/api/publico/perfil/foto", async Task<IResult> (
            HttpRequest http, IFormFile foto, RepositorioTocaEssa repositorio,
            ArmazenamentoDeImagens armazenamento, CancellationToken cancelamento) =>
        {
            var token = ObterToken(http) ?? throw new SessaoPublicaInvalidaException();
            var perfil = repositorio.ObterPerfilPublico(token);
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

            var nomeArquivo = $"publico-{perfil.Id}{imagem.Value.Extensao}";
            var url = await armazenamento.Salvar(
                nomeArquivo, imagem.Value.Tipo, memoria.ToArray(), cancelamento);
            return Results.Ok(repositorio.AtualizarFotoPerfilPublico(token, url));
        }).DisableAntiforgery();

        app.MapGet("/api/publico/apresentacoes/{codigo}", (string codigo, RepositorioTocaEssa repositorio) =>
            repositorio.ObterApresentacaoPublica(codigo) is { } apresentacao
                ? Results.Ok(apresentacao)
                : Results.NotFound());

        app.MapPost("/api/publico/apresentacoes/{codigo}/pedidos", (
            string codigo, CriarPedidoMusical requisicao, HttpRequest http,
            RepositorioTocaEssa repositorio) =>
        {
            if (requisicao.Tipo == TipoPedido.Musica && string.IsNullOrWhiteSpace(requisicao.Musica))
                return Results.ValidationProblem(new Dictionary<string, string[]> { ["musica"] = ["Informe a música."] });
            if (requisicao.Tipo == TipoPedido.Alo && string.IsNullOrWhiteSpace(requisicao.DestinatarioAlo))
                return Results.ValidationProblem(new Dictionary<string, string[]> { ["destinatarioAlo"] = ["Informe para quem é o Alô."] });
            var pedido = repositorio.CriarPedido(
                codigo, requisicao.Musica?.Trim() ?? string.Empty, requisicao.Artista?.Trim(),
                requisicao.NomeSolicitante?.Trim(), ObterToken(http),
                requisicao.FormaParticipacao, requisicao.TomPreferido?.Trim(),
                requisicao.Recado?.Trim(), requisicao.Tipo,
                requisicao.DestinatarioAlo?.Trim());
            return Results.Created($"/api/publico/apresentacoes/{codigo}/pedidos/{pedido.Id}", pedido);
        });

        app.MapGet("/api/publico/apresentacoes/{codigo}/fila", (
            string codigo, HttpRequest http, RepositorioTocaEssa repositorio) =>
            Results.Ok(repositorio.ListarFilaPublica(
                codigo, http.Headers["X-Identificador-Publico"].FirstOrDefault(), ObterToken(http))));

        app.MapGet("/api/publico/apresentacoes/{codigo}/roteiro", (
            string codigo, RepositorioTocaEssa repositorio) =>
            Results.Ok(repositorio.ObterRoteiroDoLouvor(codigo)));

        app.MapGet("/api/publico/apresentacoes/{codigo}/participantes", (
            string codigo, HttpRequest http, RepositorioTocaEssa repositorio) =>
            Results.Ok(repositorio.ListarParticipantesDaResenha(
                codigo, ObterToken(http) ?? string.Empty)));

        // Sem corpo continua valendo; no louvor, { nome } é quem a pessoa é.
        app.MapPost("/api/publico/apresentacoes/{codigo}/participacoes", (
            string codigo, RegistrarParticipacaoNoEvento? requisicao, HttpRequest http,
            RepositorioTocaEssa repositorio) =>
        {
            repositorio.RegistrarParticipacao(
                codigo, ObterToken(http) ?? string.Empty, requisicao?.Nome);
            return Results.NoContent();
        });

        app.MapPost("/api/publico/apresentacoes/{codigo}/acessos", (
            string codigo, RegistrarAcessoAoEvento requisicao, RepositorioTocaEssa repositorio) =>
        {
            var visitante = requisicao.Visitante?.Trim();
            if (string.IsNullOrEmpty(visitante) || visitante.Length > 160)
                return Results.ValidationProblem(new Dictionary<string, string[]>
                {
                    ["visitante"] = ["Informe o identificador do aparelho."]
                });
            repositorio.RegistrarAcessoAoEvento(codigo, visitante);
            return Results.NoContent();
        });

        app.MapGet("/api/publico/apresentacoes/{codigo}/pedidos/{pedidoId:guid}", (
            string codigo, Guid pedidoId, HttpRequest http, RepositorioTocaEssa repositorio) =>
            repositorio.ObterPedidoPublico(codigo, pedidoId, ObterToken(http)) is { } pedido
                ? Results.Ok(pedido)
                : Results.NotFound());

        app.MapGet("/api/publico/apresentacoes/{codigo}/meus-pedidos", (
            string codigo, HttpRequest http, RepositorioTocaEssa repositorio) =>
            Results.Ok(repositorio.ListarPedidosDoPublico(
                codigo, ObterToken(http) ?? string.Empty)));

        app.MapPatch("/api/publico/apresentacoes/{codigo}/pedidos/{pedidoId:guid}/cancelar", (
            string codigo, Guid pedidoId, HttpRequest http, RepositorioTocaEssa repositorio) =>
            Results.Ok(repositorio.CancelarPedidoPeloPublico(
                codigo, pedidoId, ObterToken(http))));

        app.MapPut("/api/publico/apresentacoes/{codigo}/pedidos/{pedidoId:guid}/avaliacao", (
            string codigo, Guid pedidoId, AvaliarPedidoMusical requisicao,
            HttpRequest http, RepositorioTocaEssa repositorio) =>
            Results.Ok(repositorio.AvaliarPedidoPeloPublico(
                codigo, pedidoId, requisicao.Estrelas,
                requisicao.IdentificadorAvaliador, ObterToken(http))));
    }
}
