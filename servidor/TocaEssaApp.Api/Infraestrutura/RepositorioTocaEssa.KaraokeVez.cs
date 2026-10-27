using TocaEssaApp.Api.Dominio;

namespace TocaEssaApp.Api.Infraestrutura;

// O que cada um faz no próprio celular: escolher a música (ou girar a
// roleta), começar a vez no Tocar na TV e terminar.
public sealed partial class RepositorioTocaEssa
{
    private const int TamanhoMaximoDaMusicaDoKaraoke = 200;

    public IReadOnlyList<MusicaDaPlaylistDoKaraoke> ListarPlaylistDoKaraoke(
        string codigo, string token)
    {
        var (apresentacao, _) = ExigirNaGalera(codigo, token);
        return [.. PlaylistDaNoite(apresentacao)
            .Select(item => new MusicaDaPlaylistDoKaraoke(item.Id, item.Musica.Titulo))];
    }

    /// Vale para a próxima vez da pessoa e pode trocar até ela começar.
    public NoiteDeKaraoke EscolherMusicaNoKaraoke(
        string codigo, string token, EscolherMusicaDoKaraoke escolha)
    {
        var (apresentacao, publicoId) = ExigirNaGalera(codigo, token);
        ExigirModo(apresentacao, ModoDasMusicas.Livre);
        var musica = MusicaEscolhida(apresentacao, escolha);
        return GravarKaraoke(apresentacao, estado => estado.ComEscolha(publicoId, musica), publicoId);
    }

    /// Sorteia da playlist; girar de novo é o "não conheço, sortear outra".
    public NoiteDeKaraoke GirarRoletaDoKaraoke(string codigo, string token)
    {
        var (apresentacao, publicoId) = ExigirNaGalera(codigo, token);
        ExigirModo(apresentacao, ModoDasMusicas.Roleta);
        var playlist = PlaylistDaNoite(apresentacao).Select(item => item.Musica).ToArray();
        return GravarKaraoke(apresentacao, estado =>
        {
            var mostradas = estado.Mostradas.GetValueOrDefault(publicoId) ?? [];
            var cantadas = estado.Vezes.Select(vez => vez.Musica.Chave).ToHashSet();
            var musica = RegrasDaVez.SortearDaRoleta(playlist, cantadas, mostradas, Random.Shared)
                ?? throw new PlaylistDoKaraokeAcabouException();
            return estado.ComEscolha(publicoId, musica) with
            {
                Mostradas = new(estado.Mostradas) { [publicoId] = [.. mostradas, musica.Chave] }
            };
        }, publicoId);
    }

    /// O Tocar na TV: só o próximo, já com a música. Encerra a vez de quem
    /// cantava; tocar de novo na própria vez não cria outra.
    public NoiteDeKaraoke ComecarVezNoKaraoke(string codigo, string token)
    {
        var (apresentacao, publicoId) = ExigirNaGalera(codigo, token);
        return GravarKaraoke(apresentacao, estado =>
        {
            if (estado.EmAndamento?.PublicoId == publicoId) return estado;
            if (!estado.Sorteada) throw new OrdemAindaNaoSorteadaException();
            var ordem = OrdemAtual(apresentacao.Id, estado);
            if (RegrasDaVez.Proximo(ordem, estado.Ultima) != publicoId)
                throw new AindaNaoEhSuaVezException();
            var musica = estado.Escolhas.GetValueOrDefault(publicoId)
                ?? throw new EscolhaAMusicaAntesException();
            var agora = DateTimeOffset.UtcNow;
            var vez = new VezDoKaraoke(publicoId, musica, RegrasDaVez.IndiceDe(ordem, publicoId), agora);
            return estado.ComEscolha(publicoId, null) with
            {
                Vezes = [.. estado.VezesEncerradas(agora), vez]
            };
        }, publicoId);
    }

    /// O "Terminei" de quem está cantando.
    public NoiteDeKaraoke TerminarVezNoKaraoke(string codigo, string token)
    {
        var (apresentacao, publicoId) = ExigirNaGalera(codigo, token);
        return GravarKaraoke(apresentacao, estado =>
        {
            if (estado.EmAndamento?.PublicoId != publicoId) throw new AindaNaoEhSuaVezException();
            return estado with { Vezes = estado.VezesEncerradas(DateTimeOffset.UtcNow) };
        }, publicoId);
    }

    /// O dono destrava uma vez esquecida aberta.
    public NoiteDeKaraoke TerminarVezNoKaraoke(string token, Guid apresentacaoId)
    {
        var apresentacao = ExigirKaraokeDoArtista(token, apresentacaoId);
        return GravarKaraoke(apresentacao,
            estado => estado with { Vezes = estado.VezesEncerradas(DateTimeOffset.UtcNow) });
    }

    private (Apresentacao Apresentacao, Guid PublicoId) ExigirNaGalera(string codigo, string token)
    {
        var apresentacao = ExigirKaraoke(ObterApresentacaoPublica(codigo)
            ?? throw new ApresentacaoNaoEncontradaException());
        var publico = ObterRegistroPublico(token)
            ?? throw new IdentificacaoPublicaObrigatoriaException();
        if (!_participacoesResenha.ContainsKey((apresentacao.Id, publico.Id)))
            throw new ForaDaGaleraDoKaraokeException();
        return (apresentacao, publico.Id);
    }

    private void ExigirModo(Apresentacao apresentacao, ModoDasMusicas modo)
    {
        if (EstadoDoKaraoke(apresentacao.Id).Configuracao.Modo != modo)
            throw new KaraokeEmOutroModoException();
    }

    private MusicaDoKaraoke MusicaEscolhida(Apresentacao apresentacao, EscolherMusicaDoKaraoke escolha)
    {
        if (escolha.MusicaId is { } id)
            return PlaylistDaNoite(apresentacao).FirstOrDefault(item => item.Id == id).Musica
                ?? throw new MusicaDoRepertorioNaoEncontradaException();
        var titulo = (escolha.Titulo ?? string.Empty).Trim();
        var link = string.IsNullOrWhiteSpace(escolha.LinkDoVideo) ? null : escolha.LinkDoVideo.Trim();
        if (titulo.Length is 0 or > TamanhoMaximoDaMusicaDoKaraoke)
            throw new MusicaDoKaraokeInvalidaException();
        if (link is not null && !RegrasDaVez.EhLinkDoYouTube(link))
            throw new MusicaDoKaraokeInvalidaException();
        return new MusicaDoKaraoke(titulo, link);
    }

    /// As músicas com vídeo da playlist da noite, na ordem do repertório.
    private List<(Guid Id, MusicaDoKaraoke Musica)> PlaylistDaNoite(Apresentacao apresentacao)
    {
        var repertorioId = RepertorioDoKaraoke(
            apresentacao.ArtistaId, EstadoDoKaraoke(apresentacao.Id).Configuracao.RepertorioId);
        return _musicasDoRepertorio.Values
            .Where(musica => musica.RepertorioId == repertorioId && musica.LinkDoVideo is not null)
            .OrderBy(musica => musica.Ordem)
            .Select(musica => (musica.Id, new MusicaDoKaraoke(musica.Titulo, musica.LinkDoVideo)))
            .ToList();
    }
}
