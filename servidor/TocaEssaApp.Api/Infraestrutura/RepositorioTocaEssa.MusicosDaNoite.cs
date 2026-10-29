using System.Collections.Concurrent;
using System.Security.Cryptography;
using TocaEssaApp.Api.Dominio;

namespace TocaEssaApp.Api.Infraestrutura;

// Músicos convidados para o evento da noite: o dono gera o link, quem abre
// entra no evento (não na conta do dono). Só resenha e louvor: no karaokê
// todos cantam como público.
public sealed partial class RepositorioTocaEssa
{
    private readonly ConcurrentDictionary<(Guid ApresentacaoId, Guid ArtistaId), MusicoDaApresentacaoRegistro>
        _musicosDaApresentacao = new();
    private readonly ConcurrentDictionary<Guid, ConviteDaApresentacaoRegistro> _convitesDaApresentacao = new();

    public string GerarConvite(string token, Guid apresentacaoId)
    {
        var evento = ObterApresentacaoDoArtista(token, apresentacaoId);
        if (!AceitaMusicos(evento.Tipo)) throw new EventoSemConviteDeMusicoException();
        lock (_sincronizacao)
        {
            var convite = new ConviteDaApresentacaoRegistro
            {
                ApresentacaoId = apresentacaoId,
                Codigo = Convert.ToHexString(RandomNumberGenerator.GetBytes(8)),
                CriadoEm = DateTimeOffset.UtcNow
            };
            _convitesDaApresentacao[apresentacaoId] = convite;
            SalvarEstado();
            return convite.Codigo;
        }
    }

    public ConviteDaNoite VerConvite(string token, string codigo)
    {
        _ = ExigirRegistroArtista(token);
        var evento = EventoDoConvite(codigo);
        return new ConviteDaNoite(evento.Id, evento.Nome, NomeDoArtista(evento.ArtistaId), evento.Data);
    }

    public void EntrarPeloConvite(string token, string codigo)
    {
        var conta = ExigirRegistroArtista(token);
        var evento = EventoDoConvite(codigo);
        if (evento.ArtistaId == conta.Id) return;
        lock (_sincronizacao)
        {
            if (!_musicosDaApresentacao.TryAdd((evento.Id, conta.Id), new MusicoDaApresentacaoRegistro
            {
                ApresentacaoId = evento.Id,
                ArtistaId = conta.Id,
                EntrouEm = DateTimeOffset.UtcNow
            })) return;
            SalvarEstado();
        }
    }

    public IReadOnlyList<MusicoDaNoite> ListarMusicos(string token, Guid apresentacaoId)
    {
        var evento = ObterApresentacaoDoArtista(token, apresentacaoId);
        return
        [
            new MusicoDaNoite(evento.ArtistaId, NomeDoArtista(evento.ArtistaId), true),
            .. MusicosDoEvento(apresentacaoId)
                .OrderBy(musico => musico.EntrouEm)
                .Select(musico => new MusicoDaNoite(musico.ArtistaId, NomeDoArtista(musico.ArtistaId), false))
        ];
    }

    /// O dono tira qualquer músico; o convidado só sai ele mesmo.
    public void TirarMusico(string token, Guid apresentacaoId, Guid artistaId)
    {
        var conta = ExigirRegistroArtista(token);
        var evento = ObterApresentacao(apresentacaoId) ?? throw new ApresentacaoNaoEncontradaException();
        var podeTirar = evento.ArtistaId == conta.Id ||
                        (artistaId == conta.Id && _musicosDaApresentacao.ContainsKey((apresentacaoId, conta.Id)));
        if (!podeTirar) throw new ApresentacaoNaoEncontradaException();
        lock (_sincronizacao)
        {
            if (_musicosDaApresentacao.TryRemove((apresentacaoId, artistaId), out _))
                SalvarEstado();
        }
    }

    /// Eventos abertos em que a conta entrou como músico.
    public IReadOnlyList<EventoConvidado> ListarConvites(string token)
    {
        var conta = ExigirRegistroArtista(token);
        return
        [
            .. _musicosDaApresentacao.Values
                .Where(musico => musico.ArtistaId == conta.Id)
                .Select(musico => ObterApresentacao(musico.ApresentacaoId))
                .OfType<Apresentacao>()
                .Where(EventoAbertoParaMusicos)
                .OrderBy(evento => evento.Data)
                .Select(evento => new EventoConvidado(evento.Id, evento.Nome, evento.Data, evento.Local,
                    evento.Tipo, evento.Status, evento.Codigo, NomeDoArtista(evento.ArtistaId)))
        ];
    }

    private Apresentacao EventoDoConvite(string codigo)
    {
        var convite = _convitesDaApresentacao.Values.FirstOrDefault(item =>
            string.Equals(item.Codigo, codigo?.Trim(), StringComparison.OrdinalIgnoreCase));
        var evento = convite is null ? null : ObterApresentacao(convite.ApresentacaoId);
        return evento is not null && EventoAbertoParaMusicos(evento)
            ? evento
            : throw new ConviteNaoEncontradoException();
    }

    private IEnumerable<MusicoDaApresentacaoRegistro> MusicosDoEvento(Guid apresentacaoId) =>
        _musicosDaApresentacao.Values.Where(musico => musico.ApresentacaoId == apresentacaoId);

    private static bool AceitaMusicos(TipoApresentacao tipo) =>
        tipo is TipoApresentacao.ResenhaEntreAmigos or TipoApresentacao.Louvor;

    private static bool EventoAbertoParaMusicos(Apresentacao evento) =>
        AceitaMusicos(evento.Tipo) && evento.Status != StatusApresentacao.Encerrada;

    private string NomeDoArtista(Guid artistaId) =>
        _configuracoesPerfis.GetValueOrDefault(artistaId)?.Perfil.NomeArtistico
        ?? _contasArtistas.GetValueOrDefault(artistaId)?.Nome
        ?? "Artista";
}
