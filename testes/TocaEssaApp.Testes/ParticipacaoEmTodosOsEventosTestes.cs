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

/// Quem tem conta guarda na memória todo encontro em que esteve: resenha,
/// show público e louvor, mesmo sem pedir música.
public sealed class ParticipacaoEmTodosOsEventosTestes
{
    // Estrofe 1, Refrão, Estrofe 2, Refrão.
    private const string Hino = """
        (Estrofe 1)
        Cristo Jesus, o santo Cordeiro
        Deu Sua vida sobre o madeiro
        (Coro)
        Por Cristo, resgatado
        Sirvo ao grande Deus
        (Estrofe 2)
        Preso estava na iniquidade
        Cristo me trouxe a liberdade
        (Coro)
        """;

    [Fact]
    public void PresencaNoShowPublicoFicaNaMemoriaSemPedidoESemExporNinguem()
    {
        var repo = new RepositorioTocaEssa();
        repo.SalvarPerfil("Duo", null);
        var show = repo.CriarApresentacao("Show", new DateOnly(2026, 9, 2), "Praça");
        var ana = repo.CriarPerfilPublico("Ana", "ana@teste.com", "senha123");
        var bia = repo.CriarPerfilPublico("Bia", "bia@teste.com", "senha123");

        repo.RegistrarParticipacao(show.Codigo, ana.Token);
        repo.RegistrarParticipacao(show.Codigo, bia.Token);

        var encontro = Assert.Single(repo.ListarHistoricoDoPublico(ana.Token));
        Assert.Equal(show.Id, encontro.Apresentacao.Id);
        Assert.Equal(0, encontro.Pedidos);
        Assert.Empty(encontro.Companhia);
        Assert.Null(encontro.NomeNoLouvor);
        Assert.Equal(1, repo.ObterEstatisticasDoPublico(ana.Token).Participacoes);
    }

    [Fact]
    public void NoLouvorGuardaQuemAPessoaEEmQuantosHinosElaCanta()
    {
        var cenario = CriarLouvor();
        var ana = cenario.Repo.CriarPerfilPublico("Ana Paula", "ana@teste.com", "senha123");

        cenario.Repo.RegistrarParticipacao(cenario.Show.Codigo, ana.Token, "Ana");

        var encontro = Assert.Single(cenario.Repo.ListarHistoricoDoPublico(ana.Token));
        Assert.Equal(cenario.Show.Id, encontro.Apresentacao.Id);
        Assert.Equal("Ana", encontro.NomeNoLouvor);
        // Ana tem parte no primeiro hino; o segundo é só do João.
        Assert.Equal(1, encontro.HinosNoLouvor);
    }

    [Fact]
    public void TrocarQuemEhNoLouvorAtualizaENomeDeForaOuSoAcompanharFicaSemNome()
    {
        var cenario = CriarLouvor();
        var ana = cenario.Repo.CriarPerfilPublico("Ana", "ana@teste.com", "senha123");

        cenario.Repo.RegistrarParticipacao(cenario.Show.Codigo, ana.Token, "Ana");
        cenario.Repo.RegistrarParticipacao(cenario.Show.Codigo, ana.Token, "joão");
        var trocado = Assert.Single(cenario.Repo.ListarHistoricoDoPublico(ana.Token));
        Assert.Equal("João", trocado.NomeNoLouvor);
        Assert.Equal(2, trocado.HinosNoLouvor);

        // Entrar de novo sem dizer quem é não apaga a escolha.
        cenario.Repo.RegistrarParticipacao(cenario.Show.Codigo, ana.Token);
        Assert.Equal("João",
            Assert.Single(cenario.Repo.ListarHistoricoDoPublico(ana.Token)).NomeNoLouvor);

        cenario.Repo.RegistrarParticipacao(cenario.Show.Codigo, ana.Token, "Zé");
        Assert.Null(Assert.Single(cenario.Repo.ListarHistoricoDoPublico(ana.Token)).NomeNoLouvor);

        cenario.Repo.RegistrarParticipacao(cenario.Show.Codigo, ana.Token, "João");
        cenario.Repo.RegistrarParticipacao(cenario.Show.Codigo, ana.Token, "");
        var soAcompanha = Assert.Single(cenario.Repo.ListarHistoricoDoPublico(ana.Token));
        Assert.Null(soAcompanha.NomeNoLouvor);
        Assert.Equal(0, soAcompanha.HinosNoLouvor);
    }

    [Fact]
    public void ForaDoLouvorONomeNaoEhGuardado()
    {
        var repo = new RepositorioTocaEssa();
        repo.SalvarPerfil("Duo", null);
        var resenha = repo.CriarApresentacao("Roda", new DateOnly(2026, 9, 1),
            "Casa", TipoApresentacao.ResenhaEntreAmigos);
        var ana = repo.CriarPerfilPublico("Ana", "ana@teste.com", "senha123");

        repo.RegistrarParticipacao(resenha.Codigo, ana.Token, "Ana");

        Assert.Null(Assert.Single(repo.ListarHistoricoDoPublico(ana.Token)).NomeNoLouvor);
    }

    [Fact]
    public void BancoAntigoGanhaAColunaDoNomeSemPerderAsParticipacoes()
    {
        var arquivo = Path.Combine(Path.GetTempPath(), $"tocaessa-participacao-{Guid.NewGuid():N}.db");
        try
        {
            var cenario = CriarLouvor(arquivo);
            var ana = cenario.Repo.CriarPerfilPublico("Ana", "ana@teste.com", "senha123");
            var resenha = cenario.Repo.CriarApresentacao(cenario.Token, "Roda",
                new DateOnly(2026, 9, 1), "Casa", TipoApresentacao.ResenhaEntreAmigos);
            cenario.Repo.RegistrarParticipacao(resenha.Codigo, ana.Token);
            SqliteConnection.ClearAllPools();
            using (var conexao = new SqliteConnection($"Data Source={arquivo}"))
            {
                conexao.Open();
                using var comando = conexao.CreateCommand();
                comando.CommandText =
                    "ALTER TABLE \"ParticipacoesResenha\" DROP COLUMN \"NomeNoLouvor\"";
                comando.ExecuteNonQuery();
            }

            var migrado = new RepositorioTocaEssa(arquivo);
            migrado.RegistrarParticipacao(cenario.Show.Codigo, ana.Token, "Ana");
            // Abrir de novo não muda nada: a coluna já existe.
            _ = new RepositorioTocaEssa(arquivo);

            var historico = new RepositorioTocaEssa(arquivo).ListarHistoricoDoPublico(ana.Token);
            Assert.Equal(2, historico.Count);
            Assert.Equal("Ana", historico.Single(e => e.Apresentacao.Id == cenario.Show.Id).NomeNoLouvor);
        }
        finally
        {
            SqliteConnection.ClearAllPools();
            foreach (var arquivoDoBanco in new[] { arquivo, $"{arquivo}-shm", $"{arquivo}-wal", $"{arquivo}.json" })
                if (File.Exists(arquivoDoBanco)) File.Delete(arquivoDoBanco);
        }
    }

    [Fact]
    public async Task RotaAceitaSemCorpoEComONomeDoLouvor()
    {
        var banco = Path.Combine(Path.GetTempPath(), $"tocaessa-participacao-rota-{Guid.NewGuid():N}.db");
        try
        {
            var repo = new RepositorioTocaEssa(banco, $"{banco}.json");
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
                        servicos.AddSingleton(repo);
                    });
                });
            using var cliente = fabrica.CreateClient();
            var token = repo.CriarContaArtista("Advair", "advair@artista.com", "senha").Token;
            repo.SalvarPerfilDaConta(token, new SalvarPerfilArtistico("Advair", null));
            var show = repo.CriarApresentacao(token, "Show", new DateOnly(2026, 9, 2), "Praça",
                TipoApresentacao.Publica);
            var louvor = repo.CriarApresentacao(token, "Louvor", new DateOnly(2026, 10, 24), "Casa",
                TipoApresentacao.Louvor);
            repo.DefinirCantoresDoLouvor(token, louvor.Id, ["Ana"]);
            var ana = repo.CriarPerfilPublico("Ana", "ana@teste.com", "senha123");

            var semToken = await cliente.PostAsync(
                $"/api/publico/apresentacoes/{show.Codigo}/participacoes", null);
            Assert.Equal(HttpStatusCode.Unauthorized, semToken.StatusCode);

            cliente.DefaultRequestHeaders.Authorization =
                new AuthenticationHeaderValue("Bearer", ana.Token);
            var semCorpo = await cliente.PostAsync(
                $"/api/publico/apresentacoes/{show.Codigo}/participacoes", null);
            Assert.Equal(HttpStatusCode.NoContent, semCorpo.StatusCode);
            var comNome = await cliente.PostAsJsonAsync(
                $"/api/publico/apresentacoes/{louvor.Codigo}/participacoes", new { nome = "Ana" });
            Assert.Equal(HttpStatusCode.NoContent, comNome.StatusCode);

            var resposta = await cliente.GetAsync("/api/publico/historico");
            using var json = JsonDocument.Parse(await resposta.Content.ReadAsStringAsync());
            var noLouvor = json.RootElement.EnumerateArray().Single(item =>
                item.GetProperty("apresentacao").GetProperty("id").GetGuid() == louvor.Id);
            Assert.Equal("Ana", noLouvor.GetProperty("nomeNoLouvor").GetString());
            Assert.Equal(2, json.RootElement.GetArrayLength());
        }
        finally
        {
            SqliteConnection.ClearAllPools();
            foreach (var arquivo in new[] { banco, $"{banco}.json", $"{banco}-wal", $"{banco}-shm" })
                if (File.Exists(arquivo)) File.Delete(arquivo);
        }
    }

    /// Dois hinos: no primeiro a Ana canta a Estrofe 1; o segundo é do João.
    private static Cenario CriarLouvor(string? arquivo = null)
    {
        var repo = new RepositorioTocaEssa(arquivo);
        var email = $"advair-{Guid.NewGuid():N}@artista.com";
        var token = repo.CriarContaArtista("Advair", email, "senha").Token;
        repo.SalvarPerfilDaConta(token, new SalvarPerfilArtistico("Advair", null));
        var show = repo.CriarApresentacao(
            token, "Louvor de sábado", new DateOnly(2026, 10, 24), "Casa da Bia",
            TipoApresentacao.Louvor);
        var hinos = repo.AdicionarMusicaAvulsaAoSetlist(token, show.Id, "80 · Resgatado", null, "G", null)
            .Concat(repo.AdicionarMusicaAvulsaAoSetlist(token, show.Id, "81 · Outro", null, "D", null))
            .DistinctBy(item => item.Id)
            .ToArray();
        repo.DefinirCantoresDoLouvor(token, show.Id, ["João", "Ana"]);
        repo.SalvarCifraEmTexto(token, "80 · Resgatado", null, Hino);
        repo.SalvarCifraEmTexto(token, "81 · Outro", null, Hino);
        // Colar a letra marcada já escala; o teste quer as partes à mão.
        repo.LimparEscalaDoLouvor(token, show.Id);
        repo.EscolherParteDoLouvor(token, show.Id, hinos[0].Id, 0, ["Ana"]);
        repo.EscolherParteDoLouvor(token, show.Id, hinos[0].Id, 2, ["João"]);
        repo.EscolherParteDoLouvor(token, show.Id, hinos[1].Id, 0, ["João"]);
        return new Cenario(repo, token, show);
    }

    private sealed record Cenario(RepositorioTocaEssa Repo, string Token, Apresentacao Show);
}
