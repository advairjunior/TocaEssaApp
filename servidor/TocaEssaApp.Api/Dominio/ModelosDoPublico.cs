namespace TocaEssaApp.Api.Dominio;

// Pedidos, conta do público, estatísticas e resenha.

public enum StatusPedidoMusical
{
    Aguardando,
    Aceito,
    TocandoAgora,
    Finalizado,
    NaoConhecemos,
    AindaNaoSabemosTocar,
    CanceladoPeloPublico
}

public enum FormaParticipacaoPedido
{
    PedidoNormal,
    EuCanto
}

public enum TipoPedido
{
    Musica,
    Alo
}

public sealed record PedidoMusical(
    Guid Id,
    Guid ApresentacaoId,
    string Musica,
    string? Artista,
    string? NomeSolicitante,
    StatusPedidoMusical Status,
    int? Posicao,
    DateTimeOffset CriadoEm,
    Guid? PublicoId = null,
    int? Avaliacao = null,
    FormaParticipacaoPedido FormaParticipacao = FormaParticipacaoPedido.PedidoNormal,
    string? TomPreferido = null,
    string? Recado = null,
    TipoPedido Tipo = TipoPedido.Musica,
    string? DestinatarioAlo = null,
    int QuantidadeAvaliacoes = 0,
    double? MediaAvaliacoes = null,
    int? MinhaAvaliacao = null,
    IReadOnlyCollection<string>? Solicitantes = null,
    int QuantidadePedidos = 1);

public sealed record GrupoPedidoMusical(
    Guid PedidoRepresentativoId,
    IReadOnlyList<Guid> PedidoIds,
    Guid ApresentacaoId,
    string Musica,
    string? Artista,
    StatusPedidoMusical Status,
    int? Posicao,
    DateTimeOffset CriadoEm,
    FormaParticipacaoPedido FormaParticipacao,
    string? TomPreferido,
    string? Recado,
    TipoPedido Tipo,
    string? DestinatarioAlo,
    int QuantidadePedidos,
    IReadOnlyList<string> Solicitantes,
    int QuantidadeAvaliacoes = 0,
    double? MediaAvaliacoes = null);

public sealed record CriarPedidoMusical(
    string Musica,
    string? Artista,
    string? NomeSolicitante,
    FormaParticipacaoPedido FormaParticipacao = FormaParticipacaoPedido.PedidoNormal,
    string? TomPreferido = null,
    string? Recado = null,
    TipoPedido Tipo = TipoPedido.Musica,
    string? DestinatarioAlo = null);

public sealed record AlterarStatusPedidoMusical(StatusPedidoMusical Status);

public sealed record ReordenarFilaMusical(IReadOnlyList<Guid> Pedidos);

public sealed record AlterarPedidosDaApresentacao(bool Abertos);

public sealed record AvaliarPedidoMusical(int Estrelas, string? IdentificadorAvaliador = null);

public sealed record PerfilPublico(
    Guid Id, string Nome, string Email, string? FotoUrl, DateTimeOffset CriadoEm);

public sealed record CriarPerfilPublico(string Nome, string Email, string Senha);

public sealed record EntrarPerfilPublico(string Email, string Senha);

public sealed record SessaoDoPublico(PerfilPublico Perfil, string Token);

public sealed record MusicaMaisPedida(string Musica, int Quantidade);

public sealed record EstatisticasDaApresentacao(
    int TotalPedidos,
    int Aguardando,
    int Aceitos,
    int Tocados,
    int Recusados,
    int Avaliados,
    double? MediaAvaliacoes,
    IReadOnlyCollection<MusicaMaisPedida> MusicasMaisPedidas,
    int PessoasNoEvento = 0,
    int PessoasQuePediram = 0,
    IReadOnlyCollection<MusicaMaisPedida>? MusicasRecusadas = null,
    DadosDaRetrospectiva? Retrospectiva = null);

/// Números do cartão de retrospectiva, já validados: cada pessoa conta uma
/// vez por música, "favorita" só se foi tocada, duração só se plausível.
/// As quantidades de `MusicaMaisPedida` aqui são pessoas, não pedidos.
public sealed record DadosDaRetrospectiva(
    MusicaMaisPedida? Favorita,
    int MusicasAPedidoTocadas,
    int PedidosConsiderados,
    int PedidosAtendidos,
    int PessoasQueAvaliaram,
    double? MediaDasAvaliacoes,
    int MusicasTocadas,
    int AlosDados,
    DateTimeOffset? IniciadaEm,
    DateTimeOffset? EncerradaEm,
    IReadOnlyCollection<MusicaMaisPedida> MaisPedidasPorPessoas,
    IReadOnlyCollection<MusicaMaisPedida> RecusadasPorPessoas);

public sealed record RegistrarAcessoAoEvento(string? Visitante);

public sealed record EstatisticasDoPublico(
    int Participacoes,
    int Pedidos,
    int PedidosTocados,
    int AvaliacoesRealizadas,
    double? MediaAvaliacoes,
    IReadOnlyCollection<MusicaMaisPedida> MusicasMaisPedidas);

public sealed record ParticipanteDaResenha(
    Guid PublicoId,
    string Nome,
    string? FotoUrl,
    int Pedidos,
    int PedidosTocados,
    double? MediaAvaliacoes,
    IReadOnlyCollection<MusicaMaisPedida> MusicasMaisPedidas,
    bool EhArtista = false,
    IReadOnlyCollection<AvaliacaoNaResenha>? Avaliacoes = null,
    EstatisticasDoPublico? EstatisticasGerais = null,
    int PedidosRecusados = 0);

public sealed record AvaliacaoNaResenha(
    string Musica, int Estrelas, DateTimeOffset AvaliadoEm);

public sealed record PessoaDoEncontro(Guid PublicoId, string Nome, string? FotoUrl);

public sealed record EncontroDoPublico(
    Apresentacao Apresentacao,
    int Pedidos,
    int PedidosTocados,
    IReadOnlyCollection<MusicaMaisPedida> MinhasMusicas,
    IReadOnlyCollection<PessoaDoEncontro> Companhia);
