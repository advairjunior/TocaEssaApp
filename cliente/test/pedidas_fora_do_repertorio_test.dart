import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:toca_essa_app/infraestrutura/api_toca_essa.dart';
import 'package:toca_essa_app/telas/gerenciar_repertorios.dart';

const _comoJson = {'content-type': 'application/json; charset=utf-8'};

Future<List<http.Request>> _abrir(WidgetTester tester,
    {required List<Map<String, Object?>> pedidas}) async {
  final requisicoes = <http.Request>[];
  final cliente = MockClient((requisicao) async {
    requisicoes.add(requisicao);
    final caminho = requisicao.url.path;
    if (caminho.endsWith('/pedidas-fora')) {
      return http.Response(jsonEncode(pedidas), 200, headers: _comoJson);
    }
    if (caminho.endsWith('/repertorios/musicas')) {
      final corpo = jsonDecode(requisicao.body) as Map<String, dynamic>;
      final titulos = [
        for (final m in corpo['musicas'] as List) m['titulo'] as String
      ];
      // Depois de adicionar, saem da lista de pedidas.
      pedidas.removeWhere((p) => titulos.contains(p['musica']));
      return http.Response(
          jsonEncode({
            'repertorio': {
              'id': 'r1',
              'artistaId': 'a1',
              'nome': 'Barzinho',
              'musicas': [],
            },
            'adicionadas': titulos.length,
            'jaEstavam': 0,
          }),
          200,
          headers: _comoJson);
    }
    return http.Response(
        jsonEncode([
          {'id': 'r1', 'artistaId': 'a1', 'nome': 'Barzinho', 'musicas': []},
        ]),
        200,
        headers: _comoJson);
  });
  await tester.pumpWidget(MaterialApp(
    home: GerenciarRepertorios(
      api: ApiTocaEssa(cliente: cliente, enderecoBase: 'http://teste'),
    ),
  ));
  await tester.pumpAndSettle();
  return requisicoes;
}

Map<String, Object?> _pedida(String musica, int vezes, int shows,
        {String? artista}) =>
    {'musica': musica, 'artista': artista, 'vezes': vezes, 'shows': shows};

void main() {
  testWidgets('mostra as mais pedidas fora do repertório', (tester) async {
    await _abrir(tester, pedidas: [
      _pedida('Garçom', 7, 3, artista: 'Reginaldo Rossi'),
      _pedida('Trem-Bala', 2, 1),
      _pedida('Ai Se Eu Te Pego', 1, 1),
      _pedida('Lepo Lepo', 1, 1),
    ]);

    expect(find.text('Pedidas pelo público'), findsOneWidget);
    expect(find.text('Garçom · pedida 7x em 3 shows'), findsOneWidget);
    expect(find.text('Trem-Bala · pedida 2x'), findsOneWidget);
    expect(find.text('Ai Se Eu Te Pego · pedida 1x'), findsOneWidget);
    // Só as três primeiras no cartão; as outras ficam no Ver todas.
    expect(find.textContaining('Lepo Lepo'), findsNothing);
    expect(find.text('Ver as 4 e adicionar'), findsOneWidget);
  });

  testWidgets('sem pedidas fora do acervo, o cartão não aparece',
      (tester) async {
    await _abrir(tester, pedidas: []);

    expect(find.text('Pedidas pelo público'), findsNothing);
    expect(find.text('Barzinho'), findsOneWidget);
  });

  testWidgets('leva as pedidas a um repertório e o cartão atualiza',
      (tester) async {
    final requisicoes = await _abrir(tester, pedidas: [
      _pedida('Garçom', 7, 3, artista: 'Reginaldo Rossi'),
      _pedida('Trem-Bala', 2, 1),
    ]);

    await tester.tap(find.text('Ver as 2 e adicionar'));
    await tester.pumpAndSettle();
    expect(find.text('Reginaldo Rossi · pedida 7x em 3 shows'), findsOneWidget);
    await tester.tap(find.text('Trem-Bala'));
    await tester.pump();
    await tester.tap(find.text('Adicionar 1 música ao repertório'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Barzinho').last);
    await tester.pumpAndSettle();

    final envio = requisicoes
        .singleWhere((r) => r.url.path.endsWith('/repertorios/musicas'));
    expect(jsonDecode(envio.body), {
      'repertorioId': 'r1',
      'musicas': [
        {'titulo': 'Garçom', 'artista': 'Reginaldo Rossi', 'tom': null},
      ],
    });
    expect(find.text('Garçom · pedida 7x em 3 shows'), findsNothing);
    expect(find.text('Trem-Bala · pedida 2x'), findsOneWidget);
  });
}
