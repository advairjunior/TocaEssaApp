import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:toca_essa_app/dominio/modelos.dart';
import 'package:toca_essa_app/infraestrutura/api_toca_essa.dart';
import 'package:toca_essa_app/telas/setlist_do_artista.dart';

const _id = '33333333-3333-3333-3333-333333333333';

Map<String, Object?> _item(String id, String titulo, int ordem,
        {bool tocada = false, String? tom}) =>
    {
      'id': id,
      'apresentacaoId': _id,
      'titulo': titulo,
      'artista': 'Banda $id',
      'tom': tom,
      'tocada': tocada,
      'ordem': ordem,
    };

Future<List<http.Request>> _abrir(
  WidgetTester tester, {
  List<Map<String, Object?>>? itens,
}) async {
  final requisicoes = <http.Request>[];
  final lista = itens ??
      [
        _item('1', 'Garota de Ipanema', 1, tocada: true),
        _item('2', 'Velha Infância', 2, tom: 'G'),
        _item('3', 'Evidências', 3),
      ];
  final cliente = MockClient((requisicao) async {
    requisicoes.add(requisicao);
    final caminho = requisicao.url.path;
    if (caminho.endsWith('/setlist')) {
      return http.Response(jsonEncode(lista), 200,
          headers: {'content-type': 'application/json; charset=utf-8'});
    }
    if (caminho.endsWith('/grupos-pedidos')) {
      return http.Response(
        jsonEncode([
          {
            'pedidoRepresentativoId': 'p1',
            'pedidoIds': ['p1', 'p2'],
            'apresentacaoId': _id,
            'musica': 'Evidências',
            'solicitantes': ['Ana', 'Beto'],
            'quantidadePedidos': 2,
            'status': 'Aceito',
            'criadoEm': '2026-09-10T12:00:00Z',
            'tipo': 'Musica',
          }
        ]),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    }
    if (caminho.endsWith('/tocada')) {
      final corpo = jsonDecode(requisicao.body) as Map<String, dynamic>;
      final item = lista.firstWhere((i) => caminho.contains('/${i['id']}/'));
      return http.Response(
        jsonEncode({...item, 'tocada': corpo['tocada']}),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    }
    return http.Response('[]', 200);
  });
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: SetlistDoArtista(
        api: ApiTocaEssa(cliente: cliente, enderecoBase: 'http://teste')
          ..definirTokenArtista('TOKEN'),
        apresentacao: Apresentacao(
          id: _id,
          nome: 'Show',
          data: DateTime(2026, 9, 10),
          local: 'Bar',
          codigo: 'ABC123',
          perfilArtistico: const PerfilArtistico(
              id: '22222222-2222-2222-2222-222222222222',
              nomeArtistico: 'Duo Aurora'),
          pedidosAbertos: true,
          status: StatusApresentacao.emAndamento,
          tipo: TipoApresentacao.publica,
        ),
        incorporada: true,
      ),
    ),
  ));
  await tester.pumpAndSettle();
  return requisicoes;
}

void main() {
  testWidgets('setlist mostra progresso, próxima e pedidos na fila',
      (tester) async {
    await _abrir(tester);

    expect(find.byType(Card), findsNothing);
    expect(find.byType(Checkbox), findsNothing);
    expect(find.text('1 de 3 tocadas'), findsOneWidget);
    expect(find.text('Trocar repertório'), findsOneWidget);
    expect(find.text('Próxima'), findsOneWidget);
    expect(find.text('Banda 2 · Tom G'), findsOneWidget);
    expect(find.text('2 pedidos na fila'), findsOneWidget);
  });

  testWidgets('tocar na linha marca a música como tocada', (tester) async {
    final requisicoes = await _abrir(tester);

    await tester.tap(find.text('Velha Infância'));
    await tester.pumpAndSettle();

    final marcacao = requisicoes.singleWhere((r) => r.method == 'PATCH');
    expect(marcacao.url.path, '/api/apresentacoes/$_id/setlist/2/tocada');
    expect(marcacao.body, contains('"tocada":true'));
    expect(find.text('2 de 3 tocadas'), findsOneWidget);
  });

  testWidgets('linha da música é anunciada como marcável', (tester) async {
    final semantica = tester.ensureSemantics();
    await _abrir(tester);

    expect(
      tester.getSemantics(find.text('Garota de Ipanema')),
      containsSemantics(hasCheckedState: true, isChecked: true),
    );
    semantica.dispose();
  });

  testWidgets('sem repertório, convida a importar', (tester) async {
    await _abrir(tester, itens: []);

    expect(find.text('Nenhum repertório nesta apresentação'), findsOneWidget);
    expect(find.text('Importar repertório'), findsOneWidget);
  });

  testWidgets('setlist cabe em celular de 360px', (tester) async {
    addTearDown(tester.view.reset);
    tester.view.devicePixelRatio = 3;
    tester.view.physicalSize = const Size(360, 740) * 3;
    await _abrir(tester);

    expect(tester.takeException(), isNull);
  });
}
