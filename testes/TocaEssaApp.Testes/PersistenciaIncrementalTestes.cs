using System.Collections.Concurrent;
using System.Diagnostics;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Diagnostics;
using TocaEssaApp.Api.Dominio;
using TocaEssaApp.Api.Infraestrutura;

namespace TocaEssaApp.Testes;

public class PersistenciaIncrementalTestes
{
    [Fact]
    public void GravarPedidoNaoExecutaVerificacaoDeEstrutura()
    {
        var arquivo = CriarCaminhoBanco();
        try
        {
            var (repo, _, apresentacao) = CriarApresentacao(arquivo);

            using var captura = new CapturaDeComandos(arquivo);
            repo.CriarPedido(apresentacao.Codigo, "Evidências", null, "Convidado");

            Assert.DoesNotContain(captura.Comandos, comando =>
                comando.Contains("CREATE TABLE", StringComparison.OrdinalIgnoreCase) ||
                comando.Contains("ALTER TABLE", StringComparison.OrdinalIgnoreCase));
        }
        finally
        {
            ExcluirBanco(arquivo);
        }
    }

    [Fact]
    public void GravarPedidoInsereSomenteONovoRegistroSemApagarOsExistentes()
    {
        var arquivo = CriarCaminhoBanco();
        try
        {
            var (repo, _, apresentacao) = CriarApresentacao(arquivo);
            for (var indice = 0; indice < 20; indice++)
                repo.CriarPedido(apresentacao.Codigo, $"Música {indice}", null, "Convidado");

            using var captura = new CapturaDeComandos(arquivo);
            repo.CriarPedido(apresentacao.Codigo, "Nova música", null, "Convidado");

            var sql = string.Join("\n", captura.Comandos);
            Assert.DoesNotContain("DELETE", sql, StringComparison.OrdinalIgnoreCase);
            Assert.Equal(1, ContarOcorrencias(sql, "INSERT INTO"));
            Assert.Contains("\"PedidosMusicais\"", sql);
        }
        finally
        {
            ExcluirBanco(arquivo);
        }
    }

    [Fact]
    public void AlteracoesERemocoesSobrevivemAoReinicioEGravacoesSeguintes()
    {
        var arquivo = CriarCaminhoBanco();
        try
        {
            var (repo, token, apresentacao) = CriarApresentacao(arquivo);
            var aceito = repo.CriarPedido(apresentacao.Codigo, "Aceita", null, "Ana");
            repo.CriarPedido(apresentacao.Codigo, "Fica aguardando", null, "Bia");
            repo.AlterarStatus(token, apresentacao.Id, aceito.Id, StatusPedidoMusical.Aceito);
            var mantida = repo.SalvarCifraDoArtista(token, "Mantida", null,
                "https://www.cifraclub.com.br/mantida/");
            var removida = repo.SalvarCifraDoArtista(token, "Removida", null,
                "https://www.cifraclub.com.br/removida/");
            repo.RemoverCifraDoArtista(token, removida.Id);

            var reiniciado = new RepositorioTocaEssa(arquivo);
            reiniciado.CriarPedido(apresentacao.Codigo, "Depois do reinício", null, "Caio");
            var cifraNova = reiniciado.SalvarCifraDoArtista(token, "Nova", null,
                "https://www.cifraclub.com.br/nova/");
            reiniciado.RemoverCifraDoArtista(token, mantida.Id);

            var final = new RepositorioTocaEssa(arquivo);
            var pedidos = final.ListarPedidosDoArtista(token, apresentacao.Id);
            Assert.Equal(3, pedidos.Count);
            Assert.Equal(StatusPedidoMusical.Aceito,
                pedidos.Single(item => item.Id == aceito.Id).Status);
            Assert.Contains(pedidos, item => item.Musica == "Depois do reinício");
            Assert.Equal(cifraNova.Id, final.ListarCifrasDoArtista(token).Single().Id);
        }
        finally
        {
            ExcluirBanco(arquivo);
        }
    }

    private static (RepositorioTocaEssa Repo, string Token, Apresentacao Apresentacao)
        CriarApresentacao(string arquivo)
    {
        var repo = new RepositorioTocaEssa(arquivo);
        var token = repo.CriarContaArtista("Banda", "banda@teste.com", "senha123").Token;
        repo.SalvarPerfilDaConta(token, new SalvarPerfilArtistico("Banda", null));
        var apresentacao = repo.CriarApresentacao(token, "Casamento",
            new DateOnly(2026, 10, 10), "Salão");
        return (repo, token, apresentacao);
    }

    private static int ContarOcorrencias(string texto, string trecho)
    {
        var total = 0;
        var indice = texto.IndexOf(trecho, StringComparison.OrdinalIgnoreCase);
        while (indice >= 0)
        {
            total++;
            indice = texto.IndexOf(trecho, indice + trecho.Length,
                StringComparison.OrdinalIgnoreCase);
        }
        return total;
    }

    private static string CriarCaminhoBanco() =>
        Path.Combine(Path.GetTempPath(), $"tocaessa-incremental-{Guid.NewGuid()}.db");

    private static void ExcluirBanco(string caminho)
    {
        foreach (var arquivo in new[] { caminho, $"{caminho}-shm", $"{caminho}-wal" })
            if (File.Exists(arquivo)) File.Delete(arquivo);
    }

    private sealed class CapturaDeComandos :
        IObserver<DiagnosticListener>, IObserver<KeyValuePair<string, object?>>, IDisposable
    {
        private readonly string _arquivo;
        private readonly ConcurrentQueue<string> _comandos = new();
        private readonly List<IDisposable> _assinaturas = [];

        public CapturaDeComandos(string arquivo)
        {
            _arquivo = Path.GetFileName(arquivo);
            _assinaturas.Add(DiagnosticListener.AllListeners.Subscribe(this));
        }

        public IReadOnlyCollection<string> Comandos => _comandos.ToArray();

        public void OnNext(DiagnosticListener ouvinte)
        {
            if (ouvinte.Name == DbLoggerCategory.Name)
                lock (_assinaturas) _assinaturas.Add(ouvinte.Subscribe(this));
        }

        public void OnNext(KeyValuePair<string, object?> evento)
        {
            if (evento.Key == RelationalEventId.CommandExecuting.Name &&
                evento.Value is CommandEventData dados &&
                dados.Command.Connection?.DataSource?.Contains(_arquivo) == true)
                _comandos.Enqueue(dados.Command.CommandText);
        }

        public void OnCompleted() { }

        public void OnError(Exception erro) { }

        public void Dispose()
        {
            lock (_assinaturas)
                foreach (var assinatura in _assinaturas) assinatura.Dispose();
        }
    }
}
