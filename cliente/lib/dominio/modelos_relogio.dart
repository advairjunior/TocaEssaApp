part of 'modelos.dart';

enum AlertaDoRelogio { normal, trintaMinutos, dezMinutos, passou }

/// Cronômetro do show, visto só pelos artistas. As contas usam a hora do
/// servidor, corrigida pelo relógio do aparelho, para todos os aparelhos da
/// banda mostrarem o mesmo tempo.
class RelogioDoShow {
  const RelogioDoShow({
    required this.duracaoContratadaMinutos,
    required this.intervaloPausaRelogio,
    required this.iniciadaEm,
    required this.emIntervaloDesde,
    required this.segundosEmIntervalo,
    required this.musicasComecadas,
    required this.musicasRestantes,
    required Duration ajusteDoAparelho,
  }) : _ajusteDoAparelho = ajusteDoAparelho;

  final int? duracaoContratadaMinutos;
  final bool intervaloPausaRelogio;
  final DateTime? iniciadaEm;
  final DateTime? emIntervaloDesde;
  final int segundosEmIntervalo;
  final int musicasComecadas;
  final int musicasRestantes;
  // Hora do servidor menos a hora do aparelho no momento da resposta.
  final Duration _ajusteDoAparelho;

  factory RelogioDoShow.deJson(Map<String, dynamic> json,
      {required DateTime recebidoEm}) {
    DateTime? data(String chave) => switch (json[chave]) {
          final String valor => DateTime.parse(valor),
          _ => null,
        };
    return RelogioDoShow(
      duracaoContratadaMinutos: json['duracaoContratadaMinutos'] as int?,
      intervaloPausaRelogio: json['intervaloPausaRelogio'] as bool? ?? false,
      iniciadaEm: data('iniciadaEm'),
      emIntervaloDesde: data('emIntervaloDesde'),
      segundosEmIntervalo: json['segundosEmIntervalo'] as int? ?? 0,
      musicasComecadas: json['musicasComecadas'] as int? ?? 0,
      musicasRestantes: json['musicasRestantes'] as int? ?? 0,
      ajusteDoAparelho: data('agora')!.difference(recebidoEm),
    );
  }

  bool get ativo => duracaoContratadaMinutos != null && iniciadaEm != null;
  bool get emIntervalo => emIntervaloDesde != null;

  DateTime _noServidor(DateTime agora) => agora.add(_ajusteDoAparelho);

  Duration tempoEmIntervalo(DateTime agora) => emIntervaloDesde == null
      ? Duration.zero
      : _noServidor(agora).difference(emIntervaloDesde!);

  /// Tempo tocando, sem nenhum intervalo: base do ritmo das músicas.
  Duration tempoDeShow(DateTime agora) =>
      _noServidor(agora).difference(iniciadaEm!) -
      Duration(seconds: segundosEmIntervalo) -
      tempoEmIntervalo(agora);

  Duration restante(DateTime agora) {
    final contado = intervaloPausaRelogio
        ? tempoDeShow(agora)
        : _noServidor(agora).difference(iniciadaEm!);
    return Duration(minutes: duracaoContratadaMinutos!) - contado;
  }

  /// Na hora do aparelho; com o intervalo pausando, anda junto da pausa.
  DateTime termino(DateTime agora) => agora.add(restante(agora));

  AlertaDoRelogio alerta(DateTime agora) {
    final falta = restante(agora);
    if (falta.isNegative) return AlertaDoRelogio.passou;
    if (falta <= const Duration(minutes: 10)) return AlertaDoRelogio.dezMinutos;
    if (falta <= const Duration(minutes: 30)) {
      return AlertaDoRelogio.trintaMinutos;
    }
    return AlertaDoRelogio.normal;
  }
}

/// "1h42", "3h00" ou "42 min".
String formatarTempoDoShow(Duration tempo) {
  final minutos = tempo.inMinutes.abs();
  if (minutos < 60) return '$minutos min';
  return '${minutos ~/ 60}h${(minutos % 60).toString().padLeft(2, '0')}';
}
