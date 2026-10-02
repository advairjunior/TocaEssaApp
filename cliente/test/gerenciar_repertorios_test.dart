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
}
