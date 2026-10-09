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
        foreach (var r in banco.Repertorios.AsNoTracking())
            _repertorios[r.Id] = r;
        foreach (var m in banco.MusicasDoRepertorio.AsNoTracking())
            _musicasDoRepertorio[m.Id] = m;
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

    private void SalvarEstado()
    {
        if (_caminhoBanco is null) return;
        var pasta = _usaPostgres ? null : Path.GetDirectoryName(_caminhoBanco);
        if (!string.IsNullOrWhiteSpace(pasta)) Directory.CreateDirectory(pasta);

        using var banco = new BancoTocaEssa(_caminhoBanco);
        var gravados = _registrosGravados ?? LerRegistrosGravados(banco);
        var atuais = MontarRegistrosAtuais(banco);
        try
        {
            using var transacao = banco.Database.BeginTransaction();
            foreach (var (tipo, registros) in atuais)
                foreach (var (chave, json) in gravados[tipo])
                    if (!registros.ContainsKey(chave))
                        banco.Remove(JsonSerializer.Deserialize(json, tipo)!);
            banco.SaveChanges();

            foreach (var (tipo, registros) in atuais)
                foreach (var (chave, (registro, json)) in registros)
                {
                    if (!gravados[tipo].TryGetValue(chave, out var jsonGravado))
                        banco.Add(registro);
                    else if (jsonGravado != json)
                        banco.Update(registro);
                }
            banco.SaveChanges();
            transacao.Commit();
        }
        catch
        {
            _registrosGravados = null;
            throw;
        }

        _registrosGravados = atuais.ToDictionary(
            tabela => tabela.Key,
            tabela => tabela.Value.ToDictionary(
                registro => registro.Key, registro => registro.Value.Json));
        _notificador?.Publicar(_apresentacoes.Keys);
    }

    private static readonly IReadOnlyList<(Type Tipo, Func<BancoTocaEssa, IEnumerable<object>> Ler)>
        TabelasPersistidas =
        [
            (typeof(PerfilArtisticoRegistro), banco => banco.Perfis.AsNoTracking()),
            (typeof(ApresentacaoRegistro), banco => banco.Apresentacoes.AsNoTracking()),
            (typeof(PedidoMusicalRegistro), banco => banco.Pedidos.AsNoTracking()),
            (typeof(AvaliacaoPedidoRegistro), banco => banco.Avaliacoes.AsNoTracking()),
            (typeof(PerfilPublicoRegistro), banco => banco.PerfisPublicos.AsNoTracking()),
            (typeof(ParticipacaoResenhaRegistro),
                banco => banco.ParticipacoesResenha.AsNoTracking()),
            (typeof(SessaoPublicoRegistro), banco => banco.SessoesPublicas.AsNoTracking()),
            (typeof(ContaArtistaRegistro), banco => banco.ContasArtistas.AsNoTracking()),
            (typeof(CifraDoArtistaRegistro), banco => banco.CifrasDoArtista.AsNoTracking()),
            (typeof(RepertorioRegistro), banco => banco.Repertorios.AsNoTracking()),
            (typeof(MusicaDoRepertorioRegistro),
                banco => banco.MusicasDoRepertorio.AsNoTracking()),
            (typeof(ItemDoSetlistRegistro), banco => banco.ItensDoSetlist.AsNoTracking()),
            (typeof(SessaoArtistaRegistro), banco => banco.SessoesArtistas.AsNoTracking()),
            (typeof(AcessoAoEventoRegistro), banco => banco.AcessosAoEvento.AsNoTracking())
        ];

    private static Dictionary<Type, Dictionary<string, string>> LerRegistrosGravados(
        BancoTocaEssa banco) =>
        TabelasPersistidas.ToDictionary(
            tabela => tabela.Tipo,
            tabela => tabela.Ler(banco).ToDictionary(
                registro => ObterChaveDoRegistro(banco, tabela.Tipo, registro),
                registro => JsonSerializer.Serialize(registro, tabela.Tipo)));

    private static string ObterChaveDoRegistro(BancoTocaEssa banco, Type tipo, object registro) =>
        string.Join("|", banco.Model.FindEntityType(tipo)!.FindPrimaryKey()!.Properties
            .Select(propriedade => propriedade.PropertyInfo!.GetValue(registro)?.ToString()));

    private Dictionary<Type, Dictionary<string, (object Registro, string Json)>>
        MontarRegistrosAtuais(BancoTocaEssa banco)
    {
        var perfis = new List<object>();
        var configuracoes = _configuracoesPerfis.Count > 0
            ? _configuracoesPerfis
            : _configuracaoPerfil is null
                ? new ConcurrentDictionary<Guid, ConfiguracaoPerfilArtistico>()
                : new ConcurrentDictionary<Guid, ConfiguracaoPerfilArtistico>(
                    _contasArtistas.Count == 1
                        ? new[]
                        {
                            new KeyValuePair<Guid, ConfiguracaoPerfilArtistico>(
                                _contasArtistas.Keys.Single(), _configuracaoPerfil)
                        }
                        : []);
        foreach (var (artistaId, configuracao) in configuracoes)
        {
            var perfil = configuracao.Perfil;
            perfis.Add(new PerfilArtisticoRegistro
            {
                Id = perfil.Id,
                ArtistaId = artistaId,
                NomeArtistico = perfil.NomeArtistico,
                Bio = perfil.Bio,
                FotoUrl = perfil.FotoUrl,
                Instagram = configuracao.Instagram,
                ExibirInstagram = configuracao.ExibirInstagram,
                Whatsapp = configuracao.Whatsapp,
                ExibirWhatsapp = configuracao.ExibirWhatsapp,
                PixAtivo = configuracao.PixAtivo,
                PixChave = configuracao.PixChave,
                PixNomeBeneficiario = configuracao.PixNomeBeneficiario,
                PixCidadeBeneficiario = configuracao.PixCidadeBeneficiario,
                PixMensagem = configuracao.PixMensagem
            });
        }

        IEnumerable<object> apresentacoes = _apresentacoes.Values.Select(item =>
            new ApresentacaoRegistro
            {
                Id = item.Id,
                ArtistaId = item.ArtistaId,
                Nome = item.Nome,
                Data = item.Data,
                Local = item.Local,
                Codigo = item.Codigo,
                PedidosAbertos = item.PedidosAbertos,
                Status = item.Status,
                Tipo = item.Tipo,
                FotoRetrospectivaUrl = item.FotoRetrospectivaUrl,
                PedidosASeguir = EscreverPedidosASeguir(item.Id)
            });

        IEnumerable<object> pedidos = _pedidos.Values.Select(item =>
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
            });

        var agora = DateTimeOffset.UtcNow;
        IEnumerable<object>[] registrosPorTabela =
        [
            perfis,
            apresentacoes,
            pedidos,
            _avaliacoes.Values,
            _perfisPublicos.Values,
            _participacoesResenha.Values,
            _sessoesPublicas.Values.Where(item => item.ExpiraEm > agora),
            _contasArtistas.Values,
            _cifrasDoArtista.Values,
            _repertorios.Values,
            _musicasDoRepertorio.Values,
            _itensDoSetlist.Values,
            _sessoesArtistas.Values.Where(item => item.ExpiraEm > agora),
            _acessosAoEvento.Values
        ];
        return TabelasPersistidas
            .Select((tabela, indice) => (tabela.Tipo, Registros: registrosPorTabela[indice]))
            .ToDictionary(
                tabela => tabela.Tipo,
                tabela => tabela.Registros.ToDictionary(
                    registro => ObterChaveDoRegistro(banco, tabela.Tipo, registro),
                    registro => (registro, JsonSerializer.Serialize(registro, tabela.Tipo))));
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

    private static PerfilArtistico ParaPerfilPublico(
        PerfilArtisticoRegistro registro)
    {
        var apoioDisponivel = registro.PixAtivo &&
                              !string.IsNullOrWhiteSpace(registro.PixChave) &&
                              !string.IsNullOrWhiteSpace(registro.PixNomeBeneficiario) &&
                              !string.IsNullOrWhiteSpace(registro.PixCidadeBeneficiario);
        return new PerfilArtistico(
            registro.Id,
            registro.NomeArtistico,
            registro.Bio,
            registro.FotoUrl,
            registro.ExibirInstagram ? registro.Instagram : null,
            registro.ExibirWhatsapp ? registro.Whatsapp : null,
            apoioDisponivel);
    }

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
