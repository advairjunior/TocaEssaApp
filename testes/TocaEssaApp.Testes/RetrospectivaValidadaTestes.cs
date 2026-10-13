using TocaEssaApp.Api.Dominio;
using TocaEssaApp.Api.Infraestrutura;

namespace TocaEssaApp.Testes;

/// A retrospectiva vira cartão compartilhado: só entram números verdadeiros,
/// sem repetição da mesma pessoa nem música que não foi tocada.
public class RetrospectivaValidadaTestes
{
    private static readonly DateTimeOffset Inicio = new(2026, 10, 17, 21, 0, 0, TimeSpan.Zero);

    [Fact]
    public void MesmaPessoaPedindoVariasVezesNaoViraFavorita()
    {
        var cenario = CriarCenario();
        for (var i = 0; i < 3; i++)
            cenario.Repo.CriarPedido(cenario.Show.Codigo, "Evidências", null, "Rui");

        var dados = Retrospectiva(cenario);

        Assert.Null(dados.Favorita);
        Assert.Equal([new MusicaMaisPedida("Evidências", 1)], dados.MaisPedidasPorPessoas);
        Assert.Equal(1, dados.PedidosConsiderados);
    }

    [Fact]
    public void FavoritaSoComDuasPessoasEDepoisDeTocada()
    {
        var cenario = CriarCenario();
        var rui = cenario.Repo.CriarPedido(cenario.Show.Codigo, "Evidências", null, "Rui");
        cenario.Repo.CriarPedido(cenario.Show.Codigo, "evidencias", null, "Bia");

        Assert.Null(Retrospectiva(cenario).Favorita);

        Tocar(cenario, rui.Id);
        var dados = Retrospectiva(cenario);

        Assert.Equal(new MusicaMaisPedida("Evidências", 2), dados.Favorita);
    }

    [Fact]
    public void MusicaPedidaPorTresETocadaUmaVezContaUmaMusica()
    {
        var cenario = CriarCenario();
        var primeiro = cenario.Repo.CriarPedido(cenario.Show.Codigo, "Asa Branca", null, "Rui");
        cenario.Repo.CriarPedido(cenario.Show.Codigo, "Asa Branca", null, "Bia");
        cenario.Repo.CriarPedido(cenario.Show.Codigo, "Asa Branca", null, "Leo");
        cenario.Repo.CriarPedido(cenario.Show.Codigo, "Macarena", null, "Leo");

        Tocar(cenario, primeiro.Id);
        var dados = Retrospectiva(cenario);

        Assert.Equal(1, dados.MusicasAPedidoTocadas);
        Assert.Equal(4, dados.PedidosConsiderados);
        Assert.Equal(3, dados.PedidosAtendidos);
    }

    [Fact]
    public void NotaValeUmVotoPorPessoaPorMusica()
    {
        var cenario = CriarCenario();
        var pedidos = new[] { "Rui", "Bia", "Leo" }
            .Select(nome => cenario.Repo.CriarPedido(cenario.Show.Codigo, "Asa Branca", null, nome))
            .ToArray();
        Tocar(cenario, pedidos[0].Id, StatusPedidoMusical.Finalizado);

        // A mesma pessoa avalia cada pedido do grupo: vale um voto, o último.
        foreach (var (pedido, estrelas) in new[] { (pedidos[0], 5), (pedidos[1], 5), (pedidos[2], 3) })
        {
            cenario.Agora = cenario.Agora.AddMinutes(1);
            cenario.Repo.AvaliarPedidoPeloPublico(cenario.Show.Codigo, pedido.Id, estrelas, "aparelho-ana");
        }
        Assert.Equal(1, Retrospectiva(cenario).PessoasQueAvaliaram);
        Assert.Equal(3, Retrospectiva(cenario).MediaDasAvaliacoes);

        cenario.Repo.AvaliarPedidoPeloPublico(cenario.Show.Codigo, pedidos[0].Id, 5, "aparelho-caio");
        var dados = Retrospectiva(cenario);
        Assert.Equal(2, dados.PessoasQueAvaliaram);
        Assert.Equal(4, dados.MediaDasAvaliacoes);
    }

    [Fact]
    public void MusicasTocadasJuntamSetlistEPedidosSemRepetir()
    {
        var cenario = CriarCenario();
        var repertorio = cenario.Repo.CriarRepertorio(cenario.Token, "Noite");
        foreach (var titulo in new[] { "Evidências", "Tempo Perdido", "Pense em Mim" })
            cenario.Repo.AdicionarMusicaAoRepertorio(cenario.Token, repertorio.Id, titulo, null);
        var setlist = cenario.Repo.ImportarRepertorioParaSetlist(
            cenario.Token, cenario.Show.Id, repertorio.Id).ToArray();
        cenario.Repo.MarcarItemDoSetlist(cenario.Token, cenario.Show.Id, setlist[0].Id, tocada: true);
        cenario.Repo.MarcarItemDoSetlist(cenario.Token, cenario.Show.Id, setlist[1].Id, tocada: true);
        var repetida = cenario.Repo.CriarPedido(cenario.Show.Codigo, "evidencias", null, "Rui");
        var nova = cenario.Repo.CriarPedido(cenario.Show.Codigo, "Asa Branca", null, "Bia");
        Tocar(cenario, repetida.Id, StatusPedidoMusical.Finalizado);
        Tocar(cenario, nova.Id);

        Assert.Equal(3, Retrospectiva(cenario).MusicasTocadas);
    }

    [Fact]
    public void AloContaSoQuandoDadoEUmaVezPorPessoaEDestinatario()
    {
        var cenario = CriarCenario();
        Alo(cenario, "Rui", "Bia", dado: true);
        Alo(cenario, "Rui", "bia", dado: true);
        Alo(cenario, "Leo", "Bia", dado: true);
        Alo(cenario, "Leo", "Caio", dado: false);

        Assert.Equal(2, Retrospectiva(cenario).AlosDados);
    }

    [Fact]
    public void RecusadasContamPessoasDiferentes()
    {
        var cenario = CriarCenario();
        var primeiro = cenario.Repo.CriarPedido(cenario.Show.Codigo, "Macarena", null, "Rui");
        cenario.Repo.CriarPedido(cenario.Show.Codigo, "Macarena", null, "Rui");
        cenario.Repo.AlterarStatusDoGrupo(
            cenario.Token, cenario.Show.Id, primeiro.Id, StatusPedidoMusical.NaoConhecemos);

        Assert.Equal([new MusicaMaisPedida("Macarena", 1)], Retrospectiva(cenario).RecusadasPorPessoas);
    }

    [Fact]
    public void DuracaoSoDeShowEncerradoComTempoPlausivel()
    {
        var cenario = CriarCenario();
        cenario.Repo.AlterarStatusApresentacao(
            cenario.Token, cenario.Show.Id, StatusApresentacao.EmAndamento);
        cenario.Agora = Inicio.AddHours(3);

        // Ainda ao vivo: sem horário de fim, nada de duração.
        Assert.Null(Retrospectiva(cenario).EncerradaEm);

        cenario.Repo.AlterarStatusApresentacao(
            cenario.Token, cenario.Show.Id, StatusApresentacao.Encerrada);
        var dados = Retrospectiva(cenario);
        Assert.Equal(Inicio, dados.IniciadaEm);
        Assert.Equal(Inicio.AddHours(3), dados.EncerradaEm);
    }

    [Theory]
    [InlineData(10)]
    [InlineData(13 * 60)]
    public void DuracaoImplausivelNaoAparece(int minutos)
    {
        var cenario = CriarCenario();
        cenario.Repo.AlterarStatusApresentacao(
            cenario.Token, cenario.Show.Id, StatusApresentacao.EmAndamento);
        cenario.Agora = Inicio.AddMinutes(minutos);
        cenario.Repo.AlterarStatusApresentacao(
            cenario.Token, cenario.Show.Id, StatusApresentacao.Encerrada);

        var dados = Retrospectiva(cenario);
        Assert.Null(dados.IniciadaEm);
        Assert.Null(dados.EncerradaEm);
    }

    private static DadosDaRetrospectiva Retrospectiva(Cenario cenario) =>
        cenario.Repo.ObterEstatisticasDaApresentacao(cenario.Token, cenario.Show.Id).Retrospectiva!;

    private static void Tocar(
        Cenario cenario, Guid pedidoId,
        StatusPedidoMusical status = StatusPedidoMusical.TocandoAgora) =>
        cenario.Repo.AlterarStatusDoGrupo(cenario.Token, cenario.Show.Id, pedidoId, status);

    private static void Alo(Cenario cenario, string quem, string para, bool dado)
    {
        var alo = cenario.Repo.CriarPedido(
            cenario.Show.Codigo, "Alô", null, quem, tipo: TipoPedido.Alo, destinatarioAlo: para);
        if (dado) Tocar(cenario, alo.Id, StatusPedidoMusical.Finalizado);
    }

    private static Cenario CriarCenario()
    {
        var repo = new RepositorioTocaEssa();
        var token = repo.CriarContaArtista("Ana", "ana@artista.com", "senha").Token;
        repo.SalvarPerfilDaConta(token, new SalvarPerfilArtistico("Ana", null));
        var show = repo.CriarApresentacao(token, "Casamento", new DateOnly(2026, 10, 17), "Salão");
        var cenario = new Cenario(repo, token, show);
        repo.Agora = () => cenario.Agora;
        return cenario;
    }

    private sealed class Cenario(RepositorioTocaEssa repo, string token, Apresentacao show)
    {
        public RepositorioTocaEssa Repo { get; } = repo;
        public string Token { get; } = token;
        public Apresentacao Show { get; } = show;
        public DateTimeOffset Agora { get; set; } = Inicio;
    }
}
