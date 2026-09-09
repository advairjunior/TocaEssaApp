using TocaEssaApp.Api.Dominio;

namespace TocaEssaApp.Api.Infraestrutura;

public sealed partial class RepositorioTocaEssa
{
    public void RegistrarParticipacaoNaResenha(string codigo, string token)
    {
        lock (_sincronizacao)
        {
            var apresentacao = ObterApresentacaoPublica(codigo)
                ?? throw new ApresentacaoNaoEncontradaException();
            if (apresentacao.Tipo != TipoApresentacao.ResenhaEntreAmigos)
                throw new RecursoDisponivelSomenteNaResenhaException();
            var publico = ObterRegistroPublico(token)
                ?? throw new SessaoPublicaInvalidaException();
            var chave = (apresentacao.Id, publico.Id);
            if (_participacoesResenha.ContainsKey(chave)) return;
            _participacoesResenha[chave] = new ParticipacaoResenhaRegistro
            {
                ApresentacaoId = apresentacao.Id,
                PublicoId = publico.Id,
                EntrouEm = DateTimeOffset.UtcNow
            };
            SalvarEstado();
        }
    }

    public IReadOnlyCollection<ParticipanteDaResenha> ListarParticipantesDaResenha(
        Guid apresentacaoId)
    {
        var apresentacao = _apresentacoes.Values.SingleOrDefault(
            item => item.Id == apresentacaoId)
            ?? throw new ApresentacaoNaoEncontradaException();
        if (apresentacao.Tipo != TipoApresentacao.ResenhaEntreAmigos)
            throw new RecursoDisponivelSomenteNaResenhaException();

        var pedidos = _pedidos.Values
            .Where(item => item.ApresentacaoId == apresentacaoId &&
                           item.Tipo == TipoPedido.Musica &&
                           item.PublicoId.HasValue &&
                           item.Status is not StatusPedidoMusical.NaoConhecemos and
                               not StatusPedidoMusical.AindaNaoSabemosTocar and
                               not StatusPedidoMusical.CanceladoPeloPublico)
            .GroupBy(item => item.PublicoId!.Value)
            .ToDictionary(grupo => grupo.Key, grupo => grupo.ToArray());
        var participantes = _participacoesResenha.Values
            .Where(item => item.ApresentacaoId == apresentacaoId)
            .Select(item => item.PublicoId)
            .Concat(pedidos.Keys)
            .Distinct();

        var resumos = participantes
            .Select(publicoId => CriarResumoDoParticipante(
                apresentacaoId, publicoId,
                pedidos.GetValueOrDefault(publicoId) ?? []))
            .ToList();
        if (_perfil is not null)
            resumos.Add(new ParticipanteDaResenha(
                _perfil.Id,
                _perfil.NomeArtistico,
                _perfil.FotoUrl,
                0,
                0,
                null,
                [],
                true));

        return resumos
            .OrderByDescending(item => item.PedidosTocados)
            .ThenByDescending(item => item.Pedidos)
            .ThenByDescending(item => item.EhArtista)
            .ThenBy(item => item.Nome)
            .ToArray();
    }

    public IReadOnlyCollection<ParticipanteDaResenha> ListarParticipantesDaResenha(
        string codigo, string token)
    {
        var apresentacao = ObterApresentacaoPublica(codigo)
            ?? throw new ApresentacaoNaoEncontradaException();
        _ = ObterRegistroPublico(token)
            ?? throw new IdentificacaoPublicaObrigatoriaException();
        return ListarParticipantesDaResenha(apresentacao.Id);
    }

    private ParticipanteDaResenha CriarResumoDoParticipante(
        Guid apresentacaoId, Guid publicoId, PedidoMusical[] pedidos)
    {
        var perfil = _perfisPublicos.GetValueOrDefault(publicoId);
        var avaliacoes = _avaliacoes.Values
            .Where(item => item.PublicoId == publicoId &&
                           _pedidos.GetValueOrDefault(item.PedidoId)?.ApresentacaoId ==
                           apresentacaoId)
            .OrderByDescending(item => item.AvaliadoEm)
            .Select(item => new AvaliacaoNaResenha(
                _pedidos[item.PedidoId].Musica, item.Estrelas, item.AvaliadoEm))
            .ToArray();
        return new ParticipanteDaResenha(
            publicoId,
            perfil?.Nome ?? pedidos.FirstOrDefault()?.NomeSolicitante ?? "Participante",
            perfil?.FotoUrl,
            pedidos.Length,
            pedidos.Count(item => item.Status == StatusPedidoMusical.Finalizado),
            avaliacoes.Length == 0 ? null : Math.Round(avaliacoes.Average(item => item.Estrelas), 1),
            AgruparMusicas(pedidos),
            Avaliacoes: avaliacoes,
            EstatisticasGerais: CalcularEstatisticasGerais(publicoId));
    }
}
