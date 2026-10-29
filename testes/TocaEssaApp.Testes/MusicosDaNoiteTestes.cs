using TocaEssaApp.Api.Dominio;
using TocaEssaApp.Api.Infraestrutura;

namespace TocaEssaApp.Testes;

/// O dono convida os amigos músicos para o evento da noite por um link;
/// quem aceita passa a ter o evento na seção Convites do próprio painel.
public sealed class MusicosDaNoiteTestes
{
    [Fact]
    public void MusicoEntraPeloConviteEVeOEventoNosConvites()
    {
        var repo = new RepositorioTocaEssa();
        var (dono, resenha) = CriarEvento(repo, "Advair", TipoApresentacao.ResenhaEntreAmigos);
        var musico = CriarArtista(repo, "Bia");

        var codigo = repo.GerarConvite(dono, resenha.Id);
        var convite = repo.VerConvite(musico, codigo);
        repo.EntrarPeloConvite(musico, codigo);
        repo.EntrarPeloConvite(musico, codigo);

        Assert.Equal("Resenha House", convite.Evento);
        Assert.Equal("Advair", convite.Dono);
        var convidado = Assert.Single(repo.ListarConvites(musico));
        Assert.Equal(resenha.Id, convidado.ApresentacaoId);
        Assert.Equal("Advair", convidado.Dono);
        Assert.Equal(TipoApresentacao.ResenhaEntreAmigos, convidado.Tipo);
        Assert.Equal(["Advair", "Bia"], repo.ListarMusicos(dono, resenha.Id).Select(m => m.Nome));
        Assert.True(repo.ListarMusicos(dono, resenha.Id)[0].Dono);
        Assert.DoesNotContain(repo.ListarApresentacoes(musico), item => item.Id == resenha.Id);
    }

    [Fact]
    public void LouvorTambemRecebeMusicos()
    {
        var repo = new RepositorioTocaEssa();
        var (dono, louvor) = CriarEvento(repo, "Advair", TipoApresentacao.Louvor);
        var musico = CriarArtista(repo, "Bia");

        repo.EntrarPeloConvite(musico, repo.GerarConvite(dono, louvor.Id));

        Assert.Single(repo.ListarConvites(musico));
    }

    [Theory]
    [InlineData(TipoApresentacao.Karaoke)]
    [InlineData(TipoApresentacao.Publica)]
    public void KaraokeEShowNaoTemConviteDeMusico(TipoApresentacao tipo)
    {
        var repo = new RepositorioTocaEssa();
        var (dono, evento) = CriarEvento(repo, "Advair", tipo);

        Assert.Throws<EventoSemConviteDeMusicoException>(() => repo.GerarConvite(dono, evento.Id));
    }

    [Fact]
    public void LinkNovoDesfazOAnterior()
    {
        var repo = new RepositorioTocaEssa();
        var (dono, resenha) = CriarEvento(repo, "Advair", TipoApresentacao.ResenhaEntreAmigos);
        var musico = CriarArtista(repo, "Bia");
        var antigo = repo.GerarConvite(dono, resenha.Id);

        var novo = repo.GerarConvite(dono, resenha.Id);

        Assert.NotEqual(antigo, novo);
        Assert.Throws<ConviteNaoEncontradoException>(() => repo.VerConvite(musico, antigo));
        Assert.Throws<ConviteNaoEncontradoException>(() => repo.EntrarPeloConvite(musico, antigo));
        Assert.Empty(repo.ListarConvites(musico));
    }

    [Fact]
    public void EventoEncerradoNaoAceitaNemAparece()
    {
        var repo = new RepositorioTocaEssa();
        var (dono, resenha) = CriarEvento(repo, "Advair", TipoApresentacao.ResenhaEntreAmigos);
        var musico = CriarArtista(repo, "Bia");
        var atrasado = CriarArtista(repo, "Caio");
        var codigo = repo.GerarConvite(dono, resenha.Id);
        repo.EntrarPeloConvite(musico, codigo);

        repo.AlterarStatusApresentacao(dono, resenha.Id, StatusApresentacao.Encerrada);

        Assert.Empty(repo.ListarConvites(musico));
        Assert.Throws<ConviteNaoEncontradoException>(() => repo.EntrarPeloConvite(atrasado, codigo));
    }

    [Fact]
    public void DonoAbrindoOProprioConviteNaoViraConvidado()
    {
        var repo = new RepositorioTocaEssa();
        var (dono, resenha) = CriarEvento(repo, "Advair", TipoApresentacao.ResenhaEntreAmigos);

        repo.EntrarPeloConvite(dono, repo.GerarConvite(dono, resenha.Id));

        Assert.Empty(repo.ListarConvites(dono));
        Assert.Single(repo.ListarMusicos(dono, resenha.Id));
    }

    [Fact]
    public void DonoTiraEConvidadoSai()
    {
        var repo = new RepositorioTocaEssa();
        var (dono, resenha) = CriarEvento(repo, "Advair", TipoApresentacao.ResenhaEntreAmigos);
        var bia = CriarArtista(repo, "Bia");
        var caio = CriarArtista(repo, "Caio");
        var codigo = repo.GerarConvite(dono, resenha.Id);
        repo.EntrarPeloConvite(bia, codigo);
        repo.EntrarPeloConvite(caio, codigo);
        var idDaBia = repo.ListarMusicos(dono, resenha.Id).Single(m => m.Nome == "Bia").ArtistaId;
        var idDoCaio = repo.ListarMusicos(dono, resenha.Id).Single(m => m.Nome == "Caio").ArtistaId;

        // Convidado não tira outro convidado.
        Assert.Throws<ApresentacaoNaoEncontradaException>(
            () => repo.TirarMusico(caio, resenha.Id, idDaBia));
        repo.TirarMusico(dono, resenha.Id, idDaBia);
        repo.TirarMusico(caio, resenha.Id, idDoCaio);

        Assert.Empty(repo.ListarConvites(bia));
        Assert.Empty(repo.ListarConvites(caio));
        Assert.Single(repo.ListarMusicos(dono, resenha.Id));
    }

    [Fact]
    public void SoODonoConvidaEVeOsMusicos()
    {
        var repo = new RepositorioTocaEssa();
        var (dono, resenha) = CriarEvento(repo, "Advair", TipoApresentacao.ResenhaEntreAmigos);
        var bia = CriarArtista(repo, "Bia");
        var estranho = CriarArtista(repo, "Zeca");
        repo.EntrarPeloConvite(bia, repo.GerarConvite(dono, resenha.Id));

        Assert.Throws<ApresentacaoNaoEncontradaException>(() => repo.GerarConvite(bia, resenha.Id));
        Assert.Throws<ApresentacaoNaoEncontradaException>(() => repo.GerarConvite(estranho, resenha.Id));
        Assert.Throws<ApresentacaoNaoEncontradaException>(() => repo.ListarMusicos(estranho, resenha.Id));
    }

    [Fact]
    public void ConvidadosEConviteSobrevivemAoReinicio()
    {
        var arquivo = Path.Combine(Path.GetTempPath(), $"tocaessa-musicos-{Guid.NewGuid():N}.db");
        try
        {
            var repo = new RepositorioTocaEssa(arquivo);
            var (dono, resenha) = CriarEvento(repo, "Advair", TipoApresentacao.ResenhaEntreAmigos);
            var bia = CriarArtista(repo, "Bia");
            var codigo = repo.GerarConvite(dono, resenha.Id);
            repo.EntrarPeloConvite(bia, codigo);

            var reiniciado = new RepositorioTocaEssa(arquivo);

            Assert.Single(reiniciado.ListarConvites(bia));
            Assert.Equal("Resenha House", reiniciado.VerConvite(bia, codigo).Evento);
        }
        finally
        {
            foreach (var caminho in new[] { arquivo, $"{arquivo}-shm", $"{arquivo}-wal" })
                if (File.Exists(caminho)) File.Delete(caminho);
        }
    }

    private static string CriarArtista(RepositorioTocaEssa repo, string nome)
    {
        var token = repo.CriarContaArtista(nome, $"{nome}-{Guid.NewGuid():N}@artista.com", "senha123").Token;
        repo.SalvarPerfilDaConta(token, new SalvarPerfilArtistico(nome, null));
        return token;
    }

    private static (string Token, Apresentacao Evento) CriarEvento(
        RepositorioTocaEssa repo, string dono, TipoApresentacao tipo)
    {
        var token = CriarArtista(repo, dono);
        return (token, repo.CriarApresentacao(
            token, "Resenha House", new DateOnly(2026, 10, 30), "Casa do Advair", tipo));
    }
}
