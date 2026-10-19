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
    ResenhaEntreAmigos,
    Louvor
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

/// [Texto] é a letra e cifra coladas no app, independente do link.
public sealed record ResultadoCifraDoArtista(
    CifraDoArtista? Cifra, string? UrlSugerida, string UrlPesquisa, string? Texto = null);

public sealed record SalvarCifraEmTexto(string Musica, string? Artista, string? Texto);

public sealed record CifraDaMusicaDoRepertorio(
    Guid MusicaId, bool TemTexto, string? Url, string UrlPesquisa);

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

public sealed record AdicionarMusicasAoSetlist(Guid[]? MusicaIds);

public sealed record AdicionarMusicaAvulsa(
    string Titulo, string? Artista = null, string? Tom = null, Guid? RepertorioId = null);

public sealed record ReordenarSetlist(Guid[]? ItemIds);

public sealed record CriarApresentacao(
    string Nome, DateOnly Data, string Local, TipoApresentacao Tipo = TipoApresentacao.Publica);

public sealed record EditarApresentacao(
    string Nome, DateOnly Data, string Local, TipoApresentacao Tipo = TipoApresentacao.Publica);

public sealed record AlterarStatusApresentacao(StatusApresentacao Status);

/// Cronômetro do show, visto só pelo artista dono. `Agora` é a hora do
/// servidor, para os aparelhos da banda contarem a partir do mesmo relógio.
public sealed record RelogioDoShow(
    int? DuracaoContratadaMinutos,
    bool IntervaloPausaRelogio,
    DateTimeOffset? IniciadaEm,
    DateTimeOffset? EmIntervaloDesde,
    int SegundosEmIntervalo,
    int MusicasComecadas,
    int MusicasRestantes,
    DateTimeOffset Agora,
    DateTimeOffset? EncerradaEm = null,
    // Média dos shows encerrados do artista; nula sem histórico.
    int? RitmoMedioSegundos = null);

public sealed record ConfigurarRelogioDoShow(
    int? DuracaoContratadaMinutos, bool IntervaloPausaRelogio = false);

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

public enum TipoDeStory
{
    Video,
    Foto
}

/// Vídeo ou foto que alguém do público quer mandar para o show.
public sealed record PedidoDeEnvio(
    TipoDeStory Tipo,
    string TipoDeConteudo,
    long Tamanho,
    string? Nome,
    string Aparelho);

/// Envio aberto: o arquivo vai direto para o armazenamento nesta chave.
public sealed record EnvioCriado(Guid Id, string Chave, string TipoDeConteudo);

/// Story que todos do show veem; sem nada que identifique o aparelho.
public sealed record StoryDoShow(
    Guid Id,
    TipoDeStory Tipo,
    string? Nome,
    DateTimeOffset CriadoEm,
    string Chave,
    string TipoDeConteudo,
    bool DoArtista = false);

/// Envio como o artista vê: inclui os escondidos por denúncia.
public sealed record EnvioDoShow(
    Guid Id,
    TipoDeStory Tipo,
    string? Nome,
    DateTimeOffset CriadoEm,
    DateTimeOffset ExpiraEm,
    bool Escondido,
    string Chave,
    string TipoDeConteudo,
    bool DoArtista = false);

public sealed record EnviosDoShow(
    IReadOnlyList<EnvioDoShow> Envios,
    IReadOnlyList<string> ChavesExpiradas);

public sealed record DenunciaDeStory(string Aparelho);

/// Hino da setlist com a letra separada em partes e quem canta cada uma.
public sealed record HinoDoLouvor(
    Guid ItemId,
    string Titulo,
    string? Artista,
    string? Tom,
    bool Tocado,
    bool TemLetra,
    IReadOnlyList<ParteEscalada> Partes);

public sealed record LouvorDoArtista(
    IReadOnlyList<string> Cantores,
    IReadOnlyList<PlacarDoCantor> Placar,
    IReadOnlyList<HinoDoLouvor> Hinos);

/// O que cada participante vê pelo código: hinos, partes e o hino atual.
public sealed record RoteiroDoLouvor(
    string Nome,
    IReadOnlyList<string> Cantores,
    Guid? HinoAtualId,
    IReadOnlyList<HinoDoLouvor> Hinos);

public sealed record DefinirCantoresDoLouvor(string[]? Nomes);

/// [Cantores] nulo devolve a parte à escala; vazio quer dizer Todos.
public sealed record EscolherParteDoLouvor(Guid ItemId, int Indice, string[]? Cantores);
