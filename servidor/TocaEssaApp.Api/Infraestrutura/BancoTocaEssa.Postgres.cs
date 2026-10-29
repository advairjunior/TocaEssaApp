using Microsoft.EntityFrameworkCore;

namespace TocaEssaApp.Api.Infraestrutura;

/// Estrutura e migrações do banco de produção (PostgreSQL no Neon).
internal sealed partial class BancoTocaEssa
{
    private void GarantirEstruturaPostgres()
    {
        using var consulta = Database.GetDbConnection().CreateCommand();
        consulta.CommandText = "SELECT to_regclass('public.\"PerfisArtisticos\"') IS NOT NULL";
        Database.OpenConnection();
        var estruturaCriada = consulta.ExecuteScalar() as bool? == true;
        if (!estruturaCriada)
            Database.ExecuteSqlRaw(Database.GenerateCreateScript());
        Database.ExecuteSqlRaw("""
            CREATE TABLE IF NOT EXISTS "ParticipacoesResenha" (
                "ApresentacaoId" uuid NOT NULL,
                "PublicoId" uuid NOT NULL,
                "EntrouEm" timestamp with time zone NOT NULL,
                CONSTRAINT "PK_ParticipacoesResenha"
                    PRIMARY KEY ("ApresentacaoId", "PublicoId")
            );
            CREATE INDEX IF NOT EXISTS "IX_ParticipacoesResenha_PublicoId"
                ON "ParticipacoesResenha" ("PublicoId");
            CREATE TABLE IF NOT EXISTS "AcessosAoEvento" (
                "ApresentacaoId" uuid NOT NULL,
                "Visitante" character varying(160) NOT NULL,
                "AcessouEm" timestamp with time zone NOT NULL,
                CONSTRAINT "PK_AcessosAoEvento"
                    PRIMARY KEY ("ApresentacaoId", "Visitante")
            );
            ALTER TABLE "PedidosMusicais"
                ADD COLUMN IF NOT EXISTS "FormaParticipacao" integer NOT NULL DEFAULT 0;
            ALTER TABLE "PedidosMusicais"
                ADD COLUMN IF NOT EXISTS "TomPreferido" character varying(30) NULL;
            ALTER TABLE "PedidosMusicais"
                ADD COLUMN IF NOT EXISTS "Recado" character varying(240) NULL;
            ALTER TABLE "PedidosMusicais"
                ADD COLUMN IF NOT EXISTS "Tipo" integer NOT NULL DEFAULT 0;
            ALTER TABLE "PedidosMusicais"
                ADD COLUMN IF NOT EXISTS "DestinatarioAlo" character varying(120) NULL;
            ALTER TABLE "Apresentacoes"
                ADD COLUMN IF NOT EXISTS "PedidosASeguir" text NULL;
            ALTER TABLE "Apresentacoes"
                ADD COLUMN IF NOT EXISTS "DuracaoContratadaMinutos" integer NULL;
            ALTER TABLE "Apresentacoes"
                ADD COLUMN IF NOT EXISTS "IntervaloPausaRelogio" boolean NOT NULL DEFAULT false;
            ALTER TABLE "Apresentacoes"
                ADD COLUMN IF NOT EXISTS "IniciadaEm" timestamp with time zone NULL;
            ALTER TABLE "Apresentacoes"
                ADD COLUMN IF NOT EXISTS "EmIntervaloDesde" timestamp with time zone NULL;
            ALTER TABLE "Apresentacoes"
                ADD COLUMN IF NOT EXISTS "SegundosEmIntervalo" integer NOT NULL DEFAULT 0;
            ALTER TABLE "Apresentacoes"
                ADD COLUMN IF NOT EXISTS "EncerradaEm" timestamp with time zone NULL;
            ALTER TABLE "Apresentacoes"
                ADD COLUMN IF NOT EXISTS "CantoresDoLouvor" text NULL;
            ALTER TABLE "Apresentacoes"
                ADD COLUMN IF NOT EXISTS "EscolhasDoLouvor" text NULL;
            ALTER TABLE "Apresentacoes"
                ADD COLUMN IF NOT EXISTS "SolistasDoLouvor" text NULL;
            ALTER TABLE "Apresentacoes"
                ADD COLUMN IF NOT EXISTS "ConfiguracaoDoLouvor" text NULL;
            ALTER TABLE "Apresentacoes"
                ADD COLUMN IF NOT EXISTS "CoralDoLouvor" text NULL;
            ALTER TABLE "Apresentacoes"
                ADD COLUMN IF NOT EXISTS "KaraokeDaNoite" text NULL;
            ALTER TABLE "ParticipacoesResenha"
                ADD COLUMN IF NOT EXISTS "NomeNoLouvor" character varying(80) NULL;
            CREATE TABLE IF NOT EXISTS "AvaliacoesPedidos" (
                "PedidoId" uuid NOT NULL,
                "IdentificadorAvaliador" character varying(160) NOT NULL,
                "PublicoId" uuid NULL,
                "Estrelas" integer NOT NULL,
                "AvaliadoEm" timestamp with time zone NOT NULL,
                CONSTRAINT "PK_AvaliacoesPedidos"
                    PRIMARY KEY ("PedidoId", "IdentificadorAvaliador")
            );
            CREATE INDEX IF NOT EXISTS "IX_AvaliacoesPedidos_PedidoId"
                ON "AvaliacoesPedidos" ("PedidoId");
            CREATE TABLE IF NOT EXISTS "Imagens" (
                "Chave" character varying(300) NOT NULL,
                "TipoDeConteudo" character varying(100) NOT NULL,
                "Conteudo" bytea NOT NULL,
                "AtualizadaEm" timestamp with time zone NOT NULL,
                CONSTRAINT "PK_Imagens" PRIMARY KEY ("Chave")
            );
            CREATE TABLE IF NOT EXISTS "CifrasDoArtista" (
                "Id" uuid NOT NULL,
                "ArtistaId" uuid NOT NULL,
                "Musica" character varying(200) NOT NULL,
                "Artista" character varying(200) NULL,
                "MusicaNormalizada" character varying(200) NOT NULL,
                "ArtistaNormalizado" character varying(200) NOT NULL,
                "Url" character varying(2048) NOT NULL,
                "Fonte" character varying(255) NOT NULL,
                "CriadaEm" timestamp with time zone NOT NULL,
                "AtualizadaEm" timestamp with time zone NOT NULL,
                CONSTRAINT "PK_CifrasDoArtista" PRIMARY KEY ("Id")
            );
            CREATE UNIQUE INDEX IF NOT EXISTS "IX_CifrasDoArtista_Chave"
                ON "CifrasDoArtista" ("ArtistaId", "MusicaNormalizada", "ArtistaNormalizado");
            CREATE TABLE IF NOT EXISTS "CifrasEmTexto" (
                "Id" uuid NOT NULL,
                "ArtistaId" uuid NOT NULL,
                "Musica" character varying(200) NOT NULL,
                "Artista" character varying(200) NULL,
                "MusicaNormalizada" character varying(200) NOT NULL,
                "ArtistaNormalizado" character varying(200) NOT NULL,
                "Conteudo" text NOT NULL,
                "AtualizadaEm" timestamp with time zone NOT NULL,
                CONSTRAINT "PK_CifrasEmTexto" PRIMARY KEY ("Id")
            );
            CREATE UNIQUE INDEX IF NOT EXISTS "IX_CifrasEmTexto_Chave"
                ON "CifrasEmTexto" ("ArtistaId", "MusicaNormalizada", "ArtistaNormalizado");
            CREATE TABLE IF NOT EXISTS "TelasDaTv" (
                "Id" uuid NOT NULL,
                "ArtistaId" uuid NOT NULL,
                "TokenHash" character varying(64) NOT NULL,
                "CriadaEm" timestamp with time zone NOT NULL,
                CONSTRAINT "PK_TelasDaTv" PRIMARY KEY ("Id")
            );
            CREATE UNIQUE INDEX IF NOT EXISTS "IX_TelasDaTv_TokenHash" ON "TelasDaTv" ("TokenHash");
            CREATE TABLE IF NOT EXISTS "MusicosDaApresentacao" (
                "ApresentacaoId" uuid NOT NULL,
                "ArtistaId" uuid NOT NULL,
                "EntrouEm" timestamp with time zone NOT NULL,
                CONSTRAINT "PK_MusicosDaApresentacao" PRIMARY KEY ("ApresentacaoId", "ArtistaId")
            );
            CREATE TABLE IF NOT EXISTS "ConvitesDaApresentacao" (
                "ApresentacaoId" uuid NOT NULL,
                "Codigo" character varying(32) NOT NULL,
                "CriadoEm" timestamp with time zone NOT NULL,
                CONSTRAINT "PK_ConvitesDaApresentacao" PRIMARY KEY ("ApresentacaoId")
            );
            CREATE UNIQUE INDEX IF NOT EXISTS "IX_ConvitesDaApresentacao_Codigo"
                ON "ConvitesDaApresentacao" ("Codigo");
            CREATE TABLE IF NOT EXISTS "EnviosDoPublico" (
                "Id" uuid NOT NULL,
                "ApresentacaoId" uuid NOT NULL,
                "ArtistaId" uuid NOT NULL,
                "Chave" character varying(200) NOT NULL,
                "Tipo" integer NOT NULL,
                "TipoDeConteudo" character varying(40) NOT NULL,
                "Tamanho" bigint NOT NULL,
                "Nome" character varying(40) NULL,
                "IdentificadorDoAparelho" character varying(64) NOT NULL,
                "CriadoEm" timestamp with time zone NOT NULL,
                "ExpiraEm" timestamp with time zone NOT NULL,
                "Confirmado" boolean NOT NULL DEFAULT FALSE,
                "Escondido" boolean NOT NULL DEFAULT FALSE,
                "Denuncias" text NOT NULL DEFAULT '',
                CONSTRAINT "PK_EnviosDoPublico" PRIMARY KEY ("Id")
            );
            CREATE INDEX IF NOT EXISTS "IX_EnviosDoPublico_ApresentacaoId"
                ON "EnviosDoPublico" ("ApresentacaoId");
            ALTER TABLE "EnviosDoPublico"
                ADD COLUMN IF NOT EXISTS "DoArtista" boolean NOT NULL DEFAULT FALSE;
            CREATE TABLE IF NOT EXISTS "Repertorios" (
                "Id" uuid NOT NULL,
                "ArtistaId" uuid NOT NULL,
                "Nome" character varying(120) NOT NULL,
                "CriadoEm" timestamp with time zone NOT NULL,
                CONSTRAINT "PK_Repertorios" PRIMARY KEY ("Id")
            );
            CREATE INDEX IF NOT EXISTS "IX_Repertorios_ArtistaId"
                ON "Repertorios" ("ArtistaId");
            CREATE TABLE IF NOT EXISTS "MusicasDoRepertorio" (
                "Id" uuid NOT NULL,
                "RepertorioId" uuid NOT NULL,
                "ArtistaId" uuid NOT NULL,
                "Titulo" character varying(200) NOT NULL,
                "Artista" character varying(200) NULL,
                "Tom" character varying(10) NULL,
                "Ordem" integer NOT NULL DEFAULT 0,
                CONSTRAINT "PK_MusicasDoRepertorio" PRIMARY KEY ("Id")
            );
            CREATE INDEX IF NOT EXISTS "IX_MusicasDoRepertorio_RepertorioId"
                ON "MusicasDoRepertorio" ("RepertorioId");
            ALTER TABLE "MusicasDoRepertorio"
                ADD COLUMN IF NOT EXISTS "Tom" character varying(10) NULL;
            ALTER TABLE "MusicasDoRepertorio"
                ADD COLUMN IF NOT EXISTS "LinkDoVideo" character varying(300) NULL;
            CREATE TABLE IF NOT EXISTS "ItensDoSetlist" (
                "Id" uuid NOT NULL,
                "ApresentacaoId" uuid NOT NULL,
                "ArtistaId" uuid NOT NULL,
                "MusicaDoRepertorioId" uuid NULL,
                "Titulo" character varying(200) NOT NULL,
                "Artista" character varying(200) NULL,
                "Tom" character varying(10) NULL,
                "Tocada" boolean NOT NULL DEFAULT FALSE,
                "Ordem" integer NOT NULL DEFAULT 0,
                CONSTRAINT "PK_ItensDoSetlist" PRIMARY KEY ("Id")
            );
            CREATE INDEX IF NOT EXISTS "IX_ItensDoSetlist_ApresentacaoId"
                ON "ItensDoSetlist" ("ApresentacaoId");
            ALTER TABLE "ItensDoSetlist"
                ADD COLUMN IF NOT EXISTS "Tom" character varying(10) NULL;
            ALTER TABLE "ItensDoSetlist"
                ADD COLUMN IF NOT EXISTS "MusicaDoRepertorioId" uuid NULL;
            ALTER TABLE "PerfisArtisticos"
                ADD COLUMN IF NOT EXISTS "Instagram" character varying(120) NULL;
            ALTER TABLE "PerfisArtisticos"
                ADD COLUMN IF NOT EXISTS "ExibirInstagram" boolean NOT NULL DEFAULT FALSE;
            ALTER TABLE "PerfisArtisticos"
                ADD COLUMN IF NOT EXISTS "Whatsapp" character varying(20) NULL;
            ALTER TABLE "PerfisArtisticos"
                ADD COLUMN IF NOT EXISTS "ExibirWhatsapp" boolean NOT NULL DEFAULT FALSE;
            ALTER TABLE "PerfisArtisticos"
                ADD COLUMN IF NOT EXISTS "PixAtivo" boolean NOT NULL DEFAULT FALSE;
            ALTER TABLE "PerfisArtisticos"
                ADD COLUMN IF NOT EXISTS "PixChave" character varying(140) NULL;
            ALTER TABLE "PerfisArtisticos"
                ADD COLUMN IF NOT EXISTS "PixNomeBeneficiario" character varying(25) NULL;
            ALTER TABLE "PerfisArtisticos"
                ADD COLUMN IF NOT EXISTS "PixCidadeBeneficiario" character varying(15) NULL;
            ALTER TABLE "PerfisArtisticos"
                ADD COLUMN IF NOT EXISTS "PixMensagem" character varying(72) NULL;
            """);
        MigrarPropriedadePostgres();
    }

    private void MigrarPropriedadePostgres()
    {
        using var transacao = Database.BeginTransaction();
        Database.ExecuteSqlRaw("""
            ALTER TABLE "PerfisArtisticos"
                ADD COLUMN IF NOT EXISTS "ArtistaId" uuid NULL;
            ALTER TABLE "Apresentacoes"
                ADD COLUMN IF NOT EXISTS "ArtistaId" uuid NULL;

            DO $$
            DECLARE
                quantidade_contas integer;
                conta_id uuid;
            BEGIN
                IF EXISTS (SELECT 1 FROM "PerfisArtisticos" WHERE "ArtistaId" IS NULL)
                   OR EXISTS (SELECT 1 FROM "Apresentacoes" WHERE "ArtistaId" IS NULL) THEN
                    SELECT COUNT(*) INTO quantidade_contas FROM "ContasArtistas";
                    IF quantidade_contas <> 1 THEN
                        RAISE EXCEPTION 'Dados artísticos legados exigem exatamente uma conta proprietária.';
                    END IF;
                    SELECT "Id" INTO conta_id FROM "ContasArtistas" LIMIT 1;
                    UPDATE "PerfisArtisticos" SET "ArtistaId" = conta_id
                    WHERE "ArtistaId" IS NULL;
                    UPDATE "Apresentacoes" SET "ArtistaId" = conta_id
                    WHERE "ArtistaId" IS NULL;
                END IF;
            END $$;

            ALTER TABLE "PerfisArtisticos" ALTER COLUMN "ArtistaId" SET NOT NULL;
            ALTER TABLE "Apresentacoes" ALTER COLUMN "ArtistaId" SET NOT NULL;
            CREATE UNIQUE INDEX IF NOT EXISTS "IX_PerfisArtisticos_ArtistaId"
                ON "PerfisArtisticos" ("ArtistaId");
            CREATE INDEX IF NOT EXISTS "IX_Apresentacoes_ArtistaId"
                ON "Apresentacoes" ("ArtistaId");
            """);
        transacao.Commit();
    }

}
