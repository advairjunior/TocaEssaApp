using Microsoft.Data.Sqlite;
using TocaEssaApp.Api.Dominio;
using TocaEssaApp.Api.Infraestrutura;

namespace TocaEssaApp.Testes;

/// Vídeos e fotos que o público manda durante o show: todos do show veem
/// como stories por 24 h depois do fim; o artista guarda por 7 dias.
public class StoriesDoShowTestes
{
    private const long MB = 1024 * 1024;
    private static readonly DateTimeOffset Inicio = new(2026, 10, 17, 21, 0, 0, TimeSpan.Zero);

    [Fact]
    public void EnvioConfirmadoViraStoryParaOPublico()
    {
        var cenario = CriarCenario();
        cenario.Iniciar();

        var envio = cenario.Repo.CriarEnvio(cenario.Show.Codigo,
            new PedidoDeEnvio(TipoDeStory.Video, "video/mp4", 40 * MB, " Ana, mesa 4 ", "aparelho-1"));

        Assert.Equal($"envios/{cenario.Show.Id}/{envio.Id}.mp4", envio.Chave);
        Assert.Empty(cenario.Repo.ListarStoriesDoShow(cenario.Show.Codigo));

        cenario.Repo.ConfirmarEnvio(cenario.Show.Codigo, envio.Id, 40 * MB);

        var story = Assert.Single(cenario.Repo.ListarStoriesDoShow(cenario.Show.Codigo));
        Assert.Equal(envio.Id, story.Id);
        Assert.Equal(TipoDeStory.Video, story.Tipo);
        Assert.Equal("Ana, mesa 4", story.Nome);
        Assert.Equal(Inicio, story.CriadoEm);
    }

    [Fact]
    public void ShowAgendadoJaRecebeEMostraStories()
    {
        var cenario = CriarCenario();

        cenario.Enviar("aparelho-1");

        Assert.Single(cenario.Repo.ListarStoriesDoShow(cenario.Show.Codigo));
    }

    [Fact]
    public void PublicoNaoVeStoryDepoisDos7DiasMesmoComOShowAgendado()
    {
        var cenario = CriarCenario();
        cenario.Enviar("aparelho-1");

        cenario.Agora = Inicio.AddDays(7).AddMinutes(1);

        Assert.Empty(cenario.Repo.ListarStoriesDoShow(cenario.Show.Codigo));
    }

    [Fact]
    public void ArtistaPostaStoryQueOPublicoVeComDestaque()
    {
        var cenario = CriarCenario();
        var envio = cenario.Repo.CriarEnvioDoArtista(cenario.Token, cenario.Show.Id,
            new PedidoDeEnvio(TipoDeStory.Video, "video/quicktime", 30 * MB, null, string.Empty));

        cenario.Repo.ConfirmarEnvioDoArtista(cenario.Token, cenario.Show.Id, envio.Id, 30 * MB);

        var story = Assert.Single(cenario.Repo.ListarStoriesDoShow(cenario.Show.Codigo));
        Assert.True(story.DoArtista);
        Assert.Equal("Duo Aurora", story.Nome);
        Assert.True(Assert.Single(cenario.Repo
            .ListarEnviosDoShow(cenario.Token, cenario.Show.Id).Envios).DoArtista);
    }

    [Fact]
    public void StoryDoArtistaNaoContaNoLimiteDoAparelhoNemSomePorDenuncia()
    {
        var cenario = CriarCenario();
        for (var i = 0; i < 12; i++)
        {
            var envio = cenario.Repo.CriarEnvioDoArtista(cenario.Token, cenario.Show.Id,
                new PedidoDeEnvio(TipoDeStory.Foto, "image/jpeg", MB, null, string.Empty));
            cenario.Repo.ConfirmarEnvioDoArtista(cenario.Token, cenario.Show.Id, envio.Id, MB);
        }
        var primeiro = cenario.Repo.ListarStoriesDoShow(cenario.Show.Codigo)[0].Id;

        for (var i = 1; i <= 3; i++)
            cenario.Repo.DenunciarStory(cenario.Show.Codigo, primeiro, $"denuncia-{i}");

        Assert.Equal(12, cenario.Repo.ListarStoriesDoShow(cenario.Show.Codigo).Count);
        cenario.Enviar("aparelho-1");
    }

    [Fact]
    public void OutroArtistaNaoPostaNoShowDeQuemNaoE()
    {
        var cenario = CriarCenario();
        var tokenBia = cenario.Repo.CriarContaArtista("Bia", "bia@artista.com", "senha").Token;

        Assert.Throws<ApresentacaoNaoEncontradaException>(() =>
            cenario.Repo.CriarEnvioDoArtista(tokenBia, cenario.Show.Id,
                new PedidoDeEnvio(TipoDeStory.Foto, "image/jpeg", MB, null, string.Empty)));
    }

    [Fact]
    public void DepoisDoFimRecebeEMostraPor24HorasEOArtistaContinuaVendo()
    {
        var cenario = CriarCenario();
        cenario.Iniciar();
        cenario.Enviar("aparelho-1");
        cenario.Repo.AlterarStatusApresentacao(
            cenario.Token, cenario.Show.Id, StatusApresentacao.Encerrada);

        cenario.Agora = Inicio.AddHours(23);
        cenario.Enviar("aparelho-2");
        Assert.Equal(2, cenario.Repo.ListarStoriesDoShow(cenario.Show.Codigo).Count);

        cenario.Agora = Inicio.AddHours(25);
        Assert.Throws<StoriesFechadosException>(() => cenario.Enviar("aparelho-3"));
        Assert.Empty(cenario.Repo.ListarStoriesDoShow(cenario.Show.Codigo));
        Assert.Equal(2, cenario.Repo.ListarEnviosDoShow(cenario.Token, cenario.Show.Id).Envios.Count);
    }

    [Theory]
    [InlineData(TipoDeStory.Video, "video/mp4", 101 * MB)]
    [InlineData(TipoDeStory.Video, "video/mp4", 0)]
    [InlineData(TipoDeStory.Foto, "image/jpeg", 16 * MB)]
    [InlineData(TipoDeStory.Video, "text/html", MB)]
    [InlineData(TipoDeStory.Foto, "video/mp4", MB)]
    public void TipoOuTamanhoForaDoLimiteERecusado(TipoDeStory tipo, string tipoDeConteudo, long tamanho)
    {
        var cenario = CriarCenario();
        cenario.Iniciar();

        Assert.Throws<EnvioInvalidoException>(() => cenario.Repo.CriarEnvio(cenario.Show.Codigo,
            new PedidoDeEnvio(tipo, tipoDeConteudo, tamanho, null, "aparelho-1")));
    }

    [Fact]
    public void AparelhoENomeSaoObrigatoriosEDentroDoTamanho()
    {
        var cenario = CriarCenario();
        cenario.Iniciar();

        Assert.Throws<EnvioInvalidoException>(() => cenario.Repo.CriarEnvio(cenario.Show.Codigo,
            new PedidoDeEnvio(TipoDeStory.Foto, "image/jpeg", MB, null, " ")));
        Assert.Throws<EnvioInvalidoException>(() => cenario.Repo.CriarEnvio(cenario.Show.Codigo,
            new PedidoDeEnvio(TipoDeStory.Foto, "image/jpeg", MB, new string('a', 41), "aparelho-1")));
    }

    [Fact]
    public void ArquivoGuardadoDiferenteDoDeclaradoERecusadoESome()
    {
        var cenario = CriarCenario();
        cenario.Iniciar();
        var maior = cenario.Repo.CriarEnvio(cenario.Show.Codigo,
            new PedidoDeEnvio(TipoDeStory.Foto, "image/jpeg", MB, null, "aparelho-1"));
        var faltando = cenario.Repo.CriarEnvio(cenario.Show.Codigo,
            new PedidoDeEnvio(TipoDeStory.Foto, "image/jpeg", MB, null, "aparelho-1"));

        Assert.Throws<EnvioInvalidoException>(() =>
            cenario.Repo.ConfirmarEnvio(cenario.Show.Codigo, maior.Id, 2 * MB));
        Assert.Throws<EnvioInvalidoException>(() =>
            cenario.Repo.ConfirmarEnvio(cenario.Show.Codigo, faltando.Id, null));

        Assert.Throws<EnvioNaoEncontradoException>(() =>
            cenario.Repo.ConfirmarEnvio(cenario.Show.Codigo, maior.Id, MB));
        Assert.Empty(cenario.Repo.ListarEnviosDoShow(cenario.Token, cenario.Show.Id).Envios);
    }

    [Fact]
    public void CadaAparelhoEnviaAte10PorShow()
    {
        var cenario = CriarCenario();
        cenario.Iniciar();
        for (var i = 0; i < 10; i++) cenario.Enviar("aparelho-1");

        Assert.Throws<LimiteDeEnviosException>(() => cenario.Enviar("aparelho-1"));
        cenario.Enviar("aparelho-2");
    }

    [Fact]
    public void ShowRecebeAte3GB()
    {
        var cenario = CriarCenario();
        cenario.Iniciar();
        for (var i = 0; i < 28; i++) cenario.Enviar($"aparelho-{i}", 100 * MB);

        Assert.Throws<LimiteDeEnviosException>(() => cenario.Enviar("aparelho-novo", 100 * MB));
    }

    [Fact]
    public void TresDenunciasEscondemDoPublicoEOArtistaMostraDeNovo()
    {
        var cenario = CriarCenario();
        cenario.Iniciar();
        var story = cenario.Enviar("aparelho-1");

        cenario.Repo.DenunciarStory(cenario.Show.Codigo, story, "denuncia-1");
        cenario.Repo.DenunciarStory(cenario.Show.Codigo, story, "denuncia-2");
        cenario.Repo.DenunciarStory(cenario.Show.Codigo, story, "denuncia-2");
        Assert.Single(cenario.Repo.ListarStoriesDoShow(cenario.Show.Codigo));

        cenario.Repo.DenunciarStory(cenario.Show.Codigo, story, "denuncia-3");
        Assert.Empty(cenario.Repo.ListarStoriesDoShow(cenario.Show.Codigo));
        Assert.True(Assert.Single(cenario.Repo
            .ListarEnviosDoShow(cenario.Token, cenario.Show.Id).Envios).Escondido);

        cenario.Repo.MostrarEnvio(cenario.Token, cenario.Show.Id, story);
        Assert.Single(cenario.Repo.ListarStoriesDoShow(cenario.Show.Codigo));
        cenario.Repo.DenunciarStory(cenario.Show.Codigo, story, "denuncia-4");
        Assert.Single(cenario.Repo.ListarStoriesDoShow(cenario.Show.Codigo));
    }

    [Fact]
    public void ArtistaApagaESomeParaTodos()
    {
        var cenario = CriarCenario();
        cenario.Iniciar();
        var story = cenario.Enviar("aparelho-1");

        var chave = cenario.Repo.ApagarEnvio(cenario.Token, cenario.Show.Id, story);

        Assert.Equal($"envios/{cenario.Show.Id}/{story}.jpg", chave);
        Assert.Empty(cenario.Repo.ListarStoriesDoShow(cenario.Show.Codigo));
        Assert.Empty(cenario.Repo.ListarEnviosDoShow(cenario.Token, cenario.Show.Id).Envios);
    }

    [Fact]
    public void ArtistaVe7DiasEDepoisOEnvioSaiComAChaveParaApagar()
    {
        var cenario = CriarCenario();
        cenario.Iniciar();
        var story = cenario.Enviar("aparelho-1");

        cenario.Agora = Inicio.AddDays(6);
        var envio = Assert.Single(cenario.Repo.ListarEnviosDoShow(cenario.Token, cenario.Show.Id).Envios);
        Assert.Equal(Inicio.AddDays(7), envio.ExpiraEm);

        cenario.Agora = Inicio.AddDays(7).AddMinutes(1);
        var lista = cenario.Repo.ListarEnviosDoShow(cenario.Token, cenario.Show.Id);
        Assert.Empty(lista.Envios);
        Assert.Equal([$"envios/{cenario.Show.Id}/{story}.jpg"], lista.ChavesExpiradas);
        Assert.Empty(cenario.Repo.ListarEnviosDoShow(cenario.Token, cenario.Show.Id).ChavesExpiradas);
    }

    [Fact]
    public void OutroArtistaNaoVeNemMexeNosEnvios()
    {
        var cenario = CriarCenario();
        cenario.Iniciar();
        var story = cenario.Enviar("aparelho-1");
        var tokenBia = cenario.Repo.CriarContaArtista("Bia", "bia@artista.com", "senha").Token;

        Assert.Throws<ApresentacaoNaoEncontradaException>(() =>
            cenario.Repo.ListarEnviosDoShow(tokenBia, cenario.Show.Id));
        Assert.Throws<ApresentacaoNaoEncontradaException>(() =>
            cenario.Repo.ApagarEnvio(tokenBia, cenario.Show.Id, story));
        Assert.Throws<ApresentacaoNaoEncontradaException>(() =>
            cenario.Repo.MostrarEnvio(tokenBia, cenario.Show.Id, story));
        Assert.Single(cenario.Repo.ListarStoriesDoShow(cenario.Show.Codigo));
    }

    [Fact]
    public void CodigoInexistenteNaoEncontra()
    {
        var cenario = CriarCenario();

        Assert.Throws<ApresentacaoNaoEncontradaException>(() =>
            cenario.Repo.ListarStoriesDoShow("ZZZZZZ"));
    }

    [Fact]
    public void StoriesSobrevivemAoReinicioEBancoAntigoGanhaATabela()
    {
        var arquivo = Path.Combine(Path.GetTempPath(), $"tocaessa-stories-{Guid.NewGuid():N}.db");
        try
        {
            var cenario = CriarCenario(arquivo);
            cenario.Iniciar();
            var story = cenario.Enviar("aparelho-1");
            cenario.Repo.DenunciarStory(cenario.Show.Codigo, story, "denuncia-1");

            var reiniciado = new RepositorioTocaEssa(arquivo) { Agora = () => Inicio };
            Assert.Equal(story, Assert.Single(reiniciado.ListarStoriesDoShow(cenario.Show.Codigo)).Id);

            using (var conexao = new SqliteConnection($"Data Source={arquivo};Pooling=False"))
            {
                conexao.Open();
                using var comando = conexao.CreateCommand();
                comando.CommandText = "DROP TABLE \"EnviosDoPublico\"";
                comando.ExecuteNonQuery();
            }
            var migrado = new RepositorioTocaEssa(arquivo) { Agora = () => Inicio };
            Assert.Empty(migrado.ListarStoriesDoShow(cenario.Show.Codigo));
            var novo = migrado.CriarEnvio(cenario.Show.Codigo,
                new PedidoDeEnvio(TipoDeStory.Foto, "image/png", MB, null, "aparelho-2"));
            migrado.ConfirmarEnvio(cenario.Show.Codigo, novo.Id, MB);
            Assert.Single(new RepositorioTocaEssa(arquivo) { Agora = () => Inicio }
                .ListarStoriesDoShow(cenario.Show.Codigo));
        }
        finally
        {
            SqliteConnection.ClearAllPools();
            foreach (var caminho in new[] { arquivo, $"{arquivo}-shm", $"{arquivo}-wal" })
                if (File.Exists(caminho)) File.Delete(caminho);
        }
    }

    [Fact]
    public void TabelaDeStoriesSemAColunaDoArtistaGanhaAColunaSemPerderEnvios()
    {
        var arquivo = Path.Combine(Path.GetTempPath(), $"tocaessa-stories-coluna-{Guid.NewGuid():N}.db");
        try
        {
            var cenario = CriarCenario(arquivo);
            var story = cenario.Enviar("aparelho-1");
            using (var conexao = new SqliteConnection($"Data Source={arquivo};Pooling=False"))
            {
                conexao.Open();
                using var comando = conexao.CreateCommand();
                comando.CommandText = "ALTER TABLE \"EnviosDoPublico\" DROP COLUMN \"DoArtista\"";
                comando.ExecuteNonQuery();
            }

            var migrado = new RepositorioTocaEssa(arquivo) { Agora = () => Inicio };
            var doPublico = Assert.Single(migrado.ListarStoriesDoShow(cenario.Show.Codigo));
            Assert.Equal(story, doPublico.Id);
            Assert.False(doPublico.DoArtista);
            var envio = migrado.CriarEnvioDoArtista(cenario.Token, cenario.Show.Id,
                new PedidoDeEnvio(TipoDeStory.Foto, "image/jpeg", MB, null, string.Empty));
            migrado.ConfirmarEnvioDoArtista(cenario.Token, cenario.Show.Id, envio.Id, MB);
            Assert.Contains(new RepositorioTocaEssa(arquivo) { Agora = () => Inicio }
                .ListarStoriesDoShow(cenario.Show.Codigo), item => item.DoArtista);
        }
        finally
        {
            SqliteConnection.ClearAllPools();
            foreach (var caminho in new[] { arquivo, $"{arquivo}-shm", $"{arquivo}-wal" })
                if (File.Exists(caminho)) File.Delete(caminho);
        }
    }

    [Fact]
    public void ExcluirAApresentacaoApagaOsEnviosDoBanco()
    {
        var arquivo = Path.Combine(Path.GetTempPath(), $"tocaessa-stories-excluir-{Guid.NewGuid():N}.db");
        try
        {
            var cenario = CriarCenario(arquivo);
            cenario.Iniciar();
            cenario.Enviar("aparelho-1");

            cenario.Repo.ExcluirApresentacao(cenario.Token, cenario.Show.Id);

            using var conexao = new SqliteConnection($"Data Source={arquivo};Pooling=False");
            conexao.Open();
            using var comando = conexao.CreateCommand();
            comando.CommandText = "SELECT COUNT(*) FROM \"EnviosDoPublico\"";
            Assert.Equal(0L, (long)comando.ExecuteScalar()!);
        }
        finally
        {
            SqliteConnection.ClearAllPools();
            foreach (var caminho in new[] { arquivo, $"{arquivo}-shm", $"{arquivo}-wal" })
                if (File.Exists(caminho)) File.Delete(caminho);
        }
    }

    private static Cenario CriarCenario(string? arquivo = null)
    {
        var repo = new RepositorioTocaEssa(arquivo);
        var token = repo.CriarContaArtista("Ana", "ana@artista.com", "senha").Token;
        repo.SalvarPerfilDaConta(token, new SalvarPerfilArtistico("Duo Aurora", null));
        var show = repo.CriarApresentacao(token, "Noite Acústica", new DateOnly(2026, 10, 17), "Bar");
        var cenario = new Cenario(repo, token, show);
        repo.Agora = () => cenario.Agora;
        return cenario;
    }

    private sealed class Cenario(RepositorioTocaEssa repo, string token, Apresentacao show)
    {
        public RepositorioTocaEssa Repo { get; } = repo;
        public string Token { get; } = token;
        public Apresentacao Show { get; } = show;
        public DateTimeOffset Agora { get; set; } = Inicio;

        public void Iniciar() =>
            Repo.AlterarStatusApresentacao(Token, Show.Id, StatusApresentacao.EmAndamento);

        /// Manda e confirma uma foto; devolve o id do story.
        public Guid Enviar(string aparelho, long tamanho = MB)
        {
            var tipo = tamanho > 15 * MB ? TipoDeStory.Video : TipoDeStory.Foto;
            var envio = Repo.CriarEnvio(Show.Codigo, new PedidoDeEnvio(
                tipo, tipo == TipoDeStory.Video ? "video/mp4" : "image/jpeg", tamanho, null, aparelho));
            Repo.ConfirmarEnvio(Show.Codigo, envio.Id, tamanho);
            return envio.Id;
        }
    }
}
