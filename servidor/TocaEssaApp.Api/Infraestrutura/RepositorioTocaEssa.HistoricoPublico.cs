using TocaEssaApp.Api.Dominio;

namespace TocaEssaApp.Api.Infraestrutura;

public sealed partial class RepositorioTocaEssa
{
    public IReadOnlyCollection<Apresentacao> ListarApresentacoesDoPublico(string token)
    {
        var publico = ObterRegistroPublico(token)
            ?? throw new SessaoPublicaInvalidaException();
        var ids = _participacoesResenha.Values
            .Where(item => item.PublicoId == publico.Id)
            .Select(item => item.ApresentacaoId)
            .Concat(_pedidos.Values.Where(item => item.PublicoId == publico.Id)
                .Select(item => item.ApresentacaoId))
            .Concat(_avaliacoes.Values.Where(item => item.PublicoId == publico.Id)
                .Select(item => _pedidos.GetValueOrDefault(item.PedidoId)?.ApresentacaoId)
                .OfType<Guid>())
            .ToHashSet();
        return _apresentacoes.Values.Where(item => ids.Contains(item.Id))
            .OrderByDescending(item => item.Data).ToArray();
    }

    /// <summary>
    /// Cada encontro do público com seus próprios números e, só na resenha
    /// entre amigos, quem mais estava lá — no show público ninguém é exposto.
    /// </summary>
    public IReadOnlyCollection<EncontroDoPublico> ListarHistoricoDoPublico(string token)
    {
        var publico = ObterRegistroPublico(token)
            ?? throw new SessaoPublicaInvalidaException();
        return ListarApresentacoesDoPublico(token)
            .Select(apresentacao => ResumirEncontro(apresentacao, publico.Id))
            .ToArray();
    }

    private EncontroDoPublico ResumirEncontro(Apresentacao apresentacao, Guid publicoId)
    {
        var pedidosDaNoite = _pedidos.Values
            .Where(item => item.ApresentacaoId == apresentacao.Id &&
                           item.Tipo == TipoPedido.Musica &&
                           item.PublicoId.HasValue &&
                           item.Status != StatusPedidoMusical.CanceladoPeloPublico)
            .ToArray();
        var meus = pedidosDaNoite.Where(item => item.PublicoId == publicoId).ToArray();
        var companhia = apresentacao.Tipo != TipoApresentacao.ResenhaEntreAmigos
            ? []
            : _participacoesResenha.Values
                .Where(item => item.ApresentacaoId == apresentacao.Id)
                .Select(item => item.PublicoId)
                .Concat(pedidosDaNoite.Select(item => item.PublicoId!.Value))
                .Where(id => id != publicoId)
                .Distinct()
                .Select(id => _perfisPublicos.GetValueOrDefault(id) is { } perfil
                    ? new PessoaDoEncontro(id, perfil.Nome, perfil.FotoUrl)
                    : new PessoaDoEncontro(id, "Participante", null))
                .OrderBy(pessoa => pessoa.Nome, StringComparer.CurrentCultureIgnoreCase)
                .ToArray();
        return new EncontroDoPublico(
            apresentacao,
            meus.Length,
            meus.Count(item => item.Status == StatusPedidoMusical.Finalizado),
            AgruparMusicas(meus),
            companhia);
    }
}
