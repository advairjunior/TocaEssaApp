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

        foreach (var conta in banco.ContasArtistas.AsNoTracking())
            _contasArtistas[conta.Id] = conta;

        foreach (var perfil in banco.Perfis.AsNoTracking())
        {
            var perfilPublico = ParaPerfilPublico(perfil);
            var configuracao = new ConfiguracaoPerfilArtistico(
                perfilPublico,
                perfil.Instagram,
                perfil.ExibirInstagram,
                perfil.Whatsapp,
                perfil.ExibirWhatsapp,
                perfil.PixAtivo,
                perfil.PixChave,
                perfil.PixNomeBeneficiario,
                perfil.PixCidadeBeneficiario,
                perfil.PixMensagem);
            _configuracoesPerfis[perfil.ArtistaId] = configuracao;
        }

        if (_configuracoesPerfis.Count == 1)
        {
            _configuracaoPerfil = _configuracoesPerfis.Values.Single();
            _perfil = _configuracaoPerfil.Perfil;
        }

        foreach (var apresentacao in banco.Apresentacoes.AsNoTracking())
        {
            if (!_configuracoesPerfis.TryGetValue(apresentacao.ArtistaId, out var configuracao))
                throw new InvalidOperationException(
                    $"A apresentação {apresentacao.Id} não possui perfil artístico válido.");
            _apresentacoes[apresentacao.Codigo] = new Apresentacao(
                apresentacao.Id,
                apresentacao.Nome,
                apresentacao.Data,
                apresentacao.Local,
                apresentacao.Codigo,
                configuracao.Perfil,
                apresentacao.PedidosAbertos,
                apresentacao.Status,
                apresentacao.Tipo,
                apresentacao.FotoRetrospectivaUrl,
                apresentacao.ArtistaId);
            if (LerPedidosASeguir(apresentacao.PedidosASeguir) is { Count: > 0 } aSeguir)
                _pedidosASeguir[apresentacao.Id] = aSeguir;
            CarregarRelogio(apresentacao);
            CarregarLouvor(apresentacao);
            CarregarKaraoke(apresentacao);
        }

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
        foreach (var acesso in banco.AcessosAoEvento.AsNoTracking())
            _acessosAoEvento[(acesso.ApresentacaoId, acesso.Visitante)] = acesso;
        foreach (var sessao in banco.SessoesPublicas.AsNoTracking().AsEnumerable()
                     .Where(item => item.ExpiraEm > DateTimeOffset.UtcNow))
            _sessoesPublicas[sessao.TokenHash] = sessao;
        foreach (var sessao in banco.SessoesArtistas.AsNoTracking().AsEnumerable()
                     .Where(item => item.ExpiraEm > DateTimeOffset.UtcNow))
            _sessoesArtistas[sessao.TokenHash] = sessao;
        foreach (var cifra in banco.CifrasDoArtista.AsNoTracking())
            _cifrasDoArtista[(cifra.ArtistaId, cifra.MusicaNormalizada,
                cifra.ArtistaNormalizado)] = cifra;
        foreach (var cifra in banco.CifrasEmTexto.AsNoTracking())
            _cifrasEmTexto[(cifra.ArtistaId, cifra.MusicaNormalizada,
                cifra.ArtistaNormalizado)] = cifra;
        foreach (var envio in banco.EnviosDoPublico.AsNoTracking())
            _enviosDoPublico[envio.Id] = envio;
        foreach (var r in banco.Repertorios.AsNoTracking())
            _repertorios[r.Id] = r;
        foreach (var m in banco.MusicasDoRepertorio.AsNoTracking())
            _musicasDoRepertorio[m.Id] = m;
        foreach (var tv in banco.TelasDaTv.AsNoTracking())
            _telasDaTv[tv.Id] = tv;
        foreach (var i in banco.ItensDoSetlist.AsNoTracking())
            _itensDoSetlist[i.Id] = i;

        if (_configuracoesPerfis.Count > 0 || _apresentacoes.Count > 0 || _pedidos.Count > 0 ||
            _caminhoJsonLegado is null || !File.Exists(_caminhoJsonLegado))
            return;

        var estado = JsonSerializer.Deserialize<EstadoPersistido>(
            File.ReadAllText(_caminhoJsonLegado));
        if (estado is null) return;
        if (estado.Perfil is not null)
        {
            var conta = _contasArtistas.Values.SingleOrDefault()
                ?? throw new InvalidOperationException(
                    "Dados artísticos legados exigem exatamente uma conta proprietária.");
            _perfil = estado.Perfil;
            _configuracaoPerfil = new ConfiguracaoPerfilArtistico(
                estado.Perfil, null, false, null, false, false,
                null, null, null, null);
            _configuracoesPerfis[conta.Id] = _configuracaoPerfil;
        }
        foreach (var apresentacao in estado.Apresentacoes)
        {
            var conta = _contasArtistas.Values.SingleOrDefault()
                ?? throw new InvalidOperationException(
                    "Dados artísticos legados exigem exatamente uma conta proprietária.");
            _apresentacoes[apresentacao.Codigo] = apresentacao with { ArtistaId = conta.Id };
        }
        foreach (var pedido in estado.Pedidos)
            if (Enum.IsDefined(pedido.Status))
                _pedidos[pedido.Id] = pedido;
        SalvarEstado();
    }
}
