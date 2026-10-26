using TocaEssaApp.Api.Dominio;

namespace TocaEssaApp.Api.Infraestrutura;

internal sealed class PerfilArtisticoRegistro
{
    public Guid Id { get; set; }
    public Guid ArtistaId { get; set; }
    public string NomeArtistico { get; set; } = string.Empty;
    public string? Bio { get; set; }
    public string? FotoUrl { get; set; }
    public string? Instagram { get; set; }
    public bool ExibirInstagram { get; set; }
    public string? Whatsapp { get; set; }
    public bool ExibirWhatsapp { get; set; }
    public bool PixAtivo { get; set; }
    public string? PixChave { get; set; }
    public string? PixNomeBeneficiario { get; set; }
    public string? PixCidadeBeneficiario { get; set; }
    public string? PixMensagem { get; set; }
}

internal sealed class ApresentacaoRegistro
{
    public Guid Id { get; set; }
    public Guid ArtistaId { get; set; }
    public string Nome { get; set; } = string.Empty;
    public DateOnly Data { get; set; }
    public string Local { get; set; } = string.Empty;
    public string Codigo { get; set; } = string.Empty;
    public bool PedidosAbertos { get; set; }
    public StatusApresentacao Status { get; set; }
    public TipoApresentacao Tipo { get; set; }
    public string? FotoRetrospectivaUrl { get; set; }
    // ids dos pedidos marcados para tocar a seguir, em ordem, separados por vírgula
    public string? PedidosASeguir { get; set; }
    // Louvor: nomes de quem canta e partes escolhidas à mão, em JSON
    public string? CantoresDoLouvor { get; set; }
    public string? EscolhasDoLouvor { get; set; }
    public string? SolistasDoLouvor { get; set; }
    public string? ConfiguracaoDoLouvor { get; set; }
    // Partes em que o coral canta junto, em JSON
    public string? CoralDoLouvor { get; set; }
    // Karaokê: modo, playlist e ordem de quem canta, em JSON
    public string? KaraokeDaNoite { get; set; }
    // Cronômetro do show, visto só pelo artista
    public int? DuracaoContratadaMinutos { get; set; }
    public bool IntervaloPausaRelogio { get; set; }
    public DateTimeOffset? IniciadaEm { get; set; }
    public DateTimeOffset? EmIntervaloDesde { get; set; }
    public int SegundosEmIntervalo { get; set; }
    public DateTimeOffset? EncerradaEm { get; set; }
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
    // No louvor, quem a pessoa escolheu ser no roteiro.
    public string? NomeNoLouvor { get; set; }
}

/// Um aparelho que abriu a página pública do evento; conta o público que
/// passou pelo app mesmo sem fazer pedido.
internal sealed class AcessoAoEventoRegistro
{
    public Guid ApresentacaoId { get; set; }
    public string Visitante { get; set; } = string.Empty;
    public DateTimeOffset AcessouEm { get; set; }
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

// Letra e cifra coladas no app, com a mesma chave de música dos links.
internal sealed class CifraEmTextoRegistro
{
    public Guid Id { get; set; }
    public Guid ArtistaId { get; set; }
    public string Musica { get; set; } = string.Empty;
    public string? Artista { get; set; }
    public string MusicaNormalizada { get; set; } = string.Empty;
    public string ArtistaNormalizado { get; set; } = string.Empty;
    public string Conteudo { get; set; } = string.Empty;
    public DateTimeOffset AtualizadaEm { get; set; }
}

internal sealed class CifraDoArtistaRegistro
{
    public Guid Id { get; set; }
    public Guid ArtistaId { get; set; }
    public string Musica { get; set; } = string.Empty;
    public string? Artista { get; set; }
    public string MusicaNormalizada { get; set; } = string.Empty;
    public string ArtistaNormalizado { get; set; } = string.Empty;
    public string Url { get; set; } = string.Empty;
    public string Fonte { get; set; } = string.Empty;
    public DateTimeOffset CriadaEm { get; set; }
    public DateTimeOffset AtualizadaEm { get; set; }
}

internal sealed class RepertorioRegistro
{
    public Guid Id { get; set; }
    public Guid ArtistaId { get; set; }
    public string Nome { get; set; } = string.Empty;
    public DateTimeOffset CriadoEm { get; set; }
}

internal sealed class MusicaDoRepertorioRegistro
{
    public Guid Id { get; set; }
    public Guid RepertorioId { get; set; }
    public Guid ArtistaId { get; set; }
    public string Titulo { get; set; } = string.Empty;
    public string? Artista { get; set; }
    public string? Tom { get; set; }
    public int Ordem { get; set; }
    // Vídeo de karaokê no YouTube, vindo da playlist importada.
    public string? LinkDoVideo { get; set; }
}

internal sealed class ItemDoSetlistRegistro
{
    public Guid Id { get; set; }
    public Guid ApresentacaoId { get; set; }
    public Guid ArtistaId { get; set; }
    public Guid? MusicaDoRepertorioId { get; set; }
    public string Titulo { get; set; } = string.Empty;
    public string? Artista { get; set; }
    public string? Tom { get; set; }
    public bool Tocada { get; set; }
    public int Ordem { get; set; }
}

// Vídeo ou foto do público para os stories do show. O arquivo fica no
// armazenamento (R2) na Chave; aqui só os dados.
internal sealed class EnvioDoPublicoRegistro
{
    public Guid Id { get; set; }
    public Guid ApresentacaoId { get; set; }
    public Guid ArtistaId { get; set; }
    public string Chave { get; set; } = string.Empty;
    public TipoDeStory Tipo { get; set; }
    public string TipoDeConteudo { get; set; } = string.Empty;
    public long Tamanho { get; set; }
    public string? Nome { get; set; }
    public string IdentificadorDoAparelho { get; set; } = string.Empty;
    public DateTimeOffset CriadoEm { get; set; }
    public DateTimeOffset ExpiraEm { get; set; }
    public bool Confirmado { get; set; }
    public bool Escondido { get; set; }
    // Aparelhos que denunciaram, um por linha; zera quando o artista mostra.
    public string Denuncias { get; set; } = string.Empty;
    // Postado pelo artista dono: destaque para o público e sem denúncia.
    public bool DoArtista { get; set; }
}
