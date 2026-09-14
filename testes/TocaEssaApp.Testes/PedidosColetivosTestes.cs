using TocaEssaApp.Api.Dominio;
using TocaEssaApp.Api.Infraestrutura;

namespace TocaEssaApp.Testes;

public class PedidosColetivosTestes
{
    [Fact]
    public void PedidosEquivalentesFormamUmGrupoDestacado()
    {
        var repositorio = CriarRepositorioComApresentacao(out var apresentacao);
        repositorio.CriarPedido(apresentacao.Codigo, "  Evidências ",
            "Chitãozinho   & Xororó", "Ana");
        repositorio.CriarPedido(apresentacao.Codigo, "evidências",
            "chitãozinho & xororó", "Beto");

        var grupo = repositorio.ListarGruposDePedidosDoArtista(apresentacao.Id).Single();

        Assert.Equal(2, grupo.QuantidadePedidos);
        Assert.Equal(2, grupo.PedidoIds.Count);
        Assert.Equal(["Ana", "Beto"], grupo.Solicitantes);
    }

    [Fact]
    public void AceitarGrupoAlteraTodosENovaDuplicataHerdaAFila()
    {
        var repositorio = CriarRepositorioComApresentacao(out var apresentacao);
        var primeiro = repositorio.CriarPedido(
            apresentacao.Codigo, "Evidências", null, "Ana");
        repositorio.CriarPedido(
            apresentacao.Codigo, "evidências", null, "Beto");

        repositorio.AlterarStatusDoGrupo(
            apresentacao.Id, primeiro.Id, StatusPedidoMusical.Aceito);
        var terceiro = repositorio.CriarPedido(
            apresentacao.Codigo, " EVIDÊNCIAS ", null, "Carla");

        Assert.Equal(StatusPedidoMusical.Aceito, terceiro.Status);
        Assert.All(
            repositorio.ListarPedidosDoArtista(apresentacao.Id),
            pedido => Assert.Equal(StatusPedidoMusical.Aceito, pedido.Status));
        Assert.Equal(3, repositorio
            .ListarGruposDePedidosDoArtista(apresentacao.Id).Single()
            .QuantidadePedidos);
    }

    [Fact]
    public void PedidoDepoisDaFinalizacaoIniciaNovoGrupoAguardando()
    {
        var repositorio = CriarRepositorioComApresentacao(out var apresentacao);
        var primeiro = repositorio.CriarPedido(
            apresentacao.Codigo, "Evidências", null, "Ana");
        repositorio.AlterarStatusDoGrupo(
            apresentacao.Id, primeiro.Id, StatusPedidoMusical.Aceito);
        repositorio.AlterarStatusDoGrupo(
            apresentacao.Id, primeiro.Id, StatusPedidoMusical.Finalizado);

        var novo = repositorio.CriarPedido(
            apresentacao.Codigo, "Evidências", null, "Beto");

        Assert.Equal(StatusPedidoMusical.Aguardando, novo.Status);
        Assert.Equal(2, repositorio
            .ListarGruposDePedidosDoArtista(apresentacao.Id).Count);
    }

    [Fact]
    public void CancelarUmPedidoMantemOsDemaisNoGrupo()
    {
        var repositorio = CriarRepositorioComApresentacao(out var apresentacao);
        var ana = repositorio.CriarPedido(
            apresentacao.Codigo, "Evidências", null, "Ana");
        repositorio.CriarPedido(
            apresentacao.Codigo, "evidências", null, "Beto");

        repositorio.CancelarPedidoPeloPublico(apresentacao.Codigo, ana.Id);

        var grupo = repositorio.ListarGruposDePedidosDoArtista(apresentacao.Id)
            .Single(item => item.Status == StatusPedidoMusical.Aguardando);
        Assert.Equal(1, grupo.QuantidadePedidos);
        Assert.Equal(["Beto"], grupo.Solicitantes);
    }

    [Fact]
    public void GrafiasDiferentesEAlosNaoEntramNoMesmoGrupoMusical()
    {
        var repositorio = CriarRepositorioComApresentacao(out var apresentacao);
        repositorio.CriarPedido(apresentacao.Codigo, "Evidências", null, "Ana");
        repositorio.CriarPedido(apresentacao.Codigo, "Evidencia", null, "Beto");
        repositorio.CriarPedido(apresentacao.Codigo, "", null, "Carla",
            tipo: TipoPedido.Alo, destinatarioAlo: "Mesa 4");

        var grupos = repositorio.ListarGruposDePedidosDoArtista(apresentacao.Id);

        Assert.Equal(3, grupos.Count);
        Assert.Equal(2, grupos.Count(item => item.Tipo == TipoPedido.Musica));
        Assert.Single(grupos, item => item.Tipo == TipoPedido.Alo);
    }

    [Fact]
    public void ReordenarGruposMantemMembrosContiguos()
    {
        var repositorio = CriarRepositorioComApresentacao(out var apresentacao);
        var evidencia = repositorio.CriarPedido(
            apresentacao.Codigo, "Evidências", null, "Ana");
        repositorio.CriarPedido(
            apresentacao.Codigo, "evidências", null, "Beto");
        var tempo = repositorio.CriarPedido(
            apresentacao.Codigo, "Tempo perdido", null, "Carla");
        repositorio.AlterarStatusDoGrupo(
            apresentacao.Id, evidencia.Id, StatusPedidoMusical.Aceito);
        repositorio.AlterarStatusDoGrupo(
            apresentacao.Id, tempo.Id, StatusPedidoMusical.Aceito);

        repositorio.ReordenarGruposDaFila(
            apresentacao.Id, [tempo.Id, evidencia.Id]);

        var fila = repositorio.ListarPedidosDoArtista(apresentacao.Id)
            .Where(item => item.Status == StatusPedidoMusical.Aceito)
            .ToArray();
        Assert.Equal(["Tempo perdido", "Evidências", "evidências"],
            fila.Select(item => item.Musica));
        Assert.Equal([1, 2, 3], fila.Select(item => item.Posicao));
    }

    private static RepositorioTocaEssa CriarRepositorioComApresentacao(
        out Apresentacao apresentacao)
    {
        var repositorio = new RepositorioTocaEssa();
        repositorio.SalvarPerfil("Duo Aurora", null);
        apresentacao = repositorio.CriarApresentacao(
            "Noite acústica", new DateOnly(2026, 9, 20), "Café Central",
            TipoApresentacao.Publica);
        return repositorio;
    }
}
