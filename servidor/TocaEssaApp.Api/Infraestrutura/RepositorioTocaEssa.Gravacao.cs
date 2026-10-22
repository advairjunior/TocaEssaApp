using System.Collections.Concurrent;
using System.Security.Cryptography;
using System.Text.Json;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using TocaEssaApp.Api.Dominio;

namespace TocaEssaApp.Api.Infraestrutura;

// Gravação do estado no banco, só do que mudou.
public sealed partial class RepositorioTocaEssa
{
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
            (typeof(CifraEmTextoRegistro), banco => banco.CifrasEmTexto.AsNoTracking()),
            (typeof(EnvioDoPublicoRegistro), banco => banco.EnviosDoPublico.AsNoTracking()),
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
        {
            var registro = new ApresentacaoRegistro
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
            };
            EscreverRelogio(registro);
            EscreverLouvor(registro);
            return registro;
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
            _cifrasEmTexto.Values,
            _enviosDoPublico.Values,
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
}
