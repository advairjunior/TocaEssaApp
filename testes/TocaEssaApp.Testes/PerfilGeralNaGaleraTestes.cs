using System.Text.Json;
using TocaEssaApp.Api.Dominio;
using TocaEssaApp.Api.Infraestrutura;

namespace TocaEssaApp.Testes;

public class PerfilGeralNaGaleraTestes
{
    [Fact]
    public void GaleraSeparaTrajetoriaGeralDoEncontroSemExporCredenciais()
    {
        var repositorio = new RepositorioTocaEssa();
        repositorio.SalvarPerfil("Duo", null);
        var atual = repositorio.CriarApresentacao("Resenha", new DateOnly(2026, 9, 9),
            "Casa", TipoApresentacao.ResenhaEntreAmigos);
        var outra = repositorio.CriarApresentacao("Show", new DateOnly(2026, 9, 10),
            "Praça", TipoApresentacao.Publica);
        var ana = repositorio.CriarPerfilPublico("Ana", "ana@exemplo.com", "senha123");
        repositorio.RegistrarParticipacaoNaResenha(atual.Codigo, ana.Token);
        repositorio.CriarPedido(atual.Codigo, "Música daqui", null, null, ana.Token);
        repositorio.CriarPedido(outra.Codigo, "Música de outro show", null, null, ana.Token);

        var participante = repositorio.ListarParticipantesDaResenha(atual.Id)
            .Single(item => item.PublicoId == ana.Perfil.Id);
        Assert.Equal(1, participante.Pedidos);
        Assert.Single(participante.MusicasMaisPedidas);
        var geral = Assert.IsType<EstatisticasDoPublico>(participante.EstatisticasGerais);
        Assert.Equal(2, geral.Pedidos);
        Assert.Equal(2, geral.Participacoes);
        Assert.Equal(repositorio.ObterEstatisticasDoPublico(ana.Token).Pedidos, geral.Pedidos);
        var json = JsonSerializer.Serialize(participante);
        Assert.DoesNotContain("ana@exemplo.com", json);
        Assert.DoesNotContain(ana.Token, json);
        Assert.DoesNotContain("Senha", json);
    }
}
