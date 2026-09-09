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
        string? tokenPublico = null,
        FormaParticipacaoPedido formaParticipacao = FormaParticipacaoPedido.PedidoNormal,
        string? tomPreferido = null,
        string? recado = null,
        TipoPedido tipo = TipoPedido.Musica,
        string? destinatarioAlo = null)
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
            if (apresentacao.Tipo == TipoApresentacao.Publica)
            {
                formaParticipacao = FormaParticipacaoPedido.PedidoNormal;
                tomPreferido = null;
                if (tipo == TipoPedido.Musica) recado = null;
            }
            if (tipo == TipoPedido.Alo)
            {
                destinatarioAlo = Limitar(destinatarioAlo, 120);
                if (destinatarioAlo is null) throw new DestinatarioAloObrigatorioException();
                musica = $"Alô para {destinatarioAlo}";
                artista = null;
                formaParticipacao = FormaParticipacaoPedido.PedidoNormal;
                tomPreferido = null;
            }
            var pedido = new PedidoMusical(
                Guid.NewGuid(), apresentacao.Id, musica, artista,
                perfilPublico?.Nome ?? nomeSolicitante,
                StatusPedidoMusical.Aguardando, null, DateTimeOffset.UtcNow,
                perfilPublico?.Id, null, formaParticipacao,
                Limitar(tomPreferido, 30), Limitar(recado, 240), tipo,
                destinatarioAlo);
            _pedidos[pedido.Id] = pedido;
            SalvarEstado();
            return pedido;
        }
    }

    private static string? Limitar(string? valor, int tamanhoMaximo)
    {
        var normalizado = string.IsNullOrWhiteSpace(valor) ? null : valor.Trim();
        return normalizado is { Length: > 0 } && normalizado.Length > tamanhoMaximo
            ? normalizado[..tamanhoMaximo]
            : normalizado;
    }

    public IReadOnlyCollection<PedidoMusical> ListarPedidosDoArtista(Guid apresentacaoId) =>
        _pedidos.Values
            .Where(item => item.ApresentacaoId == apresentacaoId)
            .OrderBy(item => item.Posicao ?? int.MaxValue)
            .ThenBy(item => item.CriadoEm)
            .Select(item => ComAvaliacoes(item, null))
            .ToArray();

    public EstatisticasDaApresentacao ObterEstatisticasDaApresentacao(
        Guid apresentacaoId)
    {
        if (!_apresentacoes.Values.Any(item => item.Id == apresentacaoId))
            throw new ApresentacaoNaoEncontradaException();
        var pedidos = _pedidos.Values
            .Where(item => item.ApresentacaoId == apresentacaoId &&
                           item.Tipo == TipoPedido.Musica &&
                           item.Status != StatusPedidoMusical.CanceladoPeloPublico)
            .ToArray();
        var idsPedidos = pedidos.Select(item => item.Id).ToHashSet();
        var avaliacoes = _avaliacoes.Values
            .Where(item => idsPedidos.Contains(item.PedidoId))
            .Select(item => item.Estrelas)
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
        return CalcularEstatisticasGerais(publico.Id);
    }

    private EstatisticasDoPublico CalcularEstatisticasGerais(Guid publicoId)
    {
        var pedidos = _pedidos.Values
            .Where(item => item.PublicoId == publicoId &&
                           item.Tipo == TipoPedido.Musica &&
                           item.Status != StatusPedidoMusical.CanceladoPeloPublico)
            .ToArray();
        var avaliacoes = _avaliacoes.Values
            .Where(item => item.PublicoId == publicoId)
            .Select(item => item.Estrelas)
            .ToArray();
        return new EstatisticasDoPublico(
            _participacoesResenha.Values
                .Where(item => item.PublicoId == publicoId)
                .Select(item => item.ApresentacaoId)
                .Concat(pedidos.Select(item => item.ApresentacaoId))
                .Distinct()
                .Count(),
            pedidos.Length,
            pedidos.Count(item => item.Status == StatusPedidoMusical.Finalizado),
            avaliacoes.Length,
            avaliacoes.Length == 0 ? null : Math.Round(avaliacoes.Average(), 1),
            AgruparMusicas(pedidos));
    }

    public IReadOnlyCollection<PedidoMusical> ListarFilaPublica(
        string codigo, string? identificadorAvaliador = null, string? tokenPublico = null)
    {
        var apresentacao = ObterApresentacaoPublica(codigo)
            ?? throw new ApresentacaoNaoEncontradaException();
        var visiveis = new[]
        {
            StatusPedidoMusical.Aceito, StatusPedidoMusical.TocandoAgora,
            StatusPedidoMusical.Finalizado
        };
        var avaliador = IdentificarAvaliador(apresentacao, identificadorAvaliador,
            tokenPublico, exigir: false);
        return PrepararFilaPublica(apresentacao.Id, visiveis, avaliador);
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
