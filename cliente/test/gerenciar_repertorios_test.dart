import 'dart:convert';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:toca_essa_app/infraestrutura/api_toca_essa.dart';
import 'package:toca_essa_app/telas/componentes_formulario.dart';
import 'package:toca_essa_app/telas/gerenciar_repertorios.dart';

const _repertoriosJson =
    '[{"id":"r1","artistaId":"a1","nome":"Barzinho","musicas":['
    '{"id":"m1","repertorioId":"r1","titulo":"Evidências","artista":"Chitãozinho & Xororó","tom":"A","ordem":1},'
    '{"id":"m2","repertorioId":"r1","titulo":"Sozinho","artista":null,"tom":null,"ordem":2}'
    ']}]';

Future<List<http.Request>> _abrir(WidgetTester tester) async {
  final requisicoes = <http.Request>[];
  final cliente = MockClient((requisicao) async {
    requisicoes.add(requisicao);
    if (requisicao.method == 'DELETE') return http.Response('', 204);
    return http.Response(_repertoriosJson, 200,
        headers: {'content-type': 'application/json; charset=utf-8'});
  });
  await tester.pumpWidget(MaterialApp(
    home: GerenciarRepertorios(
      api: ApiTocaEssa(cliente: cliente, enderecoBase: 'http://teste'),
    ),
  ));
  await tester.pumpAndSettle();
  return requisicoes;
}

void main() {
  testWidgets('lista de repertórios sem cards e sem excluir à mão',
      (tester) async {
    await _abrir(tester);

    expect(find.text('Meus repertórios'), findsOneWidget);
    expect(find.byType(Card), findsNothing);
    expect(find.text('Barzinho'), findsOneWidget);
    expect(find.text('2 músicas'), findsOneWidget);
    // Excluir fica dentro do repertório, longe de um toque acidental.
    expect(find.byTooltip('Excluir'), findsNothing);
  });

  testWidgets('tocar na música abre a edição; excluir fica no menu',
      (tester) async {
    final requisicoes = await _abrir(tester);
    await tester.tap(find.text('Barzinho'));
    await tester.pumpAndSettle();

    expect(find.byType(ListTile), findsNothing);
    expect(find.text('Chitãozinho & Xororó · Tom A'), findsOneWidget);
    expect(find.byTooltip('Editar'), findsNothing);
    expect(find.byTooltip('Remover'), findsNWidgets(2));

    await tester.tap(find.text('Evidências'));
    await tester.pumpAndSettle();
    expect(find.text('Editar música'), findsOneWidget);
    expect(find.widgetWithText(CampoTexto, 'Música'), findsOneWidget);
    expect(find.widgetWithText(CampoTexto, 'Artista'), findsOneWidget);
    expect(find.widgetWithText(CampoTexto, 'Tom preferido'), findsOneWidget);
    await tester.tap(find.byTooltip('Fechar'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Mais opções'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Excluir repertório'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Excluir'));
    await tester.pumpAndSettle();

    expect(requisicoes.where((r) => r.method == 'DELETE'), hasLength(1));
    expect(find.text('Meus repertórios'), findsOneWidget);
  });

  testWidgets('menu do repertório permite renomear com o nome atual preenchido',
      (tester) async {
    var nomeAtual = 'Barzinho';
    final requisicoes = <http.Request>[];
    final cliente = MockClient((requisicao) async {
      requisicoes.add(requisicao);
      if (requisicao.method == 'PUT') {
        nomeAtual = (jsonDecode(requisicao.body) as Map)['nome'] as String;
      }
      final json = _repertoriosJson.replaceFirst('Barzinho', nomeAtual);
      final corpo = requisicao.method == 'PUT'
          ? jsonEncode((jsonDecode(json) as List).single)
          : json;
      return http.Response(corpo, 200,
          headers: {'content-type': 'application/json; charset=utf-8'});
    });
    await tester.pumpWidget(MaterialApp(
      home: GerenciarRepertorios(
        api: ApiTocaEssa(cliente: cliente, enderecoBase: 'http://teste'),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Barzinho'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Mais opções'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Renomear repertório'));
    await tester.pumpAndSettle();
    final campoNome = find.descendant(
      of: find.widgetWithText(CampoTexto, 'Nome do repertório'),
      matching: find.byType(TextField),
    );
    expect(tester.widget<TextField>(campoNome).controller!.text, 'Barzinho');
    await tester.enterText(campoNome, 'Casamento');
    await tester.tap(find.widgetWithText(TextButton, 'Salvar'));
    await tester.pumpAndSettle();

    final renomear = requisicoes.singleWhere((r) => r.method == 'PUT');
    expect(renomear.url.path, '/api/artista/repertorios/r1');
    expect(jsonDecode(renomear.body), {'nome': 'Casamento'});
    expect(find.text('Casamento'), findsOneWidget);
    expect(find.text('Evidências'), findsOneWidget);

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.text('Meus repertórios'), findsOneWidget);
    expect(find.text('Casamento'), findsOneWidget);
  });

  testWidgets('segurar e arrastar a música salva a nova ordem do repertório',
      (tester) async {
    final requisicoes = await _abrirRepertorio(tester);
    expect(_titulosNaTela(tester), ['Evidências', 'Sozinho', 'Trem-Bala']);

    await _segurarEArrastar(tester, find.text('Trem-Bala'),
        tester.getCenter(find.text('Evidências')) -
            tester.getCenter(find.text('Trem-Bala')) -
            const Offset(0, 20));

    expect(_titulosNaTela(tester), ['Trem-Bala', 'Evidências', 'Sozinho']);
    final ordem = requisicoes.singleWhere((r) => r.method == 'PUT');
    expect(ordem.url.path, '/api/artista/repertorios/r1/musicas/ordem');
    expect(jsonDecode(ordem.body), {
      'musicaIds': ['m3', 'm1', 'm2']
    });
  });

  testWidgets('alça de arrastar move a música sem precisar segurar',
      (tester) async {
    final requisicoes = await _abrirRepertorio(tester);

    await tester.drag(find.byTooltip('Arrastar para reordenar').first,
        const Offset(0, 300));
    await tester.pumpAndSettle();

    expect(_titulosNaTela(tester).last, 'Evidências');
    expect(jsonDecode(requisicoes.singleWhere((r) => r.method == 'PUT').body),
        {
          'musicaIds': ['m2', 'm3', 'm1']
        });
  });

  testWidgets('se o servidor recusar a ordem, a lista volta como estava',
      (tester) async {
    await _abrirRepertorio(tester, falharOrdem: true);

    await tester.drag(find.byTooltip('Arrastar para reordenar').first,
        const Offset(0, 300));
    await tester.pumpAndSettle();

    expect(_titulosNaTela(tester), ['Evidências', 'Sozinho', 'Trem-Bala']);
    expect(find.text('O repertório mudou. Atualize a página e tente de novo.'),
        findsOneWidget);
  });
}

Future<List<http.Request>> _abrirRepertorio(WidgetTester tester,
    {bool falharOrdem = false}) async {
  final requisicoes = <http.Request>[];
  final cliente = MockClient((requisicao) async {
    requisicoes.add(requisicao);
    if (requisicao.method == 'PUT' &&
        requisicao.url.path.endsWith('/musicas/ordem')) {
      if (falharOrdem) {
        return http.Response(
            '{"mensagem":"O repertório mudou. Atualize a página e tente de novo."}',
            400,
            headers: {'content-type': 'application/json; charset=utf-8'});
      }
      final ids = (jsonDecode(requisicao.body)['musicaIds'] as List).cast<String>();
      final musicas = {
        'm1': '{"id":"m1","repertorioId":"r1","titulo":"Evidências","artista":"Chitãozinho & Xororó","tom":"A","ordem":%o}',
        'm2': '{"id":"m2","repertorioId":"r1","titulo":"Sozinho","artista":null,"tom":null,"ordem":%o}',
        'm3': '{"id":"m3","repertorioId":"r1","titulo":"Trem-Bala","artista":null,"tom":null,"ordem":%o}',
      };
      final corpo = [
        for (final (indice, id) in ids.indexed)
          musicas[id]!.replaceFirst('%o', '${indice + 1}')
      ].join(',');
      return http.Response(
          '{"id":"r1","artistaId":"a1","nome":"Barzinho","musicas":[$corpo]}', 200,
          headers: {'content-type': 'application/json; charset=utf-8'});
    }
    return http.Response(_repertorioComTresJson, 200,
        headers: {'content-type': 'application/json; charset=utf-8'});
  });
  await tester.pumpWidget(MaterialApp(
    home: GerenciarRepertorios(
      api: ApiTocaEssa(cliente: cliente, enderecoBase: 'http://teste'),
    ),
  ));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Barzinho'));
  await tester.pumpAndSettle();
  return requisicoes;
}

const _repertorioComTresJson =
    '[{"id":"r1","artistaId":"a1","nome":"Barzinho","musicas":['
    '{"id":"m1","repertorioId":"r1","titulo":"Evidências","artista":"Chitãozinho & Xororó","tom":"A","ordem":1},'
    '{"id":"m2","repertorioId":"r1","titulo":"Sozinho","artista":null,"tom":null,"ordem":2},'
    '{"id":"m3","repertorioId":"r1","titulo":"Trem-Bala","artista":null,"tom":null,"ordem":3}'
    ']}]';

List<String> _titulosNaTela(WidgetTester tester) {
  final titulos = ['Evidências', 'Sozinho', 'Trem-Bala'];
  return titulos.toList()
    ..sort((a, b) => tester
        .getTopLeft(find.text(a))
        .dy
        .compareTo(tester.getTopLeft(find.text(b)).dy));
}

Future<void> _segurarEArrastar(
    WidgetTester tester, Finder alvo, Offset deslocamento) async {
  final gesto = await tester.startGesture(tester.getCenter(alvo));
  await tester.pump(kLongPressTimeout + const Duration(milliseconds: 100));
  for (var passo = 0; passo < 10; passo++) {
    await gesto.moveBy(deslocamento / 10);
    await tester.pump(const Duration(milliseconds: 16));
  }
  await gesto.up();
  await tester.pumpAndSettle();
}
