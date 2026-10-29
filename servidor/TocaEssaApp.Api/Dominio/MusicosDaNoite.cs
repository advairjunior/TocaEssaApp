namespace TocaEssaApp.Api.Dominio;

/// O que aparece para quem abre o link de convite, antes de entrar.
public sealed record ConviteDaNoite(Guid ApresentacaoId, string Evento, string Dono, DateOnly Data);

/// Quem cuida do evento: o dono primeiro, depois quem entrou pelo convite.
public sealed record MusicoDaNoite(Guid ArtistaId, string Nome, bool Dono);

/// Evento em que a conta é convidada, na seção Convites do painel. Traz só
/// o que o músico precisa para tocar naquela noite, nada da conta do dono.
public sealed record EventoConvidado(
    Guid ApresentacaoId,
    string Nome,
    DateOnly Data,
    string Local,
    TipoApresentacao Tipo,
    StatusApresentacao Status,
    string Codigo,
    string Dono);

/// Erro do convite com o status e a mensagem que a pessoa vê.
public abstract class ErroDoConviteException(int status, string mensagem) : Exception(mensagem)
{
    public int Status { get; } = status;
}

public sealed class ConviteNaoEncontradoException()
    : ErroDoConviteException(404, "Convite não encontrado. Peça um link novo para quem convidou.");

public sealed class EventoSemConviteDeMusicoException()
    : ErroDoConviteException(409, "Convite de músico é só para resenha e louvor.");
