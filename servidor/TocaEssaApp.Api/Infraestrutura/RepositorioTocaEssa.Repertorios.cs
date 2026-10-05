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

    public Repertorio RenomearRepertorio(string token, Guid id, string nome)
    {
        var conta = ExigirRegistroArtista(token);
        lock (_sincronizacao)
        {
            if (!_repertorios.TryGetValue(id, out var registro) ||
                registro.ArtistaId != conta.Id)
                throw new RepertorioNaoEncontradoException();
            registro.Nome = nome.Trim();
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
        string token, Guid repertorioId, string titulo, string? artista,
        string? tom = null)
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
                Tom = string.IsNullOrWhiteSpace(tom) ? null : tom.Trim(),
                Ordem = proxima
            };
            VincularSetlistsLegados(conta.Id, repertorioId);
            _musicasDoRepertorio[registro.Id] = registro;
            SincronizarSetlistsDoRepertorio(conta.Id, repertorioId);
            SalvarEstado();
            return ParaDominio(registro);
        }
    }

    public MusicaDoRepertorio EditarMusicaDoRepertorio(
        string token, Guid repertorioId, Guid musicaId,
        string titulo, string? artista, string? tom)
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
            var tituloAntigo = musica.Titulo;
            musica.Titulo = titulo.Trim();
            musica.Artista = string.IsNullOrWhiteSpace(artista) ? null : artista.Trim();
            musica.Tom = string.IsNullOrWhiteSpace(tom) ? null : tom.Trim();
            _musicasDoRepertorio[musicaId] = musica;

            // Propagar edição para setlists vinculados por ID ou por título (fallback
            // para itens importados antes de existir o campo MusicaDoRepertorioId).
            foreach (var item in _itensDoSetlist.Values
                         .Where(i => i.ArtistaId == conta.Id && (
                             i.MusicaDoRepertorioId == musicaId ||
                             (i.MusicaDoRepertorioId == null &&
                              string.Equals(i.Titulo, tituloAntigo,
                                  StringComparison.OrdinalIgnoreCase)))))
            {
                item.MusicaDoRepertorioId ??= musicaId; // vincula para atualizações futuras
                item.Titulo = musica.Titulo;
                item.Artista = musica.Artista;
                item.Tom = musica.Tom;
            }

            SalvarEstado();
            return ParaDominio(musica);
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
            VincularSetlistsLegados(conta.Id, repertorioId);
            _musicasDoRepertorio.TryRemove(musicaId, out _);
            var emAberto = ApresentacoesEmAberto(conta.Id);
            foreach (var itemId in _itensDoSetlist.Values
                         .Where(i => i.MusicaDoRepertorioId == musicaId &&
                                     emAberto.Contains(i.ApresentacaoId))
                         .Select(i => i.Id)
                         .ToArray())
                _itensDoSetlist.TryRemove(itemId, out _);
            SincronizarSetlistsDoRepertorio(conta.Id, repertorioId);
            SalvarEstado();
        }
    }

    public Repertorio ReordenarMusicasDoRepertorio(
        string token, Guid repertorioId, IReadOnlyList<Guid> musicaIds)
    {
        var conta = ExigirRegistroArtista(token);
        lock (_sincronizacao)
        {
            if (!_repertorios.TryGetValue(repertorioId, out var repertorio) ||
                repertorio.ArtistaId != conta.Id)
                throw new RepertorioNaoEncontradoException();
            var musicas = _musicasDoRepertorio.Values
                .Where(m => m.RepertorioId == repertorioId)
                .ToDictionary(m => m.Id);
            if (musicaIds.Count != musicas.Count ||
                musicaIds.Distinct().Count() != musicaIds.Count ||
                musicaIds.Any(id => !musicas.ContainsKey(id)))
                throw new OrdemDoRepertorioInvalidaException();

            VincularSetlistsLegados(conta.Id, repertorioId);
            for (var indice = 0; indice < musicaIds.Count; indice++)
                musicas[musicaIds[indice]].Ordem = indice + 1;
            SincronizarSetlistsDoRepertorio(conta.Id, repertorioId);
            SalvarEstado();
            return ParaDominio(repertorio);
        }
    }

    // Setlists de apresentações encerradas ficam como histórico e não acompanham o repertório.
    private HashSet<Guid> ApresentacoesEmAberto(Guid artistaId) =>
        _apresentacoes.Values
            .Where(a => a.ArtistaId == artistaId && a.Status != StatusApresentacao.Encerrada)
            .Select(a => a.Id)
            .ToHashSet();

    private ItemDoSetlistRegistro[][] SetlistsEmAberto(Guid artistaId)
    {
        var emAberto = ApresentacoesEmAberto(artistaId);
        return _itensDoSetlist.Values
            .Where(i => i.ArtistaId == artistaId && emAberto.Contains(i.ApresentacaoId))
            .GroupBy(i => i.ApresentacaoId)
            .Select(grupo => grupo.ToArray())
            .ToArray();
    }

    // Setlists importados antes do vínculo por ID são associados pelo título ao
    // repertório do artista com mais músicas em comum.
    private void VincularSetlistsLegados(Guid artistaId, Guid repertorioId)
    {
        var titulosPorRepertorio = _musicasDoRepertorio.Values
            .Where(m => m.ArtistaId == artistaId)
            .GroupBy(m => m.RepertorioId)
            .ToDictionary(
                grupo => grupo.Key,
                grupo => grupo.Select(m => NormalizarTitulo(m.Titulo)).ToHashSet());
        if (!titulosPorRepertorio.TryGetValue(repertorioId, out var titulos)) return;
        var musicasDoRepertorio = _musicasDoRepertorio.Values
            .Where(m => m.RepertorioId == repertorioId)
            .ToArray();
        var idsDoRepertorio = musicasDoRepertorio.Select(m => m.Id).ToHashSet();

        foreach (var itens in SetlistsEmAberto(artistaId))
        {
            var legados = itens.Where(i => i.MusicaDoRepertorioId is null).ToArray();
            if (legados.Length == 0) continue;
            var vinculados = itens.Where(i => i.MusicaDoRepertorioId is not null).ToArray();
            var pertenceAoRepertorio = vinculados.Length > 0
                ? vinculados.Any(i => idsDoRepertorio.Contains(i.MusicaDoRepertorioId!.Value))
                : RepertorioComMaisTitulosEmComum(legados, titulosPorRepertorio) == repertorioId;
            if (!pertenceAoRepertorio) continue;

            foreach (var item in legados)
            {
                var musica = musicasDoRepertorio.FirstOrDefault(m =>
                    NormalizarTitulo(m.Titulo) == NormalizarTitulo(item.Titulo) &&
                    itens.All(i => i.MusicaDoRepertorioId != m.Id));
                if (musica is not null) item.MusicaDoRepertorioId = musica.Id;
            }
        }
    }

    private static Guid? RepertorioComMaisTitulosEmComum(
        IReadOnlyCollection<ItemDoSetlistRegistro> itens,
        IReadOnlyDictionary<Guid, HashSet<string>> titulosPorRepertorio)
    {
        var contagens = titulosPorRepertorio
            .Select(par => (RepertorioId: par.Key,
                EmComum: itens.Count(i => par.Value.Contains(NormalizarTitulo(i.Titulo)))))
            .Where(par => par.EmComum > 0)
            .OrderByDescending(par => par.EmComum)
            .ToArray();
        if (contagens.Length == 0) return null;
        if (contagens.Length > 1 && contagens[1].EmComum == contagens[0].EmComum) return null;
        return contagens[0].RepertorioId;
    }

    private static string NormalizarTitulo(string titulo) => titulo.Trim().ToLowerInvariant();

    // Setlists em aberto vinculados ao repertório recebem as músicas novas e seguem sua ordem.
    private void SincronizarSetlistsDoRepertorio(Guid artistaId, Guid repertorioId)
    {
        var musicas = _musicasDoRepertorio.Values
            .Where(m => m.RepertorioId == repertorioId)
            .OrderBy(m => m.Ordem)
            .ToArray();
        var idsDoRepertorio = musicas.Select(m => m.Id).ToHashSet();

        foreach (var itens in SetlistsEmAberto(artistaId))
        {
            if (!itens.Any(i => i.MusicaDoRepertorioId is { } id && idsDoRepertorio.Contains(id)))
                continue;
            var apresentacaoId = itens[0].ApresentacaoId;
            foreach (var musica in musicas)
            {
                var item = itens.FirstOrDefault(i => i.MusicaDoRepertorioId == musica.Id);
                if (item is not null)
                {
                    item.Ordem = musica.Ordem;
                    continue;
                }
                var novo = new ItemDoSetlistRegistro
                {
                    Id = Guid.NewGuid(),
                    ApresentacaoId = apresentacaoId,
                    ArtistaId = artistaId,
                    MusicaDoRepertorioId = musica.Id,
                    Titulo = musica.Titulo,
                    Artista = musica.Artista,
                    Tom = musica.Tom,
                    Tocada = false,
                    Ordem = musica.Ordem
                };
                _itensDoSetlist[novo.Id] = novo;
            }
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
                    MusicaDoRepertorioId = musica.Id,
                    Titulo = musica.Titulo,
                    Artista = musica.Artista,
                    Tom = musica.Tom,
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
        m.Id, m.RepertorioId, m.Titulo, m.Artista, m.Tom, m.Ordem);

    private static ItemDoSetlist ParaDominio(ItemDoSetlistRegistro i) => new(
        i.Id, i.ApresentacaoId, i.Titulo, i.Artista, i.Tom, i.Tocada, i.Ordem);
}
