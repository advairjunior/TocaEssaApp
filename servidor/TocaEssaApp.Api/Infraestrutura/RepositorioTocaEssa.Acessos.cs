using TocaEssaApp.Api.Dominio;

namespace TocaEssaApp.Api.Infraestrutura;

public sealed partial class RepositorioTocaEssa
{
    private const int TamanhoMaximoVisitante = 160;

    /// Registra que um aparelho abriu o evento. Cada aparelho conta uma vez e,
    /// depois do encerramento, quem revisita não infla o público da noite.
    public void RegistrarAcessoAoEvento(string codigo, string visitante)
    {
        lock (_sincronizacao)
        {
            var apresentacao = ObterApresentacaoPublica(codigo)
                ?? throw new ApresentacaoNaoEncontradaException();
            var identificador = visitante?.Trim() ?? string.Empty;
            if (identificador.Length is 0 or > TamanhoMaximoVisitante) return;
            if (apresentacao.Status == StatusApresentacao.Encerrada) return;
            var chave = (apresentacao.Id, identificador);
            if (_acessosAoEvento.ContainsKey(chave)) return;
            _acessosAoEvento[chave] = new AcessoAoEventoRegistro
            {
                ApresentacaoId = apresentacao.Id,
                Visitante = identificador,
                AcessouEm = DateTimeOffset.UtcNow
            };
            SalvarEstado();
        }
    }

    /// Quantas pessoas estiveram no evento pelo app: o maior entre os
    /// aparelhos que abriram a página e quem participou ou pediu música.
    private (int PessoasNoEvento, int PessoasQuePediram) ContarPublicoDoEvento(
        Guid apresentacaoId)
    {
        var quemPediu = _pedidos.Values
            .Where(item => item.ApresentacaoId == apresentacaoId &&
                           item.Status != StatusPedidoMusical.CanceladoPeloPublico)
            .Select(IdentificarSolicitante)
            .ToHashSet();
        var participantes = _participacoesResenha.Keys
            .Where(chave => chave.ApresentacaoId == apresentacaoId)
            .Select(chave => $"publico:{chave.PublicoId:N}")
            .Concat(quemPediu)
            .ToHashSet();
        var aparelhos = _acessosAoEvento.Keys
            .Count(chave => chave.ApresentacaoId == apresentacaoId);
        return (Math.Max(aparelhos, participantes.Count), quemPediu.Count);
    }

    private static string IdentificarSolicitante(PedidoMusical pedido) =>
        pedido.PublicoId is { } publicoId
            ? $"publico:{publicoId:N}"
            : string.IsNullOrWhiteSpace(pedido.NomeSolicitante)
                ? $"pedido:{pedido.Id:N}"
                : $"nome:{pedido.NomeSolicitante.Trim().ToUpperInvariant()}";
}
