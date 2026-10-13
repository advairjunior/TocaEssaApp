using Microsoft.Data.Sqlite;
using TocaEssaApp.Api.Dominio;
using TocaEssaApp.Api.Infraestrutura;

namespace TocaEssaApp.Testes;

public class RelogioDoShowTestes
{
    private static readonly DateTimeOffset Inicio = new(2026, 10, 17, 21, 0, 0, TimeSpan.Zero);

    [Fact]
    public void ShowNovoNaoTemDuracaoNemInicio()
    {
        var cenario = CriarCenario();

        var relogio = cenario.Repo.ObterRelogio(cenario.Token, cenario.Show.Id);

        Assert.Null(relogio.DuracaoContratadaMinutos);
        Assert.False(relogio.IntervaloPausaRelogio);
        Assert.Null(relogio.IniciadaEm);
        Assert.Null(relogio.EmIntervaloDesde);
        Assert.Equal(0, relogio.SegundosEmIntervalo);
        Assert.Equal(Inicio, relogio.Agora);
    }

    [Fact]
    public void PrimeiroIniciarMarcaOInicioEReiniciarNaoZera()
    {
        var cenario = CriarCenario();

        cenario.Repo.AlterarStatusApresentacao(
            cenario.Token, cenario.Show.Id, StatusApresentacao.EmAndamento);
        cenario.Agora = Inicio.AddMinutes(30);
        cenario.Repo.AlterarStatusApresentacao(
            cenario.Token, cenario.Show.Id, StatusApresentacao.Agendada);
        cenario.Repo.AlterarStatusApresentacao(
            cenario.Token, cenario.Show.Id, StatusApresentacao.EmAndamento);

        Assert.Equal(Inicio, cenario.Repo.ObterRelogio(cenario.Token, cenario.Show.Id).IniciadaEm);
    }

    [Fact]
    public void ConfigurarGuardaDuracaoEOpcaoDePausa()
    {
        var cenario = CriarCenario();

        var relogio = cenario.Repo.ConfigurarRelogio(
            cenario.Token, cenario.Show.Id, 240, intervaloPausaRelogio: true);

        Assert.Equal(240, relogio.DuracaoContratadaMinutos);
        Assert.True(relogio.IntervaloPausaRelogio);
        Assert.Null(relogio.IniciadaEm);

        var semDuracao = cenario.Repo.ConfigurarRelogio(
            cenario.Token, cenario.Show.Id, null, intervaloPausaRelogio: false);
        Assert.Null(semDuracao.DuracaoContratadaMinutos);
        Assert.False(semDuracao.IntervaloPausaRelogio);
    }

    [Fact]
    public void IntervaloSomaOTempoParadoAoVoltar()
    {
        var cenario = CriarCenario();
        cenario.Repo.AlterarStatusApresentacao(
            cenario.Token, cenario.Show.Id, StatusApresentacao.EmAndamento);

        cenario.Agora = Inicio.AddMinutes(60);
        var emIntervalo = cenario.Repo.IniciarIntervalo(cenario.Token, cenario.Show.Id);
        Assert.Equal(Inicio.AddMinutes(60), emIntervalo.EmIntervaloDesde);

        // Tocar Intervalo de novo em outro aparelho não reinicia a pausa.
        cenario.Agora = Inicio.AddMinutes(65);
        cenario.Repo.IniciarIntervalo(cenario.Token, cenario.Show.Id);

        cenario.Agora = Inicio.AddMinutes(75);
        var voltou = cenario.Repo.EncerrarIntervalo(cenario.Token, cenario.Show.Id);
        Assert.Null(voltou.EmIntervaloDesde);
        Assert.Equal(15 * 60, voltou.SegundosEmIntervalo);

        // Voltar de novo sem intervalo não muda nada.
        cenario.Agora = Inicio.AddMinutes(80);
        Assert.Equal(15 * 60,
            cenario.Repo.EncerrarIntervalo(cenario.Token, cenario.Show.Id).SegundosEmIntervalo);
    }

    [Fact]
    public void IntervaloSoDepoisDeIniciarOShow()
    {
        var cenario = CriarCenario();

        Assert.Throws<ShowNaoIniciadoException>(() =>
            cenario.Repo.IniciarIntervalo(cenario.Token, cenario.Show.Id));
    }

    [Fact]
    public void EncerrarOShowDuranteOIntervaloFechaOIntervalo()
    {
        var cenario = CriarCenario();
        cenario.Repo.AlterarStatusApresentacao(
            cenario.Token, cenario.Show.Id, StatusApresentacao.EmAndamento);
        cenario.Agora = Inicio.AddMinutes(100);
        cenario.Repo.IniciarIntervalo(cenario.Token, cenario.Show.Id);

        cenario.Agora = Inicio.AddMinutes(110);
        cenario.Repo.AlterarStatusApresentacao(
            cenario.Token, cenario.Show.Id, StatusApresentacao.Encerrada);

        var relogio = cenario.Repo.ObterRelogio(cenario.Token, cenario.Show.Id);
        Assert.Null(relogio.EmIntervaloDesde);
        Assert.Equal(10 * 60, relogio.SegundosEmIntervalo);
    }

    [Fact]
    public void ContaMusicasComecadasEAsQueFaltamNaSequencia()
    {
        var cenario = CriarCenario();
        var repertorio = cenario.Repo.CriarRepertorio(cenario.Token, "Casamentos");
        foreach (var titulo in new[] { "Evidências", "Pense em Mim", "Tempo Perdido" })
            cenario.Repo.AdicionarMusicaAoRepertorio(cenario.Token, repertorio.Id, titulo, null);
        var setlist = cenario.Repo.ImportarRepertorioParaSetlist(
            cenario.Token, cenario.Show.Id, repertorio.Id).ToArray();
        cenario.Repo.MarcarItemDoSetlist(cenario.Token, cenario.Show.Id, setlist[0].Id, tocada: true);
        var tocando = cenario.Repo.CriarPedido(cenario.Show.Codigo, "Asa Branca", null, "Rui");
        var aSeguir = cenario.Repo.CriarPedido(cenario.Show.Codigo, "Garota de Ipanema", null, "Bia");
        cenario.Repo.CriarPedido(cenario.Show.Codigo, "Asa Branca", null, "Leo");
        cenario.Repo.AlterarStatusDoGrupo(
            cenario.Token, cenario.Show.Id, tocando.Id, StatusPedidoMusical.TocandoAgora);
        cenario.Repo.ColocarPedidoASeguir(cenario.Token, cenario.Show.Id, aSeguir.Id, noInicio: false);

        var relogio = cenario.Repo.ObterRelogio(cenario.Token, cenario.Show.Id);

        // Asa Branca pedida por dois conta uma vez só.
        Assert.Equal(2, relogio.MusicasComecadas);
        Assert.Equal(3, relogio.MusicasRestantes);
    }

    [Fact]
    public void OutroArtistaNaoVeNemMexeNoRelogio()
    {
        var cenario = CriarCenario();
        var tokenBia = cenario.Repo.CriarContaArtista("Bia", "bia@artista.com", "senha").Token;

        Assert.Throws<ApresentacaoNaoEncontradaException>(() =>
            cenario.Repo.ObterRelogio(tokenBia, cenario.Show.Id));
        Assert.Throws<ApresentacaoNaoEncontradaException>(() =>
            cenario.Repo.ConfigurarRelogio(tokenBia, cenario.Show.Id, 60, false));
        Assert.Throws<ApresentacaoNaoEncontradaException>(() =>
            cenario.Repo.IniciarIntervalo(tokenBia, cenario.Show.Id));
        Assert.Throws<ApresentacaoNaoEncontradaException>(() =>
            cenario.Repo.EncerrarIntervalo(tokenBia, cenario.Show.Id));
    }

    [Fact]
    public void RelogioSobreviveAoReinicioDoServidor()
    {
        var arquivo = Path.Combine(Path.GetTempPath(), $"tocaessa-relogio-{Guid.NewGuid():N}.db");
        try
        {
            var cenario = CriarCenario(arquivo);
            cenario.Repo.ConfigurarRelogio(cenario.Token, cenario.Show.Id, 240, true);
            cenario.Repo.AlterarStatusApresentacao(
                cenario.Token, cenario.Show.Id, StatusApresentacao.EmAndamento);
            cenario.Agora = Inicio.AddMinutes(90);
            cenario.Repo.IniciarIntervalo(cenario.Token, cenario.Show.Id);

            var reiniciado = new RepositorioTocaEssa(arquivo);
            var relogio = reiniciado.ObterRelogio(cenario.Token, cenario.Show.Id);

            Assert.Equal(240, relogio.DuracaoContratadaMinutos);
            Assert.True(relogio.IntervaloPausaRelogio);
            Assert.Equal(Inicio, relogio.IniciadaEm);
            Assert.Equal(Inicio.AddMinutes(90), relogio.EmIntervaloDesde);
        }
        finally
        {
            ExcluirBanco(arquivo);
        }
    }

    [Fact]
    public void BancoAntigoGanhaORelogioSemPerderDadosEShowAoVivoComecaAoConfigurar()
    {
        var arquivo = Path.Combine(Path.GetTempPath(), $"tocaessa-relogio-legado-{Guid.NewGuid():N}.db");
        try
        {
            var cenario = CriarCenario(arquivo);
            cenario.Repo.CriarPedido(cenario.Show.Codigo, "Evidências", null, "Rui");
            cenario.Repo.AlterarStatusApresentacao(
                cenario.Token, cenario.Show.Id, StatusApresentacao.EmAndamento);
            using (var conexao = new SqliteConnection($"Data Source={arquivo};Pooling=False"))
            {
                conexao.Open();
                using var comando = conexao.CreateCommand();
                foreach (var coluna in new[]
                         {
                             "DuracaoContratadaMinutos", "IntervaloPausaRelogio", "IniciadaEm",
                             "EmIntervaloDesde", "SegundosEmIntervalo"
                         })
                {
                    comando.CommandText = $"ALTER TABLE \"Apresentacoes\" DROP COLUMN \"{coluna}\"";
                    comando.ExecuteNonQuery();
                }
            }

            var migrado = new RepositorioTocaEssa(arquivo) { Agora = () => Inicio.AddMinutes(45) };
            Assert.Null(migrado.ObterRelogio(cenario.Token, cenario.Show.Id).IniciadaEm);
            var configurado = migrado.ConfigurarRelogio(cenario.Token, cenario.Show.Id, 180, false);

            Assert.Equal(Inicio.AddMinutes(45), configurado.IniciadaEm);
            var migradoDeNovo = new RepositorioTocaEssa(arquivo);
            Assert.Equal(180,
                migradoDeNovo.ObterRelogio(cenario.Token, cenario.Show.Id).DuracaoContratadaMinutos);
            Assert.Single(migradoDeNovo.ListarPedidosDoArtista(cenario.Token, cenario.Show.Id));
        }
        finally
        {
            ExcluirBanco(arquivo);
        }
    }

    private static Cenario CriarCenario(string? arquivo = null)
    {
        var repo = new RepositorioTocaEssa(arquivo);
        var token = repo.CriarContaArtista("Ana", "ana@artista.com", "senha").Token;
        repo.SalvarPerfilDaConta(token, new SalvarPerfilArtistico("Ana", null));
        var show = repo.CriarApresentacao(token, "Casamento", new DateOnly(2026, 10, 17), "Salão");
        var cenario = new Cenario(repo, token, show);
        repo.Agora = () => cenario.Agora;
        return cenario;
    }

    private static void ExcluirBanco(string caminho)
    {
        SqliteConnection.ClearAllPools();
        foreach (var arquivo in new[] { caminho, $"{caminho}-shm", $"{caminho}-wal", $"{caminho}.json" })
            if (File.Exists(arquivo)) File.Delete(arquivo);
    }

    private sealed class Cenario(RepositorioTocaEssa repo, string token, Apresentacao show)
    {
        public RepositorioTocaEssa Repo { get; } = repo;
        public string Token { get; } = token;
        public Apresentacao Show { get; } = show;
        public DateTimeOffset Agora { get; set; } = Inicio;
    }
}
