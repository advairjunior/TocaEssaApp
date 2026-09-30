using Microsoft.Data.Sqlite;
using TocaEssaApp.Api.Infraestrutura;

namespace TocaEssaApp.Testes;

public sealed class MigracaoMultiartistaTestes
{
    private static readonly Guid ArtistaId = Guid.Parse("11111111-1111-1111-1111-111111111111");
    private static readonly Guid PerfilId = Guid.Parse("22222222-2222-2222-2222-222222222222");
    private static readonly Guid ApresentacaoId = Guid.Parse("33333333-3333-3333-3333-333333333333");

    [Fact]
    public void BancoLegadoComUmaContaAdotaPerfilEApresentacoes()
    {
        var caminho = CaminhoTemporario();
        try
        {
            CriarBancoLegado(caminho, incluirConta: true);

            _ = new RepositorioTocaEssa(caminho);

            using var conexao = Abrir(caminho);
            var colunaPerfil = ObterColuna(conexao, "PerfisArtisticos", "ArtistaId");
            var colunaApresentacao = ObterColuna(conexao, "Apresentacoes", "ArtistaId");
            Assert.True(colunaPerfil.Existe);
            Assert.True(colunaPerfil.Obrigatoria);
            Assert.True(colunaApresentacao.Existe);
            Assert.True(colunaApresentacao.Obrigatoria);
            Assert.Equal(ArtistaId.ToString(), ConsultarTexto(
                conexao, "SELECT \"ArtistaId\" FROM \"PerfisArtisticos\""));
            Assert.Equal(ArtistaId.ToString(), ConsultarTexto(
                conexao, "SELECT \"ArtistaId\" FROM \"Apresentacoes\""));
            Assert.Equal(PerfilId.ToString(), ConsultarTexto(
                conexao, "SELECT \"Id\" FROM \"PerfisArtisticos\""));
            Assert.Equal(ApresentacaoId.ToString(), ConsultarTexto(
                conexao, "SELECT \"Id\" FROM \"Apresentacoes\""));
            Assert.Equal("ABC123", ConsultarTexto(
                conexao, "SELECT \"Codigo\" FROM \"Apresentacoes\""));
        }
        finally
        {
            ExcluirBanco(caminho);
        }
    }

    [Fact]
    public void MigracaoPodeExecutarDuasVezes()
    {
        var caminho = CaminhoTemporario();
        try
        {
            CriarBancoLegado(caminho, incluirConta: true);

            _ = new RepositorioTocaEssa(caminho);
            _ = new RepositorioTocaEssa(caminho);

            using var conexao = Abrir(caminho);
            Assert.True(ObterColuna(conexao, "PerfisArtisticos", "ArtistaId").Existe);
            Assert.True(ObterColuna(conexao, "Apresentacoes", "ArtistaId").Existe);
            Assert.Equal(ArtistaId.ToString(), ConsultarTexto(
                conexao, "SELECT \"ArtistaId\" FROM \"PerfisArtisticos\""));
            Assert.Equal(1L, ConsultarInteiro(
                conexao, "SELECT COUNT(*) FROM \"Apresentacoes\""));
        }
        finally
        {
            ExcluirBanco(caminho);
        }
    }

    [Fact]
    public void BancoLegadoComDadosSemProprietarioUnicoFalhaSemAlterarDados()
    {
        var caminho = CaminhoTemporario();
        try
        {
            CriarBancoLegado(caminho, incluirConta: false);

            Assert.Throws<InvalidOperationException>(() => new RepositorioTocaEssa(caminho));

            using var conexao = Abrir(caminho);
            Assert.False(ObterColuna(conexao, "PerfisArtisticos", "ArtistaId").Existe);
            Assert.False(ObterColuna(conexao, "Apresentacoes", "ArtistaId").Existe);
            Assert.Equal(PerfilId.ToString(), ConsultarTexto(
                conexao, "SELECT \"Id\" FROM \"PerfisArtisticos\""));
            Assert.Equal("ABC123", ConsultarTexto(
                conexao, "SELECT \"Codigo\" FROM \"Apresentacoes\""));
        }
        finally
        {
            ExcluirBanco(caminho);
        }
    }

    private static void CriarBancoLegado(string caminho, bool incluirConta)
    {
        using var conexao = Abrir(caminho);
        using var comando = conexao.CreateCommand();
        comando.CommandText = """
            CREATE TABLE "PerfisArtisticos" (
                "Id" TEXT NOT NULL PRIMARY KEY,
                "NomeArtistico" TEXT NOT NULL,
                "Bio" TEXT NULL,
                "FotoUrl" TEXT NULL,
                "Instagram" TEXT NULL,
                "ExibirInstagram" INTEGER NOT NULL DEFAULT 0,
                "Whatsapp" TEXT NULL,
                "ExibirWhatsapp" INTEGER NOT NULL DEFAULT 0,
                "PixAtivo" INTEGER NOT NULL DEFAULT 0,
                "PixChave" TEXT NULL,
                "PixNomeBeneficiario" TEXT NULL,
                "PixCidadeBeneficiario" TEXT NULL,
                "PixMensagem" TEXT NULL
            );
            CREATE TABLE "Apresentacoes" (
                "Id" TEXT NOT NULL PRIMARY KEY,
                "Nome" TEXT NOT NULL,
                "Data" TEXT NOT NULL,
                "Local" TEXT NOT NULL,
                "Codigo" TEXT NOT NULL,
                "PedidosAbertos" INTEGER NOT NULL,
                "Status" INTEGER NOT NULL,
                "Tipo" INTEGER NOT NULL,
                "FotoRetrospectivaUrl" TEXT NULL
            );
            CREATE UNIQUE INDEX "IX_Apresentacoes_Codigo" ON "Apresentacoes" ("Codigo");
            CREATE TABLE "PedidosMusicais" (
                "Id" TEXT NOT NULL PRIMARY KEY,
                "ApresentacaoId" TEXT NOT NULL,
                "Musica" TEXT NOT NULL,
                "Artista" TEXT NULL,
                "NomeSolicitante" TEXT NULL,
                "Status" INTEGER NOT NULL,
                "Posicao" INTEGER NULL,
                "CriadoEm" TEXT NOT NULL,
                "PublicoId" TEXT NULL,
                "Avaliacao" INTEGER NULL,
                "FormaParticipacao" INTEGER NOT NULL DEFAULT 0,
                "TomPreferido" TEXT NULL,
                "Recado" TEXT NULL,
                "Tipo" INTEGER NOT NULL DEFAULT 0,
                "DestinatarioAlo" TEXT NULL
            );
            CREATE TABLE "ContasArtistas" (
                "Id" TEXT NOT NULL PRIMARY KEY,
                "Nome" TEXT NOT NULL,
                "Email" TEXT NOT NULL,
                "EmailNormalizado" TEXT NOT NULL,
                "SenhaHash" TEXT NOT NULL,
                "CriadoEm" TEXT NOT NULL
            );
            CREATE UNIQUE INDEX "IX_ContasArtistas_EmailNormalizado"
                ON "ContasArtistas" ("EmailNormalizado");
            """;
        comando.ExecuteNonQuery();

        comando.CommandText = $"""
            INSERT INTO "PerfisArtisticos" ("Id", "NomeArtistico", "Bio")
            VALUES ('{PerfilId}', 'Artista legado', 'Bio');
            INSERT INTO "Apresentacoes"
                ("Id", "Nome", "Data", "Local", "Codigo", "PedidosAbertos", "Status", "Tipo")
            VALUES ('{ApresentacaoId}', 'Show legado', '2026-09-08', 'Bar', 'ABC123', 1, 0, 0);
            """;
        if (incluirConta)
            comando.CommandText += $"""
                INSERT INTO "ContasArtistas"
                    ("Id", "Nome", "Email", "EmailNormalizado", "SenhaHash", "CriadoEm")
                VALUES ('{ArtistaId}', 'Artista', 'artista@teste.com',
                    'ARTISTA@TESTE.COM', 'hash-legado', '2026-09-08 12:00:00+00:00');
                """;
        comando.ExecuteNonQuery();
    }

    private static SqliteConnection Abrir(string caminho)
    {
        var conexao = new SqliteConnection($"Data Source={caminho};Pooling=False");
        conexao.Open();
        return conexao;
    }

    private static (bool Existe, bool Obrigatoria) ObterColuna(
        SqliteConnection conexao, string tabela, string coluna)
    {
        using var comando = conexao.CreateCommand();
        comando.CommandText = $"PRAGMA table_info('{tabela}')";
        using var leitor = comando.ExecuteReader();
        while (leitor.Read())
            if (string.Equals(leitor.GetString(1), coluna, StringComparison.OrdinalIgnoreCase))
                return (true, leitor.GetInt32(3) == 1);
        return (false, false);
    }

    private static string ConsultarTexto(SqliteConnection conexao, string sql)
    {
        using var comando = conexao.CreateCommand();
        comando.CommandText = sql;
        return Assert.IsType<string>(comando.ExecuteScalar());
    }

    private static long ConsultarInteiro(SqliteConnection conexao, string sql)
    {
        using var comando = conexao.CreateCommand();
        comando.CommandText = sql;
        return Assert.IsType<long>(comando.ExecuteScalar());
    }

    private static string CaminhoTemporario() =>
        Path.Combine(Path.GetTempPath(), $"tocaessa-migracao-{Guid.NewGuid():N}.db");

    private static void ExcluirBanco(string caminho)
    {
        foreach (var arquivo in new[] { caminho, $"{caminho}-shm", $"{caminho}-wal" })
            if (File.Exists(arquivo)) File.Delete(arquivo);
    }
}
