using Microsoft.EntityFrameworkCore;
using Npgsql;
using TocaEssaApp.Api.Dominio;

namespace TocaEssaApp.Api.Infraestrutura;

internal sealed partial class BancoTocaEssa(string destinoBanco) : DbContext
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
    internal DbSet<AcessoAoEventoRegistro> AcessosAoEvento => Set<AcessoAoEventoRegistro>();
    internal DbSet<SessaoPublicoRegistro> SessoesPublicas => Set<SessaoPublicoRegistro>();
    internal DbSet<ContaArtistaRegistro> ContasArtistas => Set<ContaArtistaRegistro>();
    internal DbSet<SessaoArtistaRegistro> SessoesArtistas => Set<SessaoArtistaRegistro>();
    internal DbSet<CifraDoArtistaRegistro> CifrasDoArtista => Set<CifraDoArtistaRegistro>();
    internal DbSet<CifraEmTextoRegistro> CifrasEmTexto => Set<CifraEmTextoRegistro>();
    internal DbSet<TvDaContaRegistro> TelasDaTv => Set<TvDaContaRegistro>();
    internal DbSet<MusicoDaApresentacaoRegistro> MusicosDaApresentacao =>
        Set<MusicoDaApresentacaoRegistro>();
    internal DbSet<ConviteDaApresentacaoRegistro> ConvitesDaApresentacao =>
        Set<ConviteDaApresentacaoRegistro>();
    internal DbSet<EnvioDoPublicoRegistro> EnviosDoPublico => Set<EnvioDoPublicoRegistro>();
    internal DbSet<RepertorioRegistro> Repertorios => Set<RepertorioRegistro>();
    internal DbSet<MusicaDoRepertorioRegistro> MusicasDoRepertorio => Set<MusicaDoRepertorioRegistro>();
    internal DbSet<ItemDoSetlistRegistro> ItensDoSetlist => Set<ItemDoSetlistRegistro>();

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
            entidade.HasIndex(item => item.ArtistaId).IsUnique();
            entidade.Property(item => item.NomeArtistico).HasMaxLength(160);
            entidade.Property(item => item.Bio).HasMaxLength(500);
            entidade.Property(item => item.Instagram).HasMaxLength(120);
            entidade.Property(item => item.Whatsapp).HasMaxLength(20);
            entidade.Property(item => item.PixChave).HasMaxLength(140);
            entidade.Property(item => item.PixNomeBeneficiario).HasMaxLength(25);
            entidade.Property(item => item.PixCidadeBeneficiario).HasMaxLength(15);
            entidade.Property(item => item.PixMensagem).HasMaxLength(72);
        });

        modelo.Entity<ApresentacaoRegistro>(entidade =>
        {
            entidade.ToTable("Apresentacoes");
            entidade.HasKey(item => item.Id);
            entidade.HasIndex(item => item.Codigo).IsUnique();
            entidade.HasIndex(item => item.ArtistaId);
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
            entidade.Property(item => item.NomeNoLouvor).HasMaxLength(80);
        });

        modelo.Entity<AcessoAoEventoRegistro>(entidade =>
        {
            entidade.ToTable("AcessosAoEvento");
            entidade.HasKey(item => new { item.ApresentacaoId, item.Visitante });
            entidade.Property(item => item.Visitante).HasMaxLength(160);
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

        modelo.Entity<TvDaContaRegistro>(entidade =>
        {
            entidade.ToTable("TelasDaTv");
            entidade.HasKey(item => item.Id);
            entidade.Property(item => item.TokenHash).HasMaxLength(64);
            entidade.HasIndex(item => item.TokenHash).IsUnique();
        });

        modelo.Entity<MusicoDaApresentacaoRegistro>(entidade =>
        {
            entidade.ToTable("MusicosDaApresentacao");
            entidade.HasKey(item => new { item.ApresentacaoId, item.ArtistaId });
        });

        modelo.Entity<ConviteDaApresentacaoRegistro>(entidade =>
        {
            entidade.ToTable("ConvitesDaApresentacao");
            entidade.HasKey(item => item.ApresentacaoId);
            entidade.Property(item => item.Codigo).HasMaxLength(32);
            entidade.HasIndex(item => item.Codigo).IsUnique();
        });

        modelo.Entity<CifraEmTextoRegistro>(entidade =>
        {
            entidade.ToTable("CifrasEmTexto");
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
        });

        modelo.Entity<EnvioDoPublicoRegistro>(entidade =>
        {
            entidade.ToTable("EnviosDoPublico");
            entidade.HasKey(item => item.Id);
            entidade.HasIndex(item => item.ApresentacaoId);
            entidade.Property(item => item.Chave).HasMaxLength(200);
            entidade.Property(item => item.TipoDeConteudo).HasMaxLength(40);
            entidade.Property(item => item.Nome).HasMaxLength(40);
            entidade.Property(item => item.IdentificadorDoAparelho).HasMaxLength(64);
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

        modelo.Entity<RepertorioRegistro>(entidade =>
        {
            entidade.ToTable("Repertorios");
            entidade.HasKey(item => item.Id);
            entidade.HasIndex(item => item.ArtistaId);
            entidade.Property(item => item.Nome).HasMaxLength(120);
        });

        modelo.Entity<MusicaDoRepertorioRegistro>(entidade =>
        {
            entidade.ToTable("MusicasDoRepertorio");
            entidade.HasKey(item => item.Id);
            entidade.HasIndex(item => item.RepertorioId);
            entidade.HasIndex(item => item.ArtistaId);
            entidade.Property(item => item.Titulo).HasMaxLength(200);
            entidade.Property(item => item.Artista).HasMaxLength(200);
            entidade.Property(item => item.Tom).HasMaxLength(10);
            entidade.Property(item => item.LinkDoVideo).HasMaxLength(300);
        });

        modelo.Entity<ItemDoSetlistRegistro>(entidade =>
        {
            entidade.ToTable("ItensDoSetlist");
            entidade.HasKey(item => item.Id);
            entidade.HasIndex(item => item.ApresentacaoId);
            entidade.HasIndex(item => item.ArtistaId);
            entidade.HasIndex(item => item.MusicaDoRepertorioId);
            entidade.Property(item => item.Titulo).HasMaxLength(200);
            entidade.Property(item => item.Artista).HasMaxLength(200);
            entidade.Property(item => item.Tom).HasMaxLength(10);
        });
    }

    internal void GarantirEstrutura()
    {
        Database.EnsureCreated();
        if (_usaPostgres)
        {
            GarantirEstruturaPostgres();
            return;
        }
        GarantirEstruturaSqlite();
    }
}
