using System.Collections.Concurrent;

namespace TocaEssaApp.Api.Infraestrutura;

public sealed partial class RepositorioTocaEssa
{
    // Pedidos que o artista marcou para tocar a seguir, em ordem, por
    // apresentação. Ficam no servidor para todos os aparelhos da banda verem.
    private readonly ConcurrentDictionary<Guid, IReadOnlyList<Guid>> _pedidosASeguir = new();

    public IReadOnlyList<Guid> ListarPedidosASeguir(string token, Guid apresentacaoId)
    {
        _ = ObterApresentacaoDoArtista(token, apresentacaoId);
        return _pedidosASeguir.GetValueOrDefault(apresentacaoId) ?? [];
    }

    /// Coloca o pedido no fim ou no início da sequência; se já estava, só muda
    /// de lugar.
    public IReadOnlyList<Guid> ColocarPedidoASeguir(
        string token, Guid apresentacaoId, Guid pedidoId, bool noInicio)
    {
        _ = ObterApresentacaoDoArtista(token, apresentacaoId);
        lock (_sincronizacao)
        {
            if (!_pedidos.TryGetValue(pedidoId, out var pedido) ||
                pedido.ApresentacaoId != apresentacaoId)
                throw new PedidoMusicalNaoEncontradoException();
            var demais = SemOPedido(apresentacaoId, pedidoId);
            return GravarPedidosASeguir(apresentacaoId,
                noInicio ? [pedidoId, .. demais] : [.. demais, pedidoId]);
        }
    }

    public IReadOnlyList<Guid> TirarPedidoASeguir(
        string token, Guid apresentacaoId, Guid pedidoId)
    {
        _ = ObterApresentacaoDoArtista(token, apresentacaoId);
        lock (_sincronizacao)
        {
            var atuais = _pedidosASeguir.GetValueOrDefault(apresentacaoId) ?? [];
            return atuais.Contains(pedidoId)
                ? GravarPedidosASeguir(apresentacaoId, SemOPedido(apresentacaoId, pedidoId))
                : atuais;
        }
    }

    private Guid[] SemOPedido(Guid apresentacaoId, Guid pedidoId) =>
        (_pedidosASeguir.GetValueOrDefault(apresentacaoId) ?? [])
            .Where(id => id != pedidoId)
            .ToArray();

    private IReadOnlyList<Guid> GravarPedidosASeguir(
        Guid apresentacaoId, IReadOnlyList<Guid> pedidos)
    {
        _pedidosASeguir[apresentacaoId] = pedidos;
        SalvarEstado();
        return pedidos;
    }

    private static IReadOnlyList<Guid> LerPedidosASeguir(string? gravados) =>
        string.IsNullOrWhiteSpace(gravados)
            ? []
            : gravados.Split(',', StringSplitOptions.RemoveEmptyEntries)
                .Select(id => Guid.TryParse(id, out var valor) ? valor : (Guid?)null)
                .OfType<Guid>()
                .ToArray();

    private string? EscreverPedidosASeguir(Guid apresentacaoId) =>
        _pedidosASeguir.GetValueOrDefault(apresentacaoId) is { Count: > 0 } pedidos
            ? string.Join(',', pedidos)
            : null;
}
