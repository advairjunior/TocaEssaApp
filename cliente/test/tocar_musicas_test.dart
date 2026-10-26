import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:toca_essa_app/infraestrutura/api_toca_essa.dart';
import 'package:toca_essa_app/telas/tocar_musicas.dart';

const _json = {'content-type': 'application/json; charset=utf-8'};
const _cifraVelha =
    'G    D\nQuando eu digo que deixei de te amar\nEm   C\nÉ porque eu te amo';

Map<String, Object?> _musica(
        String id, String repertorioId, String titulo, int ordem,
        {String? artista = 'Banda', String? tom}) =>
    {
      'id': id,
      'repertorioId': repertorioId,
      'titulo': titulo,
      'artista': artista,
      'tom': tom,
      'ordem': ordem,
    };

final _repertorios = [
  {
    'id': 'r1',
    'artistaId': 'a1',
    'nome': 'Barzinho',
    'musicas': [
      _musica('m1', 'r1', 'Velha Infância', 1, tom: 'G'),
      _musica('m2', 'r1', 'Evidências', 2),
      _musica('m3', 'r1', 'Garota de Ipanema', 3),
    ],
  },
  {
    'id': 'r2',
    'artistaId': 'a1',
    'nome': 'Em casa',
    'musicas': [
      // A mesma do Barzinho: em Todas aparece uma vez só.
      _musica('m4', 'r2', 'Evidencias', 1, artista: 'banda'),
      _musica('m5', 'r2', 'Aleluia', 2, artista: null),
    ],
  },
];

Future<List<http.Request>> _abrir(WidgetTester tester,
    {String? repertorioInicialId}) async {
  final requisicoes = <http.Request>[];
  final cliente = MockClient((requisicao) async {
    requisicoes.add(requisicao);
    final caminho = requisicao.url.path;
    if (caminho == '/api/artista/repertorios') {
      return http.Response(jsonEncode(_repertorios), 200, headers: _json);
    }
    if (caminho.endsWith('/cifras/consulta')) {
      final musica = requisicao.url.queryParameters['musica'];
      return http.Response(
        jsonEncode({
          'cifra': null,
          'urlPesquisa': 'https://www.google.com/search?q=cifra',
          'texto': musica == 'Velha Infância' ? _cifraVelha : null,
        }),
        200,
        headers: _json,
      );
    }
    return http.Response('', 404);
  });
  final api = ApiTocaEssa(cliente: cliente, enderecoBase: 'http://teste')
    ..definirTokenArtista('TOKEN');
  await tester.pumpWidget(MaterialApp(
    home: TocarMusicas(
      api: api,
      repertorioInicialId: repertorioInicialId,
      abrirUrl: (_) async {},
    ),
  ));
  await tester.pumpAndSettle();
  return requisicoes;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('tocar na música abre a cifra no leitor, sem show e sem Tocar',
      (tester) async {
    final requisicoes = await _abrir(tester);

    await tester.tap(find.text('Velha Infância'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Quando eu digo que deixei'), findsOneWidget);
    // Sem show não há o que marcar como tocada.
    expect(find.widgetWithText(FilledButton, 'Tocar'), findsNothing);
    expect(find.text('1 de 4'), findsOneWidget);
    expect(find.text('Depois: Evidências'), findsOneWidget);

    await tester.tap(find.byTooltip('Próxima música'));
    await tester.pumpAndSettle();
    expect(find.text('2 de 4'), findsOneWidget);
    expect(find.text('Sem cifra no app'), findsOneWidget);

    // Nada de show: só o acervo e as cifras passam pelo servidor.
    expect(
        requisicoes.where(
            (r) => r.url.path.contains('/apresentacoes') || r.method != 'GET'),
        isEmpty);
  });

  testWidgets('a busca acha sem acento e as setas andam só pelas achadas',
      (tester) async {
    await _abrir(tester);

    await tester.enterText(find.byType(TextField), 'evidencias');
    await tester.pumpAndSettle();

    expect(find.text('Evidências'), findsOneWidget);
    expect(find.text('Velha Infância'), findsNothing);

    await tester.tap(find.text('Evidências'));
    await tester.pumpAndSettle();
    expect(find.text('1 de 1'), findsOneWidget);
    expect(find.text('Fim da lista'), findsOneWidget);
  });

  testWidgets('busca sem resultado oferece limpar', (tester) async {
    await _abrir(tester);

    await tester.enterText(find.byType(TextField), 'xyz');
    await tester.pumpAndSettle();
    expect(find.text('Nenhuma música com "xyz"'), findsOneWidget);

    await tester.tap(find.text('Limpar busca'));
    await tester.pumpAndSettle();
    expect(find.text('Velha Infância'), findsOneWidget);
  });

  testWidgets('abre já no repertório escolhido e o chip troca a lista',
      (tester) async {
    await _abrir(tester, repertorioInicialId: 'r2');

    expect(find.text('Aleluia'), findsOneWidget);
    expect(find.text('Velha Infância'), findsNothing);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Todas'));
    await tester.pumpAndSettle();
    expect(find.text('Velha Infância'), findsOneWidget);
    expect(find.text('Aleluia'), findsOneWidget);
  });

  testWidgets('cada linha mostra cantor e tom', (tester) async {
    await _abrir(tester);

    expect(find.text('Banda · Tom G'), findsOneWidget);
  });
}
