using TocaEssaApp.Api.Dominio;

namespace TocaEssaApp.Api.Infraestrutura;

public sealed partial class RepositorioTocaEssa
{
    /// Coloca no fim da setlist as músicas escolhidas do acervo, sem repetir
    /// as que já estão nela (mesmo vindas de outro repertório).
    public IReadOnlyCollection<ItemDoSetlist> AdicionarMusicasAoSetlist(
        string token, Guid apresentacaoId, IReadOnlyList<Guid> musicaIds)
    {
        var conta = ExigirRegistroArtista(token);
        _ = ObterApresentacaoDoArtista(token, apresentacaoId);
        lock (_sincronizacao)
        {
            var musicas = musicaIds.Select(id =>
                    _musicasDoRepertorio.TryGetValue(id, out var musica) && musica.ArtistaId == conta.Id
                        ? musica
                        : throw new MusicaDoRepertorioNaoEncontradaException())
                .ToArray();
            var itens = ItensDaSetlist(apresentacaoId);
            foreach (var musica in musicas)
            {
                if (itens.Any(item => MesmaMusica(item.Titulo, item.Artista, musica.Titulo, musica.Artista)))
                    continue;
                itens.Add(NovoItem(conta.Id, apresentacaoId, musica.Id,
                    musica.Titulo, musica.Artista, musica.Tom, itens));
            }
            SalvarEstado();
            return ObterSetlistOrdenada(apresentacaoId);
        }
    }

    /// Música fora do acervo direto na setlist; com [repertorioId], fica
    /// também no acervo e recebe as correções feitas lá.
    public IReadOnlyCollection<ItemDoSetlist> AdicionarMusicaAvulsaAoSetlist(
        string token, Guid apresentacaoId, string titulo, string? artista, string? tom,
        Guid? repertorioId)
    {
        var conta = ExigirRegistroArtista(token);
        _ = ObterApresentacaoDoArtista(token, apresentacaoId);
        lock (_sincronizacao)
        {
            var itens = ItensDaSetlist(apresentacaoId);
            if (itens.Any(item => MesmaMusica(item.Titulo, item.Artista, titulo, artista)))
                throw new MusicaJaNaSetlistException();
            Guid? musicaId = repertorioId is { } id
                ? AdicionarMusicaAoRepertorio(token, id, titulo, artista, tom).Id
                : null;
            itens.Add(NovoItem(conta.Id, apresentacaoId, musicaId, titulo, artista, tom, itens));
            SalvarEstado();
            return ObterSetlistOrdenada(apresentacaoId);
        }
    }

    /// Música já tocada fica na setlist, como histórico do show.
    public IReadOnlyCollection<ItemDoSetlist> RemoverItemDoSetlist(
        string token, Guid apresentacaoId, Guid itemId)
    {
        _ = ObterApresentacaoDoArtista(token, apresentacaoId);
        lock (_sincronizacao)
        {
            if (!_itensDoSetlist.TryGetValue(itemId, out var item) ||
                item.ApresentacaoId != apresentacaoId)
                throw new ItemDoSetlistNaoEncontradoException();
            if (item.Tocada) throw new ItemDoSetlistJaTocadoException();
            _itensDoSetlist.TryRemove(itemId, out _);
            Renumerar(ItensDaSetlist(apresentacaoId));
            SalvarEstado();
            return ObterSetlistOrdenada(apresentacaoId);
        }
    }

    /// [itemIds] traz a nova ordem das músicas que faltam; as tocadas ficam
    /// nas posições em que estão.
    public IReadOnlyCollection<ItemDoSetlist> ReordenarSetlist(
        string token, Guid apresentacaoId, IReadOnlyList<Guid> itemIds)
    {
        _ = ObterApresentacaoDoArtista(token, apresentacaoId);
        lock (_sincronizacao)
        {
            var itens = ItensDaSetlist(apresentacaoId);
            var faltam = itens.Where(item => !item.Tocada).ToDictionary(item => item.Id);
            if (itemIds.Count != faltam.Count ||
                itemIds.Distinct().Count() != itemIds.Count ||
                itemIds.Any(id => !faltam.ContainsKey(id)))
                throw new OrdemDoSetlistInvalidaException();
            var novaOrdem = new Queue<ItemDoSetlistRegistro>(itemIds.Select(id => faltam[id]));
            Renumerar(itens.Select(item => item.Tocada ? item : novaOrdem.Dequeue()).ToList());
            SalvarEstado();
            return ObterSetlistOrdenada(apresentacaoId);
        }
    }

    private List<ItemDoSetlistRegistro> ItensDaSetlist(Guid apresentacaoId) =>
        _itensDoSetlist.Values
            .Where(item => item.ApresentacaoId == apresentacaoId)
            .OrderBy(item => item.Ordem)
            .ToList();

    private IReadOnlyCollection<ItemDoSetlist> ObterSetlistOrdenada(Guid apresentacaoId) =>
        ItensDaSetlist(apresentacaoId).Select(ParaDominio).ToArray();

    private ItemDoSetlistRegistro NovoItem(
        Guid artistaId, Guid apresentacaoId, Guid? musicaId, string titulo, string? artista,
        string? tom, IReadOnlyCollection<ItemDoSetlistRegistro> itens)
    {
        var item = new ItemDoSetlistRegistro
        {
            Id = Guid.NewGuid(),
            ApresentacaoId = apresentacaoId,
            ArtistaId = artistaId,
            MusicaDoRepertorioId = musicaId,
            Titulo = titulo.Trim(),
            Artista = string.IsNullOrWhiteSpace(artista) ? null : artista.Trim(),
            Tom = string.IsNullOrWhiteSpace(tom) ? null : tom.Trim(),
            Tocada = false,
            Ordem = itens.Select(i => i.Ordem).DefaultIfEmpty(0).Max() + 1
        };
        _itensDoSetlist[item.Id] = item;
        return item;
    }

    private static void Renumerar(IReadOnlyList<ItemDoSetlistRegistro> itens)
    {
        for (var indice = 0; indice < itens.Count; indice++)
            itens[indice].Ordem = indice + 1;
    }

    /// Mesmo título (sem acento nem maiúscula) e mesmo cantor; sem cantor
    /// num dos lados, vale só o título.
    private static bool MesmaMusica(string titulo, string? artista, string outroTitulo, string? outroArtista)
    {
        if (NormalizarMusica(titulo) != NormalizarMusica(outroTitulo)) return false;
        var (um, outro) = (NormalizarMusica(artista), NormalizarMusica(outroArtista));
        return um.Length == 0 || outro.Length == 0 || um == outro;
    }
}
