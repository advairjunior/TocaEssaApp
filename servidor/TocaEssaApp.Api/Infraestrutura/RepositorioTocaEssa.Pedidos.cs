using System.Collections.Concurrent;
using System.Security.Cryptography;
using System.Text.Json;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using TocaEssaApp.Api.Dominio;

namespace TocaEssaApp.Api.Infraestrutura;

public sealed partial class RepositorioTocaEssa
{
    public PedidoMusical CriarPedido(
        string codigo,
        string musica,
        string? artista,
        string? nomeSolicitante,
        string? tokenPublico = null)
    {
        lock (_sincronizacao)
        {
            var apresentacao = ObterApresentacaoPublica(codigo)
                ?? throw new ApresentacaoNaoEncontradaException();
            if (!apresentacao.PedidosAbertos || apresentacao.Status == StatusApresentacao.Encerrada)
                throw new PedidosEncerradosException();
            var perfilPublico = ObterRegistroPublico(tokenPublico);
            if (apresentacao.Tipo == TipoApresentacao.ResenhaEntreAmigos && perfilPublico is null)
                throw new IdentificacaoPublicaObrigatoriaException();
            var pedido = new PedidoMusical(
                Guid.NewGuid(), apresentacao.Id, musica, artista,
                perfilPublico?.Nome ?? nomeSolicitante,
                StatusPedidoMusical.Aguardando, null, DateTimeOffset.UtcNow,
                perfilPublico?.Id);
            _pedidos[pedido.Id] = pedido;
            SalvarEstado();
            return pedido;
        }
    }

    public IReadOnlyCollection<PedidoMusical> ListarPedidosDoArtista(Guid apresentacaoId) =>
        _pedidos.Values
            .Where(item => item.ApresentacaoId == apresentacaoId)
            .OrderBy(item => item.Posicao ?? int.MaxValue)
            .ThenBy(item => item.CriadoEm)
            .ToArray();

    public EstatisticasDaApresentacao ObterEstatisticasDaApresentacao(
        Guid apresentacaoId)
    {
        if (!_apresentacoes.Values.Any(item => item.Id == apresentacaoId))
            throw new ApresentacaoNaoEncontradaException();
        var pedidos = _pedidos.Values
            .Where(item => item.ApresentacaoId == apresentacaoId &&
                           item.Status != StatusPedidoMusical.CanceladoPeloPublico)
            .ToArray();
        var avaliacoes = pedidos
            .Where(item => item.Avaliacao.HasValue)
            .Select(item => item.Avaliacao!.Value)
            .ToArray();
        return new EstatisticasDaApresentacao(
            pedidos.Length,
            pedidos.Count(item => item.Status == StatusPedidoMusical.Aguardando),
            pedidos.Count(item => item.Status is StatusPedidoMusical.Aceito or
                StatusPedidoMusical.TocandoAgora or StatusPedidoMusical.Finalizado),
            pedidos.Count(item => item.Status == StatusPedidoMusical.Finalizado),
            pedidos.Count(item => item.Status is StatusPedidoMusical.NaoConhecemos or
                StatusPedidoMusical.AindaNaoSabemosTocar),
            avaliacoes.Length,
            avaliacoes.Length == 0 ? null : Math.Round(avaliacoes.Average(), 1),
            AgruparMusicas(pedidos));
    }

    public EstatisticasDoPublico ObterEstatisticasDoPublico(string token)
    {
        var publico = ObterRegistroPublico(token)
            ?? throw new SessaoPublicaInvalidaException();
        var idsResenhas = _apresentacoes.Values
            .Where(item => item.Tipo == TipoApresentacao.ResenhaEntreAmigos)
            .Select(item => item.Id)
            .ToHashSet();
        var pedidos = _pedidos.Values
            .Where(item => item.PublicoId == publico.Id &&
                           idsResenhas.Contains(item.ApresentacaoId) &&
                           item.Status != StatusPedidoMusical.CanceladoPeloPublico)
            .ToArray();
        var avaliacoes = pedidos
            .Where(item => item.Avaliacao.HasValue)
            .Select(item => item.Avaliacao!.Value)
            .ToArray();
        return new EstatisticasDoPublico(
            pedidos.Select(item => item.ApresentacaoId).Distinct().Count(),
            pedidos.Length,
            pedidos.Count(item => item.Status == StatusPedidoMusical.Finalizado),
            avaliacoes.Length,
            avaliacoes.Length == 0 ? null : Math.Round(avaliacoes.Average(), 1),
            AgruparMusicas(pedidos));
    }

    public IReadOnlyCollection<ParticipanteDaResenha> ListarParticipantesDaResenha(
        Guid apresentacaoId)
    {
        var apresentacao = _apresentacoes.Values.SingleOrDefault(
            item => item.Id == apresentacaoId)
            ?? throw new ApresentacaoNaoEncontradaException();
        if (apresentacao.Tipo != TipoApresentacao.ResenhaEntreAmigos)
            throw new RecursoDisponivelSomenteNaResenhaException();

        return _pedidos.Values
            .Where(item => item.ApresentacaoId == apresentacaoId &&
                           item.PublicoId.HasValue &&
                           item.Status is not StatusPedidoMusical.NaoConhecemos and
                               not StatusPedidoMusical.AindaNaoSabemosTocar and
                               not StatusPedidoMusical.CanceladoPeloPublico)
            .GroupBy(item => item.PublicoId!.Value)
            .Select(grupo =>
            {
                var perfil = _perfisPublicos.GetValueOrDefault(grupo.Key);
                var avaliacoes = grupo.Where(item => item.Avaliacao.HasValue)
                    .Select(item => item.Avaliacao!.Value)
                    .ToArray();
                return new ParticipanteDaResenha(
                    grupo.Key,
                    perfil?.Nome ?? grupo.First().NomeSolicitante ?? "Participante",
                    perfil?.FotoUrl,
                    grupo.Count(),
                    grupo.Count(item => item.Status == StatusPedidoMusical.Finalizado),
                    avaliacoes.Length == 0 ? null : Math.Round(avaliacoes.Average(), 1),
                    AgruparMusicas(grupo));
            })
            .OrderByDescending(item => item.PedidosTocados)
            .ThenByDescending(item => item.Pedidos)
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

    public IReadOnlyCollection<PedidoMusical> ListarFilaPublica(string codigo)
    {
        var apresentacao = ObterApresentacaoPublica(codigo)
            ?? throw new ApresentacaoNaoEncontradaException();
        var visiveis = new[]
        {
            StatusPedidoMusical.Aceito, StatusPedidoMusical.TocandoAgora,
            StatusPedidoMusical.Finalizado
        };
        return ListarPedidosDoArtista(apresentacao.Id)
            .Where(item => visiveis.Contains(item.Status))
            .ToArray();
    }

    public IReadOnlyCollection<PedidoMusical> ListarPedidosDoPublico(
        string codigo, string token)
    {
        var apresentacao = ObterApresentacaoPublica(codigo)
            ?? throw new ApresentacaoNaoEncontradaException();
        var publico = ObterRegistroPublico(token)
            ?? throw new SessaoPublicaInvalidaException();
        return _pedidos.Values
            .Where(item => item.ApresentacaoId == apresentacao.Id &&
                           item.PublicoId == publico.Id)
            .OrderByDescending(item => item.CriadoEm)
            .ToArray();
    }

    public PedidoMusical? ObterPedidoPublico(
        string codigo, Guid pedidoId, string? tokenPublico = null)
    {
        var apresentacao = ObterApresentacaoPublica(codigo)
            ?? throw new ApresentacaoNaoEncontradaException();
        if (!_pedidos.TryGetValue(pedidoId, out var pedido) ||
            pedido.ApresentacaoId != apresentacao.Id)
            return null;
        if (apresentacao.Tipo == TipoApresentacao.ResenhaEntreAmigos &&
            pedido.PublicoId != ObterRegistroPublico(tokenPublico)?.Id)
            throw new SessaoPublicaInvalidaException();
        return pedido;
    }

    public PedidoMusical CancelarPedidoPeloPublico(
        string codigo, Guid pedidoId, string? tokenPublico = null)
    {
        lock (_sincronizacao)
        {
            var apresentacao = ObterApresentacaoPublica(codigo)
                ?? throw new ApresentacaoNaoEncontradaException();
            if (!_pedidos.TryGetValue(pedidoId, out var pedido) ||
                pedido.ApresentacaoId != apresentacao.Id)
                throw new PedidoMusicalNaoEncontradoException();
            if (apresentacao.Tipo == TipoApresentacao.ResenhaEntreAmigos &&
                pedido.PublicoId != ObterRegistroPublico(tokenPublico)?.Id)
                throw new SessaoPublicaInvalidaException();
            if (pedido.Status != StatusPedidoMusical.Aguardando)
                throw new PedidoMusicalNaoPodeSerCanceladoException();

            var cancelado = pedido with
            {
                Status = StatusPedidoMusical.CanceladoPeloPublico,
                Posicao = null
            };
            _pedidos[pedidoId] = cancelado;
            SalvarEstado();
            return cancelado;
        }
    }

    public PedidoMusical AvaliarPedidoPeloPublico(
        string codigo, Guid pedidoId, int estrelas, string? tokenPublico = null)
    {
        lock (_sincronizacao)
        {
            if (estrelas is < 1 or > 5) throw new AvaliacaoInvalidaException();
            var apresentacao = ObterApresentacaoPublica(codigo)
                ?? throw new ApresentacaoNaoEncontradaException();
            if (!_pedidos.TryGetValue(pedidoId, out var pedido) ||
                pedido.ApresentacaoId != apresentacao.Id)
                throw new PedidoMusicalNaoEncontradoException();
            if (apresentacao.Tipo == TipoApresentacao.ResenhaEntreAmigos &&
                pedido.PublicoId != ObterRegistroPublico(tokenPublico)?.Id)
                throw new SessaoPublicaInvalidaException();
            if (pedido.Status != StatusPedidoMusical.Finalizado)
                throw new PedidoAindaNaoTocadoException();

            var avaliado = pedido with { Avaliacao = estrelas };
            _pedidos[pedidoId] = avaliado;
            SalvarEstado();
            return avaliado;
        }
    }

    public PedidoMusical AlterarStatus(Guid apresentacaoId, Guid pedidoId, StatusPedidoMusical status)
    {
        lock (_sincronizacao)
        {
            if (!_pedidos.TryGetValue(pedidoId, out var pedido) || pedido.ApresentacaoId != apresentacaoId)
                throw new PedidoMusicalNaoEncontradoException();

            var posicao = pedido.Posicao;
            if (status == StatusPedidoMusical.Aceito && posicao is null)
            {
                posicao = _pedidos.Values
                    .Where(item => item.ApresentacaoId == apresentacaoId &&
                                   item.Status == StatusPedidoMusical.Aceito && item.Posicao.HasValue)
                    .Select(item => item.Posicao!.Value)
                    .DefaultIfEmpty(0)
                    .Max() + 1;
            }
            else if (status != StatusPedidoMusical.Aceito)
            {
                posicao = null;
            }

            if (status == StatusPedidoMusical.TocandoAgora)
            {
                foreach (var tocando in _pedidos.Values.Where(item =>
                             item.ApresentacaoId == apresentacaoId &&
                             item.Id != pedidoId &&
                             item.Status == StatusPedidoMusical.TocandoAgora))
                    _pedidos[tocando.Id] = tocando with
                    {
                        Status = StatusPedidoMusical.Finalizado,
                        Posicao = null
                    };
            }

            var atualizado = pedido with { Status = status, Posicao = posicao };
            _pedidos[pedidoId] = atualizado;
            NormalizarFila(apresentacaoId);
            SalvarEstado();
            return _pedidos[pedidoId];
        }
    }

    public Apresentacao AlterarPedidos(Guid apresentacaoId, bool abertos)
    {
        lock (_sincronizacao)
        {
            var item = _apresentacoes.FirstOrDefault(par => par.Value.Id == apresentacaoId);
            if (item.Value is null) throw new ApresentacaoNaoEncontradaException();
            if (abertos && item.Value.Status == StatusApresentacao.Encerrada)
                throw new PedidosEncerradosException();
            var atualizada = item.Value with { PedidosAbertos = abertos };
            _apresentacoes[item.Key] = atualizada;
            SalvarEstado();
            return atualizada;
        }
    }

    public IReadOnlyCollection<PedidoMusical> ReordenarFila(
        Guid apresentacaoId, IReadOnlyList<Guid> pedidos)
    {
        lock (_sincronizacao)
        {
            var filaAtual = _pedidos.Values
                .Where(item => item.ApresentacaoId == apresentacaoId && item.Status == StatusPedidoMusical.Aceito)
                .ToDictionary(item => item.Id);
            if (pedidos.Count != filaAtual.Count || pedidos.Distinct().Count() != pedidos.Count ||
                pedidos.Any(id => !filaAtual.ContainsKey(id)))
                throw new FilaMusicalInvalidaException();

            for (var indice = 0; indice < pedidos.Count; indice++)
            {
                var pedido = filaAtual[pedidos[indice]] with { Posicao = indice + 1 };
                _pedidos[pedido.Id] = pedido;
            }
            SalvarEstado();
            return ListarPedidosDoArtista(apresentacaoId);
        }
    }

}

