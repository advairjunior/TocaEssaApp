using TocaEssaApp.Api.Dominio;
using TocaEssaApp.Api.Infraestrutura;

namespace TocaEssaApp.Testes;

public class RepertorioTestes
{
    [Fact]
    public void ArtistaCriaRepertorioEAdicionaMusicas()
    {
        var repositorio = new RepositorioTocaEssa();
        var token = repositorio.CriarContaArtista("Ana", "ana@artista.com", "senha").Token;

        var repertorio = repositorio.CriarRepertorio(token, "Sertanejo");
        repositorio.AdicionarMusicaAoRepertorio(token, repertorio.Id, "Evidências",
            "Chitãozinho e Xororó");
        repositorio.AdicionarMusicaAoRepertorio(token, repertorio.Id, "Cuida Bem Dela", null);

        var lista = repositorio.ListarRepertorios(token);
        var rep = Assert.Single(lista);
        Assert.Equal("Sertanejo", rep.Nome);
        Assert.Equal(2, rep.Musicas.Count);
        Assert.Contains(rep.Musicas, m => m.Titulo == "Evidências");
        Assert.Contains(rep.Musicas, m => m.Titulo == "Cuida Bem Dela" && m.Artista == null);
    }

    [Fact]
    public void ArtistaNaoPodeAcessarRepertorioDeOutroArtista()
    {
        var repositorio = new RepositorioTocaEssa();
        var tokenAna = repositorio.CriarContaArtista("Ana", "ana@artista.com", "senha").Token;
        var tokenBia = repositorio.CriarContaArtista("Bia", "bia@artista.com", "senha").Token;

        var repertorio = repositorio.CriarRepertorio(tokenAna, "Sertanejo");

        Assert.Throws<RepertorioNaoEncontradoException>(() =>
            repositorio.ExcluirRepertorio(tokenBia, repertorio.Id));
        Assert.Throws<RepertorioNaoEncontradoException>(() =>
            repositorio.AdicionarMusicaAoRepertorio(tokenBia, repertorio.Id, "Música", null));
    }

    [Fact]
    public void RenomearRepertorioMantemAsMusicas()
    {
        var repositorio = new RepositorioTocaEssa();
        var token = repositorio.CriarContaArtista("Ana", "ana@artista.com", "senha").Token;
        var repertorio = repositorio.CriarRepertorio(token, "Sertanejo");
        repositorio.AdicionarMusicaAoRepertorio(token, repertorio.Id, "Evidências", null);

        var renomeado = repositorio.RenomearRepertorio(token, repertorio.Id, "  Barzinho  ");

        Assert.Equal("Barzinho", renomeado.Nome);
        var rep = Assert.Single(repositorio.ListarRepertorios(token));
        Assert.Equal("Barzinho", rep.Nome);
        Assert.Single(rep.Musicas);
    }

    [Fact]
    public void ArtistaNaoPodeRenomearRepertorioDeOutroArtista()
    {
        var repositorio = new RepositorioTocaEssa();
        var tokenAna = repositorio.CriarContaArtista("Ana", "ana@artista.com", "senha").Token;
        var tokenBia = repositorio.CriarContaArtista("Bia", "bia@artista.com", "senha").Token;
        var repertorio = repositorio.CriarRepertorio(tokenAna, "Sertanejo");

        Assert.Throws<RepertorioNaoEncontradoException>(() =>
            repositorio.RenomearRepertorio(tokenBia, repertorio.Id, "Invadido"));
        Assert.Equal("Sertanejo", Assert.Single(repositorio.ListarRepertorios(tokenAna)).Nome);
    }

    [Fact]
    public void NomeDoRepertorioRenomeadoSobreviveAoReinicio()
    {
        var arquivo = Path.Combine(Path.GetTempPath(),
            $"tocaessa-renomear-repertorio-{Guid.NewGuid()}.db");
        try
        {
            var repositorio = new RepositorioTocaEssa(arquivo);
            var token = repositorio.CriarContaArtista("Ana", "ana@artista.com", "senha").Token;
            var repertorio = repositorio.CriarRepertorio(token, "Sertanejo");

            repositorio.RenomearRepertorio(token, repertorio.Id, "Barzinho");
            var reiniciado = new RepositorioTocaEssa(arquivo);

            Assert.Equal("Barzinho", Assert.Single(reiniciado.ListarRepertorios(token)).Nome);
        }
        finally
        {
            Microsoft.Data.Sqlite.SqliteConnection.ClearAllPools();
            foreach (var caminho in new[] { arquivo, $"{arquivo}-shm", $"{arquivo}-wal" })
                if (File.Exists(caminho)) File.Delete(caminho);
        }
    }

    [Fact]
    public void ExcluirRepertorioRemoveSuasMusicas()
    {
        var repositorio = new RepositorioTocaEssa();
        var token = repositorio.CriarContaArtista("Ana", "ana@artista.com", "senha").Token;

        var repertorio = repositorio.CriarRepertorio(token, "Rock");
        repositorio.AdicionarMusicaAoRepertorio(token, repertorio.Id, "Bohemian Rhapsody", "Queen");
        repositorio.ExcluirRepertorio(token, repertorio.Id);

        Assert.Empty(repositorio.ListarRepertorios(token));
    }

    [Fact]
    public void ImportarRepertorioParaApresentacaoCopiaMusicas()
    {
        var repositorio = new RepositorioTocaEssa();
        var token = repositorio.CriarContaArtista("Ana", "ana@artista.com", "senha").Token;
        repositorio.SalvarPerfilDaConta(token,
            new SalvarPerfilArtistico("Ana Rock", null));
        var show = repositorio.CriarApresentacao(token, "Show de Rock",
            new DateOnly(2026, 10, 1), "Bar");

        var repertorio = repositorio.CriarRepertorio(token, "Rock");
        repositorio.AdicionarMusicaAoRepertorio(token, repertorio.Id,
            "Bohemian Rhapsody", "Queen");
        repositorio.AdicionarMusicaAoRepertorio(token, repertorio.Id,
            "Hotel California", "Eagles");

        var setlist = repositorio.ImportarRepertorioParaSetlist(token, show.Id, repertorio.Id);

        Assert.Equal(2, setlist.Count);
        Assert.All(setlist, item => Assert.False(item.Tocada));
        Assert.Contains(setlist, item => item.Titulo == "Bohemian Rhapsody" &&
                                         item.Artista == "Queen");
        Assert.Contains(setlist, item => item.Titulo == "Hotel California");
    }

    [Fact]
    public void ArtistaMarcaItemComoTocado()
    {
        var repositorio = new RepositorioTocaEssa();
        var token = repositorio.CriarContaArtista("Ana", "ana@artista.com", "senha").Token;
        repositorio.SalvarPerfilDaConta(token, new SalvarPerfilArtistico("Ana Rock", null));
        var show = repositorio.CriarApresentacao(token, "Show",
            new DateOnly(2026, 10, 1), "Bar");
        var repertorio = repositorio.CriarRepertorio(token, "Rock");
        repositorio.AdicionarMusicaAoRepertorio(token, repertorio.Id,
            "Bohemian Rhapsody", "Queen");
        repositorio.AdicionarMusicaAoRepertorio(token, repertorio.Id,
            "Hotel California", "Eagles");
        var setlist = repositorio.ImportarRepertorioParaSetlist(token, show.Id, repertorio.Id);

        var item = setlist.First(x => x.Titulo == "Bohemian Rhapsody");
        var atualizado = repositorio.MarcarItemDoSetlist(token, show.Id, item.Id, true);

        Assert.True(atualizado.Tocada);
        Assert.False(repositorio.ObterSetlist(token, show.Id)
            .First(x => x.Titulo == "Hotel California").Tocada);
    }

    [Fact]
    public void SetlistEIndependentePorApresentacao()
    {
        var repositorio = new RepositorioTocaEssa();
        var token = repositorio.CriarContaArtista("Ana", "ana@artista.com", "senha").Token;
        repositorio.SalvarPerfilDaConta(token, new SalvarPerfilArtistico("Ana Rock", null));
        var show1 = repositorio.CriarApresentacao(token, "Show 1",
            new DateOnly(2026, 10, 1), "Bar A");
        var show2 = repositorio.CriarApresentacao(token, "Show 2",
            new DateOnly(2026, 10, 2), "Bar B");
        var repertorio = repositorio.CriarRepertorio(token, "Rock");
        repositorio.AdicionarMusicaAoRepertorio(token, repertorio.Id,
            "Bohemian Rhapsody", "Queen");

        var setlist1 = repositorio.ImportarRepertorioParaSetlist(token, show1.Id, repertorio.Id);
        var setlist2 = repositorio.ImportarRepertorioParaSetlist(token, show2.Id, repertorio.Id);

        repositorio.MarcarItemDoSetlist(token, show1.Id, setlist1.First().Id, true);

        Assert.True(repositorio.ObterSetlist(token, show1.Id).First().Tocada);
        Assert.False(repositorio.ObterSetlist(token, show2.Id).First().Tocada);
    }

    [Fact]
    public void ImportarSubstituiSetlistExistente()
    {
        var repositorio = new RepositorioTocaEssa();
        var token = repositorio.CriarContaArtista("Ana", "ana@artista.com", "senha").Token;
        repositorio.SalvarPerfilDaConta(token, new SalvarPerfilArtistico("Ana Rock", null));
        var show = repositorio.CriarApresentacao(token, "Show",
            new DateOnly(2026, 10, 1), "Bar");
        var rock = repositorio.CriarRepertorio(token, "Rock");
        repositorio.AdicionarMusicaAoRepertorio(token, rock.Id, "Bohemian Rhapsody", "Queen");
        var mpb = repositorio.CriarRepertorio(token, "MPB");
        repositorio.AdicionarMusicaAoRepertorio(token, mpb.Id, "Aquarela", "Toquinho");

        repositorio.ImportarRepertorioParaSetlist(token, show.Id, rock.Id);
        var setlistFinal = repositorio.ImportarRepertorioParaSetlist(token, show.Id, mpb.Id);

        Assert.Single(setlistFinal);
        Assert.Equal("Aquarela", setlistFinal.First().Titulo);
    }

    [Fact]
    public void ArtistaNaoPodeMarcarItemDeOutroArtista()
    {
        var repositorio = new RepositorioTocaEssa();
        var tokenAna = repositorio.CriarContaArtista("Ana", "ana@artista.com", "senha").Token;
        var tokenBia = repositorio.CriarContaArtista("Bia", "bia@artista.com", "senha").Token;
        repositorio.SalvarPerfilDaConta(tokenAna, new SalvarPerfilArtistico("Ana", null));
        repositorio.SalvarPerfilDaConta(tokenBia, new SalvarPerfilArtistico("Bia", null));
        var showAna = repositorio.CriarApresentacao(tokenAna, "Show Ana",
            new DateOnly(2026, 10, 1), "Bar");
        var rep = repositorio.CriarRepertorio(tokenAna, "Rock");
        repositorio.AdicionarMusicaAoRepertorio(tokenAna, rep.Id, "Música", null);
        var setlist = repositorio.ImportarRepertorioParaSetlist(tokenAna, showAna.Id, rep.Id);

        Assert.Throws<ItemDoSetlistNaoEncontradoException>(() =>
            repositorio.MarcarItemDoSetlist(tokenBia, showAna.Id, setlist.First().Id, true));
    }
}
