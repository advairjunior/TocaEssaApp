using System.Reflection;
using TocaEssaApp.Api.Dominio;
using TocaEssaApp.Api.Infraestrutura;

namespace TocaEssaApp.Testes;

public sealed class ContasArtistasTestes
{
    [Fact]
    public void DoisArtistasPodemCriarContaEEntrar()
    {
        var repositorio = new RepositorioTocaEssa();

        var ana = repositorio.CriarContaArtista(
            "Ana", "ana@artista.com", "senha123");
        var bia = repositorio.CriarContaArtista(
            "Bia", "bia@artista.com", "outrasenha");

        Assert.NotEqual(ana.Conta.Id, bia.Conta.Id);
        Assert.Equal(ana.Conta.Id,
            repositorio.EntrarContaArtista("ANA@ARTISTA.COM", "senha123").Conta.Id);
        Assert.Equal(bia.Conta.Id,
            repositorio.EntrarContaArtista("bia@artista.com", "outrasenha").Conta.Id);
    }

    [Fact]
    public void EmailArtisticoDuplicadoIgnoraMaiusculasEEspacos()
    {
        var repositorio = new RepositorioTocaEssa();
        repositorio.CriarContaArtista("Ana", "ana@artista.com", "senha123");

        var erro = Record.Exception(() => repositorio.CriarContaArtista(
            "Outra Ana", "  ANA@ARTISTA.COM  ", "outrasenha"));

        Assert.NotNull(erro);
        Assert.Equal("EmailArtistaJaCadastradoException", erro.GetType().Name);
    }

    [Fact]
    public async Task CadastrosConcorrentesNaoDuplicamEmail()
    {
        var repositorio = new RepositorioTocaEssa();
        using var inicio = new ManualResetEventSlim(false);
        var tarefas = Enumerable.Range(0, 2).Select(indice => Task.Run(() =>
        {
            inicio.Wait();
            return Record.Exception(() => repositorio.CriarContaArtista(
                $"Artista {indice}", "mesmo@artista.com", $"senha{indice}23"));
        })).ToArray();

        inicio.Set();
        var resultados = await Task.WhenAll(tarefas);

        Assert.Single(resultados, erro => erro is null);
        var duplicado = Assert.Single(resultados, erro => erro is not null);
        Assert.Equal("EmailArtistaJaCadastradoException", duplicado!.GetType().Name);
    }

    [Fact]
    public void CadaArtistaPossuiSeuProprioPerfil()
    {
        var caminho = Path.Combine(
            Path.GetTempPath(), $"tocaessa-perfis-{Guid.NewGuid():N}.db");
        try
        {
            var repositorio = new RepositorioTocaEssa(caminho);
            var ana = repositorio.CriarContaArtista(
                "Ana", "ana@artista.com", "senha123");
            var bia = repositorio.CriarContaArtista(
                "Bia", "bia@artista.com", "outrasenha");

            SalvarPerfil(repositorio, ana.Token, "Duo Aurora");
            SalvarPerfil(repositorio, bia.Token, "Banda Horizonte");

            var reiniciado = new RepositorioTocaEssa(caminho);
            var sessaoAna = reiniciado.EntrarContaArtista(
                "ana@artista.com", "senha123");
            var sessaoBia = reiniciado.EntrarContaArtista(
                "bia@artista.com", "outrasenha");
            Assert.Equal("Duo Aurora",
                ObterPerfil(reiniciado, sessaoAna.Token)?.NomeArtistico);
            Assert.Equal("Banda Horizonte",
                ObterPerfil(reiniciado, sessaoBia.Token)?.NomeArtistico);
        }
        finally
        {
            ExcluirBanco(caminho);
        }
    }

    private static void SalvarPerfil(
        RepositorioTocaEssa repositorio, string token, string nome)
    {
        var metodo = typeof(RepositorioTocaEssa).GetMethod(
            "SalvarPerfilDaConta",
            BindingFlags.Instance | BindingFlags.Public,
            binder: null,
            [typeof(string), typeof(SalvarPerfilArtistico)],
            modifiers: null);
        Assert.NotNull(metodo);
        _ = metodo.Invoke(repositorio,
            [token, new SalvarPerfilArtistico(nome, null)]);
    }

    private static PerfilArtistico? ObterPerfil(
        RepositorioTocaEssa repositorio, string token)
    {
        var metodo = typeof(RepositorioTocaEssa).GetMethod(
            "ObterPerfil",
            BindingFlags.Instance | BindingFlags.Public,
            binder: null,
            [typeof(string)],
            modifiers: null);
        Assert.NotNull(metodo);
        return Assert.IsType<PerfilArtistico>(metodo.Invoke(repositorio, [token]));
    }

    private static void ExcluirBanco(string caminho)
    {
        foreach (var arquivo in new[] { caminho, $"{caminho}-shm", $"{caminho}-wal" })
            if (File.Exists(arquivo)) File.Delete(arquivo);
    }
}
