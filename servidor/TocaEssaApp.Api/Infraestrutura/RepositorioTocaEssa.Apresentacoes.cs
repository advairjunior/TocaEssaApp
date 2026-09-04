using System.Collections.Concurrent;
using System.Security.Cryptography;
using System.Text.Json;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using TocaEssaApp.Api.Dominio;

namespace TocaEssaApp.Api.Infraestrutura;

public sealed partial class RepositorioTocaEssa
{
    public IReadOnlyCollection<Apresentacao> ListarApresentacoes() =>
        _apresentacoes.Values.OrderByDescending(item => item.Data).ToArray();

    public Apresentacao CriarApresentacao(
        string nome, DateOnly data, string local,
        TipoApresentacao tipo = TipoApresentacao.Publica)
    {
        lock (_sincronizacao)
        {
            var perfil = _perfil ?? throw new PerfilArtisticoNaoCadastradoException();
            string codigo;
            do
            {
                codigo = string.Create(6, Random.Shared, static (destino, aleatorio) =>
                {
                    for (var i = 0; i < destino.Length; i++)
                        destino[i] = CaracteresCodigo[aleatorio.Next(CaracteresCodigo.Length)];
                });
            } while (_apresentacoes.ContainsKey(codigo));

            var apresentacao = new Apresentacao(
                Guid.NewGuid(), nome, data, local, codigo, perfil, Tipo: tipo);
            _apresentacoes[codigo] = apresentacao;
            SalvarEstado();
            return apresentacao;
        }
    }

    public Apresentacao? ObterApresentacaoPublica(string codigo) =>
        _apresentacoes.GetValueOrDefault(codigo.Trim().ToUpperInvariant());

    public Apresentacao? ObterApresentacao(Guid apresentacaoId) =>
        _apresentacoes.Values.SingleOrDefault(item => item.Id == apresentacaoId);

    public Apresentacao AtualizarFotoRetrospectiva(
        Guid apresentacaoId, string fotoUrl)
    {
        lock (_sincronizacao)
        {
            var item = _apresentacoes.FirstOrDefault(
                par => par.Value.Id == apresentacaoId);
            if (item.Value is null) throw new ApresentacaoNaoEncontradaException();
            if (item.Value.Tipo != TipoApresentacao.ResenhaEntreAmigos)
                throw new RecursoDisponivelSomenteNaResenhaException();
            var atualizada = item.Value with { FotoRetrospectivaUrl = fotoUrl };
            _apresentacoes[item.Key] = atualizada;
            SalvarEstado();
            return atualizada;
        }
    }

    public Apresentacao EditarApresentacao(
        Guid apresentacaoId, string nome, DateOnly data, string local,
        TipoApresentacao tipo = TipoApresentacao.Publica)
    {
        lock (_sincronizacao)
        {
            var item = _apresentacoes.FirstOrDefault(par => par.Value.Id == apresentacaoId);
            if (item.Value is null) throw new ApresentacaoNaoEncontradaException();
            var atualizada = item.Value with
            {
                Nome = nome,
                Data = data,
                Local = local,
                Tipo = tipo
            };
            _apresentacoes[item.Key] = atualizada;
            SalvarEstado();
            return atualizada;
        }
    }

    public void ExcluirApresentacao(Guid apresentacaoId)
    {
        lock (_sincronizacao)
        {
            var item = _apresentacoes.FirstOrDefault(par => par.Value.Id == apresentacaoId);
            if (item.Value is null) throw new ApresentacaoNaoEncontradaException();
            _apresentacoes.TryRemove(item.Key, out _);
            foreach (var pedido in _pedidos.Values
                         .Where(pedido => pedido.ApresentacaoId == apresentacaoId)
                         .ToArray())
                _pedidos.TryRemove(pedido.Id, out _);
            SalvarEstado();
            _notificador?.Publicar(item.Key);
        }
    }

    public Apresentacao AlterarStatusApresentacao(Guid apresentacaoId, StatusApresentacao status)
    {
        lock (_sincronizacao)
        {
            var item = _apresentacoes.FirstOrDefault(par => par.Value.Id == apresentacaoId);
            if (item.Value is null) throw new ApresentacaoNaoEncontradaException();
            var pedidosAbertos = status switch
            {
                StatusApresentacao.EmAndamento => true,
                StatusApresentacao.Encerrada => false,
                _ => item.Value.PedidosAbertos
            };
            var atualizada = item.Value with { Status = status, PedidosAbertos = pedidosAbertos };
            _apresentacoes[item.Key] = atualizada;
            SalvarEstado();
            return atualizada;
        }
    }

}
