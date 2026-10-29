using TocaEssaApp.Api.Dominio;

namespace TocaEssaApp.Api.Infraestrutura;

// Setlist de cada apresentação: ler, importar um repertório, marcar e limpar.
public sealed partial class RepositorioTocaEssa
{
    public IReadOnlyCollection<ItemDoSetlist> ObterSetlist(string token, Guid apresentacaoId)
    {
        var evento = ObterApresentacaoDaNoite(token, apresentacaoId);
        return _itensDoSetlist.Values
            .Where(i => i.ApresentacaoId == apresentacaoId && i.ArtistaId == evento.ArtistaId)
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
        // O músico convidado também marca: a setlist da noite é uma só.
        var evento = ObterApresentacao(apresentacaoId);
        lock (_sincronizacao)
        {
            if (!_itensDoSetlist.TryGetValue(itemId, out var item) ||
                item.ApresentacaoId != apresentacaoId || evento is null ||
                !TocaNaNoite(conta.Id, evento) || item.ArtistaId != evento.ArtistaId)
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

    private static ItemDoSetlist ParaDominio(ItemDoSetlistRegistro i) => new(
        i.Id, i.ApresentacaoId, i.Titulo, i.Artista, i.Tom, i.Tocada, i.Ordem);
}
