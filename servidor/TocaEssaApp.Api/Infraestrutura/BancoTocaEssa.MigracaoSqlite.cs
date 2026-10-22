using Microsoft.EntityFrameworkCore;

namespace TocaEssaApp.Api.Infraestrutura;

/// Migrações do SQLite que precisam ler ou reconstruir tabelas.
internal sealed partial class BancoTocaEssa
{
    private void MigrarPropriedadeSqlite(System.Data.Common.DbCommand comando)
    {
        var colunaPerfil = ObterColunaSqlite(comando, "PerfisArtisticos", "ArtistaId");
        var colunaApresentacao = ObterColunaSqlite(comando, "Apresentacoes", "ArtistaId");
        var perfisOrfaos = colunaPerfil.Existe
            ? ConsultarInteiro(comando,
                "SELECT COUNT(*) FROM \"PerfisArtisticos\" WHERE \"ArtistaId\" IS NULL OR \"ArtistaId\" = ''")
            : ConsultarInteiro(comando, "SELECT COUNT(*) FROM \"PerfisArtisticos\"");
        var apresentacoesOrfas = colunaApresentacao.Existe
            ? ConsultarInteiro(comando,
                "SELECT COUNT(*) FROM \"Apresentacoes\" WHERE \"ArtistaId\" IS NULL OR \"ArtistaId\" = ''")
            : ConsultarInteiro(comando, "SELECT COUNT(*) FROM \"Apresentacoes\"");

        string? artistaId = null;
        if (perfisOrfaos + apresentacoesOrfas > 0)
        {
            var quantidadeContas = ConsultarInteiro(
                comando, "SELECT COUNT(*) FROM \"ContasArtistas\"");
            if (quantidadeContas != 1)
                throw new InvalidOperationException(
                    "Dados artísticos legados exigem exatamente uma conta proprietária.");
            comando.CommandText = "SELECT \"Id\" FROM \"ContasArtistas\" LIMIT 1";
            artistaId = comando.ExecuteScalar() as string
                ?? throw new InvalidOperationException("A conta proprietária não possui ID válido.");
        }

        using var transacao = Database.BeginTransaction();
        if (!colunaPerfil.Existe)
            Database.ExecuteSqlRaw(
                "ALTER TABLE \"PerfisArtisticos\" ADD COLUMN \"ArtistaId\" TEXT NULL");
        if (!colunaApresentacao.Existe)
            Database.ExecuteSqlRaw(
                "ALTER TABLE \"Apresentacoes\" ADD COLUMN \"ArtistaId\" TEXT NULL");
        if (artistaId is not null)
        {
            Database.ExecuteSqlInterpolated(
                $"UPDATE \"PerfisArtisticos\" SET \"ArtistaId\" = {artistaId} WHERE \"ArtistaId\" IS NULL OR \"ArtistaId\" = ''");
            Database.ExecuteSqlInterpolated(
                $"UPDATE \"Apresentacoes\" SET \"ArtistaId\" = {artistaId} WHERE \"ArtistaId\" IS NULL OR \"ArtistaId\" = ''");
        }

        if (!colunaPerfil.Obrigatoria)
            ReconstruirPerfisSqlite();
        if (!colunaApresentacao.Obrigatoria)
            ReconstruirApresentacoesSqlite();
        transacao.Commit();
    }

    private void ReconstruirPerfisSqlite()
    {
        Database.ExecuteSqlRaw("""
            DROP TABLE IF EXISTS "__PerfisArtisticos_Multiartista";
            CREATE TABLE "__PerfisArtisticos_Multiartista" (
                "Id" TEXT NOT NULL CONSTRAINT "PK_PerfisArtisticos" PRIMARY KEY,
                "ArtistaId" TEXT NOT NULL,
                "NomeArtistico" TEXT NOT NULL,
                "Bio" TEXT NULL,
                "FotoUrl" TEXT NULL,
                "Instagram" TEXT NULL,
                "ExibirInstagram" INTEGER NOT NULL,
                "Whatsapp" TEXT NULL,
                "ExibirWhatsapp" INTEGER NOT NULL,
                "PixAtivo" INTEGER NOT NULL,
                "PixChave" TEXT NULL,
                "PixNomeBeneficiario" TEXT NULL,
                "PixCidadeBeneficiario" TEXT NULL,
                "PixMensagem" TEXT NULL
            );
            INSERT INTO "__PerfisArtisticos_Multiartista"
                ("Id", "ArtistaId", "NomeArtistico", "Bio", "FotoUrl", "Instagram",
                 "ExibirInstagram", "Whatsapp", "ExibirWhatsapp", "PixAtivo", "PixChave",
                 "PixNomeBeneficiario", "PixCidadeBeneficiario", "PixMensagem")
            SELECT "Id", "ArtistaId", "NomeArtistico", "Bio", "FotoUrl", "Instagram",
                   "ExibirInstagram", "Whatsapp", "ExibirWhatsapp", "PixAtivo", "PixChave",
                   "PixNomeBeneficiario", "PixCidadeBeneficiario", "PixMensagem"
            FROM "PerfisArtisticos";
            DROP TABLE "PerfisArtisticos";
            ALTER TABLE "__PerfisArtisticos_Multiartista" RENAME TO "PerfisArtisticos";
            CREATE UNIQUE INDEX "IX_PerfisArtisticos_ArtistaId"
                ON "PerfisArtisticos" ("ArtistaId");
            """);
    }

    private void ReconstruirApresentacoesSqlite()
    {
        Database.ExecuteSqlRaw("""
            DROP TABLE IF EXISTS "__Apresentacoes_Multiartista";
            CREATE TABLE "__Apresentacoes_Multiartista" (
                "Id" TEXT NOT NULL CONSTRAINT "PK_Apresentacoes" PRIMARY KEY,
                "ArtistaId" TEXT NOT NULL,
                "Nome" TEXT NOT NULL,
                "Data" TEXT NOT NULL,
                "Local" TEXT NOT NULL,
                "Codigo" TEXT NOT NULL,
                "PedidosAbertos" INTEGER NOT NULL,
                "Status" INTEGER NOT NULL,
                "Tipo" INTEGER NOT NULL,
                "FotoRetrospectivaUrl" TEXT NULL
            );
            INSERT INTO "__Apresentacoes_Multiartista"
                ("Id", "ArtistaId", "Nome", "Data", "Local", "Codigo", "PedidosAbertos",
                 "Status", "Tipo", "FotoRetrospectivaUrl")
            SELECT "Id", "ArtistaId", "Nome", "Data", "Local", "Codigo", "PedidosAbertos",
                   "Status", "Tipo", "FotoRetrospectivaUrl"
            FROM "Apresentacoes";
            DROP TABLE "Apresentacoes";
            ALTER TABLE "__Apresentacoes_Multiartista" RENAME TO "Apresentacoes";
            CREATE UNIQUE INDEX "IX_Apresentacoes_Codigo" ON "Apresentacoes" ("Codigo");
            CREATE INDEX "IX_Apresentacoes_ArtistaId" ON "Apresentacoes" ("ArtistaId");
            """);
    }

    private static (bool Existe, bool Obrigatoria) ObterColunaSqlite(
        System.Data.Common.DbCommand comando, string tabela, string coluna)
    {
        comando.CommandText = $"PRAGMA table_info('{tabela}')";
        using var leitor = comando.ExecuteReader();
        while (leitor.Read())
            if (string.Equals(leitor.GetString(1), coluna, StringComparison.OrdinalIgnoreCase))
                return (true, leitor.GetInt32(3) == 1);
        return (false, false);
    }

    private static long ConsultarInteiro(
        System.Data.Common.DbCommand comando, string consulta)
    {
        comando.CommandText = consulta;
        return Convert.ToInt64(comando.ExecuteScalar());
    }

    private void AdicionarColunaSqliteSeNecessario(
        System.Data.Common.DbCommand comando,
        string tabela,
        string coluna,
        string definicao)
    {
        comando.CommandText = $"PRAGMA table_info('{tabela}')";
        using var leitor = comando.ExecuteReader();
        var existe = false;
        while (leitor.Read())
            if (string.Equals(leitor.GetString(1), coluna,
                    StringComparison.OrdinalIgnoreCase))
                existe = true;
        leitor.Close();
        if (!existe)
#pragma warning disable EF1002 // Nomes e definições vêm apenas de chamadas internas fixas.
            Database.ExecuteSqlRaw(
                $"ALTER TABLE \"{tabela}\" ADD COLUMN \"{coluna}\" {definicao}");
#pragma warning restore EF1002
    }
}
