namespace TocaEssaApp.Api.Dominio;

public sealed record PerfilArtistico(
    Guid Id,
    string NomeArtistico,
    string? Bio,
    string? FotoUrl = null,
    string? Instagram = null,
    string? Whatsapp = null,
    bool ApoioPixDisponivel = false);

public sealed record ConfiguracaoPerfilArtistico(
    PerfilArtistico Perfil,
    string? Instagram,
    bool ExibirInstagram,
    string? Whatsapp,
    bool ExibirWhatsapp,
    bool PixAtivo,
    string? PixChave,
    string? PixNomeBeneficiario,
    string? PixCidadeBeneficiario,
    string? PixMensagem);

public enum StatusApresentacao
{
    Agendada,
    EmAndamento,
    Encerrada
}

public enum TipoApresentacao
{
    Publica,
    ResenhaEntreAmigos
}

public sealed record Apresentacao(
    Guid Id,
    string Nome,
    DateOnly Data,
    string Local,
    string Codigo,
    PerfilArtistico PerfilArtistico,
    bool PedidosAbertos = true,
    StatusApresentacao Status = StatusApresentacao.Agendada,
    TipoApresentacao Tipo = TipoApresentacao.Publica,
    string? FotoRetrospectivaUrl = null,
    Guid ArtistaId = default);

public sealed record SalvarPerfilArtistico(
    string NomeArtistico,
    string? Bio,
    string? Instagram = null,
    bool ExibirInstagram = false,
    string? Whatsapp = null,
    bool ExibirWhatsapp = false,
    bool PixAtivo = false,
    string? PixChave = null,
    string? PixNomeBeneficiario = null,
    string? PixCidadeBeneficiario = null,
    string? PixMensagem = null);

public sealed record ApoioPix(
    decimal Valor, string PixCopiaECola, string Mensagem);

public sealed record ContaArtista(
    Guid Id, string Nome, string Email, DateTimeOffset CriadoEm);

public sealed record CriarContaArtista(string Nome, string Email, string Senha);

public sealed record EntrarContaArtista(string Email, string Senha);

public sealed record SessaoDoArtista(ContaArtista Conta, string Token);

public sealed record CifraDoArtista(
    Guid Id,
    Guid ArtistaId,
    string Musica,
    string? Artista,
    string Url,
    string Fonte,
    DateTimeOffset CriadaEm,
    DateTimeOffset AtualizadaEm);

public sealed record ResultadoCifraDoArtista(
    CifraDoArtista? Cifra, string? UrlSugerida, string UrlPesquisa);

public sealed record SalvarCifraDoArtista(
    string Musica, string? Artista, string Url);

public sealed record Repertorio(
    Guid Id,
    Guid ArtistaId,
    string Nome,
    IReadOnlyCollection<MusicaDoRepertorio> Musicas);

public sealed record MusicaDoRepertorio(
    Guid Id,
    Guid RepertorioId,
    string Titulo,
    string? Artista,
    string? Tom,
    int Ordem);

public sealed record ItemDoSetlist(
    Guid Id,
    Guid ApresentacaoId,
    string Titulo,
    string? Artista,
    string? Tom,
    bool Tocada,
    int Ordem);

public sealed record CriarRepertorio(string Nome);

public sealed record RenomearRepertorio(string Nome);

public sealed record AdicionarMusicaAoRepertorio(string Titulo, string? Artista, string? Tom = null);

public sealed record EditarMusicaDoRepertorio(string Titulo, string? Artista, string? Tom = null);

public sealed record ReordenarMusicasDoRepertorio(Guid[]? MusicaIds);

public sealed record MarcarItemDoSetlist(bool Tocada);

public sealed record ImportarRepertorio(Guid RepertorioId);

public sealed record CriarApresentacao(
    string Nome, DateOnly Data, string Local, TipoApresentacao Tipo = TipoApresentacao.Publica);

public sealed record EditarApresentacao(
    string Nome, DateOnly Data, string Local, TipoApresentacao Tipo = TipoApresentacao.Publica);

public sealed record AlterarStatusApresentacao(StatusApresentacao Status);

public sealed record ApresentacaoCriada(Apresentacao Apresentacao, string LinkPublico);

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
    IReadOnlyCollection<MusicaMaisPedida>? MusicasRecusadas = null);

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
