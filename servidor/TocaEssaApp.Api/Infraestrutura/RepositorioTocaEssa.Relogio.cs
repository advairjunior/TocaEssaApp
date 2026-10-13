using System.Collections.Concurrent;
using TocaEssaApp.Api.Dominio;

namespace TocaEssaApp.Api.Infraestrutura;

public sealed partial class RepositorioTocaEssa
{
    // Cronômetro de cada apresentação. Fica fora de `Apresentacao`, que também
    // vai para as rotas públicas: o público não vê o tempo do contrato.
    private readonly ConcurrentDictionary<Guid, EstadoDoRelogio> _relogios = new();

    internal Func<DateTimeOffset> Agora { get; set; } = () => DateTimeOffset.UtcNow;

    private sealed record EstadoDoRelogio(
        int? DuracaoContratadaMinutos = null,
        bool IntervaloPausaRelogio = false,
        DateTimeOffset? IniciadaEm = null,
        DateTimeOffset? EmIntervaloDesde = null,
        int SegundosEmIntervalo = 0,
        DateTimeOffset? EncerradaEm = null);

    // Fora disso, o show ficou aberto por engano e distorceria a média.
    private static readonly TimeSpan RitmoMinimo = TimeSpan.FromMinutes(1);
    private static readonly TimeSpan RitmoMaximo = TimeSpan.FromMinutes(15);
    private const int MusicasParaMedirRitmo = 3;

    private static readonly StatusPedidoMusical[] StatusComecados =
        [StatusPedidoMusical.TocandoAgora, StatusPedidoMusical.Finalizado];

    public RelogioDoShow ObterRelogio(string token, Guid apresentacaoId)
    {
        _ = ObterApresentacaoDoArtista(token, apresentacaoId);
        return MontarRelogio(apresentacaoId);
    }

    /// Show que já estava ao vivo sem início registrado começa a contar agora.
    public RelogioDoShow ConfigurarRelogio(
        string token, Guid apresentacaoId, int? duracaoContratadaMinutos,
        bool intervaloPausaRelogio)
    {
        var show = ObterApresentacaoDoArtista(token, apresentacaoId);
        lock (_sincronizacao)
        {
            var estado = EstadoDoRelogioDe(apresentacaoId);
            var iniciadaEm = estado.IniciadaEm ??
                (show.Status == StatusApresentacao.EmAndamento &&
                 duracaoContratadaMinutos is not null
                    ? Agora()
                    : null);
            return GravarRelogio(apresentacaoId, estado with
            {
                DuracaoContratadaMinutos = duracaoContratadaMinutos,
                IntervaloPausaRelogio = intervaloPausaRelogio,
                IniciadaEm = iniciadaEm
            });
        }
    }

    /// Entrar em intervalo de novo, por outro aparelho, mantém o início dele.
    public RelogioDoShow IniciarIntervalo(string token, Guid apresentacaoId)
    {
        var show = ObterApresentacaoDoArtista(token, apresentacaoId);
        if (show.Status != StatusApresentacao.EmAndamento)
            throw new ShowNaoIniciadoException();
        lock (_sincronizacao)
        {
            var estado = EstadoDoRelogioDe(apresentacaoId);
            return estado.EmIntervaloDesde is not null
                ? MontarRelogio(apresentacaoId)
                : GravarRelogio(apresentacaoId, estado with { EmIntervaloDesde = Agora() });
        }
    }

    public RelogioDoShow EncerrarIntervalo(string token, Guid apresentacaoId)
    {
        _ = ObterApresentacaoDoArtista(token, apresentacaoId);
        lock (_sincronizacao)
        {
            var estado = EstadoDoRelogioDe(apresentacaoId);
            return estado.EmIntervaloDesde is null
                ? MontarRelogio(apresentacaoId)
                : GravarRelogio(apresentacaoId, SemIntervalo(estado));
        }
    }

    /// Chamado dentro da sincronização, antes de salvar a mudança de status.
    private void AtualizarRelogioPeloStatus(Guid apresentacaoId, StatusApresentacao status)
    {
        var estado = EstadoDoRelogioDe(apresentacaoId);
        var atualizado = status switch
        {
            StatusApresentacao.EmAndamento when estado.IniciadaEm is null =>
                estado with { IniciadaEm = Agora() },
            StatusApresentacao.Encerrada => (estado.EmIntervaloDesde is null
                ? estado
                : SemIntervalo(estado)) with { EncerradaEm = Agora() },
            _ => estado
        };
        if (atualizado != estado) _relogios[apresentacaoId] = atualizado;
    }

    private EstadoDoRelogio SemIntervalo(EstadoDoRelogio estado) => estado with
    {
        EmIntervaloDesde = null,
        SegundosEmIntervalo = estado.SegundosEmIntervalo +
            (int)Math.Max(0, (Agora() - estado.EmIntervaloDesde!.Value).TotalSeconds)
    };

    private EstadoDoRelogio EstadoDoRelogioDe(Guid apresentacaoId) =>
        _relogios.GetValueOrDefault(apresentacaoId) ?? new EstadoDoRelogio();

    private RelogioDoShow GravarRelogio(Guid apresentacaoId, EstadoDoRelogio estado)
    {
        _relogios[apresentacaoId] = estado;
        SalvarEstado();
        return MontarRelogio(apresentacaoId);
    }

    private RelogioDoShow MontarRelogio(Guid apresentacaoId)
    {
        var estado = EstadoDoRelogioDe(apresentacaoId);
        var setlist = _itensDoSetlist.Values
            .Where(item => item.ApresentacaoId == apresentacaoId)
            .ToArray();
        var pedidosASeguir = (_pedidosASeguir.GetValueOrDefault(apresentacaoId) ?? [])
            .Count(id => _pedidos.TryGetValue(id, out var pedido) &&
                         !StatusComecados.Contains(pedido.Status));
        return new RelogioDoShow(
            estado.DuracaoContratadaMinutos,
            estado.IntervaloPausaRelogio,
            estado.IniciadaEm,
            estado.EmIntervaloDesde,
            estado.SegundosEmIntervalo,
            ContarMusicasComecadas(apresentacaoId),
            setlist.Count(item => !item.Tocada) + pedidosASeguir,
            Agora(),
            estado.EncerradaEm,
            CalcularRitmoMedio(apresentacaoId));
    }

    private int ContarMusicasComecadas(Guid apresentacaoId) =>
        _itensDoSetlist.Values.Count(item =>
            item.ApresentacaoId == apresentacaoId && item.Tocada) +
        ListarGruposDePedidosDoArtista(apresentacaoId)
            .Count(grupo => grupo.Tipo == TipoPedido.Musica &&
                            StatusComecados.Contains(grupo.Status));

    /// Tempo tocado (sem intervalo) somado dos shows encerrados do mesmo
    /// artista, dividido pelo total de músicas começadas neles.
    private int? CalcularRitmoMedio(Guid apresentacaoId)
    {
        var artistaId = _apresentacoes.Values.First(item => item.Id == apresentacaoId).ArtistaId;
        double segundos = 0;
        var musicas = 0;
        foreach (var show in _apresentacoes.Values.Where(item =>
                     item.ArtistaId == artistaId &&
                     item.Id != apresentacaoId &&
                     item.Status == StatusApresentacao.Encerrada))
        {
            var estado = EstadoDoRelogioDe(show.Id);
            if (estado is not { IniciadaEm: { } inicio, EncerradaEm: { } fim }) continue;
            var comecadas = ContarMusicasComecadas(show.Id);
            if (comecadas < MusicasParaMedirRitmo) continue;
            var tocado = (fim - inicio).TotalSeconds - estado.SegundosEmIntervalo;
            var ritmo = TimeSpan.FromSeconds(tocado / comecadas);
            if (ritmo < RitmoMinimo || ritmo > RitmoMaximo) continue;
            segundos += tocado;
            musicas += comecadas;
        }
        return musicas == 0 ? null : (int)Math.Round(segundos / musicas);
    }

    private void CarregarRelogio(ApresentacaoRegistro registro)
    {
        var estado = new EstadoDoRelogio(
            registro.DuracaoContratadaMinutos,
            registro.IntervaloPausaRelogio,
            registro.IniciadaEm,
            registro.EmIntervaloDesde,
            registro.SegundosEmIntervalo,
            registro.EncerradaEm);
        if (estado != new EstadoDoRelogio()) _relogios[registro.Id] = estado;
    }

    private void EscreverRelogio(ApresentacaoRegistro registro)
    {
        var estado = EstadoDoRelogioDe(registro.Id);
        registro.DuracaoContratadaMinutos = estado.DuracaoContratadaMinutos;
        registro.IntervaloPausaRelogio = estado.IntervaloPausaRelogio;
        registro.IniciadaEm = estado.IniciadaEm;
        registro.EmIntervaloDesde = estado.EmIntervaloDesde;
        registro.SegundosEmIntervalo = estado.SegundosEmIntervalo;
        registro.EncerradaEm = estado.EncerradaEm;
    }
}
