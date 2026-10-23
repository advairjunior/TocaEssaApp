using Microsoft.EntityFrameworkCore;

namespace TocaEssaApp.Api.Infraestrutura;

/// Estrutura do banco local (SQLite), usado no computador e nos testes.
internal sealed partial class BancoTocaEssa
{
    private void GarantirEstruturaSqlite()
    {
        Database.ExecuteSqlRaw("""
            CREATE TABLE IF NOT EXISTS "PerfisPublicos" (
                "Id" TEXT NOT NULL CONSTRAINT "PK_PerfisPublicos" PRIMARY KEY,
                "Nome" TEXT NOT NULL,
                "Email" TEXT NOT NULL,
                "EmailNormalizado" TEXT NOT NULL,
                "SenhaHash" TEXT NOT NULL,
                "FotoUrl" TEXT NULL,
                "CriadoEm" TEXT NOT NULL
            );
            CREATE UNIQUE INDEX IF NOT EXISTS "IX_PerfisPublicos_EmailNormalizado"
                ON "PerfisPublicos" ("EmailNormalizado");
            CREATE TABLE IF NOT EXISTS "SessoesPublicas" (
                "TokenHash" TEXT NOT NULL CONSTRAINT "PK_SessoesPublicas" PRIMARY KEY,
                "PublicoId" TEXT NOT NULL,
                "ExpiraEm" TEXT NOT NULL
            );
            CREATE INDEX IF NOT EXISTS "IX_SessoesPublicas_PublicoId"
                ON "SessoesPublicas" ("PublicoId");
            CREATE TABLE IF NOT EXISTS "ParticipacoesResenha" (
                "ApresentacaoId" TEXT NOT NULL,
                "PublicoId" TEXT NOT NULL,
                "EntrouEm" TEXT NOT NULL,
                CONSTRAINT "PK_ParticipacoesResenha"
                    PRIMARY KEY ("ApresentacaoId", "PublicoId")
            );
            CREATE INDEX IF NOT EXISTS "IX_ParticipacoesResenha_PublicoId"
                ON "ParticipacoesResenha" ("PublicoId");
            CREATE TABLE IF NOT EXISTS "AcessosAoEvento" (
                "ApresentacaoId" TEXT NOT NULL,
                "Visitante" TEXT NOT NULL,
                "AcessouEm" TEXT NOT NULL,
                CONSTRAINT "PK_AcessosAoEvento"
                    PRIMARY KEY ("ApresentacaoId", "Visitante")
            );
            CREATE TABLE IF NOT EXISTS "ContasArtistas" (
                "Id" TEXT NOT NULL CONSTRAINT "PK_ContasArtistas" PRIMARY KEY,
                "Nome" TEXT NOT NULL,
                "Email" TEXT NOT NULL,
                "EmailNormalizado" TEXT NOT NULL,
                "SenhaHash" TEXT NOT NULL,
                "CriadoEm" TEXT NOT NULL
            );
            CREATE UNIQUE INDEX IF NOT EXISTS "IX_ContasArtistas_EmailNormalizado"
                ON "ContasArtistas" ("EmailNormalizado");
            CREATE TABLE IF NOT EXISTS "SessoesArtistas" (
                "TokenHash" TEXT NOT NULL CONSTRAINT "PK_SessoesArtistas" PRIMARY KEY,
                "ArtistaId" TEXT NOT NULL,
                "ExpiraEm" TEXT NOT NULL
            );
            CREATE INDEX IF NOT EXISTS "IX_SessoesArtistas_ArtistaId"
                ON "SessoesArtistas" ("ArtistaId");
            CREATE TABLE IF NOT EXISTS "AvaliacoesPedidos" (
                "PedidoId" TEXT NOT NULL,
                "IdentificadorAvaliador" TEXT NOT NULL,
                "PublicoId" TEXT NULL,
                "Estrelas" INTEGER NOT NULL,
                "AvaliadoEm" TEXT NOT NULL,
                CONSTRAINT "PK_AvaliacoesPedidos"
                    PRIMARY KEY ("PedidoId", "IdentificadorAvaliador")
            );
            CREATE INDEX IF NOT EXISTS "IX_AvaliacoesPedidos_PedidoId"
                ON "AvaliacoesPedidos" ("PedidoId");
            CREATE TABLE IF NOT EXISTS "Imagens" (
                "Chave" TEXT NOT NULL CONSTRAINT "PK_Imagens" PRIMARY KEY,
                "TipoDeConteudo" TEXT NOT NULL,
                "Conteudo" BLOB NOT NULL,
                "AtualizadaEm" TEXT NOT NULL
            );
            CREATE TABLE IF NOT EXISTS "CifrasDoArtista" (
                "Id" TEXT NOT NULL CONSTRAINT "PK_CifrasDoArtista" PRIMARY KEY,
                "ArtistaId" TEXT NOT NULL,
                "Musica" TEXT NOT NULL,
                "Artista" TEXT NULL,
                "MusicaNormalizada" TEXT NOT NULL,
                "ArtistaNormalizado" TEXT NOT NULL,
                "Url" TEXT NOT NULL,
                "Fonte" TEXT NOT NULL,
                "CriadaEm" TEXT NOT NULL,
                "AtualizadaEm" TEXT NOT NULL
            );
            CREATE UNIQUE INDEX IF NOT EXISTS "IX_CifrasDoArtista_Chave"
                ON "CifrasDoArtista" ("ArtistaId", "MusicaNormalizada", "ArtistaNormalizado");
            CREATE TABLE IF NOT EXISTS "CifrasEmTexto" (
                "Id" TEXT NOT NULL CONSTRAINT "PK_CifrasEmTexto" PRIMARY KEY,
                "ArtistaId" TEXT NOT NULL,
                "Musica" TEXT NOT NULL,
                "Artista" TEXT NULL,
                "MusicaNormalizada" TEXT NOT NULL,
                "ArtistaNormalizado" TEXT NOT NULL,
                "Conteudo" TEXT NOT NULL,
                "AtualizadaEm" TEXT NOT NULL
            );
            CREATE UNIQUE INDEX IF NOT EXISTS "IX_CifrasEmTexto_Chave"
                ON "CifrasEmTexto" ("ArtistaId", "MusicaNormalizada", "ArtistaNormalizado");
            CREATE TABLE IF NOT EXISTS "EnviosDoPublico" (
                "Id" TEXT NOT NULL CONSTRAINT "PK_EnviosDoPublico" PRIMARY KEY,
                "ApresentacaoId" TEXT NOT NULL,
                "ArtistaId" TEXT NOT NULL,
                "Chave" TEXT NOT NULL,
                "Tipo" INTEGER NOT NULL,
                "TipoDeConteudo" TEXT NOT NULL,
                "Tamanho" INTEGER NOT NULL,
                "Nome" TEXT NULL,
                "IdentificadorDoAparelho" TEXT NOT NULL,
                "CriadoEm" TEXT NOT NULL,
                "ExpiraEm" TEXT NOT NULL,
                "Confirmado" INTEGER NOT NULL DEFAULT 0,
                "Escondido" INTEGER NOT NULL DEFAULT 0,
                "Denuncias" TEXT NOT NULL DEFAULT ''
            );
            CREATE INDEX IF NOT EXISTS "IX_EnviosDoPublico_ApresentacaoId"
                ON "EnviosDoPublico" ("ApresentacaoId");
            CREATE TABLE IF NOT EXISTS "Repertorios" (
                "Id" TEXT NOT NULL CONSTRAINT "PK_Repertorios" PRIMARY KEY,
                "ArtistaId" TEXT NOT NULL,
                "Nome" TEXT NOT NULL,
                "CriadoEm" TEXT NOT NULL
            );
            CREATE INDEX IF NOT EXISTS "IX_Repertorios_ArtistaId"
                ON "Repertorios" ("ArtistaId");
            CREATE TABLE IF NOT EXISTS "MusicasDoRepertorio" (
                "Id" TEXT NOT NULL CONSTRAINT "PK_MusicasDoRepertorio" PRIMARY KEY,
                "RepertorioId" TEXT NOT NULL,
                "ArtistaId" TEXT NOT NULL,
                "Titulo" TEXT NOT NULL,
                "Artista" TEXT NULL,
                "Tom" TEXT NULL,
                "Ordem" INTEGER NOT NULL DEFAULT 0
            );
            CREATE INDEX IF NOT EXISTS "IX_MusicasDoRepertorio_RepertorioId"
                ON "MusicasDoRepertorio" ("RepertorioId");
            CREATE TABLE IF NOT EXISTS "ItensDoSetlist" (
                "Id" TEXT NOT NULL CONSTRAINT "PK_ItensDoSetlist" PRIMARY KEY,
                "ApresentacaoId" TEXT NOT NULL,
                "ArtistaId" TEXT NOT NULL,
                "MusicaDoRepertorioId" TEXT NULL,
                "Titulo" TEXT NOT NULL,
                "Artista" TEXT NULL,
                "Tom" TEXT NULL,
                "Tocada" INTEGER NOT NULL DEFAULT 0,
                "Ordem" INTEGER NOT NULL DEFAULT 0
            );
            CREATE INDEX IF NOT EXISTS "IX_ItensDoSetlist_ApresentacaoId"
                ON "ItensDoSetlist" ("ApresentacaoId");
            """);

        using var comando = Database.GetDbConnection().CreateCommand();
        comando.CommandText = "PRAGMA table_info('PedidosMusicais')";
        Database.OpenConnection();
        using var leitor = comando.ExecuteReader();
        var possuiPublicoId = false;
        while (leitor.Read())
            if (string.Equals(leitor.GetString(1), "PublicoId", StringComparison.OrdinalIgnoreCase))
                possuiPublicoId = true;
        leitor.Close();
        if (!possuiPublicoId)
            Database.ExecuteSqlRaw(
                "ALTER TABLE \"PedidosMusicais\" ADD COLUMN \"PublicoId\" TEXT NULL");

        comando.CommandText = "PRAGMA table_info('PedidosMusicais')";
        using var leitorAvaliacao = comando.ExecuteReader();
        var possuiAvaliacao = false;
        while (leitorAvaliacao.Read())
            if (string.Equals(leitorAvaliacao.GetString(1), "Avaliacao", StringComparison.OrdinalIgnoreCase))
                possuiAvaliacao = true;
        leitorAvaliacao.Close();
        if (!possuiAvaliacao)
            Database.ExecuteSqlRaw(
                "ALTER TABLE \"PedidosMusicais\" ADD COLUMN \"Avaliacao\" INTEGER NULL");

        AdicionarColunaSqliteSeNecessario(
            comando, "PedidosMusicais", "FormaParticipacao",
            "INTEGER NOT NULL DEFAULT 0");
        AdicionarColunaSqliteSeNecessario(
            comando, "PedidosMusicais", "TomPreferido", "TEXT NULL");
        AdicionarColunaSqliteSeNecessario(
            comando, "PedidosMusicais", "Recado", "TEXT NULL");
        AdicionarColunaSqliteSeNecessario(
            comando, "PedidosMusicais", "Tipo", "INTEGER NOT NULL DEFAULT 0");
        AdicionarColunaSqliteSeNecessario(
            comando, "EnviosDoPublico", "DoArtista", "INTEGER NOT NULL DEFAULT 0");
        AdicionarColunaSqliteSeNecessario(
            comando, "PedidosMusicais", "DestinatarioAlo", "TEXT NULL");
        AdicionarColunaSqliteSeNecessario(
            comando, "PerfisArtisticos", "Instagram", "TEXT NULL");
        AdicionarColunaSqliteSeNecessario(
            comando, "PerfisArtisticos", "ExibirInstagram", "INTEGER NOT NULL DEFAULT 0");
        AdicionarColunaSqliteSeNecessario(
            comando, "PerfisArtisticos", "Whatsapp", "TEXT NULL");
        AdicionarColunaSqliteSeNecessario(
            comando, "PerfisArtisticos", "ExibirWhatsapp", "INTEGER NOT NULL DEFAULT 0");
        AdicionarColunaSqliteSeNecessario(
            comando, "PerfisArtisticos", "PixAtivo", "INTEGER NOT NULL DEFAULT 0");
        AdicionarColunaSqliteSeNecessario(
            comando, "PerfisArtisticos", "PixChave", "TEXT NULL");
        AdicionarColunaSqliteSeNecessario(
            comando, "PerfisArtisticos", "PixNomeBeneficiario", "TEXT NULL");
        AdicionarColunaSqliteSeNecessario(
            comando, "PerfisArtisticos", "PixCidadeBeneficiario", "TEXT NULL");
        AdicionarColunaSqliteSeNecessario(
            comando, "PerfisArtisticos", "PixMensagem", "TEXT NULL");
        AdicionarColunaSqliteSeNecessario(
            comando, "MusicasDoRepertorio", "Tom", "TEXT NULL");
        AdicionarColunaSqliteSeNecessario(
            comando, "ItensDoSetlist", "Tom", "TEXT NULL");
        AdicionarColunaSqliteSeNecessario(
            comando, "ItensDoSetlist", "MusicaDoRepertorioId", "TEXT NULL");

        comando.CommandText = "PRAGMA table_info('Apresentacoes')";
        using var leitorFotoRetrospectiva = comando.ExecuteReader();
        var possuiFotoRetrospectiva = false;
        while (leitorFotoRetrospectiva.Read())
            if (string.Equals(leitorFotoRetrospectiva.GetString(1), "FotoRetrospectivaUrl",
                    StringComparison.OrdinalIgnoreCase))
                possuiFotoRetrospectiva = true;
        leitorFotoRetrospectiva.Close();
        if (!possuiFotoRetrospectiva)
            Database.ExecuteSqlRaw(
                "ALTER TABLE \"Apresentacoes\" ADD COLUMN \"FotoRetrospectivaUrl\" TEXT NULL");

        MigrarPropriedadeSqlite(comando);
        // Depois da migração de propriedade, que pode reconstruir a tabela.
        AdicionarColunaSqliteSeNecessario(
            comando, "Apresentacoes", "PedidosASeguir", "TEXT NULL");
        AdicionarColunaSqliteSeNecessario(
            comando, "Apresentacoes", "DuracaoContratadaMinutos", "INTEGER NULL");
        AdicionarColunaSqliteSeNecessario(
            comando, "Apresentacoes", "IntervaloPausaRelogio", "INTEGER NOT NULL DEFAULT 0");
        AdicionarColunaSqliteSeNecessario(
            comando, "Apresentacoes", "IniciadaEm", "TEXT NULL");
        AdicionarColunaSqliteSeNecessario(
            comando, "Apresentacoes", "EmIntervaloDesde", "TEXT NULL");
        AdicionarColunaSqliteSeNecessario(
            comando, "Apresentacoes", "SegundosEmIntervalo", "INTEGER NOT NULL DEFAULT 0");
        AdicionarColunaSqliteSeNecessario(
            comando, "Apresentacoes", "EncerradaEm", "TEXT NULL");
        AdicionarColunaSqliteSeNecessario(
            comando, "Apresentacoes", "CantoresDoLouvor", "TEXT NULL");
        AdicionarColunaSqliteSeNecessario(
            comando, "Apresentacoes", "EscolhasDoLouvor", "TEXT NULL");
        AdicionarColunaSqliteSeNecessario(
            comando, "Apresentacoes", "SolistasDoLouvor", "TEXT NULL");
        AdicionarColunaSqliteSeNecessario(
            comando, "Apresentacoes", "ConfiguracaoDoLouvor", "TEXT NULL");
        AdicionarColunaSqliteSeNecessario(
            comando, "Apresentacoes", "CoralDoLouvor", "TEXT NULL");
    }
}
