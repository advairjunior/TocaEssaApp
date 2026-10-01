using TocaEssaApp.Api.Dominio;

namespace TocaEssaApp.Api.Infraestrutura;

public sealed partial class RepositorioTocaEssa
{
    public IReadOnlyCollection<Repertorio> ListarRepertorios(string token)
    {
        var conta = ExigirRegistroArtista(token);
        return _repertorios.Values
            .Where(r => r.ArtistaId == conta.Id)
            .OrderBy(r => r.CriadoEm)
            .Select(r => ParaDominio(r))
            .ToArray();
    }

    public Repertorio CriarRepertorio(string token, string nome)
    {
        var conta = ExigirRegistroArtista(token);
        lock (_sincronizacao)
        {
            var registro = new RepertorioRegistro
            {
                Id = Guid.NewGuid(),
                ArtistaId = conta.Id,
                Nome = nome.Trim(),
                CriadoEm = DateTimeOffset.UtcNow
            };
            _repertorios[registro.Id] = registro;
            SalvarEstado();
            return ParaDominio(registro);
        }
    }

    public void ExcluirRepertorio(string token, Guid id)
    {
        var conta = ExigirRegistroArtista(token);
        lock (_sincronizacao)
        {
            if (!_repertorios.TryGetValue(id, out var registro) ||
                registro.ArtistaId != conta.Id)
                throw new RepertorioNaoEncontradoException();
            _repertorios.TryRemove(id, out _);
            foreach (var musicaId in _musicasDoRepertorio.Values
                         .Where(m => m.RepertorioId == id)
                         .Select(m => m.Id)
                         .ToArray())
                _musicasDoRepertorio.TryRemove(musicaId, out _);
            SalvarEstado();
        }
    }

    public MusicaDoRepertorio AdicionarMusicaAoRepertorio(
        string token, Guid repertorioId, string titulo, string? artista)
    {
        var conta = ExigirRegistroArtista(token);
        lock (_sincronizacao)
        {
            if (!_repertorios.TryGetValue(repertorioId, out var repertorio) ||
                repertorio.ArtistaId != conta.Id)
                throw new RepertorioNaoEncontradoException();
            var proxima = _musicasDoRepertorio.Values
                .Where(m => m.RepertorioId == repertorioId)
                .Select(m => m.Ordem)
                .DefaultIfEmpty(0)
                .Max() + 1;
            var registro = new MusicaDoRepertorioRegistro
            {
                Id = Guid.NewGuid(),
                RepertorioId = repertorioId,
                ArtistaId = conta.Id,
                Titulo = titulo.Trim(),
                Artista = string.IsNullOrWhiteSpace(artista) ? null : artista.Trim(),
                Ordem = proxima
            };
            _musicasDoRepertorio[registro.Id] = registro;
            SalvarEstado();
            return ParaDominio(registro);
        }
    }

    public void RemoverMusicaDoRepertorio(string token, Guid repertorioId, Guid musicaId)
    {
        var conta = ExigirRegistroArtista(token);
        lock (_sincronizacao)
        {
            if (!_repertorios.TryGetValue(repertorioId, out var repertorio) ||
                repertorio.ArtistaId != conta.Id)
                throw new RepertorioNaoEncontradoException();
            if (!_musicasDoRepertorio.TryGetValue(musicaId, out var musica) ||
                musica.RepertorioId != repertorioId)
                throw new MusicaDoRepertorioNaoEncontradaException();
            _musicasDoRepertorio.TryRemove(musicaId, out _);
            SalvarEstado();
        }
    }

    public IReadOnlyCollection<ItemDoSetlist> ObterSetlist(string token, Guid apresentacaoId)
    {
        var conta = ExigirRegistroArtista(token);
        _ = ObterApresentacaoDoArtista(token, apresentacaoId);
        return _itensDoSetlist.Values
            .Where(i => i.ApresentacaoId == apresentacaoId && i.ArtistaId == conta.Id)
            .OrderBy(i => i.Ordem)
            .Select(ParaDominio)
            .ToArray();
    }

    public IReadOnlyCollection<ItemDoSetlist> ImportarRepertorioParaSetlist(
        string token, Guid apresentacaoId, Guid repertorioId)
    {
        var conta = ExigirRegistroArtista(token);
        _ = ObterApresentacaoDoArtista(token, apresentacaoId);
        lock (_sincronizacao)
        {
            if (!_repertorios.TryGetValue(repertorioId, out var repertorio) ||
                repertorio.ArtistaId != conta.Id)
                throw new RepertorioNaoEncontradoException();

            // Substituir setlist existente da apresentação
            foreach (var itemId in _itensDoSetlist.Values
                         .Where(i => i.ApresentacaoId == apresentacaoId)
                         .Select(i => i.Id)
                         .ToArray())
                _itensDoSetlist.TryRemove(itemId, out _);

            // Copiar músicas do repertório
            var musicas = _musicasDoRepertorio.Values
                .Where(m => m.RepertorioId == repertorioId)
                .OrderBy(m => m.Ordem)
                .ToArray();

            foreach (var musica in musicas)
            {
                var item = new ItemDoSetlistRegistro
                {
                    Id = Guid.NewGuid(),
                    ApresentacaoId = apresentacaoId,
                    ArtistaId = conta.Id,
                    Titulo = musica.Titulo,
                    Artista = musica.Artista,
                    Tocada = false,
                    Ordem = musica.Ordem
                };
                _itensDoSetlist[item.Id] = item;
            }
            SalvarEstado();
            return _itensDoSetlist.Values
                .Where(i => i.ApresentacaoId == apresentacaoId && i.ArtistaId == conta.Id)
                .OrderBy(i => i.Ordem)
                .Select(ParaDominio)
                .ToArray();
        }
    }

    public ItemDoSetlist MarcarItemDoSetlist(
        string token, Guid apresentacaoId, Guid itemId, bool tocada)
    {
        var conta = ExigirRegistroArtista(token);
        lock (_sincronizacao)
        {
            if (!_itensDoSetlist.TryGetValue(itemId, out var item) ||
                item.ApresentacaoId != apresentacaoId ||
                item.ArtistaId != conta.Id)
                throw new ItemDoSetlistNaoEncontradoException();
            item.Tocada = tocada;
            _itensDoSetlist[itemId] = item;
            SalvarEstado();
            return ParaDominio(_itensDoSetlist[itemId]);
        }
    }

    public void LimparSetlist(string token, Guid apresentacaoId)
    {
        var conta = ExigirRegistroArtista(token);
        _ = ObterApresentacaoDoArtista(token, apresentacaoId);
        lock (_sincronizacao)
        {
            foreach (var itemId in _itensDoSetlist.Values
                         .Where(i => i.ApresentacaoId == apresentacaoId &&
                                     i.ArtistaId == conta.Id)
                         .Select(i => i.Id)
                         .ToArray())
                _itensDoSetlist.TryRemove(itemId, out _);
            SalvarEstado();
        }
    }

    private Repertorio ParaDominio(RepertorioRegistro r) => new(
        r.Id,
        r.ArtistaId,
        r.Nome,
        _musicasDoRepertorio.Values
            .Where(m => m.RepertorioId == r.Id)
            .OrderBy(m => m.Ordem)
            .Select(ParaDominio)
            .ToArray());

    private static MusicaDoRepertorio ParaDominio(MusicaDoRepertorioRegistro m) => new(
        m.Id, m.RepertorioId, m.Titulo, m.Artista, m.Ordem);

    private static ItemDoSetlist ParaDominio(ItemDoSetlistRegistro i) => new(
        i.Id, i.ApresentacaoId, i.Titulo, i.Artista, i.Tocada, i.Ordem);
}
