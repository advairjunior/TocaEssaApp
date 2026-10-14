import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:toca_essa_app/dominio/modelos.dart';
import 'package:toca_essa_app/infraestrutura/api_toca_essa.dart';
import 'package:toca_essa_app/telas/montar_setlist.dart';

const _show = 'aaaaaaaa-0000-0000-0000-000000000001';

Map<String, Object?> _musica(String id, String repertorio, String titulo,
        {String? artista, int ordem = 1}) =>
    {
      'id': id,
      'repertorioId': repertorio,
      'titulo': titulo,
      'artista': artista,
      'tom': null,
      'ordem': ordem,
    };

final _repertorios = [
  {
    'id': 'r1',
    'artistaId': 'a',
    'nome': 'Românticas',
    'musicas': [
      _musica('m1', 'r1', 'Evidências', artista: 'Chitãozinho', ordem: 1),
      _musica('m2', 'r1', 'Tempo Perdido', ordem: 2),
      _musica('m3', 'r1', 'Pense em Mim', ordem: 3),
    ],
  },
  {
    'id': 'r2',
    'artistaId': 'a',
    'nome': 'Animadas',
    'musicas': [
      _musica('m4', 'r2', 'Macarena', ordem: 1),
      _musica('m5', 'r2', 'evidencias', ordem: 2),
    ],
  },
];

ItemDoSetlist _item(String id, String titulo, {String? artista}) =>
    ItemDoSetlist(
      id: id,
      apresentacaoId: _show,
      titulo: titulo,
      artista: artista,
      tocada: false,
      ordem: 1,
    );

Map<String, Object?> _relogio({int? duracao}) => {
      'duracaoContratadaMinutos': duracao,
      'intervaloPausaRelogio': false,
      'iniciadaEm': null,
      'emIntervaloDesde': null,
      'segundosEmIntervalo': 0,
      'musicasComecadas': 0,
      'musicasRestantes': 0,
      'agora': '2026-12-12T21:00:00Z',
    };

Future<List<http.Request>> _abrir(
  WidgetTester tester, {
  List<ItemDoSetlist> naSetlist = const [],
  int? duracao,
}) async {
  final requisicoes = <http.Request>[];
  final cliente = MockClient((requisicao) async {
    requisicoes.add(requisicao);
    final caminho = requisicao.url.path;
    if (caminho.endsWith('/repertorios')) {
      return http.Response(jsonEncode(_repertorios), 200,
          headers: {'content-type': 'application/json; charset=utf-8'});
    }
    if (caminho.endsWith('/relogio')) {
      return http.Response(jsonEncode(_relogio(duracao: duracao)), 200);
    }
    return http.Response('[]', 200);
  });
  await tester.pumpWidget(MaterialApp(
    home: Builder(
      builder: (context) => Scaffold(
        body: TextButton(
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => MontarSetlist(
              api: ApiTocaEssa(cliente: cliente, enderecoBase: 'http://teste')
                ..definirTokenArtista('TOKEN'),
              apresentacaoId: _show,
              naSetlist: naSetlist,
            ),
          )),
          child: const Text('Abrir'),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('Abrir'));
  await tester.pumpAndSettle();
  return requisicoes;
}

http.Request _post(List<http.Request> requisicoes, String final_) =>
    requisicoes.singleWhere(
        (r) => r.method == 'POST' && r.url.path.endsWith(final_));

void main() {
  testWidgets('navega entre os repertórios do acervo', (tester) async {
    await _abrir(tester);

    expect(find.text('Românticas'), findsOneWidget);
    expect(find.text('Animadas'), findsOneWidget);
    expect(find.text('Tempo Perdido'), findsOneWidget);
    expect(find.text('Macarena'), findsNothing);

    await tester.tap(find.text('Animadas'));
    await tester.pumpAndSettle();

    expect(find.text('Macarena'), findsOneWidget);
    expect(find.text('Tempo Perdido'), findsNothing);
  });

  testWidgets('escolhe músicas de repertórios diferentes e adiciona no fim',
      (tester) async {
    final requisicoes = await _abrir(tester);

    await tester.tap(find.text('Pense em Mim'));
    await tester.tap(find.text('Tempo Perdido'));
    await tester.tap(find.text('Animadas'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Macarena'));
    await tester.pumpAndSettle();
    expect(find.textContaining('+3 selecionadas'), findsOneWidget);

    await tester.tap(find.text('Adicionar à setlist'));
    await tester.pumpAndSettle();

    expect(jsonDecode(_post(requisicoes, '/setlist/musicas').body),
        {'musicaIds': ['m3', 'm2', 'm4']});
    expect(find.text('Abrir'), findsOneWidget);
  });

  testWidgets('selecionar todas pula o que já está na setlist',
      (tester) async {
    final requisicoes = await _abrir(tester, naSetlist: [
      _item('i1', 'EVIDENCIAS'),
    ]);

    expect(find.text('na setlist'), findsOneWidget);
    await tester.tap(find.text('Selecionar todas'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Animadas'));
    await tester.pumpAndSettle();
    // A mesma música em outro repertório também conta como já escolhida.
    expect(find.text('na setlist'), findsOneWidget);
    await tester.tap(find.text('Adicionar à setlist'));
    await tester.pumpAndSettle();

    expect(jsonDecode(_post(requisicoes, '/setlist/musicas').body),
        {'musicaIds': ['m2', 'm3']});
  });

  testWidgets('busca encontra a música em todo o acervo', (tester) async {
    await _abrir(tester);

    await tester.enterText(find.byType(TextField).first, 'maca');
    await tester.pumpAndSettle();

    expect(find.text('Macarena'), findsOneWidget);
    expect(find.text('Tempo Perdido'), findsNothing);
    expect(find.text('Animadas'), findsWidgets);
  });

  testWidgets('rodapé mostra a duração estimada e as horas contratadas',
      (tester) async {
    await _abrir(tester,
        naSetlist: [for (var i = 0; i < 10; i++) _item('i$i', 'Música $i')],
        duracao: 240);

    await tester.tap(find.text('Tempo Perdido'));
    await tester.tap(find.text('Pense em Mim'));
    await tester.pumpAndSettle();

    expect(
        find.text('+2 selecionadas · 12 músicas ≈ 36 min'), findsOneWidget);
    expect(find.text('contratado 4h → faltam ~3h24 de músicas'),
        findsOneWidget);
  });

  testWidgets('rodapé conta o tempo de cada música do pout-pourri',
      (tester) async {
    await _abrir(tester,
        naSetlist: [_item('i1', 'Evidências / Página Virada')], duracao: 240);

    await tester.tap(find.text('Tempo Perdido'));
    await tester.pumpAndSettle();

    expect(find.text('+1 selecionada · 2 músicas ≈ 9 min'), findsOneWidget);
  });

  testWidgets('música avulsa entra na setlist e pode ficar no acervo',
      (tester) async {
    final requisicoes = await _abrir(tester);

    await tester.tap(find.text('Música avulsa'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.widgetWithText(TextField, 'Título'), 'Hino da empresa');
    await tester.enterText(
        find.widgetWithText(TextField, 'Cantor ou banda'), 'Coral');
    await tester.tap(find.text('Animadas').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Adicionar'));
    await tester.pumpAndSettle();

    expect(jsonDecode(_post(requisicoes, '/setlist/avulsa').body), {
      'titulo': 'Hino da empresa',
      'artista': 'Coral',
      'tom': null,
      'repertorioId': 'r2',
    });
    expect(find.text('Hino da empresa entrou na setlist.'), findsOneWidget);
  });

  testWidgets('montar setlist cabe em celular de 360px', (tester) async {
    addTearDown(tester.view.reset);
    tester.view.devicePixelRatio = 3;
    tester.view.physicalSize = const Size(360, 740) * 3;

    await _abrir(tester, duracao: 240);
    await tester.tap(find.text('Tempo Perdido'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
