using TocaEssaApp.Api.Dominio;

namespace TocaEssaApp.Api.Infraestrutura;

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
    public FormaParticipacaoPedido FormaParticipacao { get; set; }
    public string? TomPreferido { get; set; }
    public string? Recado { get; set; }
    public TipoPedido Tipo { get; set; }
    public string? DestinatarioAlo { get; set; }
}

internal sealed class AvaliacaoPedidoRegistro
{
    public Guid PedidoId { get; set; }
    public string IdentificadorAvaliador { get; set; } = string.Empty;
    public Guid? PublicoId { get; set; }
    public int Estrelas { get; set; }
    public DateTimeOffset AvaliadoEm { get; set; }
}

internal sealed class ImagemRegistro
{
    public string Chave { get; set; } = string.Empty;
    public string TipoDeConteudo { get; set; } = string.Empty;
    public byte[] Conteudo { get; set; } = [];
    public DateTimeOffset AtualizadaEm { get; set; }
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

internal sealed class ParticipacaoResenhaRegistro
{
    public Guid ApresentacaoId { get; set; }
    public Guid PublicoId { get; set; }
    public DateTimeOffset EntrouEm { get; set; }
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
