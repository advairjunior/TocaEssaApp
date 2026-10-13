using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.Data.Sqlite;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.DependencyInjection.Extensions;
using Microsoft.Extensions.Logging;
using TocaEssaApp.Api.Dominio;
using TocaEssaApp.Api.Infraestrutura;

namespace TocaEssaApp.Testes;

/// A setlist do show é montada com músicas do acervo (vários repertórios),
/// avulsas, e pode ser editada sem mexer no que já foi tocado.
public class MontarSetlistTestes
{
    [Fact]
    public void AdicionaDeVariosRepertoriosNoFimSemApagar()
    {
        var c = CriarCenario();

        c.Repo.AdicionarMusicasAoSetlist(c.Token, c.Show.Id, [c.Romanticas[0].Id, c.Romanticas[2].Id]);
        var setlist = c.Repo.AdicionarMusicasAoSetlist(c.Token, c.Show.Id, [c.Animadas[1].Id]);

        Assert.Equal(["Evidências", "Pense em Mim", "Ragatanga"], setlist.Select(i => i.Titulo));
        Assert.Equal([1, 2, 3], setlist.Select(i => i.Ordem));
    }

    [Fact]
    public void MesmaMusicaNaoEntraDuasVezes()
    {
        var c = CriarCenario();
        var repetida = c.Repo.AdicionarMusicaAoRepertorio(c.Token, c.AnimadasId, "evidencias", null);

        var setlist = c.Repo.AdicionarMusicasAoSetlist(c.Token, c.Show.Id,
            [c.Romanticas[0].Id, repetida.Id, c.Romanticas[0].Id]);

        Assert.Equal(["Evidências"], setlist.Select(i => i.Titulo));
    }

    [Fact]
    public void MusicaDeOutroArtistaNaoEntra()
    {
        var c = CriarCenario();
        var tokenBia = c.Repo.CriarContaArtista("Bia", "bia@artista.com", "senha").Token;
        var daBia = c.Repo.CriarRepertorio(tokenBia, "Bia");
        var musicaDaBia = c.Repo.AdicionarMusicaAoRepertorio(tokenBia, daBia.Id, "Segredo", null);

        Assert.Throws<MusicaDoRepertorioNaoEncontradaException>(() =>
            c.Repo.AdicionarMusicasAoSetlist(c.Token, c.Show.Id, [musicaDaBia.Id]));
        Assert.Throws<ApresentacaoNaoEncontradaException>(() =>
            c.Repo.AdicionarMusicasAoSetlist(tokenBia, c.Show.Id, [musicaDaBia.Id]));
        Assert.Empty(c.Repo.ObterSetlist(c.Token, c.Show.Id));
    }

    [Fact]
    public void AvulsaEntraNoFimEPodeFicarNoAcervo()
    {
        var c = CriarCenario();
        c.Repo.AdicionarMusicasAoSetlist(c.Token, c.Show.Id, [c.Romanticas[0].Id]);

        c.Repo.AdicionarMusicaAvulsaAoSetlist(c.Token, c.Show.Id, "Parabéns", null, null, null);
        var setlist = c.Repo.AdicionarMusicaAvulsaAoSetlist(
            c.Token, c.Show.Id, "Hino da empresa", "Coral", "C", c.AnimadasId);

        Assert.Equal(["Evidências", "Parabéns", "Hino da empresa"], setlist.Select(i => i.Titulo));
        var noAcervo = c.Repo.ListarRepertorios(c.Token).Single(r => r.Id == c.AnimadasId)
            .Musicas.Single(m => m.Titulo == "Hino da empresa");
        Assert.Equal("Coral", noAcervo.Artista);
        // Ficou ligada ao acervo: a correção chega na setlist.
        c.Repo.EditarMusicaDoRepertorio(c.Token, c.AnimadasId, noAcervo.Id, "Hino da firma", "Coral", "C");
        Assert.Equal("Hino da firma", c.Repo.ObterSetlist(c.Token, c.Show.Id).Last().Titulo);
    }

    [Fact]
    public void AvulsaRepetidaOuEmRepertorioAlheioNaoEntra()
    {
        var c = CriarCenario();
        c.Repo.AdicionarMusicasAoSetlist(c.Token, c.Show.Id, [c.Romanticas[0].Id]);
        var tokenBia = c.Repo.CriarContaArtista("Bia", "bia@artista.com", "senha").Token;
        var daBia = c.Repo.CriarRepertorio(tokenBia, "Bia");

        Assert.Throws<MusicaJaNaSetlistException>(() =>
            c.Repo.AdicionarMusicaAvulsaAoSetlist(c.Token, c.Show.Id, " EVIDENCIAS ", null, null, c.AnimadasId));
        Assert.Throws<RepertorioNaoEncontradoException>(() =>
            c.Repo.AdicionarMusicaAvulsaAoSetlist(c.Token, c.Show.Id, "Nova", null, null, daBia.Id));
        Assert.Single(c.Repo.ObterSetlist(c.Token, c.Show.Id));
        Assert.DoesNotContain(c.Repo.ListarRepertorios(c.Token).Single(r => r.Id == c.AnimadasId).Musicas,
            m => m.Titulo.Trim().Equals("EVIDENCIAS", StringComparison.OrdinalIgnoreCase));
    }

    [Fact]
    public void RemoveSoMusicaQueAindaNaoFoiTocada()
    {
        var c = CriarCenario();
        var setlist = c.Repo.AdicionarMusicasAoSetlist(
            c.Token, c.Show.Id, c.Romanticas.Select(m => m.Id).ToArray()).ToArray();
        c.Repo.MarcarItemDoSetlist(c.Token, c.Show.Id, setlist[0].Id, tocada: true);

        var restante = c.Repo.RemoverItemDoSetlist(c.Token, c.Show.Id, setlist[1].Id);

        Assert.Equal(["Evidências", "Pense em Mim"], restante.Select(i => i.Titulo));
        Assert.Throws<ItemDoSetlistJaTocadoException>(() =>
            c.Repo.RemoverItemDoSetlist(c.Token, c.Show.Id, setlist[0].Id));
        Assert.Throws<ItemDoSetlistNaoEncontradoException>(() =>
            c.Repo.RemoverItemDoSetlist(c.Token, c.Show.Id, Guid.NewGuid()));
    }

    [Fact]
    public void ReordenaAsQueFaltamMantendoAsTocadasNoLugar()
    {
        var c = CriarCenario();
        var itens = c.Repo.AdicionarMusicasAoSetlist(c.Token, c.Show.Id,
            [.. c.Romanticas.Select(m => m.Id), c.Animadas[0].Id]).ToArray();
        // Evidências, Tempo Perdido, Pense em Mim, Macarena; a segunda já tocou.
        c.Repo.MarcarItemDoSetlist(c.Token, c.Show.Id, itens[1].Id, tocada: true);

        var reordenada = c.Repo.ReordenarSetlist(c.Token, c.Show.Id,
            [itens[3].Id, itens[0].Id, itens[2].Id]);

        Assert.Equal(["Macarena", "Tempo Perdido", "Evidências", "Pense em Mim"],
            reordenada.Select(i => i.Titulo));
        Assert.Equal([1, 2, 3, 4], reordenada.Select(i => i.Ordem));
    }

    [Fact]
    public void ReordenarExigeExatamenteAsQueFaltam()
    {
        var c = CriarCenario();
        var itens = c.Repo.AdicionarMusicasAoSetlist(
            c.Token, c.Show.Id, c.Romanticas.Select(m => m.Id).ToArray()).ToArray();
        c.Repo.MarcarItemDoSetlist(c.Token, c.Show.Id, itens[0].Id, tocada: true);

        foreach (var invalida in new Guid[][]
                 {
                     [itens[1].Id],
                     [itens[1].Id, itens[2].Id, itens[0].Id],
                     [itens[1].Id, itens[1].Id],
                     [itens[1].Id, Guid.NewGuid()],
                 })
            Assert.Throws<OrdemDoSetlistInvalidaException>(() =>
                c.Repo.ReordenarSetlist(c.Token, c.Show.Id, invalida));
    }

    [Fact]
    public async Task RotasDaSetlistSaoSoDoDonoEAsPublicasContinuam()
    {
        var banco = Path.Combine(Path.GetTempPath(), $"tocaessa-api-montar-{Guid.NewGuid():N}.db");
        try
        {
            await using var fabrica = new WebApplicationFactory<Program>().WithWebHostBuilder(builder =>
            {
                builder.ConfigureLogging(logging => logging.ClearProviders());
                builder.ConfigureAppConfiguration((_, configuracao) =>
                    configuracao.AddInMemoryCollection(new Dictionary<string, string?>
                    {
                        ["ConnectionStrings:DefaultConnection"] = banco,
                        ["Aplicacao:ArquivoBanco"] = banco,
                        ["Aplicacao:ArquivoDados"] = $"{banco}.json"
                    }));
                builder.ConfigureServices(servicos =>
                {
                    servicos.RemoveAll<RepositorioTocaEssa>();
                    servicos.AddSingleton(new RepositorioTocaEssa(banco, $"{banco}.json"));
                });
            });
            var repo = fabrica.Services.GetRequiredService<RepositorioTocaEssa>();
            var token = repo.CriarContaArtista("Ana", "ana@teste.com", "senha123").Token;
            repo.SalvarPerfilDaConta(token, new SalvarPerfilArtistico("Duo Aurora", null));
            var show = repo.CriarApresentacao(token, "Firma", new DateOnly(2026, 12, 12), "Salão");
            var repertorio = repo.CriarRepertorio(token, "Românticas");
            var musica = repo.AdicionarMusicaAoRepertorio(token, repertorio.Id, "Evidências", null);
            var tokenBia = repo.CriarContaArtista("Bia", "bia@teste.com", "senha123").Token;
            using var ana = Cliente(fabrica, token);
            using var bia = Cliente(fabrica, tokenBia);
            using var publico = fabrica.CreateClient();
            var rota = $"/api/apresentacoes/{show.Id}/setlist";

            var adicionadas = await ana.PostAsJsonAsync($"{rota}/musicas", new { musicaIds = new[] { musica.Id } });
            Assert.Equal(HttpStatusCode.OK, adicionadas.StatusCode);
            var avulsa = await ana.PostAsJsonAsync($"{rota}/avulsa", new { titulo = "Parabéns" });
            Assert.Equal(HttpStatusCode.OK, avulsa.StatusCode);
            using var json = JsonDocument.Parse(await avulsa.Content.ReadAsStringAsync());
            var ids = json.RootElement.EnumerateArray().Select(i => i.GetProperty("id").GetGuid()).ToArray();
            Assert.Equal(2, ids.Length);

            Assert.Equal(HttpStatusCode.BadRequest,
                (await ana.PostAsJsonAsync($"{rota}/avulsa", new { titulo = "  " })).StatusCode);
            Assert.Equal(HttpStatusCode.Conflict,
                (await ana.PostAsJsonAsync($"{rota}/avulsa", new { titulo = "evidencias" })).StatusCode);
            Assert.Equal(HttpStatusCode.OK,
                (await ana.PutAsJsonAsync($"{rota}/ordem", new { itemIds = ids.Reverse() })).StatusCode);
            Assert.Equal(HttpStatusCode.BadRequest,
                (await ana.PutAsJsonAsync($"{rota}/ordem", new { itemIds = new[] { ids[0] } })).StatusCode);

            Assert.Equal(HttpStatusCode.NotFound,
                (await bia.PostAsJsonAsync($"{rota}/musicas", new { musicaIds = new[] { musica.Id } })).StatusCode);
            Assert.Equal(HttpStatusCode.NotFound, (await bia.DeleteAsync($"{rota}/{ids[0]}")).StatusCode);
            Assert.Equal(HttpStatusCode.Unauthorized,
                (await publico.PostAsJsonAsync($"{rota}/avulsa", new { titulo = "Invasão" })).StatusCode);

            Assert.Equal(HttpStatusCode.OK, (await ana.DeleteAsync($"{rota}/{ids[0]}")).StatusCode);
            Assert.Single(repo.ObterSetlist(token, show.Id));
            Assert.Equal(HttpStatusCode.OK,
                (await publico.GetAsync($"/api/publico/apresentacoes/{show.Codigo}")).StatusCode);
        }
        finally
        {
            SqliteConnection.ClearAllPools();
            foreach (var arquivo in new[] { banco, $"{banco}-shm", $"{banco}-wal", $"{banco}.json" })
                if (File.Exists(arquivo)) File.Delete(arquivo);
        }
    }

    private static HttpClient Cliente(WebApplicationFactory<Program> fabrica, string token)
    {
        var cliente = fabrica.CreateClient();
        cliente.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);
        return cliente;
    }

    private static Cenario CriarCenario()
    {
        var repo = new RepositorioTocaEssa();
        var token = repo.CriarContaArtista("Ana", "ana@artista.com", "senha").Token;
        repo.SalvarPerfilDaConta(token, new SalvarPerfilArtistico("Ana", null));
        var show = repo.CriarApresentacao(token, "Confraternização", new DateOnly(2026, 12, 12), "Salão");
        var romanticas = repo.CriarRepertorio(token, "Românticas");
        var animadas = repo.CriarRepertorio(token, "Animadas");
        MusicaDoRepertorio[] Musicas(Guid repertorioId, params (string Titulo, string? Artista)[] lista) =>
            lista.Select(m => repo.AdicionarMusicaAoRepertorio(token, repertorioId, m.Titulo, m.Artista)).ToArray();
        return new Cenario(repo, token, show, animadas.Id,
            Musicas(romanticas.Id, ("Evidências", "Chitãozinho & Xororó"), ("Tempo Perdido", null), ("Pense em Mim", null)),
            Musicas(animadas.Id, ("Macarena", null), ("Ragatanga", null)));
    }

    private sealed record Cenario(
        RepositorioTocaEssa Repo, string Token, Apresentacao Show, Guid AnimadasId,
        MusicaDoRepertorio[] Romanticas, MusicaDoRepertorio[] Animadas);
}
