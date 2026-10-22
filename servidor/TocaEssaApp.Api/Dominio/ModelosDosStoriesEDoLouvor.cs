namespace TocaEssaApp.Api.Dominio;

// Stories do show e escala do louvor.

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
    IReadOnlyList<HinoDoLouvor> Hinos,
    IReadOnlyList<Solista> Solistas,
    IReadOnlyList<PlacarDoSolista> PlacarDosSolos,
    ConfiguracaoDaEscala Configuracao);

/// O que cada participante vê pelo código: hinos, partes e o hino atual.
public sealed record RoteiroDoLouvor(
    string Nome,
    IReadOnlyList<string> Cantores,
    Guid? HinoAtualId,
    IReadOnlyList<HinoDoLouvor> Hinos,
    IReadOnlyList<Solista> Solistas);

public sealed record DefinirCantoresDoLouvor(string[]? Nomes);

public sealed record DefinirSolistasDoLouvor(Solista[]? Solistas);

/// [Itens] nulo escala a lista inteira.
public sealed record EscalarHinosDoLouvor(Guid[]? Itens);

/// [Cantores] nulo deixa a parte sem escala; vazio quer dizer Todos.
public sealed record EscolherParteDoLouvor(Guid ItemId, int Indice, string[]? Cantores);
