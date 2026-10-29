namespace TocaEssaApp.Api.Dominio;

/// TV recém-aberta: o token fica no aparelho dela e o código aparece na tela.
public sealed record NovaTv(Guid Id, string Token, string Codigo);

/// TV presa à conta, como aparece na lista do celular.
public sealed record TvDaConta(Guid Id, DateTimeOffset CriadaEm);

/// O que a TV pede ao abrir: o código, enquanto ninguém a conectou, ou o
/// que o celular do dono está mostrando.
public sealed record EstadoDaTv(bool Pareada, string? Codigo, ConteudoDaTv? Conteudo);

/// O que o celular do dono manda para as TVs da conta. O servidor não
/// entende de letra nem de tipo de evento: só leva o texto até a TV, que
/// separa as partes e numera as linhas do mesmo jeito que o celular.
public sealed record MostrarNaTv(
    string Titulo,
    string? Subtitulo,
    string Texto,
    string? ASeguir,
    string? Codigo,
    int Linha)
{
    public const int TamanhoMaximoDoTexto = 20_000;
    private const int TamanhoMaximoDoNome = 200;

    public void Validar()
    {
        if (string.IsNullOrWhiteSpace(Titulo) || Titulo.Length > TamanhoMaximoDoNome ||
            Subtitulo?.Length > TamanhoMaximoDoNome || ASeguir?.Length > TamanhoMaximoDoNome ||
            Codigo?.Length > 20 || Texto.Length > TamanhoMaximoDoTexto)
            throw new ConteudoDaTvInvalidoException();
        ValidarLinha(Linha);
    }

    public static void ValidarLinha(int linha)
    {
        if (linha < 0) throw new ConteudoDaTvInvalidoException();
    }
}

/// Conteúdo atual das TVs da conta. A versão muda a cada música nova: a TV
/// que receber uma linha de outra versão busca o conteúdo de novo.
public sealed record ConteudoDaTv(
    string Titulo,
    string? Subtitulo,
    string Texto,
    string? ASeguir,
    string? Codigo,
    int Linha,
    int Versao);

/// Canal de tempo real de uma TV, separado do canal das apresentações para a
/// linha não acordar os celulares do público.
public static class CanalDaTv
{
    public static string De(Guid tvId) => $"tela:{tvId:N}";

    /// "linha:3:6": versão 3 do conteúdo, linha 6 da letra.
    public static string EventoDaLinha(ConteudoDaTv conteudo) =>
        $"linha:{conteudo.Versao}:{conteudo.Linha}";
}

/// Erro da TV com o status e a mensagem que a pessoa vê.
public abstract class ErroDaTvException(int status, string mensagem) : Exception(mensagem)
{
    public int Status { get; } = status;
}

public sealed class TvNaoEncontradaException()
    : ErroDaTvException(404, "TV não encontrada. Abra o endereço da TV de novo.");

public sealed class CodigoDaTvNaoEncontradoException()
    : ErroDaTvException(404, "Código não encontrado. Confira o código que aparece na TV.");

public sealed class TvSemMusicaException()
    : ErroDaTvException(409, "A TV ainda não recebeu a música.");

public sealed class ConteudoDaTvInvalidoException()
    : ErroDaTvException(400, "A letra não pôde ir para a TV.");
