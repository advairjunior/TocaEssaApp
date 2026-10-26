using System.Collections.Concurrent;
using System.Text.Json;
using TocaEssaApp.Api.Dominio;

namespace TocaEssaApp.Api.Infraestrutura;

// A noite de karaokê: o modo, a playlist e a ordem de quem canta. A galera é
// quem entrou com conta (as participações do evento).
public sealed partial class RepositorioTocaEssa
{
    private readonly ConcurrentDictionary<Guid, EstadoDoKaraoke> _karaokes = new();

    public NoiteDeKaraoke ObterNoiteDeKaraoke(string token, Guid apresentacaoId) =>
        MontarNoiteDeKaraoke(ExigirKaraokeDoArtista(token, apresentacaoId));

    /// Para quem está na galera: só com conta.
    public NoiteDeKaraoke ObterNoiteDeKaraoke(string codigo, string tokenPublico)
    {
        var apresentacao = ObterApresentacaoPublica(codigo)
            ?? throw new ApresentacaoNaoEncontradaException();
        _ = ObterRegistroPublico(tokenPublico)
            ?? throw new IdentificacaoPublicaObrigatoriaException();
        return MontarNoiteDeKaraoke(ExigirKaraoke(apresentacao));
    }

    public NoiteDeKaraoke ConfigurarKaraoke(
        string token, Guid apresentacaoId, ConfiguracaoDoKaraoke configuracao)
    {
        var apresentacao = ExigirKaraokeDoArtista(token, apresentacaoId);
        if (configuracao.RepertorioId is { } repertorioId &&
            _repertorios.GetValueOrDefault(repertorioId)?.ArtistaId != apresentacao.ArtistaId)
            throw new RepertorioNaoEncontradoException();
        return GravarKaraoke(apresentacao,
            estado => estado with { Configuracao = configuracao });
    }

    /// Embaralha a galera; de novo, só enquanto ninguém começou a cantar.
    public NoiteDeKaraoke SortearOrdemDoKaraoke(string token, Guid apresentacaoId)
    {
        var apresentacao = ExigirKaraokeDoArtista(token, apresentacaoId);
        return GravarKaraoke(apresentacao, estado =>
        {
            if (estado.Comecou) throw new KaraokeJaComecouException();
            var galera = OrdemDoKaraoke.Montar([], GaleraPorChegada(apresentacao.Id), estado.Retirados);
            return estado with
            {
                Sorteados = [.. OrdemDoKaraoke.Sortear(galera, Random.Shared)],
                Sorteada = true
            };
        });
    }

    public NoiteDeKaraoke PassarAVezNoKaraoke(string token, Guid apresentacaoId, Guid publicoId)
    {
        var apresentacao = ExigirKaraokeDoArtista(token, apresentacaoId);
        return GravarKaraoke(apresentacao, estado => estado with
        {
            Sorteados = [.. OrdemDoKaraoke.PassarAVez(OrdemAtual(apresentacao.Id, estado), publicoId)]
        });
    }

    public NoiteDeKaraoke TirarDaOrdemDoKaraoke(string token, Guid apresentacaoId, Guid publicoId)
    {
        var apresentacao = ExigirKaraokeDoArtista(token, apresentacaoId);
        return GravarKaraoke(apresentacao, estado => estado with
        {
            Retirados = [.. estado.Retirados.Where(id => id != publicoId), publicoId]
        });
    }

    /// Volta para o fim da ordem.
    public NoiteDeKaraoke DevolverAOrdemDoKaraoke(string token, Guid apresentacaoId, Guid publicoId)
    {
        var apresentacao = ExigirKaraokeDoArtista(token, apresentacaoId);
        return GravarKaraoke(apresentacao, estado => estado with
        {
            Sorteados = [.. OrdemAtual(apresentacao.Id, estado)],
            Retirados = [.. estado.Retirados.Where(id => id != publicoId)]
        });
    }

    private Apresentacao ExigirKaraokeDoArtista(string token, Guid apresentacaoId) =>
        ExigirKaraoke(ObterApresentacaoDoArtista(token, apresentacaoId));

    private static Apresentacao ExigirKaraoke(Apresentacao apresentacao) =>
        apresentacao.Tipo == TipoApresentacao.Karaoke
            ? apresentacao
            : throw new RecursoDisponivelSomenteNoKaraokeException();

    private EstadoDoKaraoke EstadoDoKaraoke(Guid apresentacaoId) =>
        _karaokes.GetValueOrDefault(apresentacaoId) ?? new EstadoDoKaraoke();

    private NoiteDeKaraoke GravarKaraoke(
        Apresentacao apresentacao, Func<EstadoDoKaraoke, EstadoDoKaraoke> mudar)
    {
        lock (_sincronizacao)
        {
            _karaokes[apresentacao.Id] = mudar(EstadoDoKaraoke(apresentacao.Id));
            SalvarEstado();
            return MontarNoiteDeKaraoke(apresentacao);
        }
    }

    private List<Guid> GaleraPorChegada(Guid apresentacaoId) =>
        _participacoesResenha.Values
            .Where(item => item.ApresentacaoId == apresentacaoId)
            .OrderBy(item => item.EntrouEm)
            .Select(item => item.PublicoId)
            .ToList();

    private IReadOnlyList<Guid> OrdemAtual(Guid apresentacaoId, EstadoDoKaraoke estado) =>
        OrdemDoKaraoke.Montar(estado.Sorteados, GaleraPorChegada(apresentacaoId), estado.Retirados);

    private NoiteDeKaraoke MontarNoiteDeKaraoke(Apresentacao apresentacao)
    {
        var estado = EstadoDoKaraoke(apresentacao.Id);
        var naGalera = GaleraPorChegada(apresentacao.Id).ToHashSet();
        var ordem = OrdemAtual(apresentacao.Id, estado);
        PessoaDoKaraoke Pessoa(Guid id) => PessoaDoKaraoke(id, estado);
        return new NoiteDeKaraoke(
            RepertorioDoKaraoke(apresentacao.ArtistaId, estado.Configuracao.RepertorioId),
            estado.Configuracao.Modo,
            estado.Sorteada,
            !estado.Comecou,
            [.. ordem.Select(Pessoa)],
            [.. estado.Retirados.Where(naGalera.Contains).Select(Pessoa)],
            Cantando(estado),
            RegrasDaVez.Proximo(ordem, estado.Ultima));
    }

    private CantandoNoKaraoke? Cantando(EstadoDoKaraoke estado) =>
        estado.EmAndamento is { } vez
            ? new CantandoNoKaraoke(vez.PublicoId, NomeNoKaraoke(vez.PublicoId), vez.Musica, vez.ComecouEm)
            : null;

    private string NomeNoKaraoke(Guid publicoId) =>
        _perfisPublicos.GetValueOrDefault(publicoId)?.Nome ?? "Participante";

    private PessoaDoKaraoke PessoaDoKaraoke(Guid publicoId, EstadoDoKaraoke estado) =>
        new(publicoId, NomeNoKaraoke(publicoId),
            _perfisPublicos.GetValueOrDefault(publicoId)?.FotoUrl,
            estado.Escolhas.GetValueOrDefault(publicoId));

    /// O escolhido, se ainda é do artista; senão o repertório com mais vídeos.
    private Guid? RepertorioDoKaraoke(Guid artistaId, Guid? escolhido)
    {
        if (escolhido is { } id && _repertorios.GetValueOrDefault(id)?.ArtistaId == artistaId)
            return id;
        return _musicasDoRepertorio.Values
            .Where(musica => musica.ArtistaId == artistaId && musica.LinkDoVideo is not null)
            .GroupBy(musica => musica.RepertorioId)
            .OrderByDescending(grupo => grupo.Count())
            .Select(grupo => (Guid?)grupo.Key)
            .FirstOrDefault();
    }

    private void CarregarKaraoke(ApresentacaoRegistro registro)
    {
        if (LerJson<EstadoDoKaraoke>(registro.KaraokeDaNoite) is { } estado)
            _karaokes[registro.Id] = estado;
    }

    private void EscreverKaraoke(ApresentacaoRegistro registro) =>
        registro.KaraokeDaNoite = _karaokes.GetValueOrDefault(registro.Id) is { } estado
            ? JsonSerializer.Serialize(estado)
            : null;
}
