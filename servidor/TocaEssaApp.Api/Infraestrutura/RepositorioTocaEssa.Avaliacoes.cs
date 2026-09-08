using TocaEssaApp.Api.Dominio;

namespace TocaEssaApp.Api.Infraestrutura;

public sealed partial class RepositorioTocaEssa
{
    public PedidoMusical AvaliarPedidoPeloPublico(
        string codigo,
        Guid pedidoId,
        int estrelas,
        string? identificadorAvaliador = null,
        string? tokenPublico = null)
    {
        lock (_sincronizacao)
        {
            if (estrelas is < 1 or > 5) throw new AvaliacaoInvalidaException();
            var apresentacao = ObterApresentacaoPublica(codigo)
                ?? throw new ApresentacaoNaoEncontradaException();
            if (!_pedidos.TryGetValue(pedidoId, out var pedido) ||
                pedido.ApresentacaoId != apresentacao.Id)
                throw new PedidoMusicalNaoEncontradoException();
            if (pedido.Status != StatusPedidoMusical.Finalizado)
                throw new PedidoAindaNaoTocadoException();

            var (chave, publicoId) = IdentificarAvaliador(
                apresentacao, identificadorAvaliador, tokenPublico, exigir: true)!.Value;
            _avaliacoes[(pedidoId, chave)] = new AvaliacaoPedidoRegistro
            {
                PedidoId = pedidoId,
                IdentificadorAvaliador = chave,
                PublicoId = publicoId,
                Estrelas = estrelas,
                AvaliadoEm = DateTimeOffset.UtcNow
            };
            SalvarEstado();
            return ComAvaliacoes(pedido, chave);
        }
    }

    private (string Chave, Guid? PublicoId)? IdentificarAvaliador(
        Apresentacao apresentacao,
        string? identificador,
        string? token,
        bool exigir)
    {
        var perfil = ObterRegistroPublico(token);
        if (perfil is not null) return ($"perfil:{perfil.Id:N}", perfil.Id);
        if (apresentacao.Tipo == TipoApresentacao.ResenhaEntreAmigos)
        {
            if (exigir) throw new SessaoPublicaInvalidaException();
            return null;
        }
        var dispositivo = string.IsNullOrWhiteSpace(identificador)
            ? null
            : identificador.Trim();
        if (dispositivo is { Length: > 120 }) dispositivo = dispositivo[..120];
        if (dispositivo is not null) return ($"dispositivo:{dispositivo}", null);
        if (exigir) throw new IdentificacaoAvaliadorObrigatoriaException();
        return null;
    }

    private PedidoMusical ComAvaliacoes(PedidoMusical pedido, string? avaliador)
    {
        var avaliacoes = _avaliacoes.Values
            .Where(item => item.PedidoId == pedido.Id)
            .ToArray();
        return pedido with
        {
            Avaliacao = null,
            QuantidadeAvaliacoes = avaliacoes.Length,
            MediaAvaliacoes = avaliacoes.Length == 0
                ? null
                : Math.Round(avaliacoes.Average(item => item.Estrelas), 1),
            MinhaAvaliacao = avaliador is null
                ? null
                : avaliacoes.FirstOrDefault(
                    item => item.IdentificadorAvaliador == avaliador)?.Estrelas
        };
    }

    private IReadOnlyCollection<PedidoMusical> PrepararFilaPublica(
        Guid apresentacaoId,
        IReadOnlyCollection<StatusPedidoMusical> statusVisiveis,
        (string Chave, Guid? PublicoId)? avaliador)
    {
        return _pedidos.Values
            .Where(item => item.ApresentacaoId == apresentacaoId &&
                           item.Tipo == TipoPedido.Musica &&
                           statusVisiveis.Contains(item.Status))
            .OrderBy(item => item.Posicao ?? int.MaxValue)
            .ThenBy(item => item.CriadoEm)
            .GroupBy(item => new
            {
                Musica = item.Musica.Trim().ToUpperInvariant(),
                Artista = item.Artista?.Trim().ToUpperInvariant() ?? "",
                item.Status
            })
            .Select(grupo =>
            {
                var primeiro = ComAvaliacoes(grupo.First(), avaliador?.Chave);
                var solicitantes = grupo
                    .Select(item => item.NomeSolicitante?.Trim())
                    .Where(nome => !string.IsNullOrWhiteSpace(nome))
                    .Cast<string>()
                    .Distinct(StringComparer.OrdinalIgnoreCase)
                    .ToArray();
                return primeiro with { Solicitantes = solicitantes };
            })
            .ToArray();
    }
}
