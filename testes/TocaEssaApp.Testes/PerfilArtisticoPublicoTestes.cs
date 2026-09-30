using TocaEssaApp.Api.Dominio;
using TocaEssaApp.Api.Infraestrutura;

namespace TocaEssaApp.Testes;

public class PerfilArtisticoPublicoTestes
{
    [Fact]
    public void PerfilExpoeSomenteContatosAutorizadosENuncaAChavePix()
    {
        var repositorio = new RepositorioTocaEssa();
        repositorio.SalvarPerfil(new SalvarPerfilArtistico(
            "Duo Aurora", "Voz e violão", "duoaurora", true,
            "5511999999999", false, true, "chave-secreta",
            "DUO AURORA", "SAO PAULO", "Obrigado pelo apoio"));

        var publico = repositorio.ObterPerfil()!;
        var privado = repositorio.ObterConfiguracaoPerfil()!;

        Assert.Equal("duoaurora", publico.Instagram);
        Assert.Null(publico.Whatsapp);
        Assert.True(publico.ApoioPixDisponivel);
        Assert.Equal("chave-secreta", privado.PixChave);
    }

    [Fact]
    public void NovosDadosDoPerfilPersistemEPerfilSemContatosContinuaValido()
    {
        var arquivo = Path.Combine(
            Path.GetTempPath(), $"perfil-{Guid.NewGuid()}.db");
        try
        {
            var repositorio = new RepositorioTocaEssa(arquivo);
            repositorio.CriarContaArtista("Ana", "ana@artista.com", "senha123");
            repositorio.SalvarPerfil(new SalvarPerfilArtistico(
                "Duo Aurora", null, null, false, null, false, false));

            var reiniciado = new RepositorioTocaEssa(arquivo);
            var perfil = reiniciado.ObterPerfil()!;

            Assert.Null(perfil.Instagram);
            Assert.Null(perfil.Whatsapp);
            Assert.False(perfil.ApoioPixDisponivel);
        }
        finally
        {
            foreach (var item in new[]
                     {
                         arquivo,
                         $"{arquivo}-shm",
                         $"{arquivo}-wal"
                     })
                if (File.Exists(item)) File.Delete(item);
        }
    }
}
