using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
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

public class SincroniaRepertorioSetlistTestes
{
    [Fact]
    public void ReordenarRepertorioRefleteNaSetlistSemPerderMarcacaoDeTocada()
    {
        var cenario = CriarCenario();
        var setlist = cenario.Repo.ImportarRepertorioParaSetlist(
            cenario.Token, cenario.Show.Id, cenario.Repertorio.Id);
        var primeira = setlist.Single(item => item.Titulo == "Primeira");
        cenario.Repo.MarcarItemDoSetlist(cenario.Token, cenario.Show.Id, primeira.Id, true);

        var reordenado = cenario.Repo.ReordenarMusicasDoRepertorio(
            cenario.Token, cenario.Repertorio.Id,
            [cenario.Musicas[2].Id, cenario.Musicas[0].Id, cenario.Musicas[1].Id]);

        Assert.Equal(["Terceira", "Primeira", "Segunda"],
            reordenado.Musicas.OrderBy(m => m.Ordem).Select(m => m.Titulo));
        var atualizada = cenario.Repo.ObterSetlist(cenario.Token, cenario.Show.Id);
        Assert.Equal(["Terceira", "Primeira", "Segunda"], atualizada.Select(i => i.Titulo));
        Assert.True(atualizada.Single(i => i.Titulo == "Primeira").Tocada);
    }

    [Fact]
    public void MusicaAdicionadaAoRepertorioApareceNaSetlistSemReimportar()
    {
        var cenario = CriarCenario();
        cenario.Repo.ImportarRepertorioParaSetlist(
            cenario.Token, cenario.Show.Id, cenario.Repertorio.Id);

        cenario.Repo.AdicionarMusicaAoRepertorio(
            cenario.Token, cenario.Repertorio.Id, "Nova", "Banda", "G");

        var setlist = cenario.Repo.ObterSetlist(cenario.Token, cenario.Show.Id);
        Assert.Equal(["Primeira", "Segunda", "Terceira", "Nova"],
            setlist.Select(i => i.Titulo));
        var nova = setlist.Last();
        Assert.False(nova.Tocada);
        Assert.Equal("Banda", nova.Artista);
        Assert.Equal("G", nova.Tom);
    }

    [Fact]
    public void MusicaRemovidaDoRepertorioSaiDaSetlist()
    {
        var cenario = CriarCenario();
        cenario.Repo.ImportarRepertorioParaSetlist(
            cenario.Token, cenario.Show.Id, cenario.Repertorio.Id);

        cenario.Repo.RemoverMusicaDoRepertorio(
            cenario.Token, cenario.Repertorio.Id, cenario.Musicas[1].Id);

        Assert.Equal(["Primeira", "Terceira"],
            cenario.Repo.ObterSetlist(cenario.Token, cenario.Show.Id).Select(i => i.Titulo));
    }

    [Fact]
    public void ApresentacaoEncerradaPreservaSetlistComoHistorico()
    {
        var cenario = CriarCenario();
        cenario.Repo.ImportarRepertorioParaSetlist(
            cenario.Token, cenario.Show.Id, cenario.Repertorio.Id);
        cenario.Repo.AlterarStatusApresentacao(
            cenario.Token, cenario.Show.Id, StatusApresentacao.Encerrada);

        cenario.Repo.AdicionarMusicaAoRepertorio(
            cenario.Token, cenario.Repertorio.Id, "Nova", null);
        cenario.Repo.RemoverMusicaDoRepertorio(
            cenario.Token, cenario.Repertorio.Id, cenario.Musicas[0].Id);
        cenario.Repo.ReordenarMusicasDoRepertorio(cenario.Token, cenario.Repertorio.Id,
            cenario.Repo.ListarRepertorios(cenario.Token).Single().Musicas
                .Select(m => m.Id).Reverse().ToArray());

        Assert.Equal(["Primeira", "Segunda", "Terceira"],
            cenario.Repo.ObterSetlist(cenario.Token, cenario.Show.Id).Select(i => i.Titulo));
    }

    [Fact]
    public void SetlistDeOutroRepertorioNaoRecebeMusicas()
    {
        var cenario = CriarCenario();
        var outro = cenario.Repo.CriarRepertorio(cenario.Token, "Outro");
        cenario.Repo.AdicionarMusicaAoRepertorio(cenario.Token, outro.Id, "Primeira", null);
        cenario.Repo.ImportarRepertorioParaSetlist(cenario.Token, cenario.Show.Id, outro.Id);

        cenario.Repo.AdicionarMusicaAoRepertorio(
            cenario.Token, cenario.Repertorio.Id, "Nova", null);
        cenario.Repo.RemoverMusicaDoRepertorio(
            cenario.Token, cenario.Repertorio.Id, cenario.Musicas[0].Id);

        Assert.Equal(["Primeira"],
            cenario.Repo.ObterSetlist(cenario.Token, cenario.Show.Id).Select(i => i.Titulo));
    }

    [Fact]
    public void ReordenarExigeExatamenteAsMusicasDoRepertorio()
    {
        var cenario = CriarCenario();

        Assert.Throws<OrdemDoRepertorioInvalidaException>(() =>
            cenario.Repo.ReordenarMusicasDoRepertorio(cenario.Token, cenario.Repertorio.Id,
                [cenario.Musicas[0].Id, cenario.Musicas[1].Id]));
        Assert.Throws<OrdemDoRepertorioInvalidaException>(() =>
            cenario.Repo.ReordenarMusicasDoRepertorio(cenario.Token, cenario.Repertorio.Id,
                [cenario.Musicas[0].Id, cenario.Musicas[1].Id, Guid.NewGuid()]));
        Assert.Throws<OrdemDoRepertorioInvalidaException>(() =>
            cenario.Repo.ReordenarMusicasDoRepertorio(cenario.Token, cenario.Repertorio.Id,
                [cenario.Musicas[0].Id, cenario.Musicas[0].Id, cenario.Musicas[1].Id]));
    }

    [Fact]
    public void ArtistaNaoReordenaRepertorioDeOutroArtista()
    {
        var cenario = CriarCenario();
        var tokenBia = cenario.Repo.CriarContaArtista("Bia", "bia@artista.com", "senha").Token;

        Assert.Throws<RepertorioNaoEncontradoException>(() =>
            cenario.Repo.ReordenarMusicasDoRepertorio(tokenBia, cenario.Repertorio.Id,
                cenario.Musicas.Select(m => m.Id).ToArray()));
    }

    [Fact]
    public void SetlistLegadaSemVinculoPassaAAcompanharORepertorio()
    {
        var arquivo = Path.Combine(Path.GetTempPath(),
            $"tocaessa-setlist-legada-{Guid.NewGuid()}.db");
        try
        {
            var cenario = CriarCenario(arquivo);
            cenario.Repo.ImportarRepertorioParaSetlist(
                cenario.Token, cenario.Show.Id, cenario.Repertorio.Id);
            using (var conexao = new SqliteConnection($"Data Source={arquivo};Pooling=False"))
            {
                conexao.Open();
                using var comando = conexao.CreateCommand();
                comando.CommandText =
                    "UPDATE \"ItensDoSetlist\" SET \"MusicaDoRepertorioId\" = NULL";
                comando.ExecuteNonQuery();
            }
            var reiniciado = new RepositorioTocaEssa(arquivo);

            reiniciado.AdicionarMusicaAoRepertorio(
                cenario.Token, cenario.Repertorio.Id, "Nova", null);
            reiniciado.ReordenarMusicasDoRepertorio(cenario.Token, cenario.Repertorio.Id,
                reiniciado.ListarRepertorios(cenario.Token).Single().Musicas
                    .OrderBy(m => m.Ordem).Select(m => m.Id).Reverse().ToArray());

            Assert.Equal(["Nova", "Terceira", "Segunda", "Primeira"],
                reiniciado.ObterSetlist(cenario.Token, cenario.Show.Id)
                    .Select(i => i.Titulo));
        }
        finally
        {
            foreach (var caminho in new[] { arquivo, $"{arquivo}-shm", $"{arquivo}-wal" })
                if (File.Exists(caminho)) File.Delete(caminho);
        }
    }

    [Fact]
    public async Task RotaDeOrdemExigeArtistaEValidaAsMusicas()
    {
        var banco = Path.Combine(Path.GetTempPath(),
            $"tocaessa-api-ordem-{Guid.NewGuid()}.db");
        try
        {
            await using var fabrica = new WebApplicationFactory<Program>()
                .WithWebHostBuilder(builder =>
                {
                    builder.ConfigureLogging(logging => logging.ClearProviders());
                    builder.ConfigureAppConfiguration((_, configuracao) =>
                        configuracao.AddInMemoryCollection(
                            new Dictionary<string, string?>
                            {
                                ["ConnectionStrings:DefaultConnection"] = banco,
                                ["Aplicacao:ArquivoBanco"] = banco,
                                ["Aplicacao:ArquivoDados"] = $"{banco}.json"
                            }));
                    builder.ConfigureServices(servicos =>
                    {
                        servicos.RemoveAll<RepositorioTocaEssa>();
                        servicos.AddSingleton(new RepositorioTocaEssa(
                            banco, $"{banco}.json"));
                    });
                });
            using var cliente = fabrica.CreateClient();
            var repositorio = fabrica.Services.GetRequiredService<RepositorioTocaEssa>();
            var token = repositorio.CriarContaArtista("Ana", "ana@teste.com", "senha123").Token;
            var repertorio = repositorio.CriarRepertorio(token, "Casamento");
            var primeira = repositorio.AdicionarMusicaAoRepertorio(
                token, repertorio.Id, "Primeira", null);
            var segunda = repositorio.AdicionarMusicaAoRepertorio(
                token, repertorio.Id, "Segunda", null);
            var rota = $"/api/artista/repertorios/{repertorio.Id}/musicas/ordem";

            var semSessao = await cliente.PutAsJsonAsync(rota,
                new { musicaIds = new[] { segunda.Id, primeira.Id } });
            Assert.Equal(HttpStatusCode.Unauthorized, semSessao.StatusCode);

            cliente.DefaultRequestHeaders.Authorization =
                new AuthenticationHeaderValue("Bearer", token);
            var incompleta = await cliente.PutAsJsonAsync(rota,
                new { musicaIds = new[] { segunda.Id } });
            Assert.Equal(HttpStatusCode.BadRequest, incompleta.StatusCode);

            var resposta = await cliente.PutAsJsonAsync(rota,
                new { musicaIds = new[] { segunda.Id, primeira.Id } });
            resposta.EnsureSuccessStatusCode();
            var reordenado = await resposta.Content.ReadFromJsonAsync<RepertorioResposta>();
            Assert.Equal(["Segunda", "Primeira"], reordenado!.Musicas.Select(m => m.Titulo));

            var tokenBia = repositorio.CriarContaArtista("Bia", "bia@teste.com", "senha123").Token;
            cliente.DefaultRequestHeaders.Authorization =
                new AuthenticationHeaderValue("Bearer", tokenBia);
            var deOutro = await cliente.PutAsJsonAsync(rota,
                new { musicaIds = new[] { primeira.Id, segunda.Id } });
            Assert.Equal(HttpStatusCode.NotFound, deOutro.StatusCode);
        }
        finally
        {
            foreach (var caminho in new[] { banco, $"{banco}-shm", $"{banco}-wal" })
                if (File.Exists(caminho)) File.Delete(caminho);
        }
    }

    private static Cenario CriarCenario(string? arquivo = null)
    {
        var repo = new RepositorioTocaEssa(arquivo);
        var token = repo.CriarContaArtista("Ana", "ana@artista.com", "senha").Token;
        repo.SalvarPerfilDaConta(token, new SalvarPerfilArtistico("Ana", null));
        var show = repo.CriarApresentacao(token, "Casamento",
            new DateOnly(2026, 10, 10), "Salão");
        var repertorio = repo.CriarRepertorio(token, "Casamento");
        var musicas = new[] { "Primeira", "Segunda", "Terceira" }
            .Select(titulo => repo.AdicionarMusicaAoRepertorio(
                token, repertorio.Id, titulo, null))
            .ToArray();
        return new Cenario(repo, token, show, repertorio, musicas);
    }

    private sealed record Cenario(
        RepositorioTocaEssa Repo,
        string Token,
        Apresentacao Show,
        Repertorio Repertorio,
        MusicaDoRepertorio[] Musicas);

    private sealed record RepertorioResposta(List<MusicaResposta> Musicas);

    private sealed record MusicaResposta(string Titulo);
}
