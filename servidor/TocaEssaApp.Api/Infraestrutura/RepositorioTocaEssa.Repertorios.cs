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
            var registro = CriarRegistroDeRepertorio(conta.Id, nome);
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
            _musicasDoRepertorio[registro.Id] = registro;
            SalvarEstado();
            return ParaDominio(registro);
        }
    }

    /// Leva várias músicas para um repertório do artista ou para um novo
    /// chamado [nomeNovo], sem repetir as que já estão nele. Música avulsa
    /// de setlist com o mesmo nome fica ligada e recebe as correções.
    public MusicasAdicionadasAoRepertorio AdicionarMusicasAoRepertorio(
        string token, Guid? repertorioId, string? nomeNovo,
        IReadOnlyList<AdicionarMusicaAoRepertorio> musicas)
    {
        var conta = ExigirRegistroArtista(token);
        lock (_sincronizacao)
        {
            RepertorioRegistro? existente = null;
            if (repertorioId is { } id &&
                (!_repertorios.TryGetValue(id, out existente) || existente.ArtistaId != conta.Id))
                throw new RepertorioNaoEncontradoException();
            var repertorio = existente ?? CriarRegistroDeRepertorio(conta.Id, nomeNovo ?? string.Empty);
            var noRepertorio = _musicasDoRepertorio.Values
                .Where(m => m.RepertorioId == repertorio.Id)
                .ToList();
            var adicionadas = 0;
            foreach (var musica in musicas)
            {
                if (noRepertorio.Any(m => MesmaMusica(m.Titulo, m.Artista, musica.Titulo, musica.Artista)))
                    continue;
                var registro = new MusicaDoRepertorioRegistro
                {
                    Id = Guid.NewGuid(),
                    RepertorioId = repertorio.Id,
                    ArtistaId = conta.Id,
                    Titulo = musica.Titulo.Trim(),
                    Artista = string.IsNullOrWhiteSpace(musica.Artista) ? null : musica.Artista.Trim(),
                    Tom = string.IsNullOrWhiteSpace(musica.Tom) ? null : musica.Tom.Trim(),
                    Ordem = noRepertorio.Select(m => m.Ordem).DefaultIfEmpty(0).Max() + 1
                };
                _musicasDoRepertorio[registro.Id] = registro;
                noRepertorio.Add(registro);
                adicionadas++;
                foreach (var item in _itensDoSetlist.Values.Where(i =>
                             i.ArtistaId == conta.Id && i.MusicaDoRepertorioId == null &&
                             MesmaMusica(i.Titulo, i.Artista, registro.Titulo, registro.Artista)))
                    item.MusicaDoRepertorioId = registro.Id;
            }
            SalvarEstado();
            return new MusicasAdicionadasAoRepertorio(
                ParaDominio(repertorio), adicionadas, musicas.Count - adicionadas);
        }
    }

    private RepertorioRegistro CriarRegistroDeRepertorio(Guid artistaId, string nome)
    {
        var registro = new RepertorioRegistro
        {
            Id = Guid.NewGuid(),
            ArtistaId = artistaId,
            Nome = nome.Trim(),
            CriadoEm = DateTimeOffset.UtcNow
        };
        _repertorios[registro.Id] = registro;
        return registro;
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
            _musicasDoRepertorio.TryRemove(musicaId, out _);
            // A setlist é independente do acervo: a música removida continua nela.
            foreach (var item in _itensDoSetlist.Values.Where(i => i.MusicaDoRepertorioId == musicaId))
                item.MusicaDoRepertorioId = null;
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

            for (var indice = 0; indice < musicaIds.Count; indice++)
                musicas[musicaIds[indice]].Ordem = indice + 1;
            SalvarEstado();
            return ParaDominio(repertorio);
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
}
