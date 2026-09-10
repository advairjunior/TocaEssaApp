using Microsoft.EntityFrameworkCore;
using Npgsql;
using TocaEssaApp.Api.Dominio;

namespace TocaEssaApp.Api.Infraestrutura;

internal sealed class BancoTocaEssa(string destinoBanco) : DbContext
{
    private readonly bool _usaPostgres = destinoBanco.Contains("Host=", StringComparison.OrdinalIgnoreCase)
        || destinoBanco.StartsWith("postgres", StringComparison.OrdinalIgnoreCase);
    private readonly string _destinoBanco = NormalizarDestino(destinoBanco);
    internal DbSet<PerfilArtisticoRegistro> Perfis => Set<PerfilArtisticoRegistro>();
    internal DbSet<ApresentacaoRegistro> Apresentacoes => Set<ApresentacaoRegistro>();
    internal DbSet<PedidoMusicalRegistro> Pedidos => Set<PedidoMusicalRegistro>();
    internal DbSet<AvaliacaoPedidoRegistro> Avaliacoes => Set<AvaliacaoPedidoRegistro>();
    internal DbSet<ImagemRegistro> Imagens => Set<ImagemRegistro>();
    internal DbSet<PerfilPublicoRegistro> PerfisPublicos => Set<PerfilPublicoRegistro>();
    internal DbSet<ParticipacaoResenhaRegistro> ParticipacoesResenha =>
        Set<ParticipacaoResenhaRegistro>();
    internal DbSet<SessaoPublicoRegistro> SessoesPublicas => Set<SessaoPublicoRegistro>();
    internal DbSet<ContaArtistaRegistro> ContasArtistas => Set<ContaArtistaRegistro>();
    internal DbSet<SessaoArtistaRegistro> SessoesArtistas => Set<SessaoArtistaRegistro>();
    internal DbSet<CifraDoArtistaRegistro> CifrasDoArtista => Set<CifraDoArtistaRegistro>();

    protected override void OnConfiguring(DbContextOptionsBuilder opcoes)
    {
        if (_usaPostgres) opcoes.UseNpgsql(_destinoBanco);
        else opcoes.UseSqlite($"Data Source={_destinoBanco};Pooling=False");
    }

    private static string NormalizarDestino(string destino)
    {
        if (!destino.StartsWith("postgres", StringComparison.OrdinalIgnoreCase))
            return destino;

        var endereco = new Uri(destino);
        var separadorCredencial = endereco.UserInfo.IndexOf(':');
        if (separadorCredencial < 1)
            throw new InvalidOperationException("A conexão PostgreSQL não possui usuário e senha válidos.");

        return new NpgsqlConnectionStringBuilder
        {
            Host = endereco.Host,
            Port = endereco.IsDefaultPort ? 5432 : endereco.Port,
            Database = Uri.UnescapeDataString(endereco.AbsolutePath.TrimStart('/')),
            Username = Uri.UnescapeDataString(endereco.UserInfo[..separadorCredencial]),
            Password = Uri.UnescapeDataString(endereco.UserInfo[(separadorCredencial + 1)..]),
            SslMode = SslMode.Require,
        }.ConnectionString;
    }

    protected override void OnModelCreating(ModelBuilder modelo)
    {
        modelo.Entity<PerfilArtisticoRegistro>(entidade =>
        {
            entidade.ToTable("PerfisArtisticos");
            entidade.HasKey(item => item.Id);
            entidade.Property(item => item.NomeArtistico).HasMaxLength(160);
        });

        modelo.Entity<ApresentacaoRegistro>(entidade =>
        {
            entidade.ToTable("Apresentacoes");
            entidade.HasKey(item => item.Id);
            entidade.HasIndex(item => item.Codigo).IsUnique();
            entidade.Property(item => item.Codigo).HasMaxLength(6);
            entidade.Property(item => item.Nome).HasMaxLength(200);
            entidade.Property(item => item.Local).HasMaxLength(200);
        });

        modelo.Entity<PedidoMusicalRegistro>(entidade =>
        {
            entidade.ToTable("PedidosMusicais");
            entidade.HasKey(item => item.Id);
            entidade.HasIndex(item => item.ApresentacaoId);
            entidade.Property(item => item.Musica).HasMaxLength(200);
            entidade.Property(item => item.Artista).HasMaxLength(200);
            entidade.Property(item => item.NomeSolicitante).HasMaxLength(120);
            entidade.Property(item => item.TomPreferido).HasMaxLength(30);
            entidade.Property(item => item.Recado).HasMaxLength(240);
        });

        modelo.Entity<AvaliacaoPedidoRegistro>(entidade =>
        {
            entidade.ToTable("AvaliacoesPedidos");
            entidade.HasKey(item => new { item.PedidoId, item.IdentificadorAvaliador });
            entidade.Property(item => item.IdentificadorAvaliador).HasMaxLength(160);
            entidade.HasIndex(item => item.PedidoId);
        });

        modelo.Entity<ImagemRegistro>(entidade =>
        {
            entidade.ToTable("Imagens");
            entidade.HasKey(item => item.Chave);
            entidade.Property(item => item.Chave).HasMaxLength(300);
            entidade.Property(item => item.TipoDeConteudo).HasMaxLength(100);
        });

        modelo.Entity<PerfilPublicoRegistro>(entidade =>
        {
            entidade.ToTable("PerfisPublicos");
            entidade.HasKey(item => item.Id);
            entidade.HasIndex(item => item.EmailNormalizado).IsUnique();
            entidade.Property(item => item.Nome).HasMaxLength(120);
            entidade.Property(item => item.Email).HasMaxLength(240);
            entidade.Property(item => item.EmailNormalizado).HasMaxLength(240);
        });

        modelo.Entity<SessaoPublicoRegistro>(entidade =>
        {
            entidade.ToTable("SessoesPublicas");
            entidade.HasKey(item => item.TokenHash);
            entidade.Property(item => item.TokenHash).HasMaxLength(64);
            entidade.HasIndex(item => item.PublicoId);
        });

        modelo.Entity<ParticipacaoResenhaRegistro>(entidade =>
        {
            entidade.ToTable("ParticipacoesResenha");
            entidade.HasKey(item => new { item.ApresentacaoId, item.PublicoId });
            entidade.HasIndex(item => item.PublicoId);
        });

        modelo.Entity<ContaArtistaRegistro>(entidade =>
        {
            entidade.ToTable("ContasArtistas");
            entidade.HasKey(item => item.Id);
            entidade.HasIndex(item => item.EmailNormalizado).IsUnique();
            entidade.Property(item => item.Nome).HasMaxLength(120);
            entidade.Property(item => item.Email).HasMaxLength(240);
            entidade.Property(item => item.EmailNormalizado).HasMaxLength(240);
        });

        modelo.Entity<SessaoArtistaRegistro>(entidade =>
        {
            entidade.ToTable("SessoesArtistas");
            entidade.HasKey(item => item.TokenHash);
            entidade.Property(item => item.TokenHash).HasMaxLength(64);
            entidade.HasIndex(item => item.ArtistaId);
        });

        modelo.Entity<CifraDoArtistaRegistro>(entidade =>
        {
            entidade.ToTable("CifrasDoArtista");
            entidade.HasKey(item => item.Id);
            entidade.HasIndex(item => new
            {
                item.ArtistaId,
                item.MusicaNormalizada,
                item.ArtistaNormalizado
            }).IsUnique();
            entidade.Property(item => item.Musica).HasMaxLength(200);
            entidade.Property(item => item.Artista).HasMaxLength(200);
            entidade.Property(item => item.MusicaNormalizada).HasMaxLength(200);
            entidade.Property(item => item.ArtistaNormalizado).HasMaxLength(200);
            entidade.Property(item => item.Url).HasMaxLength(2048);
            entidade.Property(item => item.Fonte).HasMaxLength(255);
        });
    }

    internal void GarantirEstrutura()
    {
        Database.EnsureCreated();
        if (_usaPostgres)
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
                """);
            return;
        }
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
            comando, "PedidosMusicais", "DestinatarioAlo", "TEXT NULL");

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
