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
}) =>
    jsonEncode({
      'duracaoContratadaMinutos': duracao,
      'intervaloPausaRelogio': false,
      'iniciadaEm': _inicio.toIso8601String(),
      'emIntervaloDesde': emIntervaloDesde?.toIso8601String(),
      'segundosEmIntervalo': 0,
      'musicasComecadas': 0,
      'musicasRestantes': 0,
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
}) async {
  final servidor = _Servidor();
  // O show começou há [passado], pela hora do aparelho.
  final agora = DateTime.now();
  final inicioNoAparelho = agora.subtract(passado);
  servidor.resposta = _relogio(duracao: duracao)
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
    final termino = DateTime.now().add(const Duration(hours: 1, minutes: 42));
    expect(find.text('termina às ${_hora(termino)}'), findsOneWidget);
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
