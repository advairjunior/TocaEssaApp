using TocaEssaApp.Api.Infraestrutura;

namespace TocaEssaApp.Testes;

public sealed class NotificadorTempoRealTestes
{
    [Fact]
    public async Task PublicaAlteracaoSomenteParaApresentacaoAssinada()
    {
        var notificador = new NotificadorTempoReal();
        using var cancelamento = new CancellationTokenSource(TimeSpan.FromSeconds(2));
        await using var eventos = notificador
            .Assinar("ABC123", cancelamento.Token)
            .GetAsyncEnumerator(cancelamento.Token);

        Assert.True(await eventos.MoveNextAsync());
        Assert.Equal("conectado", eventos.Current);

        notificador.Publicar("ABC123");

        Assert.True(await eventos.MoveNextAsync());
        Assert.Equal("alteracao", eventos.Current);
    }
}
