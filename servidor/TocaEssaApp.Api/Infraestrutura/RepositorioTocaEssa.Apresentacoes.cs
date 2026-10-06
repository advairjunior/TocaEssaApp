using System.Collections.Concurrent;
using System.Security.Cryptography;
using System.Text.Json;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using TocaEssaApp.Api.Dominio;

namespace TocaEssaApp.Api.Infraestrutura;

public sealed partial class RepositorioTocaEssa
{
    internal IReadOnlyCollection<Apresentacao> ListarApresentacoes() =>
        _apresentacoes.Values.OrderByDescending(item => item.Data).ToArray();

    public IReadOnlyCollection<Apresentacao> ListarApresentacoes(string token)
    {
        var conta = ExigirRegistroArtista(token);
        return _apresentacoes.Values
            .Where(item => item.ArtistaId == conta.Id)
            .OrderByDescending(item => item.Data)
            .ToArray();
    }

    public Apresentacao CriarApresentacao(
        string token, string nome, DateOnly data, string local,
        TipoApresentacao tipo = TipoApresentacao.Publica)
    {
        var conta = ExigirRegistroArtista(token);
        var perfil = _configuracoesPerfis.GetValueOrDefault(conta.Id)?.Perfil
            ?? throw new PerfilArtisticoNaoCadastradoException();
        return CriarApresentacaoDoArtista(
            conta.Id, perfil, nome, data, local, tipo);
    }

    internal Apresentacao CriarApresentacao(
        string nome, DateOnly data, string local,
        TipoApresentacao tipo = TipoApresentacao.Publica)
    {
        var artistaId = _contasArtistas.Count == 1
            ? _contasArtistas.Keys.Single()
            : Guid.Empty;
        return CriarApresentacaoDoArtista(
            artistaId, _perfil ?? throw new PerfilArtisticoNaoCadastradoException(),
            nome, data, local, tipo);
    }

    private Apresentacao CriarApresentacaoDoArtista(
        Guid artistaId, PerfilArtistico perfil, string nome, DateOnly data,
        string local, TipoApresentacao tipo)
    {
        lock (_sincronizacao)
        {
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
                Guid.NewGuid(), nome, data, local, codigo, perfil, Tipo: tipo,
                ArtistaId: artistaId);
            _apresentacoes[codigo] = apresentacao;
            SalvarEstado();
            return apresentacao;
        }
    }

    public Apresentacao? ObterApresentacaoPublica(string codigo) =>
        _apresentacoes.GetValueOrDefault(codigo.Trim().ToUpperInvariant());

    internal Apresentacao? ObterApresentacao(Guid apresentacaoId) =>
        _apresentacoes.Values.SingleOrDefault(item => item.Id == apresentacaoId);

    public Apresentacao ObterApresentacaoDoArtista(
        string token, Guid apresentacaoId)
    {
        var conta = ExigirRegistroArtista(token);
        return ObterItemApresentacao(apresentacaoId, conta.Id).Value;
    }

    public Apresentacao AtualizarFotoRetrospectiva(
        string token, Guid apresentacaoId, string fotoUrl)
    {
        var conta = ExigirRegistroArtista(token);
        return AtualizarFotoRetrospectiva(apresentacaoId, fotoUrl, conta.Id);
    }

    internal Apresentacao AtualizarFotoRetrospectiva(
        Guid apresentacaoId, string fotoUrl)
        => AtualizarFotoRetrospectiva(apresentacaoId, fotoUrl, null);

    private Apresentacao AtualizarFotoRetrospectiva(
        Guid apresentacaoId, string fotoUrl, Guid? artistaId)
    {
        lock (_sincronizacao)
        {
            var item = ObterItemApresentacao(apresentacaoId, artistaId);
            var atualizada = item.Value with { FotoRetrospectivaUrl = fotoUrl };
            _apresentacoes[item.Key] = atualizada;
            SalvarEstado();
            return atualizada;
        }
    }

    public Apresentacao EditarApresentacao(
        string token, Guid apresentacaoId, string nome, DateOnly data, string local,
        TipoApresentacao tipo = TipoApresentacao.Publica)
    {
        var conta = ExigirRegistroArtista(token);
        return EditarApresentacao(
            apresentacaoId, nome, data, local, tipo, conta.Id);
    }

    internal Apresentacao EditarApresentacao(
        Guid apresentacaoId, string nome, DateOnly data, string local,
        TipoApresentacao tipo = TipoApresentacao.Publica)
        => EditarApresentacao(apresentacaoId, nome, data, local, tipo, null);

    private Apresentacao EditarApresentacao(
        Guid apresentacaoId, string nome, DateOnly data, string local,
        TipoApresentacao tipo, Guid? artistaId)
    {
        lock (_sincronizacao)
        {
            var item = ObterItemApresentacao(apresentacaoId, artistaId);
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

    internal void ExcluirApresentacao(Guid apresentacaoId)
        => ExcluirApresentacao(apresentacaoId, null);

    public void ExcluirApresentacao(string token, Guid apresentacaoId)
    {
        var conta = ExigirRegistroArtista(token);
        ExcluirApresentacao(apresentacaoId, conta.Id);
    }

    private void ExcluirApresentacao(Guid apresentacaoId, Guid? artistaId)
    {
        lock (_sincronizacao)
        {
            var item = ObterItemApresentacao(apresentacaoId, artistaId);
            _apresentacoes.TryRemove(item.Key, out _);
            foreach (var pedido in _pedidos.Values
                         .Where(pedido => pedido.ApresentacaoId == apresentacaoId)
                         .ToArray())
            {
                foreach (var chaveAvaliacao in _avaliacoes.Keys
                             .Where(chave => chave.PedidoId == pedido.Id).ToArray())
                    _avaliacoes.TryRemove(chaveAvaliacao, out _);
                _pedidos.TryRemove(pedido.Id, out _);
            }
            foreach (var participacao in _participacoesResenha.Keys
                         .Where(chave => chave.ApresentacaoId == apresentacaoId)
                         .ToArray())
                _participacoesResenha.TryRemove(participacao, out _);
            foreach (var acesso in _acessosAoEvento.Keys
                         .Where(chave => chave.ApresentacaoId == apresentacaoId)
                         .ToArray())
                _acessosAoEvento.TryRemove(acesso, out _);
            SalvarEstado();
            _notificador?.Publicar(item.Key);
        }
    }

    internal Apresentacao AlterarStatusApresentacao(Guid apresentacaoId, StatusApresentacao status)
        => AlterarStatusApresentacao(apresentacaoId, status, null);

    public Apresentacao AlterarStatusApresentacao(
        string token, Guid apresentacaoId, StatusApresentacao status)
    {
        var conta = ExigirRegistroArtista(token);
        return AlterarStatusApresentacao(apresentacaoId, status, conta.Id);
    }

    private Apresentacao AlterarStatusApresentacao(
        Guid apresentacaoId, StatusApresentacao status, Guid? artistaId)
    {
        lock (_sincronizacao)
        {
            var item = ObterItemApresentacao(apresentacaoId, artistaId);
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

    private KeyValuePair<string, Apresentacao> ObterItemApresentacao(
        Guid apresentacaoId, Guid? artistaId)
    {
        var item = _apresentacoes.FirstOrDefault(par =>
            par.Value.Id == apresentacaoId &&
            (artistaId is null || par.Value.ArtistaId == artistaId));
        return item.Value is null
            ? throw new ApresentacaoNaoEncontradaException()
            : item;
    }

}
