namespace TocaEssaApp.Testes;

/// Arquivo menor é mais fácil de ler e de mudar sem quebrar o vizinho.
public class TamanhoDosArquivosTestes
{
    private const int TetoDeLinhas = 350;

    [Fact]
    public void NenhumArquivoDoServidorPassaDoTeto()
    {
        var raiz = Path.Combine(PastaDaSolucao(), "servidor", "TocaEssaApp.Api");
        var problemas = new List<string>();
        foreach (var arquivo in Directory.EnumerateFiles(raiz, "*.cs", SearchOption.AllDirectories))
        {
            var caminho = Path.GetRelativePath(raiz, arquivo).Replace('\\', '/');
            if (caminho.StartsWith("bin/") || caminho.StartsWith("obj/")) continue;
            var linhas = File.ReadAllLines(arquivo).Length;
            if (linhas > TetoDeLinhas) problemas.Add($"{caminho}: {linhas}");
        }

        Assert.True(problemas.Count == 0,
            "Divida por responsabilidade em vez de aumentar o teto:\n" +
            string.Join('\n', problemas));
    }

    private static string PastaDaSolucao()
    {
        var pasta = new DirectoryInfo(AppContext.BaseDirectory);
        while (pasta is not null && !File.Exists(Path.Combine(pasta.FullName, "TocaEssaApp.sln")))
            pasta = pasta.Parent;
        return pasta?.FullName
            ?? throw new InvalidOperationException("Solução não encontrada.");
    }
}
