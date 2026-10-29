using TocaEssaApp.Api.Dominio;
using TocaEssaApp.Api.Infraestrutura;

namespace TocaEssaApp.Testes;

/// O músico convidado abre no leitor as cifras que o dono preparou para a
/// noite: só as músicas da setlist e dos pedidos daquele evento.
public sealed class CifrasDaNoiteTestes
{
    private const string Cifra = "Tom: A\nA        E\nQuando eu digo que deixei de te amar";

    [Fact]
    public void ConvidadoLeACifraDoDonoDaMusicaDaSetlist()
    {
        var (repo, dono, bia, resenha) = CriarNoite();
        repo.SalvarCifraEmTexto(dono, "Evidências", "Chitãozinho & Xororó", Cifra);
        repo.AdicionarMusicaAvulsaAoSetlist(dono, resenha.Id, "Evidências", "Chitãozinho & Xororó", null, null);

        var cifra = repo.ObterCifraDaNoite(bia, resenha.Id, "evidencias", "Chitãozinho e Xororó");

        Assert.Equal(Cifra, cifra.Texto);
    }

    [Fact]
    public void ConvidadoLeACifraDeUmaMusicaPedida()
    {
        var (repo, dono, bia, resenha) = CriarNoite();
        repo.SalvarCifraEmTexto(dono, "Lua de São Jorge", null, Cifra);
        var carla = repo.CriarPerfilPublico("Carla", $"carla-{Guid.NewGuid():N}@publico.com", "senha123");
        repo.RegistrarParticipacao(resenha.Codigo, carla.Token);
        repo.CriarPedido(resenha.Codigo, "Lua de São Jorge", null, null, carla.Token);

        Assert.Equal(Cifra, repo.ObterCifraDaNoite(bia, resenha.Id, "Lua de São Jorge", null).Texto);
    }

    [Fact]
    public void MusicaForaDaNoiteNaoMostraACifraDoDono()
    {
        var (repo, dono, bia, resenha) = CriarNoite();
        repo.SalvarCifraEmTexto(dono, "Tempo Perdido", null, Cifra);

        var cifra = repo.ObterCifraDaNoite(bia, resenha.Id, "Tempo Perdido", null);

        Assert.Null(cifra.Texto);
        Assert.Null(cifra.Cifra);
    }

    [Fact]
    public void QuemNaoTocaNaNoiteNaoLeCifra()
    {
        var (repo, dono, _, resenha) = CriarNoite();
        var zeca = repo.CriarContaArtista("Zeca", $"zeca-{Guid.NewGuid():N}@artista.com", "senha123").Token;
        repo.AdicionarMusicaAvulsaAoSetlist(dono, resenha.Id, "Evidências", null, null, null);

        Assert.Throws<ApresentacaoNaoEncontradaException>(
            () => repo.ObterCifraDaNoite(zeca, resenha.Id, "Evidências", null));
    }

    private static (RepositorioTocaEssa Repo, string Dono, string Convidado, Apresentacao Evento) CriarNoite()
    {
        var repo = new RepositorioTocaEssa();
        var dono = repo.CriarContaArtista("Advair", $"advair-{Guid.NewGuid():N}@artista.com", "senha123").Token;
        repo.SalvarPerfilDaConta(dono, new SalvarPerfilArtistico("Advair", null));
        var resenha = repo.CriarApresentacao(dono, "Resenha House", new DateOnly(2026, 10, 30), "Casa",
            TipoApresentacao.ResenhaEntreAmigos);
        var bia = repo.CriarContaArtista("Bia", $"bia-{Guid.NewGuid():N}@artista.com", "senha123").Token;
        repo.EntrarPeloConvite(bia, repo.GerarConvite(dono, resenha.Id));
        return (repo, dono, bia, resenha);
    }
}
