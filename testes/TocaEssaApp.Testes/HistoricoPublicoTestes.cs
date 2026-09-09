using TocaEssaApp.Api.Dominio;
using TocaEssaApp.Api.Infraestrutura;

namespace TocaEssaApp.Testes;

public class HistoricoPublicoTestes
{
    [Fact]
    public void HistoricoIncluiPresencaSemPedidoEEncontroEncerradoSemMisturarContas()
    {
        var repo = new RepositorioTocaEssa();
        repo.SalvarPerfil("Duo", null);
        var resenha = repo.CriarApresentacao("Entre amigos", new DateOnly(2026, 9, 1),
            "Casa", TipoApresentacao.ResenhaEntreAmigos);
        var show = repo.CriarApresentacao("Show", new DateOnly(2026, 9, 2), "Praça");
        var ana = repo.CriarPerfilPublico("Ana", "ana@teste.com", "senha123");
        var bia = repo.CriarPerfilPublico("Bia", "bia@teste.com", "senha123");
        repo.RegistrarParticipacaoNaResenha(resenha.Codigo, ana.Token);
        repo.CriarPedido(show.Codigo, "Evidências", null, null, bia.Token);
        repo.AlterarStatusApresentacao(resenha.Id, StatusApresentacao.Encerrada);

        var memoria = Assert.Single(repo.ListarApresentacoesDoPublico(ana.Token));
        Assert.Equal(resenha.Id, memoria.Id);
        Assert.Equal(StatusApresentacao.Encerrada, memoria.Status);
        Assert.Equal(show.Id, Assert.Single(repo.ListarApresentacoesDoPublico(bia.Token)).Id);
        Assert.Throws<SessaoPublicaInvalidaException>(() =>
            repo.ListarApresentacoesDoPublico("token-invalido"));
    }
}
