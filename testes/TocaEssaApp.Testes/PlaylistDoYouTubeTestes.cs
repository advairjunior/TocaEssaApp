using System.Net;
using System.Text;
using TocaEssaApp.Api.Dominio;
using TocaEssaApp.Api.Infraestrutura;

namespace TocaEssaApp.Testes;

/// Leitura da playlist pela API oficial do YouTube (playlistItems), com um
/// servidor falso no lugar do Google.
public sealed class PlaylistDoYouTubeTestes
{
    [Theory]
    [InlineData("https://youtube.com/playlist?list=PLeHLlswxpAUNM5fn1gwmNLloimGhIAfsh&si=MGCbGkE8BfnRvjIJ",
        "PLeHLlswxpAUNM5fn1gwmNLloimGhIAfsh")]
    [InlineData("https://www.youtube.com/watch?v=xKPaBwlI16o&list=PLabc_123-XYZ", "PLabc_123-XYZ")]
    [InlineData("https://music.youtube.com/playlist?list=PLmusica", "PLmusica")]
    [InlineData("  PLsoOId  ", "PLsoOId")]
    public void AchaOIdDaPlaylistNoLink(string link, string esperado) =>
        Assert.Equal(esperado, PlaylistDoYouTube.IdDaPlaylist(link));

    [Theory]
    [InlineData("https://www.youtube.com/watch?v=xKPaBwlI16o")]
    [InlineData("https://exemplo.com/playlist?list=PLabc")]
    [InlineData("não é link")]
    [InlineData("")]
    public void LinkSemPlaylistNaoTemId(string link) =>
        Assert.Null(PlaylistDoYouTube.IdDaPlaylist(link));

    [Fact]
    public async Task LeTodasAsPaginasEPulaVideoPrivadoOuApagado()
    {
        var pedidos = new List<Uri>();
        var leitor = Leitor(pedidos, pagina => pagina switch
        {
            null => Pagina("p2",
                ("xKPaBwlI16o", "Thiaguinho - Falta Você - Karaoke", "public"),
                ("priv1", "Private video", "private")),
            "p2" => Pagina(null,
                ("aorrMojEBcw", "Desejo Imortal - Gusttavo Lima (Karaokê Version)", "public"),
                ("apag1", "Deleted video", "privacyStatusUnspecified")),
            _ => throw new InvalidOperationException()
        });

        var lida = await leitor.LerAsync("PLabc");

        Assert.Equal("Karaokê da casa", lida.Titulo);
        Assert.Equal(
            [("Thiaguinho - Falta Você", "https://www.youtube.com/watch?v=xKPaBwlI16o"),
             ("Desejo Imortal - Gusttavo Lima", "https://www.youtube.com/watch?v=aorrMojEBcw")],
            lida.Musicas.Select(m => (m.Titulo, m.LinkDoVideo)));
        Assert.All(pedidos, uri => Assert.Contains("key=CHAVE", uri.Query));
        Assert.Contains("pageToken=p2", pedidos[2].Query);
    }

    [Fact]
    public async Task PlaylistQueNaoExisteOuPrivadaAvisa()
    {
        var leitor = new LeitorDePlaylistDoYouTube(
            new HttpClient(new RespostaFalsa(_ => new HttpResponseMessage(HttpStatusCode.NotFound))),
            "CHAVE");

        await Assert.ThrowsAsync<PlaylistNaoEncontradaException>(() => leitor.LerAsync("PLnada"));
    }

    [Fact]
    public async Task SemChaveDaApiAvisaQueAImportacaoNaoEstaDisponivel()
    {
        var leitor = new LeitorDePlaylistDoYouTube(
            new HttpClient(new RespostaFalsa(_ => throw new InvalidOperationException())), null);

        await Assert.ThrowsAsync<ImportacaoDePlaylistIndisponivelException>(() => leitor.LerAsync("PLabc"));
    }

    private static LeitorDePlaylistDoYouTube Leitor(List<Uri> pedidos, Func<string?, string> pagina) =>
        new(new HttpClient(new RespostaFalsa(pedido =>
        {
            pedidos.Add(pedido.RequestUri!);
            var corpo = pedido.RequestUri!.AbsolutePath.EndsWith("/playlists")
                ? """{"items":[{"snippet":{"title":"Karaokê da casa"}}]}"""
                : pagina(System.Web.HttpUtility.ParseQueryString(pedido.RequestUri.Query)["pageToken"]);
            return new HttpResponseMessage(HttpStatusCode.OK)
            {
                Content = new StringContent(corpo, Encoding.UTF8, "application/json")
            };
        })), "CHAVE");

    private static string Pagina(string? proxima, params (string Id, string Titulo, string Privacidade)[] videos) =>
        System.Text.Json.JsonSerializer.Serialize(new
        {
            nextPageToken = proxima,
            items = videos.Select(v => new
            {
                snippet = new { title = v.Titulo, resourceId = new { videoId = v.Id } },
                status = new { privacyStatus = v.Privacidade }
            })
        });

    private sealed class RespostaFalsa(Func<HttpRequestMessage, HttpResponseMessage> responder)
        : HttpMessageHandler
    {
        protected override Task<HttpResponseMessage> SendAsync(
            HttpRequestMessage pedido, CancellationToken cancelamento) =>
            Task.FromResult(responder(pedido));
    }
}
