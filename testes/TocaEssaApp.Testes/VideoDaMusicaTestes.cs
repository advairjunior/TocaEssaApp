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

/// O link do vídeo de karaokê fica na música do repertório; importar a
/// mesma playlist de novo só traz o que falta.
public sealed class VideoDaMusicaTestes
{
    private const string Falta = "https://www.youtube.com/watch?v=xKPaBwlI16o";
    private const string Desejo = "https://www.youtube.com/watch?v=aorrMojEBcw";

    [Fact]
    public void ImportarDeNovoTrazSoOsVideosNovosEDaOLinkAMusicaQueNaoTinha()
    {
        var (repo, token) = CriarConta();
        var karaoke = repo.CriarRepertorio(token, "Karaokê");
        repo.AdicionarMusicaAoRepertorio(token, karaoke.Id, "Desejo Imortal - Gusttavo Lima", null);

        var primeira = repo.AdicionarMusicasAoRepertorio(token, karaoke.Id, null,
        [
            new("Thiaguinho - Falta Você", null, LinkDoVideo: Falta),
            new("Desejo Imortal - Gusttavo Lima", null, LinkDoVideo: Desejo),
        ]);
        Assert.Equal((1, 1), (primeira.Adicionadas, primeira.JaEstavam));
        Assert.Equal([Desejo, Falta], primeira.Repertorio.Musicas.Select(m => m.LinkDoVideo));

        // O nome foi corrigido à mão: o vídeo continua sendo o mesmo.
        var falta = primeira.Repertorio.Musicas.Single(m => m.LinkDoVideo == Falta);
        repo.EditarMusicaDoRepertorio(token, karaoke.Id, falta.Id, "Falta Você", "Thiaguinho", null);
        var segunda = repo.AdicionarMusicasAoRepertorio(token, karaoke.Id, null,
        [
            new("Thiaguinho - Falta Você", null, LinkDoVideo: Falta),
            new("Djavan - Samurai", null, LinkDoVideo: "https://www.youtube.com/watch?v=oCekav-2s18"),
        ]);
        Assert.Equal((1, 1), (segunda.Adicionadas, segunda.JaEstavam));
        Assert.Equal(3, segunda.Repertorio.Musicas.Count);
    }

    [Fact]
    public void EditarAMusicaNaoApagaOVideo()
    {
        var (repo, token) = CriarConta();
        var karaoke = repo.CriarRepertorio(token, "Karaokê");
        var falta = repo.AdicionarMusicasAoRepertorio(token, karaoke.Id, null,
            [new("Thiaguinho - Falta Você", null, LinkDoVideo: Falta)]).Repertorio.Musicas.Single();

        var editada = repo.EditarMusicaDoRepertorio(token, karaoke.Id, falta.Id, "Falta Você", "Thiaguinho", "G");

        Assert.Equal(Falta, editada.LinkDoVideo);
    }

    [Fact]
    public void BancoAntigoGanhaAColunaDoVideoSemPerderAsMusicas()
    {
        var arquivo = Path.Combine(Path.GetTempPath(), $"tocaessa-video-{Guid.NewGuid():N}.db");
        try
        {
            var (repo, token) = CriarConta(arquivo);
            var karaoke = repo.CriarRepertorio(token, "Karaokê");
            repo.AdicionarMusicaAoRepertorio(token, karaoke.Id, "Antiga", null);
            SqliteConnection.ClearAllPools();
            using (var conexao = new SqliteConnection($"Data Source={arquivo}"))
            {
                conexao.Open();
                using var comando = conexao.CreateCommand();
                comando.CommandText = "ALTER TABLE \"MusicasDoRepertorio\" DROP COLUMN \"LinkDoVideo\"";
                comando.ExecuteNonQuery();
            }

            var migrado = new RepositorioTocaEssa(arquivo);
            migrado.AdicionarMusicasAoRepertorio(token, karaoke.Id, null,
                [new("Thiaguinho - Falta Você", null, LinkDoVideo: Falta)]);
            _ = new RepositorioTocaEssa(arquivo);

            var musicas = new RepositorioTocaEssa(arquivo).ListarRepertorios(token).Single().Musicas;
            Assert.Equal(["Antiga", "Thiaguinho - Falta Você"], musicas.Select(m => m.Titulo));
            Assert.Equal([null, Falta], musicas.Select(m => m.LinkDoVideo));
        }
        finally
        {
            SqliteConnection.ClearAllPools();
            foreach (var arquivoDoBanco in new[] { arquivo, $"{arquivo}-shm", $"{arquivo}-wal", $"{arquivo}.json" })
                if (File.Exists(arquivoDoBanco)) File.Delete(arquivoDoBanco);
        }
    }

    [Fact]
    public async Task RotaDaPreviaDaPlaylistExigeArtistaEDevolveOsTitulosLimpos()
    {
        var banco = Path.Combine(Path.GetTempPath(), $"tocaessa-previa-{Guid.NewGuid():N}.db");
        try
        {
            var leitor = new LeitorFalso();
            await using var fabrica = new WebApplicationFactory<Program>()
                .WithWebHostBuilder(builder =>
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
                        servicos.RemoveAll<ILeitorDePlaylist>();
                        servicos.AddSingleton<ILeitorDePlaylist>(leitor);
                    });
                });
            using var cliente = fabrica.CreateClient();
            const string link = "https://youtube.com/playlist?list=PLcasa&si=x";

            var semToken = await cliente.PostAsJsonAsync("/api/artista/repertorios/playlist", new { link });
            Assert.Equal(HttpStatusCode.Unauthorized, semToken.StatusCode);

            var conta = await cliente.PostAsJsonAsync("/api/artista/contas",
                new { nome = "Advair", email = "advair@artista.com", senha = "senha123" });
            using var sessao = JsonDocument.Parse(await conta.Content.ReadAsStringAsync());
            cliente.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue(
                "Bearer", sessao.RootElement.GetProperty("token").GetString());

            var semPlaylist = await cliente.PostAsJsonAsync("/api/artista/repertorios/playlist",
                new { link = "https://www.youtube.com/watch?v=abc" });
            Assert.Equal(HttpStatusCode.BadRequest, semPlaylist.StatusCode);

            var resposta = await cliente.PostAsJsonAsync("/api/artista/repertorios/playlist", new { link });
            Assert.Equal(HttpStatusCode.OK, resposta.StatusCode);
            Assert.Equal("PLcasa", leitor.Lida);
            using var json = JsonDocument.Parse(await resposta.Content.ReadAsStringAsync());
            Assert.Equal("Karaokê da casa", json.RootElement.GetProperty("titulo").GetString());
            var musica = json.RootElement.GetProperty("musicas")[0];
            Assert.Equal("Thiaguinho - Falta Você", musica.GetProperty("titulo").GetString());
            Assert.Equal(Falta, musica.GetProperty("linkDoVideo").GetString());

            leitor.Falha = new PlaylistNaoEncontradaException();
            var naoAchou = await cliente.PostAsJsonAsync("/api/artista/repertorios/playlist", new { link });
            Assert.Equal(HttpStatusCode.NotFound, naoAchou.StatusCode);
            leitor.Falha = new ImportacaoDePlaylistIndisponivelException();
            var semChave = await cliente.PostAsJsonAsync("/api/artista/repertorios/playlist", new { link });
            Assert.Equal(HttpStatusCode.ServiceUnavailable, semChave.StatusCode);
        }
        finally
        {
            SqliteConnection.ClearAllPools();
            foreach (var arquivo in new[] { banco, $"{banco}.json", $"{banco}-wal", $"{banco}-shm" })
                if (File.Exists(arquivo)) File.Delete(arquivo);
        }
    }

    private static (RepositorioTocaEssa Repo, string Token) CriarConta(string? arquivo = null)
    {
        var repo = new RepositorioTocaEssa(arquivo);
        var token = repo.CriarContaArtista("Advair", $"advair-{Guid.NewGuid():N}@artista.com", "senha").Token;
        return (repo, token);
    }

    private sealed class LeitorFalso : ILeitorDePlaylist
    {
        public string? Lida { get; private set; }
        public Exception? Falha { get; set; }

        public Task<PlaylistLida> LerAsync(string idDaPlaylist, CancellationToken cancelamento = default)
        {
            if (Falha is not null) throw Falha;
            Lida = idDaPlaylist;
            return Task.FromResult(new PlaylistLida("Karaokê da casa",
                [new VideoDaPlaylist("Thiaguinho - Falta Você", Falta)]));
        }
    }
}
