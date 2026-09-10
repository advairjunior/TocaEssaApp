using System.Collections.Concurrent;
using System.Security.Cryptography;
using System.Text.Json;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using TocaEssaApp.Api.Dominio;

namespace TocaEssaApp.Api.Infraestrutura;

public sealed partial class RepositorioTocaEssa
{
    private void NormalizarFila(Guid apresentacaoId)
    {
        var fila = _pedidos.Values
            .Where(item => item.ApresentacaoId == apresentacaoId &&
                           item.Status == StatusPedidoMusical.Aceito)
            .OrderBy(item => item.Posicao ?? int.MaxValue)
            .ThenBy(item => item.CriadoEm)
            .ToArray();
        for (var indice = 0; indice < fila.Length; indice++)
            _pedidos[fila[indice].Id] = fila[indice] with { Posicao = indice + 1 };
    }

    private void CarregarEstado()
    {
        if (_caminhoBanco is null)
        {
            _notificador?.Publicar(_apresentacoes.Keys);
            return;
        }
        var pasta = _usaPostgres ? null : Path.GetDirectoryName(_caminhoBanco);
        if (!string.IsNullOrWhiteSpace(pasta)) Directory.CreateDirectory(pasta);

        using var banco = new BancoTocaEssa(_caminhoBanco);
        banco.GarantirEstrutura();

        var perfil = banco.Perfis.AsNoTracking().SingleOrDefault();
        if (perfil is not null)
            _perfil = new PerfilArtistico(
                perfil.Id, perfil.NomeArtistico, perfil.Bio, perfil.FotoUrl);

        if (_perfil is not null)
            foreach (var apresentacao in banco.Apresentacoes.AsNoTracking())
                _apresentacoes[apresentacao.Codigo] = new Apresentacao(
                    apresentacao.Id,
                    apresentacao.Nome,
                    apresentacao.Data,
                    apresentacao.Local,
                    apresentacao.Codigo,
                    _perfil,
                    apresentacao.PedidosAbertos,
                    apresentacao.Status,
                    apresentacao.Tipo,
                    apresentacao.FotoRetrospectivaUrl);

        foreach (var pedido in banco.Pedidos.AsNoTracking())
            if (Enum.IsDefined(pedido.Status))
                _pedidos[pedido.Id] = new PedidoMusical(
                    pedido.Id,
                    pedido.ApresentacaoId,
                    pedido.Musica,
                    pedido.Artista,
                    pedido.NomeSolicitante,
                    pedido.Status,
                    pedido.Posicao,
                    pedido.CriadoEm,
                    pedido.PublicoId,
                    pedido.Avaliacao,
                    Enum.IsDefined(pedido.FormaParticipacao)
                        ? pedido.FormaParticipacao
                        : FormaParticipacaoPedido.PedidoNormal,
                    pedido.TomPreferido,
                    pedido.Recado,
                    Enum.IsDefined(pedido.Tipo) ? pedido.Tipo : TipoPedido.Musica,
                    pedido.DestinatarioAlo);

        foreach (var avaliacao in banco.Avaliacoes.AsNoTracking())
            _avaliacoes[(avaliacao.PedidoId, avaliacao.IdentificadorAvaliador)] = avaliacao;

        foreach (var pedido in _pedidos.Values.Where(item => item.Avaliacao.HasValue))
        {
            var identificador = pedido.PublicoId is { } publicoId
                ? $"perfil:{publicoId:N}"
                : $"legado:{pedido.Id:N}";
            _avaliacoes.TryAdd((pedido.Id, identificador), new AvaliacaoPedidoRegistro
            {
                PedidoId = pedido.Id,
                IdentificadorAvaliador = identificador,
                PublicoId = pedido.PublicoId,
                Estrelas = pedido.Avaliacao!.Value,
                AvaliadoEm = pedido.CriadoEm
            });
        }

        foreach (var publico in banco.PerfisPublicos.AsNoTracking())
            _perfisPublicos[publico.Id] = publico;
        foreach (var participacao in banco.ParticipacoesResenha.AsNoTracking())
            _participacoesResenha[(participacao.ApresentacaoId,
                participacao.PublicoId)] = participacao;
        foreach (var sessao in banco.SessoesPublicas.AsNoTracking().AsEnumerable()
                     .Where(item => item.ExpiraEm > DateTimeOffset.UtcNow))
            _sessoesPublicas[sessao.TokenHash] = sessao;
        foreach (var conta in banco.ContasArtistas.AsNoTracking())
            _contasArtistas[conta.Id] = conta;
        foreach (var sessao in banco.SessoesArtistas.AsNoTracking().AsEnumerable()
                     .Where(item => item.ExpiraEm > DateTimeOffset.UtcNow))
            _sessoesArtistas[sessao.TokenHash] = sessao;
        foreach (var cifra in banco.CifrasDoArtista.AsNoTracking())
            _cifrasDoArtista[(cifra.ArtistaId, cifra.MusicaNormalizada,
                cifra.ArtistaNormalizado)] = cifra;

        if (_perfil is not null || _apresentacoes.Count > 0 || _pedidos.Count > 0 ||
            _caminhoJsonLegado is null || !File.Exists(_caminhoJsonLegado))
            return;

        var estado = JsonSerializer.Deserialize<EstadoPersistido>(
            File.ReadAllText(_caminhoJsonLegado));
        if (estado is null) return;
        _perfil = estado.Perfil;
        foreach (var apresentacao in estado.Apresentacoes)
            _apresentacoes[apresentacao.Codigo] = apresentacao;
        foreach (var pedido in estado.Pedidos)
            if (Enum.IsDefined(pedido.Status))
                _pedidos[pedido.Id] = pedido;
        SalvarEstado();
    }

    private void SalvarEstado()
    {
        if (_caminhoBanco is null) return;
        var pasta = _usaPostgres ? null : Path.GetDirectoryName(_caminhoBanco);
        if (!string.IsNullOrWhiteSpace(pasta)) Directory.CreateDirectory(pasta);

        using var banco = new BancoTocaEssa(_caminhoBanco);
        banco.GarantirEstrutura();
        using var transacao = banco.Database.BeginTransaction();

        banco.SessoesPublicas.RemoveRange(banco.SessoesPublicas);
        banco.SessoesArtistas.RemoveRange(banco.SessoesArtistas);
        banco.ParticipacoesResenha.RemoveRange(banco.ParticipacoesResenha);
        banco.Avaliacoes.RemoveRange(banco.Avaliacoes);
        banco.Pedidos.RemoveRange(banco.Pedidos);
        banco.Apresentacoes.RemoveRange(banco.Apresentacoes);
        banco.Perfis.RemoveRange(banco.Perfis);
        banco.PerfisPublicos.RemoveRange(banco.PerfisPublicos);
        banco.ContasArtistas.RemoveRange(banco.ContasArtistas);
        banco.CifrasDoArtista.RemoveRange(banco.CifrasDoArtista);
        banco.SaveChanges();

        if (_perfil is not null)
            banco.Perfis.Add(new PerfilArtisticoRegistro
            {
                Id = _perfil.Id,
                NomeArtistico = _perfil.NomeArtistico,
                Bio = _perfil.Bio,
                FotoUrl = _perfil.FotoUrl
            });

        banco.Apresentacoes.AddRange(_apresentacoes.Values.Select(item =>
            new ApresentacaoRegistro
            {
                Id = item.Id,
                Nome = item.Nome,
                Data = item.Data,
                Local = item.Local,
                Codigo = item.Codigo,
                PedidosAbertos = item.PedidosAbertos,
                Status = item.Status,
                Tipo = item.Tipo,
                FotoRetrospectivaUrl = item.FotoRetrospectivaUrl
            }));

        banco.Pedidos.AddRange(_pedidos.Values.Select(item =>
            new PedidoMusicalRegistro
            {
                Id = item.Id,
                ApresentacaoId = item.ApresentacaoId,
                Musica = item.Musica,
                Artista = item.Artista,
                NomeSolicitante = item.NomeSolicitante,
                Status = item.Status,
                Posicao = item.Posicao,
                CriadoEm = item.CriadoEm,
                PublicoId = item.PublicoId,
                Avaliacao = item.Avaliacao,
                FormaParticipacao = item.FormaParticipacao,
                TomPreferido = item.TomPreferido,
                Recado = item.Recado,
                Tipo = item.Tipo,
                DestinatarioAlo = item.DestinatarioAlo
            }));

        banco.Avaliacoes.AddRange(_avaliacoes.Values);
        banco.PerfisPublicos.AddRange(_perfisPublicos.Values);
        banco.ParticipacoesResenha.AddRange(_participacoesResenha.Values);
        banco.SessoesPublicas.AddRange(_sessoesPublicas.Values
            .Where(item => item.ExpiraEm > DateTimeOffset.UtcNow));
        banco.ContasArtistas.AddRange(_contasArtistas.Values);
        banco.CifrasDoArtista.AddRange(_cifrasDoArtista.Values);
        banco.SessoesArtistas.AddRange(_sessoesArtistas.Values
            .Where(item => item.ExpiraEm > DateTimeOffset.UtcNow));

        banco.SaveChanges();
        transacao.Commit();
        _notificador?.Publicar(_apresentacoes.Keys);
    }

    private SessaoDoPublico CriarSessao(PerfilPublicoRegistro registro)
    {
        var token = Convert.ToHexString(RandomNumberGenerator.GetBytes(32));
        var tokenHash = GerarHashToken(token);
        _sessoesPublicas[tokenHash] = new SessaoPublicoRegistro
        {
            TokenHash = tokenHash,
            PublicoId = registro.Id,
            ExpiraEm = DateTimeOffset.UtcNow.AddDays(90)
        };
        return new SessaoDoPublico(ParaDominio(registro), token);
    }

    private SessaoDoArtista CriarSessaoArtista(ContaArtistaRegistro registro)
    {
        var token = Convert.ToHexString(RandomNumberGenerator.GetBytes(32));
        var tokenHash = GerarHashToken(token);
        _sessoesArtistas[tokenHash] = new SessaoArtistaRegistro
        {
            TokenHash = tokenHash,
            ArtistaId = registro.Id,
            ExpiraEm = DateTimeOffset.UtcNow.AddDays(90)
        };
        return new SessaoDoArtista(ParaDominio(registro), token);
    }

    private ContaArtistaRegistro? ObterRegistroArtista(string? token)
    {
        if (string.IsNullOrWhiteSpace(token)) return null;
        var hash = GerarHashToken(token);
        if (!_sessoesArtistas.TryGetValue(hash, out var sessao) ||
            sessao.ExpiraEm <= DateTimeOffset.UtcNow)
            return null;
        return _contasArtistas.GetValueOrDefault(sessao.ArtistaId);
    }

    private PerfilPublicoRegistro? ObterRegistroPublico(string? token)
    {
        if (string.IsNullOrWhiteSpace(token)) return null;
        var hash = GerarHashToken(token);
        if (!_sessoesPublicas.TryGetValue(hash, out var sessao) ||
            sessao.ExpiraEm <= DateTimeOffset.UtcNow)
            return null;
        return _perfisPublicos.GetValueOrDefault(sessao.PublicoId);
    }

    private static PerfilPublico ParaDominio(PerfilPublicoRegistro registro) =>
        new(registro.Id, registro.Nome, registro.Email, registro.FotoUrl, registro.CriadoEm);

    private static ContaArtista ParaDominio(ContaArtistaRegistro registro) =>
        new(registro.Id, registro.Nome, registro.Email, registro.CriadoEm);

    private static string NormalizarEmail(string email) =>
        email.Trim().ToUpperInvariant();

    private static string GerarHashToken(string token) =>
        Convert.ToHexString(SHA256.HashData(System.Text.Encoding.UTF8.GetBytes(token)));

    private static IReadOnlyCollection<MusicaMaisPedida> AgruparMusicas(
        IEnumerable<PedidoMusical> pedidos) => pedidos
        .Where(item => !string.IsNullOrWhiteSpace(item.Musica))
        .GroupBy(item => item.Musica.Trim(), StringComparer.OrdinalIgnoreCase)
        .OrderByDescending(grupo => grupo.Count())
        .ThenBy(grupo => grupo.Key)
        .Take(5)
        .Select(grupo => new MusicaMaisPedida(grupo.First().Musica.Trim(), grupo.Count()))
        .ToArray();
}
