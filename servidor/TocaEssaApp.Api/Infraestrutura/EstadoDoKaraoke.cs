using System.Text.Json.Serialization;
using TocaEssaApp.Api.Dominio;

namespace TocaEssaApp.Api.Infraestrutura;

/// O que fica guardado da noite: os sorteados em ordem (sem quem chegou
/// depois), quem o dono tirou, a música que cada um escolheu para a próxima
/// vez, o que a roleta já mostrou a cada um e as vezes cantadas.
internal sealed record EstadoDoKaraoke(
    ConfiguracaoDoKaraoke Configuracao,
    List<Guid> Sorteados,
    List<Guid> Retirados,
    bool Sorteada = false)
{
    public EstadoDoKaraoke() : this(new ConfiguracaoDoKaraoke(), [], []) { }

    public Dictionary<Guid, MusicaDoKaraoke> Escolhas { get; init; } = [];
    public Dictionary<Guid, List<string>> Mostradas { get; init; } = [];
    public List<VezDoKaraoke> Vezes { get; init; } = [];

    /// Depois da primeira vez, a ordem não é mais sorteada de novo.
    [JsonIgnore]
    public bool Comecou => Vezes.Count > 0;

    [JsonIgnore]
    public VezDoKaraoke? Ultima => Vezes.Count == 0 ? null : Vezes[^1];

    [JsonIgnore]
    public VezDoKaraoke? EmAndamento => Ultima is { TerminouEm: null } vez ? vez : null;

    public EstadoDoKaraoke ComEscolha(Guid publicoId, MusicaDoKaraoke? musica)
    {
        var escolhas = new Dictionary<Guid, MusicaDoKaraoke>(Escolhas);
        if (musica is null) escolhas.Remove(publicoId);
        else escolhas[publicoId] = musica;
        return this with { Escolhas = escolhas };
    }

    /// A vez em andamento (se houver) termina agora.
    public List<VezDoKaraoke> VezesEncerradas(DateTimeOffset agora) =>
        EmAndamento is null
            ? [.. Vezes]
            : [.. Vezes.SkipLast(1), Vezes[^1] with { TerminouEm = agora }];
}

/// Erro da noite de karaokê com o status e a mensagem que a pessoa vê.
public abstract class ErroDoKaraokeException(int status, string mensagem) : Exception(mensagem)
{
    public int Status { get; } = status;
}

public sealed class RecursoDisponivelSomenteNoKaraokeException()
    : ErroDoKaraokeException(409, "Este recurso está disponível somente na Noite de Karaokê.");

public sealed class KaraokeJaComecouException()
    : ErroDoKaraokeException(409, "A noite já começou: a ordem não pode mais ser sorteada de novo.");

public sealed class KaraokeEmOutroModoException()
    : ErroDoKaraokeException(409, "O modo das músicas desta noite mudou. Atualize a página.");

public sealed class ForaDaGaleraDoKaraokeException()
    : ErroDoKaraokeException(409, "Entre na galera da noite antes de escolher a música.");

public sealed class AindaNaoEhSuaVezException()
    : ErroDoKaraokeException(409, "Ainda não é a sua vez.");

public sealed class EscolhaAMusicaAntesException()
    : ErroDoKaraokeException(409, "Escolha a música antes de começar.");

public sealed class MusicaDoKaraokeInvalidaException()
    : ErroDoKaraokeException(400, "Informe o nome da música (até 200 letras) e, se quiser, um link do YouTube.");

public sealed class PlaylistDoKaraokeAcabouException()
    : ErroDoKaraokeException(409, "Todas as músicas da playlist já foram cantadas nesta noite.");

public sealed class OrdemAindaNaoSorteadaException()
    : ErroDoKaraokeException(409, "O dono da noite ainda vai sortear a ordem de quem canta.");
