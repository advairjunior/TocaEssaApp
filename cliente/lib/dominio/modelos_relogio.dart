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
    this.ritmoMedio,
  }) : _ajusteDoAparelho = ajusteDoAparelho;

  /// Ritmo dos shows encerrados do artista; nulo sem histórico.
  final Duration? ritmoMedio;

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
      ritmoMedio: switch (json['ritmoMedioSegundos']) {
        final int segundos => Duration(seconds: segundos),
        _ => null,
      },
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

  static const ritmoPadrao = Duration(minutes: 3);
  static const musicasParaMedir = 3;

  /// A partir da 3ª música, o ritmo é medido no próprio show.
  bool get ritmoMedido => musicasComecadas >= musicasParaMedir;
  bool get temRitmoMedio => ritmoMedio != null;

  /// Antes de medir: o ritmo médio do artista ou, sem histórico, 3 minutos.
  Duration get ritmoAntesDeMedir => ritmoMedio ?? ritmoPadrao;

  /// Já conta a conversa entre as músicas, mas não o intervalo.
  Duration ritmo(DateTime agora) => ritmoMedido
      ? Duration(
          seconds: tempoDeShow(agora).inSeconds ~/ musicasComecadas)
      : ritmoAntesDeMedir;

  /// Quanto [musicas] devem durar, antes de o show começar.
  Duration duracaoEstimada(int musicas) => ritmoAntesDeMedir * musicas;

  int musicasQueCabem(DateTime agora) {
    final falta = restante(agora);
    final porMusica = ritmo(agora);
    if (falta.isNegative || porMusica <= Duration.zero) return 0;
    return falta.inSeconds ~/ porMusica.inSeconds;
  }

  /// Positivo: tempo que sobra depois da sequência; negativo: quanto ela
  /// passa do horário.
  Duration sobraDaSequencia(DateTime agora) =>
      restante(agora) - ritmo(agora) * musicasRestantes;

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

/// Lê as horas contratadas como a banda escreve: "4", "3h30", "3:30", "3,5"
/// ou "45 min". Vazio significa sem cronômetro.
int? lerDuracaoContratada(String texto) {
  final limpo = texto.trim().toLowerCase().replaceAll(' ', '');
  if (limpo.isEmpty) return null;
  final horasEMinutos =
      RegExp(r'^(\d{1,2})[h:](\d{1,2})?$').firstMatch(limpo);
  final soMinutos = RegExp(r'^(\d{1,4})min$').firstMatch(limpo);
  final decimal = RegExp(r'^(\d{1,2})(?:[.,](\d+))?$').firstMatch(limpo);
  int? minutos;
  if (horasEMinutos != null) {
    final resto = int.parse(horasEMinutos[2] ?? '0');
    if (resto < 60) minutos = int.parse(horasEMinutos[1]!) * 60 + resto;
  } else if (soMinutos != null) {
    minutos = int.parse(soMinutos[1]!);
  } else if (decimal != null) {
    minutos =
        (double.parse('${decimal[1]}.${decimal[2] ?? 0}') * 60).round();
  }
  if (minutos == null || minutos < 1 || minutos > 24 * 60) {
    throw const FormatException(
        'Não entendi as horas contratadas: ex.: 4 ou 3h30.');
  }
  return minutos;
}

/// "4h", "3h30" ou "45 min", para o campo de horas contratadas.
String escreverDuracaoContratada(int minutos) {
  if (minutos < 60) return '$minutos min';
  final resto = minutos % 60;
  return '${minutos ~/ 60}h${resto == 0 ? '' : resto.toString().padLeft(2, '0')}';
}

/// "3 min" ou "3,3 min".
String formatarRitmo(Duration ritmo) {
  final decimos = (ritmo.inSeconds / 6).round();
  return decimos % 10 == 0
      ? '${decimos ~/ 10} min'
      : '${decimos ~/ 10},${decimos % 10} min';
}

/// "1h42", "3h00" ou "42 min".
String formatarTempoDoShow(Duration tempo) {
  final minutos = tempo.inMinutes.abs();
  if (minutos < 60) return '$minutos min';
  return '${minutos ~/ 60}h${(minutos % 60).toString().padLeft(2, '0')}';
}

/// Compara a duração estimada da setlist com as horas contratadas; nulo sem
/// horas contratadas.
String? compararComContrato(RelogioDoShow relogio, Duration estimada) {
  final contratada = relogio.duracaoContratadaMinutos;
  if (contratada == null) return null;
  final diferenca = Duration(minutes: contratada) - estimada;
  if (diferenca.abs() < relogio.ritmoAntesDeMedir) {
    return 'a setlist fecha as horas contratadas';
  }
  return diferenca.isNegative
      ? 'a setlist passa ~${formatarTempoDoShow(diferenca)} do contratado'
      : 'contratado ${escreverDuracaoContratada(contratada)} → '
          'faltam ~${formatarTempoDoShow(diferenca)} de músicas';
}
