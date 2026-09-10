using TocaEssaApp.Api.Infraestrutura;

namespace TocaEssaApp.Testes;

public class CifrasDoArtistaTestes
{
    [Fact]
    public void NormalizaMusicaEArtistaSemVazarEntreContas()
    {
        var primeiro = CriarRepositorioComConta("ana@teste.com", out var tokenAna);
        var segundo = CriarRepositorioComConta("bia@teste.com", out var tokenBia);

        var salva = primeiro.SalvarCifraDoArtista(tokenAna, "Evidências",
            "Chitãozinho & Xororó",
            "https://www.cifraclub.com.br/chitaozinho-e-xororo/evidencias/");

        var encontrada = primeiro.ObterCifraDoArtista(
            tokenAna, " evidencias! ", "CHITAOZINHO E XORORO");
        Assert.Equal(salva.Id, encontrada.Cifra?.Id);
        Assert.Null(primeiro.ObterCifraDoArtista(tokenAna, "Evidências", null).Cifra);
        Assert.Null(segundo.ObterCifraDoArtista(tokenBia,
            "Evidências", "Chitãozinho & Xororó").Cifra);
    }

    [Fact]
    public void SugereCifraEPesquisaSemConsultarSiteExterno()
    {
        var repo = CriarRepositorioComConta("ana@teste.com", out var token);

        var resultado = repo.ObterCifraDoArtista(
            token, "Evidências", "Chitãozinho & Xororó");

        Assert.Equal(
            "https://www.cifraclub.com.br/chitaozinho-e-xororo/evidencias/",
            resultado.UrlSugerida);
        Assert.Contains("site%3Acifraclub.com.br", resultado.UrlPesquisa);
        Assert.Contains("Evid%25C3%25AAncias", Uri.EscapeDataString(resultado.UrlPesquisa));
    }

    [Fact]
    public void SubstituiERemoveCifraDaMesmaMusica()
    {
        var repo = CriarRepositorioComConta("ana@teste.com", out var token);
        var inicial = repo.SalvarCifraDoArtista(token, "Evidências", null,
            "https://www.cifraclub.com.br/primeira/");
        var atualizada = repo.SalvarCifraDoArtista(token, " evidencias ", null,
            "https://cifras.com.br/segunda");

        Assert.Equal(inicial.Id, atualizada.Id);
        Assert.Equal("cifras.com.br", atualizada.Fonte);
        Assert.Single(repo.ListarCifrasDoArtista(token));

        repo.RemoverCifraDoArtista(token, inicial.Id);
        Assert.Empty(repo.ListarCifrasDoArtista(token));
    }

    [Theory]
    [InlineData("javascript:alert(1)")]
    [InlineData("https://usuario:senha@exemplo.com/cifra")]
    [InlineData("http://localhost/cifra")]
    [InlineData("http://127.0.0.1/cifra")]
    [InlineData("http://192.168.1.10/cifra")]
    public void RecusaEnderecoPerigoso(string url)
    {
        var repo = CriarRepositorioComConta("ana@teste.com", out var token);

        Assert.Throws<UrlDeCifraInvalidaException>(() =>
            repo.SalvarCifraDoArtista(token, "Música", null, url));
    }

    [Fact]
    public void PersisteCifraESessaoNoSqlite()
    {
        var arquivo = Path.Combine(Path.GetTempPath(),
            $"tocaessa-cifras-{Guid.NewGuid()}.db");
        try
        {
            var repo = new RepositorioTocaEssa(arquivo);
            var sessao = repo.CriarContaArtista(
                "Ana", "ana@teste.com", "senha123");
            var salva = repo.SalvarCifraDoArtista(sessao.Token,
                "Evidências", "Chitãozinho & Xororó",
                "https://www.cifraclub.com.br/chitaozinho-e-xororo/evidencias/");

            var reiniciado = new RepositorioTocaEssa(arquivo);

            Assert.Equal(salva.Id,
                reiniciado.ListarCifrasDoArtista(sessao.Token).Single().Id);
        }
        finally
        {
            ExcluirBanco(arquivo);
        }
    }

    private static RepositorioTocaEssa CriarRepositorioComConta(
        string email, out string token)
    {
        var repo = new RepositorioTocaEssa();
        token = repo.CriarContaArtista("Artista", email, "senha123").Token;
        return repo;
    }

    private static void ExcluirBanco(string caminho)
    {
        foreach (var arquivo in new[] { caminho, $"{caminho}-shm", $"{caminho}-wal" })
            if (File.Exists(arquivo)) File.Delete(arquivo);
    }
}
