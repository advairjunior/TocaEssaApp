using TocaEssaApp.Api.Dominio;

namespace TocaEssaApp.Api.Infraestrutura;

public sealed partial class RepositorioTocaEssa
{
    /// Músicas pedidas em todos os shows do artista que ainda não estão em
    /// nenhum repertório dele, as mais pedidas primeiro. Alôs e pedidos
    /// cancelados não contam.
    public IReadOnlyCollection<PedidaForaDoRepertorio> ListarPedidasForaDoRepertorio(string token)
    {
        var conta = ExigirRegistroArtista(token);
        var shows = _apresentacoes.Values
            .Where(apresentacao => apresentacao.ArtistaId == conta.Id)
            .Select(apresentacao => apresentacao.Id)
            .ToHashSet();
        var acervo = _musicasDoRepertorio.Values
            .Where(musica => musica.ArtistaId == conta.Id)
            .ToArray();
        return _pedidos.Values
            .Where(pedido => shows.Contains(pedido.ApresentacaoId) &&
                             pedido.Tipo == TipoPedido.Musica &&
                             pedido.Status != StatusPedidoMusical.CanceladoPeloPublico &&
                             !string.IsNullOrWhiteSpace(pedido.Musica))
            .GroupBy(pedido => NormalizarMusica(pedido.Musica))
            .Select(grupo => new PedidaForaDoRepertorio(
                // O jeito de escrever que o público mais usou.
                grupo.GroupBy(pedido => pedido.Musica.Trim())
                    .OrderByDescending(escrita => escrita.Count())
                    .First().Key,
                grupo.Select(pedido => pedido.Artista?.Trim())
                    .FirstOrDefault(artista => !string.IsNullOrEmpty(artista)),
                grupo.Count(),
                grupo.Select(pedido => pedido.ApresentacaoId).Distinct().Count()))
            .Where(pedida => !acervo.Any(musica =>
                MesmaMusica(musica.Titulo, musica.Artista, pedida.Musica, pedida.Artista)))
            .OrderByDescending(pedida => pedida.Vezes)
            .ThenByDescending(pedida => pedida.Shows)
            .ThenBy(pedida => pedida.Musica)
            .ToArray();
    }
}
