import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:toca_essa_app/dominio/modelos.dart';
import 'package:toca_essa_app/infraestrutura/api_toca_essa.dart';

final _inicio = DateTime.utc(2026, 10, 17, 21);

RelogioDoShow _relogio({
  int? duracao = 240,
  bool pausa = false,
  DateTime? iniciadaEm,
  DateTime? emIntervaloDesde,
  int segundosEmIntervalo = 0,
  DateTime? agoraNoServidor,
  DateTime? recebidoEm,
}) =>
    RelogioDoShow.deJson({
      'duracaoContratadaMinutos': duracao,
      'intervaloPausaRelogio': pausa,
      'iniciadaEm': (iniciadaEm ?? _inicio).toIso8601String(),
      'emIntervaloDesde': emIntervaloDesde?.toIso8601String(),
      'segundosEmIntervalo': segundosEmIntervalo,
      'musicasComecadas': 0,
      'musicasRestantes': 0,
      'agora': (agoraNoServidor ?? _inicio).toIso8601String(),
    }, recebidoEm: recebidoEm ?? agoraNoServidor ?? _inicio);

void main() {
  group('relógio corrido', () {
    test('conta o que falta das horas contratadas e quando termina', () {
      final relogio = _relogio();
      final agora = _inicio.add(const Duration(hours: 2, minutes: 18));

      expect(relogio.ativo, isTrue);
      expect(relogio.restante(agora), const Duration(hours: 1, minutes: 42));
      expect(relogio.termino(agora), _inicio.add(const Duration(hours: 4)));
      expect(relogio.alerta(agora), AlertaDoRelogio.normal);
    });

    test('o intervalo não para o relógio', () {
      final relogio = _relogio(
        emIntervaloDesde: _inicio.add(const Duration(hours: 1)),
        segundosEmIntervalo: 600,
      );
      final agora = _inicio.add(const Duration(hours: 1, minutes: 15));

      expect(relogio.emIntervalo, isTrue);
      expect(relogio.tempoEmIntervalo(agora), const Duration(minutes: 15));
      expect(relogio.restante(agora), const Duration(hours: 2, minutes: 45));
    });
  });

  group('intervalo pausa o relógio', () {
    test('desconta intervalos já feitos e o que está em andamento', () {
      final relogio = _relogio(
        pausa: true,
        emIntervaloDesde: _inicio.add(const Duration(hours: 2)),
        segundosEmIntervalo: 10 * 60,
      );
      final agora = _inicio.add(const Duration(hours: 2, minutes: 20));

      expect(relogio.restante(agora), const Duration(hours: 2, minutes: 10));
      expect(relogio.termino(agora),
          agora.add(const Duration(hours: 2, minutes: 10)));
    });
  });

  test('avisa com 30 e com 10 minutos e depois do horário', () {
    final relogio = _relogio(duracao: 60);

    expect(relogio.alerta(_inicio.add(const Duration(minutes: 30))),
        AlertaDoRelogio.trintaMinutos);
    expect(relogio.alerta(_inicio.add(const Duration(minutes: 50))),
        AlertaDoRelogio.dezMinutos);
    final passou = _inicio.add(const Duration(minutes: 68));
    expect(relogio.alerta(passou), AlertaDoRelogio.passou);
    expect(relogio.restante(passou), const Duration(minutes: -8));
  });

  test('sem duração ou sem início o relógio fica desligado', () {
    expect(_relogio(duracao: null).ativo, isFalse);
    final semInicio = RelogioDoShow.deJson({
      'duracaoContratadaMinutos': 240,
      'intervaloPausaRelogio': false,
      'iniciadaEm': null,
      'emIntervaloDesde': null,
      'segundosEmIntervalo': 0,
      'musicasComecadas': 0,
      'musicasRestantes': 0,
      'agora': _inicio.toIso8601String(),
    }, recebidoEm: _inicio);
    expect(semInicio.ativo, isFalse);
  });

  test('usa a hora do servidor mesmo com o relógio do aparelho adiantado', () {
    final aparelhoAdiantado = _inicio.add(const Duration(hours: 1, minutes: 5));
    final relogio = _relogio(
      agoraNoServidor: _inicio.add(const Duration(hours: 1)),
      recebidoEm: aparelhoAdiantado,
    );

    expect(relogio.restante(aparelhoAdiantado), const Duration(hours: 3));
  });

  group('ritmo do show', () {
    RelogioDoShow comMusicas(int comecadas, int restantes) =>
        RelogioDoShow.deJson({
          'duracaoContratadaMinutos': 240,
          'intervaloPausaRelogio': false,
          'iniciadaEm': _inicio.toIso8601String(),
          'emIntervaloDesde': null,
          'segundosEmIntervalo': 10 * 60,
          'musicasComecadas': comecadas,
          'musicasRestantes': restantes,
          'agora': _inicio.toIso8601String(),
        }, recebidoEm: _inicio);
    final umaHoraDepois = _inicio.add(const Duration(hours: 1));

    test('até a 3ª música usa 3 minutos por música', () {
      final relogio = comMusicas(2, 18);

      expect(relogio.ritmoMedido, isFalse);
      expect(relogio.ritmo(umaHoraDepois), const Duration(minutes: 3));
      expect(relogio.musicasQueCabem(umaHoraDepois), 60);
      expect(relogio.sobraDaSequencia(umaHoraDepois),
          const Duration(hours: 2, minutes: 6));
    });

    test('depois mede o ritmo real, sem contar o intervalo', () {
      // 50 min tocando (1h menos 10 min de intervalo) em 15 músicas.
      final relogio = comMusicas(15, 18);

      expect(relogio.ritmoMedido, isTrue);
      expect(relogio.ritmo(umaHoraDepois),
          const Duration(minutes: 3, seconds: 20));
      expect(relogio.musicasQueCabem(umaHoraDepois), 54);
      expect(relogio.sobraDaSequencia(umaHoraDepois), const Duration(hours: 2));
    });

    test('sequência maior que o tempo passa do horário', () {
      final relogio = comMusicas(15, 60);

      expect(relogio.sobraDaSequencia(umaHoraDepois),
          const Duration(minutes: -20));
    });

    test('depois do horário não cabe mais nenhuma', () {
      final relogio = comMusicas(15, 3);

      expect(relogio.musicasQueCabem(_inicio.add(const Duration(hours: 5))),
          0);
    });

    test('antes de medir, usa o ritmo médio dos shows anteriores', () {
      final relogio = RelogioDoShow.deJson({
        ...{
          'duracaoContratadaMinutos': 240,
          'intervaloPausaRelogio': false,
          'iniciadaEm': _inicio.toIso8601String(),
          'emIntervaloDesde': null,
          'segundosEmIntervalo': 0,
          'musicasComecadas': 2,
          'musicasRestantes': 18,
          'agora': _inicio.toIso8601String(),
        },
        'ritmoMedioSegundos': 250,
      }, recebidoEm: _inicio);

      expect(relogio.temRitmoMedio, isTrue);
      expect(relogio.ritmo(umaHoraDepois), const Duration(seconds: 250));
      expect(relogio.duracaoEstimada(18), const Duration(minutes: 75));
      expect(comMusicas(2, 18).duracaoEstimada(18),
          const Duration(minutes: 54));
    });

    test('escreve o ritmo em minutos com vírgula', () {
      expect(formatarRitmo(const Duration(minutes: 3)), '3 min');
      expect(formatarRitmo(const Duration(minutes: 3, seconds: 20)), '3,3 min');
      expect(formatarRitmo(const Duration(minutes: 4, seconds: 12)), '4,2 min');
    });
  });

  test('formata o tempo como a banda fala', () {
    expect(formatarTempoDoShow(const Duration(hours: 1, minutes: 42)), '1h42');
    expect(formatarTempoDoShow(const Duration(hours: 3)), '3h00');
    expect(formatarTempoDoShow(const Duration(minutes: 42, seconds: 30)),
        '42 min');
    expect(formatarTempoDoShow(const Duration(seconds: 20)), '0 min');
  });

  test('entende as horas contratadas do jeito que a banda escreve', () {
    expect(lerDuracaoContratada(''), isNull);
    expect(lerDuracaoContratada('  '), isNull);
    expect(lerDuracaoContratada('4'), 240);
    expect(lerDuracaoContratada('4h'), 240);
    expect(lerDuracaoContratada('3h30'), 210);
    expect(lerDuracaoContratada('3H 30'), 210);
    expect(lerDuracaoContratada('3:30'), 210);
    expect(lerDuracaoContratada('3,5'), 210);
    expect(lerDuracaoContratada('1.5'), 90);
    expect(lerDuracaoContratada('45 min'), 45);
    for (final invalida in ['abc', '0', '25', '3h75', '-2']) {
      expect(() => lerDuracaoContratada(invalida), throwsFormatException,
          reason: invalida);
    }
  });

  test('escreve a duração contratada para editar', () {
    expect(escreverDuracaoContratada(240), '4h');
    expect(escreverDuracaoContratada(210), '3h30');
    expect(escreverDuracaoContratada(45), '45 min');
  });

  test('API configura o relógio e marca o intervalo', () async {
    final requisicoes = <http.Request>[];
    final api = ApiTocaEssa(
      cliente: MockClient((requisicao) async {
        requisicoes.add(requisicao);
        return http.Response(
          jsonEncode({
            'duracaoContratadaMinutos': 240,
            'intervaloPausaRelogio': true,
            'iniciadaEm': null,
            'emIntervaloDesde': null,
            'segundosEmIntervalo': 0,
            'musicasComecadas': 0,
            'musicasRestantes': 0,
            'agora': _inicio.toIso8601String(),
          }),
          200,
        );
      }),
      enderecoBase: 'http://teste',
    )..definirTokenArtista('TOKEN');

    final relogio = await api.configurarRelogio('s1', 240, pausa: true);
    await api.obterRelogio('s1');
    await api.iniciarIntervalo('s1');
    await api.encerrarIntervalo('s1');

    expect(relogio.duracaoContratadaMinutos, 240);
    expect(
      requisicoes.map((r) => '${r.method} ${r.url.path}'),
      [
        'PUT /api/apresentacoes/s1/relogio',
        'GET /api/apresentacoes/s1/relogio',
        'POST /api/apresentacoes/s1/relogio/intervalo',
        'DELETE /api/apresentacoes/s1/relogio/intervalo',
      ],
    );
    expect(jsonDecode(requisicoes.first.body),
        {'duracaoContratadaMinutos': 240, 'intervaloPausaRelogio': true});
    expect(requisicoes.first.headers['Authorization'], 'Bearer TOKEN');
  });
}
