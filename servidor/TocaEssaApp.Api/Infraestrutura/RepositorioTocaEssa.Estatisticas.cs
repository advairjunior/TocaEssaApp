using System.Collections.Concurrent;
using System.Security.Cryptography;
using System.Text.Json;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using TocaEssaApp.Api.Dominio;

namespace TocaEssaApp.Api.Infraestrutura;

// Estatísticas da apresentação e do público.
public sealed partial class RepositorioTocaEssa
{
    internal EstatisticasDaApresentacao ObterEstatisticasDaApresentacao(
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
        var (pessoasNoEvento, pessoasQuePediram) = ContarPublicoDoEvento(apresentacaoId);
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
            AgruparMusicas(pedidos),
            pessoasNoEvento,
            pessoasQuePediram,
            AgruparMusicas(pedidos.Where(item => item.Status is
                StatusPedidoMusical.NaoConhecemos or
                StatusPedidoMusical.AindaNaoSabemosTocar)),
            MontarRetrospectiva(apresentacaoId));
    }

    public EstatisticasDaApresentacao ObterEstatisticasDaApresentacao(
        string token, Guid apresentacaoId)
    {
        _ = ObterApresentacaoDoArtista(token, apresentacaoId);
        return ObterEstatisticasDaApresentacao(apresentacaoId);
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
}
