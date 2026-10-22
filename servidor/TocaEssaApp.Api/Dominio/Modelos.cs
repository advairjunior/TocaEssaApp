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

/// O que quem abre o link de uma cifra vê, sem conta.
public sealed record CifraCompartilhada(
    string Musica, string? Artista, string? Tom, string Texto, string? NomeArtistico);

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

/// Várias músicas (da setlist, hinos ou pedidos) de uma vez para um
/// repertório já existente ou criado com [NomeNovo].
public sealed record AdicionarMusicasAoRepertorio(
    Guid? RepertorioId, string? NomeNovo, IReadOnlyList<AdicionarMusicaAoRepertorio>? Musicas);

public sealed record MusicasAdicionadasAoRepertorio(
    Repertorio Repertorio, int Adicionadas, int JaEstavam);

/// Música pedida pelo público e ainda fora do acervo: quantas vezes e em
/// quantos shows.
public sealed record PedidaForaDoRepertorio(string Musica, string? Artista, int Vezes, int Shows);

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
