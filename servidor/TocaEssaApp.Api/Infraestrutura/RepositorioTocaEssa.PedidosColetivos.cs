using TocaEssaApp.Api.Dominio;

namespace TocaEssaApp.Api.Infraestrutura;

public sealed partial class RepositorioTocaEssa
{
    private static readonly StatusPedidoMusical[] StatusAtivos =
    [
        StatusPedidoMusical.Aguardando,
        StatusPedidoMusical.Aceito,
        StatusPedidoMusical.TocandoAgora
    ];

    public IReadOnlyCollection<GrupoPedidoMusical> ListarGruposDePedidosDoArtista(
        Guid apresentacaoId)
    {
        if (!_apresentacoes.Values.Any(item => item.Id == apresentacaoId))
            throw new ApresentacaoNaoEncontradaException();

        return _pedidos.Values
            .Where(item => item.ApresentacaoId == apresentacaoId)
            .GroupBy(ChaveDoGrupo)
            .Select(CriarGrupo)
            .OrderBy(item => item.Posicao ?? int.MaxValue)
            .ThenBy(item => item.CriadoEm)
            .ToArray();
    }

    public GrupoPedidoMusical AlterarStatusDoGrupo(
        Guid apresentacaoId,
        Guid representanteId,
        StatusPedidoMusical status)
    {
        lock (_sincronizacao)
        {
            var membros = ObterMembrosDoGrupo(apresentacaoId, representanteId);

            if (status == StatusPedidoMusical.TocandoAgora)
            {
                var idsDoGrupo = membros.Select(item => item.Id).ToHashSet();
                foreach (var tocando in _pedidos.Values.Where(item =>
                             item.ApresentacaoId == apresentacaoId &&
                             item.Status == StatusPedidoMusical.TocandoAgora &&
                             !idsDoGrupo.Contains(item.Id)))
                    _pedidos[tocando.Id] = tocando with
                    {
                        Status = StatusPedidoMusical.Finalizado,
                        Posicao = null
                    };
            }

            foreach (var membro in membros)
                _pedidos[membro.Id] = membro with
                {
                    Status = status,
                    Posicao = status == StatusPedidoMusical.Aceito
                        ? membro.Posicao
                        : null
                };

            if (status == StatusPedidoMusical.Aceito)
                ReposicionarGrupoAceito(apresentacaoId,
                    membros.Select(item => item.Id).ToHashSet());
            else
                NormalizarFila(apresentacaoId);

            SalvarEstado();
            return CriarGrupo(ObterMembrosDoGrupo(apresentacaoId, representanteId));
        }
    }

    public IReadOnlyCollection<GrupoPedidoMusical> ReordenarGruposDaFila(
        Guid apresentacaoId,
        IReadOnlyList<Guid> representantes)
    {
        lock (_sincronizacao)
        {
            var grupos = ListarGruposDePedidosDoArtista(apresentacaoId)
                .Where(item => item.Status == StatusPedidoMusical.Aceito)
                .ToArray();
            var porRepresentante = grupos.ToDictionary(
                item => item.PedidoRepresentativoId);
            if (representantes.Count != grupos.Length ||
                representantes.Distinct().Count() != representantes.Count ||
                representantes.Any(id => !porRepresentante.ContainsKey(id)))
                throw new FilaMusicalInvalidaException();

            var posicao = 1;
            foreach (var representante in representantes)
            {
                foreach (var pedidoId in porRepresentante[representante].PedidoIds)
                {
                    var pedido = _pedidos[pedidoId];
                    _pedidos[pedidoId] = pedido with { Posicao = posicao++ };
                }
            }

            SalvarEstado();
            return ListarGruposDePedidosDoArtista(apresentacaoId);
        }
    }

    private PedidoMusical[] ObterMembrosDoGrupo(
        Guid apresentacaoId, Guid representanteId)
    {
        if (!_pedidos.TryGetValue(representanteId, out var representante) ||
            representante.ApresentacaoId != apresentacaoId)
            throw new PedidoMusicalNaoEncontradoException();

        var chave = ChaveDoGrupo(representante);
        return _pedidos.Values
            .Where(item => item.ApresentacaoId == apresentacaoId &&
                           ChaveDoGrupo(item) == chave)
            .OrderBy(item => item.Posicao ?? int.MaxValue)
            .ThenBy(item => item.CriadoEm)
            .ToArray();
    }

    private GrupoPedidoMusical CriarGrupo(IEnumerable<PedidoMusical> itens)
    {
        var pedidos = itens
            .OrderBy(item => item.Posicao ?? int.MaxValue)
            .ThenBy(item => item.CriadoEm)
            .ToArray();
        var primeiro = pedidos[0];
        var status = DerivarStatusDoGrupo(pedidos);
        var ids = pedidos.Select(item => item.Id).ToArray();
        var avaliacoes = _avaliacoes.Values
            .Where(item => ids.Contains(item.PedidoId))
            .Select(item => item.Estrelas)
            .ToArray();
        var solicitantes = pedidos
            .Select(item => item.NomeSolicitante?.Trim())
            .Where(nome => !string.IsNullOrWhiteSpace(nome))
            .Cast<string>()
            .Distinct(StringComparer.OrdinalIgnoreCase)
            .ToArray();

        return new GrupoPedidoMusical(
            primeiro.Id, ids, primeiro.ApresentacaoId, primeiro.Musica,
            primeiro.Artista, status,
            pedidos.Where(item => item.Posicao.HasValue)
                .Select(item => item.Posicao).Min(),
            pedidos.Min(item => item.CriadoEm), primeiro.FormaParticipacao,
            primeiro.TomPreferido, primeiro.Recado, primeiro.Tipo,
            primeiro.DestinatarioAlo, pedidos.Length, solicitantes,
            avaliacoes.Length,
            avaliacoes.Length == 0 ? null : Math.Round(avaliacoes.Average(), 1));
    }

    private static StatusPedidoMusical DerivarStatusDoGrupo(
        IReadOnlyCollection<PedidoMusical> pedidos)
    {
        if (pedidos.Any(item => item.Status == StatusPedidoMusical.TocandoAgora))
            return StatusPedidoMusical.TocandoAgora;
        if (pedidos.Any(item => item.Status == StatusPedidoMusical.Aceito))
            return StatusPedidoMusical.Aceito;
        return pedidos.First().Status;
    }

    private static string ChaveDoGrupo(PedidoMusical pedido)
    {
        if (pedido.Tipo != TipoPedido.Musica)
            return $"ALO:{pedido.Id:N}";
        var ciclo = StatusAtivos.Contains(pedido.Status)
            ? "ATIVO"
            : pedido.Status.ToString().ToUpperInvariant();
        return $"MUSICA:{NormalizarParaAgrupamento(pedido.Musica)}:" +
               $"{NormalizarParaAgrupamento(pedido.Artista)}:{ciclo}";
    }

    private static string NormalizarParaAgrupamento(string? valor) =>
        string.IsNullOrWhiteSpace(valor)
            ? string.Empty
            : string.Join(' ', valor.Trim().Split(
                (char[]?)null, StringSplitOptions.RemoveEmptyEntries))
                .ToUpperInvariant();

    private void ReposicionarGrupoAceito(
        Guid apresentacaoId, IReadOnlySet<Guid> idsDoGrupo)
    {
        var membros = idsDoGrupo.Select(id => _pedidos[id])
            .OrderBy(item => item.CriadoEm)
            .ToArray();
        var menorPosicaoExistente = membros
            .Where(item => item.Posicao.HasValue)
            .Select(item => item.Posicao!.Value)
            .DefaultIfEmpty(int.MaxValue)
            .Min();
        var demais = _pedidos.Values
            .Where(item => item.ApresentacaoId == apresentacaoId &&
                           item.Status == StatusPedidoMusical.Aceito &&
                           !idsDoGrupo.Contains(item.Id))
            .OrderBy(item => item.Posicao ?? int.MaxValue)
            .ThenBy(item => item.CriadoEm)
            .ToList();
        var indice = menorPosicaoExistente == int.MaxValue
            ? demais.Count
            : demais.Count(item => (item.Posicao ?? int.MaxValue) <
                                    menorPosicaoExistente);
        demais.InsertRange(indice, membros);
        for (var i = 0; i < demais.Count; i++)
            _pedidos[demais[i].Id] = demais[i] with { Posicao = i + 1 };
    }
}
