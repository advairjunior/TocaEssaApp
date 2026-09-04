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
    internal DbSet<PerfilPublicoRegistro> PerfisPublicos => Set<PerfilPublicoRegistro>();
    internal DbSet<SessaoPublicoRegistro> SessoesPublicas => Set<SessaoPublicoRegistro>();
    internal DbSet<ContaArtistaRegistro> ContasArtistas => Set<ContaArtistaRegistro>();
    internal DbSet<SessaoArtistaRegistro> SessoesArtistas => Set<SessaoArtistaRegistro>();

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
    }

    internal void GarantirEstrutura()
    {
        Database.EnsureCreated();
        if (_usaPostgres) return;
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
}

internal sealed class PerfilArtisticoRegistro
{
    public Guid Id { get; set; }
    public string NomeArtistico { get; set; } = string.Empty;
    public string? Bio { get; set; }
    public string? FotoUrl { get; set; }
}

internal sealed class ApresentacaoRegistro
{
    public Guid Id { get; set; }
    public string Nome { get; set; } = string.Empty;
    public DateOnly Data { get; set; }
    public string Local { get; set; } = string.Empty;
    public string Codigo { get; set; } = string.Empty;
    public bool PedidosAbertos { get; set; }
    public StatusApresentacao Status { get; set; }
    public TipoApresentacao Tipo { get; set; }
    public string? FotoRetrospectivaUrl { get; set; }
}

internal sealed class PedidoMusicalRegistro
{
    public Guid Id { get; set; }
    public Guid ApresentacaoId { get; set; }
    public string Musica { get; set; } = string.Empty;
    public string? Artista { get; set; }
    public string? NomeSolicitante { get; set; }
    public StatusPedidoMusical Status { get; set; }
    public int? Posicao { get; set; }
    public DateTimeOffset CriadoEm { get; set; }
    public Guid? PublicoId { get; set; }
    public int? Avaliacao { get; set; }
}

internal sealed class PerfilPublicoRegistro
{
    public Guid Id { get; set; }
    public string Nome { get; set; } = string.Empty;
    public string Email { get; set; } = string.Empty;
    public string EmailNormalizado { get; set; } = string.Empty;
    public string SenhaHash { get; set; } = string.Empty;
    public string? FotoUrl { get; set; }
    public DateTimeOffset CriadoEm { get; set; }
}

internal sealed class SessaoPublicoRegistro
{
    public string TokenHash { get; set; } = string.Empty;
    public Guid PublicoId { get; set; }
    public DateTimeOffset ExpiraEm { get; set; }
}

internal sealed class ContaArtistaRegistro
{
    public Guid Id { get; set; }
    public string Nome { get; set; } = string.Empty;
    public string Email { get; set; } = string.Empty;
    public string EmailNormalizado { get; set; } = string.Empty;
    public string SenhaHash { get; set; } = string.Empty;
    public DateTimeOffset CriadoEm { get; set; }
}

internal sealed class SessaoArtistaRegistro
{
    public string TokenHash { get; set; } = string.Empty;
    public Guid ArtistaId { get; set; }
    public DateTimeOffset ExpiraEm { get; set; }
}
