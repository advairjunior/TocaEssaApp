using System.Collections.Concurrent;
using System.Security.Cryptography;
using System.Text.Json;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using TocaEssaApp.Api.Dominio;

namespace TocaEssaApp.Api.Infraestrutura;

public sealed partial class RepositorioTocaEssa
{
    private const string CaracteresCodigo = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
    private readonly ConcurrentDictionary<string, Apresentacao> _apresentacoes = new();
    private readonly ConcurrentDictionary<Guid, PedidoMusical> _pedidos = new();
    private readonly ConcurrentDictionary<(Guid PedidoId, string Avaliador),
        AvaliacaoPedidoRegistro> _avaliacoes = new();
    private readonly ConcurrentDictionary<Guid, PerfilPublicoRegistro> _perfisPublicos = new();
    private readonly ConcurrentDictionary<(Guid ApresentacaoId, Guid PublicoId),
        ParticipacaoResenhaRegistro> _participacoesResenha = new();
    private readonly ConcurrentDictionary<string, SessaoPublicoRegistro> _sessoesPublicas = new();
    private readonly ConcurrentDictionary<Guid, ContaArtistaRegistro> _contasArtistas = new();
    private readonly ConcurrentDictionary<string, SessaoArtistaRegistro> _sessoesArtistas = new();
    private readonly ConcurrentDictionary<(Guid ArtistaId, string Musica, string Artista),
        CifraDoArtistaRegistro> _cifrasDoArtista = new();
    private readonly object _sincronizacao = new();
    private readonly string? _caminhoBanco;
    private readonly string? _caminhoJsonLegado;
    private readonly bool _usaPostgres;
    private readonly NotificadorTempoReal? _notificador;
    private PerfilArtistico? _perfil;
    private static readonly PasswordHasher<PerfilPublicoRegistro> Senhas = new();
    private static readonly PasswordHasher<ContaArtistaRegistro> SenhasArtista = new();

    public RepositorioTocaEssa(
        string? caminhoBanco = null,
        string? caminhoJsonLegado = null,
        NotificadorTempoReal? notificador = null)
    {
        _caminhoBanco = caminhoBanco;
        _usaPostgres = caminhoBanco?.Contains("Host=", StringComparison.OrdinalIgnoreCase) == true
            || caminhoBanco?.StartsWith("postgres", StringComparison.OrdinalIgnoreCase) == true;
        _caminhoJsonLegado = caminhoJsonLegado;
        _notificador = notificador;
        CarregarEstado();
    }

    public PerfilArtistico? ObterPerfil() => _perfil;
}

public sealed record EstadoPersistido(
    PerfilArtistico? Perfil,
    IReadOnlyCollection<Apresentacao> Apresentacoes,
    IReadOnlyCollection<PedidoMusical> Pedidos);

public sealed class PerfilArtisticoNaoCadastradoException : Exception
{
    public PerfilArtisticoNaoCadastradoException()
        : base("Cadastre o Perfil Artístico antes de criar uma Apresentação.") { }
}

public sealed class ApresentacaoNaoEncontradaException : Exception { }

public sealed class PedidoMusicalNaoEncontradoException : Exception { }

public sealed class PedidoMusicalNaoPodeSerCanceladoException : Exception { }

public sealed class FilaMusicalInvalidaException : Exception { }

public sealed class PedidosEncerradosException : Exception { }

public sealed class EmailPublicoJaCadastradoException : Exception { }

public sealed class CredenciaisPublicasInvalidasException : Exception { }

public sealed class SessaoPublicaInvalidaException : Exception { }

public sealed class IdentificacaoPublicaObrigatoriaException : Exception { }

public sealed class AvaliacaoInvalidaException : Exception { }

public sealed class PedidoAindaNaoTocadoException : Exception { }

public sealed class ContaArtistaJaConfiguradaException : Exception { }

public sealed class CredenciaisArtistaInvalidasException : Exception { }

public sealed class SessaoArtistaInvalidaException : Exception { }

public sealed class UrlDeCifraInvalidaException : Exception { }

public sealed class CifraDoArtistaNaoEncontradaException : Exception { }

public sealed class RecursoDisponivelSomenteNaResenhaException : Exception { }

public sealed class DestinatarioAloObrigatorioException : Exception { }

public sealed class IdentificacaoAvaliadorObrigatoriaException : Exception { }
