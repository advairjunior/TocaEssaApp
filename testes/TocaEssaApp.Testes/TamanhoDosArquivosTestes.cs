namespace TocaEssaApp.Testes;

/// Arquivo menor é mais fácil de ler e de mudar sem quebrar o vizinho.
public class TamanhoDosArquivosTestes
{
    private const int TetoDeLinhas = 350;

    // Os que já passavam do teto quando a régua chegou (2026-10-22), com o
    // tamanho daquele dia: podem diminuir, nunca crescer. Ao dividir um
    // deles, tire-o daqui.
    private static readonly Dictionary<string, int> AcimaDoTeto = new()
    {
        ["Dominio/Modelos.cs"] = 424,
        ["Infraestrutura/BancoTocaEssa.cs"] = 866,
        ["Infraestrutura/RepositorioTocaEssa.Louvor.cs"] = 351,
        ["Infraestrutura/RepositorioTocaEssa.Pedidos.cs"] = 359,
        ["Infraestrutura/RepositorioTocaEssa.Persistencia.cs"] = 453,
    };

    [Fact]
    public void NenhumArquivoDoServidorCresceAlemDoTeto()
    {
        var raiz = Path.Combine(PastaDaSolucao(), "servidor", "TocaEssaApp.Api");
        var problemas = new List<string>();
        foreach (var arquivo in Directory.EnumerateFiles(raiz, "*.cs", SearchOption.AllDirectories))
        {
            var caminho = Path.GetRelativePath(raiz, arquivo).Replace('\\', '/');
            if (caminho.StartsWith("bin/") || caminho.StartsWith("obj/")) continue;
            var linhas = File.ReadAllLines(arquivo).Length;
            var limite = AcimaDoTeto.GetValueOrDefault(caminho, TetoDeLinhas);
            if (linhas > limite) problemas.Add($"{caminho}: {linhas} (limite {limite})");
        }

        Assert.True(problemas.Count == 0,
            "Divida por responsabilidade em vez de aumentar o limite:\n" +
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
