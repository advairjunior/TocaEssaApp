using TocaEssaApp.Api.Dominio;
using TocaEssaApp.Api.Infraestrutura;

namespace TocaEssaApp.Api.Rotas;

/// O que várias rotas usam: token, validações e formato das respostas.
public static class AuxiliaresDasRotas
{
    public static (string Extensao, string Tipo)? DetectarImagem(byte[] dados)
    {
        if (dados.Length >= 3 && dados[0] == 0xFF && dados[1] == 0xD8 && dados[2] == 0xFF)
            return (".jpg", "image/jpeg");
        if (dados.Length >= 8 && dados.AsSpan(0, 8).SequenceEqual(
                new byte[] { 0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A }))
            return (".png", "image/png");
        if (dados.Length >= 12 &&
            dados.AsSpan(0, 4).SequenceEqual("RIFF"u8) &&
            dados.AsSpan(8, 4).SequenceEqual("WEBP"u8))
            return (".webp", "image/webp");
        return null;
    }

    public static string? ObterToken(HttpRequest http)
    {
        var cabecalho = http.Headers.Authorization.ToString();
        const string prefixo = "Bearer ";
        return cabecalho.StartsWith(prefixo, StringComparison.OrdinalIgnoreCase)
            ? cabecalho[prefixo.Length..].Trim()
            : null;
    }

    public static Dictionary<string, string[]> ValidarPerfilPublico(
        string nome, string email, string senha)
    {
        var erros = new Dictionary<string, string[]>();
        if (string.IsNullOrWhiteSpace(nome) || nome.Trim().Length < 2)
            erros["nome"] = ["Informe seu nome."];
        if (string.IsNullOrWhiteSpace(email) || !email.Contains('@'))
            erros["email"] = ["Informe um e-mail válido."];
        if (string.IsNullOrWhiteSpace(senha) || senha.Length < 6)
            erros["senha"] = ["A senha deve ter pelo menos 6 caracteres."];
        return erros;
    }

    public static Dictionary<string, string[]> ValidarConta(
        string nome, string email, string senha) =>
        ValidarPerfilPublico(nome, email, senha);

    public static async Task<object> ParaStoryPublico(StoryDoShow story, ArmazenamentoDeStories armazenamento) => new
    {
        story.Id,
        story.Tipo,
        story.Nome,
        story.CriadoEm,
        story.TipoDeConteudo,
        story.DoArtista,
        url = await armazenamento.UrlDeLeitura(story.Chave)
    };
}
