using TocaEssaApp.Api.Dominio;
using TocaEssaApp.Api.Infraestrutura;

namespace TocaEssaApp.Testes;

/// A noite de karaokê: a galera que entrou com conta, o sorteio da ordem,
/// o modo das músicas e as correções do dono da noite.
public sealed class NoiteDeKaraokeTestes
{
    [Fact]
    public void AntesDoSorteioAGaleraApareceNaOrdemDeChegada()
    {
        var cenario = CriarKaraoke();
        var ana = Entrar(cenario, "Ana");
        var bia = Entrar(cenario, "Bia");

        var noite = cenario.Repo.ObterNoiteDeKaraoke(cenario.Token, cenario.Noite.Id);

        Assert.False(noite.Sorteada);
        Assert.True(noite.PodeSortearDeNovo);
        Assert.Equal(["Ana", "Bia"], noite.Ordem.Select(pessoa => pessoa.Nome));
        Assert.Equal([ana, bia], noite.Ordem.Select(pessoa => pessoa.PublicoId));
    }

    [Fact]
    public void SortearMostraAMesmaOrdemParaODonoEParaAGalera()
    {
        var cenario = CriarKaraoke();
        foreach (var nome in new[] { "Ana", "Bia", "Caio", "Davi", "Eva" })
            Entrar(cenario, nome);
        var bia = cenario.Repo.CriarPerfilPublico("Fê", "fe@teste.com", "senha123");
        cenario.Repo.RegistrarParticipacao(cenario.Noite.Codigo, bia.Token);

        var sorteada = cenario.Repo.SortearOrdemDoKaraoke(cenario.Token, cenario.Noite.Id);
        var naGalera = cenario.Repo.ObterNoiteDeKaraoke(cenario.Noite.Codigo, bia.Token);

        Assert.True(sorteada.Sorteada);
        Assert.Equal(6, sorteada.Ordem.Count);
        Assert.Equal(sorteada.Ordem, naGalera.Ordem);
    }

    [Fact]
    public void QuemEntraDepoisDoSorteioFicaNoFim()
    {
        var cenario = CriarKaraoke();
        Entrar(cenario, "Ana");
        Entrar(cenario, "Bia");
        cenario.Repo.SortearOrdemDoKaraoke(cenario.Token, cenario.Noite.Id);

        var caio = Entrar(cenario, "Caio");

        var noite = cenario.Repo.ObterNoiteDeKaraoke(cenario.Token, cenario.Noite.Id);
        Assert.Equal(caio, noite.Ordem[^1].PublicoId);
    }

    [Fact]
    public void PassarAVezTirarEDevolverAPessoa()
    {
        var cenario = CriarKaraoke();
        var ana = Entrar(cenario, "Ana");
        var bia = Entrar(cenario, "Bia");
        var caio = Entrar(cenario, "Caio");

        var passada = cenario.Repo.PassarAVezNoKaraoke(cenario.Token, cenario.Noite.Id, ana);
        Assert.Equal([bia, ana, caio], passada.Ordem.Select(pessoa => pessoa.PublicoId));

        var tirada = cenario.Repo.TirarDaOrdemDoKaraoke(cenario.Token, cenario.Noite.Id, bia);
        Assert.Equal([ana, caio], tirada.Ordem.Select(pessoa => pessoa.PublicoId));
        Assert.Equal(bia, Assert.Single(tirada.ForaDaOrdem).PublicoId);

        var devolvida = cenario.Repo.DevolverAOrdemDoKaraoke(cenario.Token, cenario.Noite.Id, bia);
        Assert.Equal([ana, caio, bia], devolvida.Ordem.Select(pessoa => pessoa.PublicoId));
        Assert.Empty(devolvida.ForaDaOrdem);
    }

    [Fact]
    public void SemEscolherORepertorioValeOQueTemMaisVideosEOModoLivre()
    {
        var cenario = CriarKaraoke();
        var poucos = cenario.Repo.CriarRepertorio(cenario.Token, "Barzinho");
        cenario.Repo.AdicionarMusicaAoRepertorio(cenario.Token, poucos.Id, "Evidências", null);

        var noite = cenario.Repo.ObterNoiteDeKaraoke(cenario.Token, cenario.Noite.Id);

        Assert.Equal(cenario.Playlist.Id, noite.RepertorioId);
        Assert.Equal(ModoDasMusicas.Livre, noite.Modo);
    }

    [Fact]
    public void ConfigurarORepertorioEORoleta()
    {
        var cenario = CriarKaraoke();
        var outro = cenario.Repo.CriarRepertorio(cenario.Token, "Sertanejo");

        var noite = cenario.Repo.ConfigurarKaraoke(cenario.Token, cenario.Noite.Id,
            new ConfiguracaoDoKaraoke(outro.Id, ModoDasMusicas.Roleta));

        Assert.Equal(outro.Id, noite.RepertorioId);
        Assert.Equal(ModoDasMusicas.Roleta, noite.Modo);
    }

    [Fact]
    public void RepertorioDeOutroArtistaNaoServe()
    {
        var cenario = CriarKaraoke();
        var outroToken = cenario.Repo.CriarContaArtista(
            "Zé", $"ze-{Guid.NewGuid():N}@artista.com", "senha").Token;
        var alheio = cenario.Repo.CriarRepertorio(outroToken, "Do Zé");

        Assert.Throws<RepertorioNaoEncontradoException>(() => cenario.Repo.ConfigurarKaraoke(
            cenario.Token, cenario.Noite.Id, new ConfiguracaoDoKaraoke(alheio.Id)));
    }

    [Fact]
    public void ForaDoKaraokeANoiteNaoExiste()
    {
        var cenario = CriarKaraoke();
        var resenha = cenario.Repo.CriarApresentacao(cenario.Token, "Roda",
            new DateOnly(2026, 11, 1), "Casa", TipoApresentacao.ResenhaEntreAmigos);

        Assert.Throws<RecursoDisponivelSomenteNoKaraokeException>(
            () => cenario.Repo.SortearOrdemDoKaraoke(cenario.Token, resenha.Id));
    }

    [Fact]
    public void OutroArtistaNaoSorteiaANoite()
    {
        var cenario = CriarKaraoke();
        var outroToken = cenario.Repo.CriarContaArtista(
            "Zé", $"ze-{Guid.NewGuid():N}@artista.com", "senha").Token;

        Assert.Throws<ApresentacaoNaoEncontradaException>(
            () => cenario.Repo.SortearOrdemDoKaraoke(outroToken, cenario.Noite.Id));
    }

    [Fact]
    public void NaGaleraSoComConta()
    {
        var cenario = CriarKaraoke();

        Assert.Throws<IdentificacaoPublicaObrigatoriaException>(
            () => cenario.Repo.ObterNoiteDeKaraoke(cenario.Noite.Codigo, "token-qualquer"));
    }

    [Fact]
    public void AOrdemEAConfiguracaoFicamGuardadasNoBanco()
    {
        var arquivo = Path.Combine(Path.GetTempPath(), $"tocaessa-karaoke-{Guid.NewGuid():N}.db");
        try
        {
            var cenario = CriarKaraoke(arquivo);
            Entrar(cenario, "Ana");
            Entrar(cenario, "Bia");
            Entrar(cenario, "Caio");
            cenario.Repo.ConfigurarKaraoke(cenario.Token, cenario.Noite.Id,
                new ConfiguracaoDoKaraoke(cenario.Playlist.Id, ModoDasMusicas.Roleta));
            var sorteada = cenario.Repo.SortearOrdemDoKaraoke(cenario.Token, cenario.Noite.Id);

            var reaberto = new RepositorioTocaEssa(arquivo);
            var noite = reaberto.ObterNoiteDeKaraoke(cenario.Token, cenario.Noite.Id);

            Assert.True(noite.Sorteada);
            Assert.Equal(ModoDasMusicas.Roleta, noite.Modo);
            Assert.Equal(sorteada.Ordem, noite.Ordem);
        }
        finally
        {
            Microsoft.Data.Sqlite.SqliteConnection.ClearAllPools();
            File.Delete(arquivo);
        }
    }

    private static Guid Entrar(Cenario cenario, string nome)
    {
        var sessao = cenario.Repo.CriarPerfilPublico(
            nome, $"{nome.ToLowerInvariant()}-{Guid.NewGuid():N}@teste.com", "senha123");
        cenario.Repo.RegistrarParticipacao(cenario.Noite.Codigo, sessao.Token);
        return sessao.Perfil.Id;
    }

    private static Cenario CriarKaraoke(string? arquivo = null)
    {
        var repo = new RepositorioTocaEssa(arquivo);
        var token = repo.CriarContaArtista(
            "Advair", $"advair-{Guid.NewGuid():N}@artista.com", "senha").Token;
        repo.SalvarPerfilDaConta(token, new SalvarPerfilArtistico("Advair", null));
        var noite = repo.CriarApresentacao(token, "Karaokê de sexta",
            new DateOnly(2026, 10, 30), "Casa", TipoApresentacao.Karaoke);
        var playlist = repo.AdicionarMusicasAoRepertorio(token, null, "Karaokê",
        [
            new AdicionarMusicaAoRepertorio("Evidências", null,
                LinkDoVideo: "https://www.youtube.com/watch?v=abc"),
            new AdicionarMusicaAoRepertorio("Trem-Bala", null,
                LinkDoVideo: "https://www.youtube.com/watch?v=def")
        ]).Repertorio;
        return new Cenario(repo, token, noite, playlist);
    }

    private sealed record Cenario(
        RepositorioTocaEssa Repo, string Token, Apresentacao Noite, Repertorio Playlist);
}
