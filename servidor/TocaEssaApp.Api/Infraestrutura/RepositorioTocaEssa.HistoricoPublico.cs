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
}
