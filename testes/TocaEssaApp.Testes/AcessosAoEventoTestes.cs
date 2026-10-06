using TocaEssaApp.Api.Dominio;
using TocaEssaApp.Api.Infraestrutura;

namespace TocaEssaApp.Testes;

public sealed class AcessosAoEventoTestes
{
    [Fact]
    public void CadaAparelhoQueAbreOEventoContaUmaVez()
    {
        var (repositorio, sessao, show) = CriarShow(new RepositorioTocaEssa());

        repositorio.RegistrarAcessoAoEvento(show.Codigo, "aparelho-1");
        repositorio.RegistrarAcessoAoEvento(show.Codigo, "aparelho-1");
        repositorio.RegistrarAcessoAoEvento(show.Codigo.ToLowerInvariant(), "aparelho-2");

        var estatisticas = repositorio.ObterEstatisticasDaApresentacao(
            sessao.Token, show.Id);
        Assert.Equal(2, estatisticas.PessoasNoEvento);
        Assert.Equal(0, estatisticas.PessoasQuePediram);
    }

    [Fact]
    public void QuemPediuSemAcessoRegistradoTambemContaComoPublico()
    {
        var (repositorio, sessao, show) = CriarShow(new RepositorioTocaEssa());
        repositorio.RegistrarAcessoAoEvento(show.Codigo, "aparelho-1");
        repositorio.CriarPedido(show.Codigo, "Evidências", null, "Ana");
        repositorio.CriarPedido(show.Codigo, "Sozinho", null, "ana ");
        repositorio.CriarPedido(show.Codigo, "Garçom", null, "Bia");
        repositorio.CriarPedido(show.Codigo, "Exagerado", null, "Caio");

        var estatisticas = repositorio.ObterEstatisticasDaApresentacao(
            sessao.Token, show.Id);

        Assert.Equal(3, estatisticas.PessoasQuePediram);
        Assert.Equal(3, estatisticas.PessoasNoEvento);
    }

    [Fact]
    public void AcessoDepoisDoEncerramentoNaoContaComoPublico()
    {
        var (repositorio, sessao, show) = CriarShow(new RepositorioTocaEssa());
        repositorio.RegistrarAcessoAoEvento(show.Codigo, "aparelho-1");
        repositorio.AlterarStatusApresentacao(
            sessao.Token, show.Id, StatusApresentacao.Encerrada);

        repositorio.RegistrarAcessoAoEvento(show.Codigo, "aparelho-2");

        Assert.Equal(1, repositorio.ObterEstatisticasDaApresentacao(
            sessao.Token, show.Id).PessoasNoEvento);
    }

    [Fact]
    public void AcessoAEventoInexistenteRespondeComoNaoEncontrado()
    {
        var repositorio = new RepositorioTocaEssa();

        Assert.Throws<ApresentacaoNaoEncontradaException>(() =>
            repositorio.RegistrarAcessoAoEvento("NAOEXISTE", "aparelho-1"));
    }

    [Fact]
    public void AcessosSobrevivemAoReinicioESomemComOEventoExcluido()
    {
        var arquivo = Path.Combine(
            Path.GetTempPath(), $"tocaessa-acessos-{Guid.NewGuid():N}.db");
        try
        {
            var (repositorio, sessao, show) = CriarShow(new RepositorioTocaEssa(arquivo));
            repositorio.RegistrarAcessoAoEvento(show.Codigo, "aparelho-1");
            repositorio.RegistrarAcessoAoEvento(show.Codigo, "aparelho-2");

            var reiniciado = new RepositorioTocaEssa(arquivo);
            Assert.Equal(2, reiniciado.ObterEstatisticasDaApresentacao(
                sessao.Token, show.Id).PessoasNoEvento);

            reiniciado.ExcluirApresentacao(sessao.Token, show.Id);
            var (_, _, outroShow) = CriarShow(reiniciado, "outra@artista.com");
            var final = new RepositorioTocaEssa(arquivo);
            Assert.Equal(0, final.ObterEstatisticasDaApresentacao(
                outroShow.Id).PessoasNoEvento);
        }
        finally
        {
            foreach (var item in new[] { arquivo, $"{arquivo}-shm", $"{arquivo}-wal" })
                if (File.Exists(item)) File.Delete(item);
        }
    }

    [Fact]
    public void BancoAntigoSemTabelaDeAcessosGanhaATabelaSemPerderDados()
    {
        var arquivo = Path.Combine(
            Path.GetTempPath(), $"tocaessa-acessos-legado-{Guid.NewGuid():N}.db");
        try
        {
            var (repositorio, sessao, show) = CriarShow(new RepositorioTocaEssa(arquivo));
            repositorio.CriarPedido(show.Codigo, "Evidências", null, "Ana");
            using (var conexao = new Microsoft.Data.Sqlite.SqliteConnection(
                       $"Data Source={arquivo};Pooling=False"))
            {
                conexao.Open();
                using var comando = conexao.CreateCommand();
                comando.CommandText = "DROP TABLE \"AcessosAoEvento\"";
                comando.ExecuteNonQuery();
            }

            var migrado = new RepositorioTocaEssa(arquivo);
            migrado.RegistrarAcessoAoEvento(show.Codigo, "aparelho-1");
            migrado.RegistrarAcessoAoEvento(show.Codigo, "aparelho-2");
            var reaberto = new RepositorioTocaEssa(arquivo);

            var estatisticas = reaberto.ObterEstatisticasDaApresentacao(
                sessao.Token, show.Id);
            Assert.Equal(1, estatisticas.TotalPedidos);
            Assert.Equal(2, estatisticas.PessoasNoEvento);
        }
        finally
        {
            foreach (var item in new[] { arquivo, $"{arquivo}-shm", $"{arquivo}-wal" })
                if (File.Exists(item)) File.Delete(item);
        }
    }

    [Fact]
    public void NaResenhaQuemEntrouPeloPerfilContaComoPublico()
    {
        var repositorio = new RepositorioTocaEssa();
        var sessao = repositorio.CriarContaArtista("Ana", "ana@artista.com", "senha123");
        repositorio.SalvarPerfilDaConta(sessao.Token,
            new SalvarPerfilArtistico("Duo Aurora", null));
        var resenha = repositorio.CriarApresentacao(sessao.Token, "Resenha",
            new DateOnly(2026, 10, 6), "Casa", TipoApresentacao.ResenhaEntreAmigos);
        foreach (var nome in new[] { "Bia", "Caio" })
        {
            var publico = repositorio.CriarPerfilPublico(
                nome, $"{nome}@publico.com", "senha123");
            repositorio.RegistrarParticipacaoNaResenha(resenha.Codigo, publico.Token);
        }

        Assert.Equal(2, repositorio.ObterEstatisticasDaApresentacao(
            sessao.Token, resenha.Id).PessoasNoEvento);
    }

    private static (RepositorioTocaEssa, SessaoDoArtista, Apresentacao) CriarShow(
        RepositorioTocaEssa repositorio, string email = "ana@artista.com")
    {
        var sessao = repositorio.CriarContaArtista("Ana", email, "senha123");
        repositorio.SalvarPerfilDaConta(sessao.Token,
            new SalvarPerfilArtistico("Duo Aurora", null));
        var show = repositorio.CriarApresentacao(sessao.Token, "Show",
            new DateOnly(2026, 10, 6), "Bar", TipoApresentacao.Publica);
        return (repositorio, sessao, show);
    }
}
