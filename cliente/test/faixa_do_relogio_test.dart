import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:toca_essa_app/infraestrutura/api_toca_essa.dart';
import 'package:toca_essa_app/telas/faixa_do_relogio.dart';

final _inicio = DateTime.utc(2026, 10, 17, 21);

String _relogio({
  int? duracao = 240,
  DateTime? emIntervaloDesde,
  int comecadas = 0,
  int restantes = 0,
  int? ritmoMedio,
}) =>
    jsonEncode({
      'ritmoMedioSegundos': ritmoMedio,
      'duracaoContratadaMinutos': duracao,
      'intervaloPausaRelogio': false,
      'iniciadaEm': _inicio.toIso8601String(),
      'emIntervaloDesde': emIntervaloDesde?.toIso8601String(),
      'segundosEmIntervalo': 0,
      'musicasComecadas': comecadas,
      'musicasRestantes': restantes,
      // O servidor responde com a mesma hora do aparelho nos testes.
      'agora': DateTime.now().toUtc().toIso8601String(),
    });

String _hora(DateTime data) {
  final local = data.toLocal();
  return '${local.hour.toString().padLeft(2, '0')}:'
      '${local.minute.toString().padLeft(2, '0')}';
}

class _Servidor {
  final requisicoes = <http.Request>[];
  late String resposta;
}

Future<_Servidor> _abrir(
  WidgetTester tester, {
  required Duration passado,
  int? duracao = 240,
  int comecadas = 0,
  int restantes = 0,
  int? ritmoMedio,
}) async {
  final servidor = _Servidor();
  // O show começou há [passado], pela hora do aparelho.
  final agora = DateTime.now();
  final inicioNoAparelho = agora.subtract(passado);
  servidor.resposta = _relogio(
          duracao: duracao,
          comecadas: comecadas,
          restantes: restantes,
          ritmoMedio: ritmoMedio)
      .replaceAll(_inicio.toIso8601String(),
          inicioNoAparelho.toUtc().toIso8601String());
  final api = ApiTocaEssa(
    cliente: MockClient((requisicao) async {
      servidor.requisicoes.add(requisicao);
      if (requisicao.method == 'POST') {
        return http.Response(
            _relogio(emIntervaloDesde: DateTime.now().toUtc()).replaceAll(
                _inicio.toIso8601String(),
                inicioNoAparelho.toUtc().toIso8601String()),
            200);
      }
      return http.Response(servidor.resposta, 200);
    }),
    enderecoBase: 'http://teste',
  )..definirTokenArtista('TOKEN');
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: FaixaDoRelogio(
        api: api,
        apresentacaoId: 's1',
        codigo: 'ABC123',
      ),
    ),
  ));
  await tester.pumpAndSettle();
  return servidor;
}

void main() {
  testWidgets('mostra quanto falta e a hora de terminar', (tester) async {
    await _abrir(tester, passado: const Duration(hours: 2, minutes: 18));

    expect(find.text('Restam 1h42'), findsOneWidget);
    // Tolera a virada de um minuto entre a tela e o teste.
    final termino = DateTime.now().add(const Duration(hours: 1, minutes: 42));
    final aceitas = {
      for (final ajuste in [-1, 0, 1])
        'termina às ${_hora(termino.add(Duration(minutes: ajuste)))}'
    };
    expect(
      find.byWidgetPredicate((w) => w is Text && aceitas.contains(w.data)),
      findsOneWidget,
    );
  });

  testWidgets('depois do horário mostra quanto passou', (tester) async {
    await _abrir(tester,
        passado: const Duration(hours: 4, minutes: 8, seconds: 30));

    expect(find.text('Passou 8 min'), findsOneWidget);
  });

  testWidgets('sem horas contratadas não aparece', (tester) async {
    await _abrir(tester, passado: const Duration(hours: 1), duracao: null);

    expect(find.textContaining('Restam'), findsNothing);
    expect(find.text('Intervalo'), findsNothing);
  });

  testWidgets('intervalo e voltar ao show', (tester) async {
    final servidor =
        await _abrir(tester, passado: const Duration(hours: 1));

    await tester.tap(find.text('Intervalo'));
    await tester.pumpAndSettle();

    expect(find.text('Intervalo · 0 min'), findsOneWidget);
    expect(find.text('Voltar ao show'), findsOneWidget);
    await tester.tap(find.text('Voltar ao show'));
    await tester.pumpAndSettle();

    expect(
      servidor.requisicoes.map((r) => '${r.method} ${r.url.path}'),
      containsAllInOrder([
        'POST /api/apresentacoes/s1/relogio/intervalo',
        'DELETE /api/apresentacoes/s1/relogio/intervalo',
      ]),
    );
    expect(find.text('Intervalo'), findsOneWidget);
  });

  group('ritmo do show', () {
    testWidgets('antes de medir, avisa que estima 3 min por música',
        (tester) async {
      await _abrir(tester,
          passado: const Duration(minutes: 59, seconds: 50),
          comecadas: 2,
          restantes: 18);

      expect(find.text('Cabem ~60 músicas (estimativa: 3 min cada)'),
          findsOneWidget);
      expect(find.text('Sequência de 18 músicas: sobram ~2h06'),
          findsOneWidget);
    });

    testWidgets('antes de medir, usa o ritmo médio dos shows anteriores',
        (tester) async {
      await _abrir(tester,
          passado: const Duration(minutes: 59, seconds: 50),
          comecadas: 2,
          ritmoMedio: 240);

      expect(find.text('Cabem ~45 músicas (seu ritmo médio: 4 min)'),
          findsOneWidget);
    });

    testWidgets('com o ritmo medido, mostra o ritmo do show', (tester) async {
      await _abrir(tester,
          passado: const Duration(minutes: 49, seconds: 59), comecadas: 15);

      expect(find.text('Cabem ~57 músicas no ritmo de 3,3 min'),
          findsOneWidget);
      expect(find.textContaining('Sequência'), findsNothing);
    });

    testWidgets('avisa quando a sequência passa do horário', (tester) async {
      await _abrir(tester,
          passado: const Duration(minutes: 49, seconds: 59),
          comecadas: 15,
          restantes: 65);

      expect(find.text('Sequência de 65 músicas passa ~25 min do horário'),
          findsOneWidget);
    });

    testWidgets('tocar na faixa explica como o app calcula', (tester) async {
      await _abrir(tester, passado: const Duration(hours: 1));

      await tester.tap(find.textContaining('Restam'));
      await tester.pumpAndSettle();

      expect(find.text('Como o TocaEssa calcula'), findsOneWidget);
      expect(find.textContaining('3 minutos por música'), findsOneWidget);
    });
  });

  testWidgets('falha ao consultar o relógio não incomoda a banda',
      (tester) async {
    final api = ApiTocaEssa(
      cliente: MockClient((_) async => http.Response('[]', 200)),
      enderecoBase: 'http://teste',
    );
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: FaixaDoRelogio(api: api, apresentacaoId: 's1', codigo: 'ABC'),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.byType(SnackBar), findsNothing);
    expect(find.textContaining('Restam'), findsNothing);
  });
}
