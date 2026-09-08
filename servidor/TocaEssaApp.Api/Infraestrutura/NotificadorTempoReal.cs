using System.Collections.Concurrent;
using System.Runtime.CompilerServices;
using System.Threading.Channels;

namespace TocaEssaApp.Api.Infraestrutura;

public sealed class NotificadorTempoReal
{
    private readonly ConcurrentDictionary<string,
        ConcurrentDictionary<Guid, Channel<string>>> _assinaturas = new();

    public async IAsyncEnumerable<string> Assinar(
        string codigo,
        [EnumeratorCancellation] CancellationToken cancelamento)
    {
        var chave = Normalizar(codigo);
        var identificador = Guid.NewGuid();
        var canal = Channel.CreateBounded<string>(new BoundedChannelOptions(1)
        {
            FullMode = BoundedChannelFullMode.DropOldest,
            SingleReader = true,
            SingleWriter = false
        });
        var assinaturasDaApresentacao = _assinaturas.GetOrAdd(
            chave, _ => new ConcurrentDictionary<Guid, Channel<string>>());
        assinaturasDaApresentacao[identificador] = canal;
        using var encerramento = CancellationTokenSource.CreateLinkedTokenSource(cancelamento);
        var pulsos = EnviarPulsos(canal.Writer, encerramento.Token);

        try
        {
            yield return "conectado";
            await foreach (var evento in canal.Reader.ReadAllAsync(cancelamento))
                yield return evento;
        }
        finally
        {
            assinaturasDaApresentacao.TryRemove(identificador, out _);
            if (assinaturasDaApresentacao.IsEmpty)
                _assinaturas.TryRemove(chave, out _);
            encerramento.Cancel();
            try { await pulsos; }
            catch (OperationCanceledException) { }
        }
    }

    public void Publicar(IEnumerable<string> codigos)
    {
        foreach (var codigo in codigos.Distinct(StringComparer.OrdinalIgnoreCase))
            Publicar(codigo);
    }

    public void Publicar(string codigo)
    {
        if (!_assinaturas.TryGetValue(Normalizar(codigo), out var assinaturas))
            return;
        foreach (var canal in assinaturas.Values)
            canal.Writer.TryWrite("alteracao");
    }

    private static string Normalizar(string codigo) =>
        codigo.Trim().ToUpperInvariant();

    private static async Task EnviarPulsos(
        ChannelWriter<string> canal,
        CancellationToken cancelamento)
    {
        using var relogio = new PeriodicTimer(TimeSpan.FromSeconds(15));
        while (await relogio.WaitForNextTickAsync(cancelamento))
            canal.TryWrite("pulso");
    }
}
