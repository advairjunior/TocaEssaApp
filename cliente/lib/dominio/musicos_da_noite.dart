import 'modelos.dart';

/// O que aparece para quem abre o link de convite, antes de entrar.
class ConviteDaNoite {
  const ConviteDaNoite({
    required this.apresentacaoId,
    required this.evento,
    required this.dono,
    required this.data,
  });

  final String apresentacaoId;
  final String evento;
  final String dono;
  final DateTime data;

  factory ConviteDaNoite.deJson(Map<String, dynamic> json) => ConviteDaNoite(
        apresentacaoId: json['apresentacaoId'] as String,
        evento: json['evento'] as String,
        dono: json['dono'] as String,
        data: DateTime.parse(json['data'] as String),
      );
}

/// Quem cuida do evento: o dono primeiro, depois quem entrou pelo convite.
class MusicoDaNoite {
  const MusicoDaNoite(
      {required this.artistaId, required this.nome, required this.dono});

  final String artistaId;
  final String nome;
  final bool dono;

  factory MusicoDaNoite.deJson(Map<String, dynamic> json) => MusicoDaNoite(
        artistaId: json['artistaId'] as String,
        nome: json['nome'] as String,
        dono: json['dono'] as bool? ?? false,
      );
}

/// Evento em que a conta toca como convidada, na seção Convites do painel.
class EventoConvidado {
  const EventoConvidado({
    required this.apresentacaoId,
    required this.nome,
    required this.data,
    required this.local,
    required this.tipo,
    required this.status,
    required this.codigo,
    required this.dono,
  });

  final String apresentacaoId;
  final String nome;
  final DateTime data;
  final String local;
  final TipoApresentacao tipo;
  final StatusApresentacao status;
  final String codigo;
  final String dono;

  factory EventoConvidado.deJson(Map<String, dynamic> json) => EventoConvidado(
        apresentacaoId: json['apresentacaoId'] as String,
        nome: json['nome'] as String,
        data: DateTime.parse(json['data'] as String),
        local: json['local'] as String? ?? '',
        tipo: TipoApresentacao.deJson(json['tipo'] as String? ?? 'Publica'),
        status:
            StatusApresentacao.deJson(json['status'] as String? ?? 'Agendada'),
        codigo: json['codigo'] as String,
        dono: json['dono'] as String,
      );
}

/// Link de convite trocado, de evento encerrado ou que nunca existiu.
class ConviteNaoEncontrado implements Exception {
  const ConviteNaoEncontrado(this.mensagem);

  final String mensagem;

  @override
  String toString() => mensagem;
}
