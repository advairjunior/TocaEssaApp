import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:toca_essa_app/dominio/modelos.dart';
import 'package:toca_essa_app/infraestrutura/api_toca_essa.dart';
import 'package:toca_essa_app/telas/fila_musical_artista.dart';

// No Safari do iPhone, a lista reordenável do Flutter (que usa "arrasto
// múltiplo") não respondia. A fila passa a usar a lista própria do app.

String _pedido(int numero, String musica) => '''
  {
    "pedidoRepresentativoId":"10000000-0000-0000-0000-00000000000$numero",
    "pedidoIds":["10000000-0000-0000-0000-00000000000$numero"],
    "apresentacaoId":"33333333-3333-3333-3333-333333333333",
    "musica":"$musica",
    "solicitantes":["Ana"],
    "quantidadePedidos":1,
    "status":"Aceito",
    "posicao":$numero,
    "criadoEm":"2026-09-10T12:0$numero:00Z",
    "tipo":"Musica"
  }''';

final _fila = '[${_pedido(1, 'Evidências')},${_pedido(2, 'Sozinho')},'
    '${_pedido(3, 'Trem-Bala')}]';

Future<List<http.Request>> _abrirFila(WidgetTester tester) async {
  final requisicoes = <http.Request>[];
  final api = ApiTocaEssa(
    enderecoBase: 'https://tocaessa.test',
    cliente: MockClient((requisicao) async {
      requisicoes.add(requisicao);
      if (requisicao.url.path.endsWith('/estatisticas')) {
        return http.Response('{}', 500);
      }
      return http.Response(_fila, 200);
    }),
  )..definirTokenArtista('token-artista');
  await tester.binding.setSurfaceSize(const Size(420, 1600));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: FilaMusicalArtista(
        api: api,
        incorporada: true,
        apresentacao: Apresentacao(
          id: '33333333-3333-3333-3333-333333333333',
          nome: 'Show',
          data: DateTime(2026, 10, 9),
          local: 'Bar',
          codigo: 'ABC123',
          perfilArtistico: const PerfilArtistico(
              id: '22222222-2222-2222-2222-222222222222',
              nomeArtistico: 'Duo Aurora'),
          pedidosAbertos: true,
          status: StatusApresentacao.emAndamento,
          tipo: TipoApresentacao.publica,
        ),
      ),
    ),
  ));
  await tester.pumpAndSettle();
  return requisicoes;
}

List<String> _ordemEnviada(List<http.Request> requisicoes) =>
    (jsonDecode(requisicoes
            .lastWhere((r) => r.url.path.endsWith('/fila-agrupada'))
            .body)['pedidos'] as List<dynamic>)
        .cast<String>();

void main() {
  testWidgets('fila não usa mais a lista reordenável que falhava no iPhone',
      (tester) async {
    await _abrirFila(tester);

    expect(find.byType(ReorderableListView), findsNothing);
    expect(find.bySemanticsLabel('Arrastar para reordenar'), findsNWidgets(3));
  });

  testWidgets('tocar na alça da fila e mover para baixo salva a ordem',
      (tester) async {
    final requisicoes = await _abrirFila(tester);

    await tester.tap(find.bySemanticsLabel('Arrastar para reordenar').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mover para baixo'));
    await tester.pumpAndSettle();

    expect(_ordemEnviada(requisicoes), [
      '10000000-0000-0000-0000-000000000002',
      '10000000-0000-0000-0000-000000000001',
      '10000000-0000-0000-0000-000000000003',
    ]);
  });

  testWidgets('arrastar a alça da fila para cima salva a ordem',
      (tester) async {
    final requisicoes = await _abrirFila(tester);
    final alcas = find.bySemanticsLabel('Arrastar para reordenar');
    final distancia =
        tester.getCenter(alcas.at(0)).dy - tester.getCenter(alcas.at(2)).dy;

    await tester.drag(alcas.at(2), Offset(0, distancia));
    await tester.pumpAndSettle();

    expect(_ordemEnviada(requisicoes).first,
        '10000000-0000-0000-0000-000000000003');
  });
}
