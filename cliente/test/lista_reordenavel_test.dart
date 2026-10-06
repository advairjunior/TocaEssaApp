import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:toca_essa_app/telas/lista_reordenavel.dart';

const _nomes = ['Evidências', 'Sozinho', 'Trem-Bala', 'Garçom'];

Future<List<(int, int)>> _montar(
  WidgetTester tester, {
  bool segurarParaArrastar = false,
  bool habilitada = true,
  ScrollController? rolagem,
}) async {
  final movimentos = <(int, int)>[];
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        controller: rolagem,
        child: Column(
          children: [
            const SizedBox(height: 100),
            ListaReordenavel(
              quantidade: _nomes.length,
              chaveDoItem: (indice) => ValueKey(_nomes[indice]),
              segurarParaArrastar: segurarParaArrastar,
              habilitada: habilitada,
              aoReordenar: (de, para) => movimentos.add((de, para)),
              construirItem: (context, indice, alca) => SizedBox(
                height: 64,
                child: Row(
                  children: [
                    Expanded(child: Text(_nomes[indice])),
                    alca(const Icon(Icons.drag_indicator_rounded)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 1200),
          ],
        ),
      ),
    ),
  ));
  await tester.pumpAndSettle();
  return movimentos;
}

Finder _alca(int indice) =>
    find.bySemanticsLabel('Arrastar para reordenar').at(indice);

void main() {
  testWidgets('arrastar a alça para baixo move a música', (tester) async {
    final movimentos = await _montar(tester);

    await tester.drag(_alca(0), const Offset(0, 140));
    await tester.pumpAndSettle();

    expect(movimentos, [(0, 2)]);
  }, variant: _plataformas);

  testWidgets('arrastar a alça para cima move a música', (tester) async {
    final movimentos = await _montar(tester);

    await tester.drag(_alca(3), const Offset(0, -200));
    await tester.pumpAndSettle();

    expect(movimentos, [(3, 0)]);
  }, variant: _plataformas);

  testWidgets('dentro de uma tela que rola, a alça move o item e não a página',
      (tester) async {
    final rolagem = ScrollController();
    final movimentos = await _montar(tester, rolagem: rolagem);

    await tester.drag(_alca(0), const Offset(0, 80));
    await tester.pumpAndSettle();

    expect(movimentos, [(0, 1)]);
    expect(rolagem.offset, 0);
  }, variant: _plataformas);

  testWidgets('soltar no mesmo lugar não reordena', (tester) async {
    final movimentos = await _montar(tester);

    await tester.drag(_alca(1), const Offset(0, 20));
    await tester.pumpAndSettle();

    expect(movimentos, isEmpty);
  });

  testWidgets('segurar a linha e arrastar move a música', (tester) async {
    final movimentos = await _montar(tester, segurarParaArrastar: true);

    final gesto =
        await tester.startGesture(tester.getCenter(find.text('Garçom')));
    await tester.pump(const Duration(milliseconds: 600));
    await gesto.moveBy(const Offset(0, -70));
    await tester.pump();
    await gesto.moveBy(const Offset(0, -70));
    await tester.pump();
    await gesto.up();
    await tester.pumpAndSettle();

    expect(movimentos, [(3, 1)]);
  }, variant: _plataformas);

  testWidgets('tocar na alça oferece mover sem precisar arrastar',
      (tester) async {
    final movimentos = await _montar(tester);

    await tester.tap(_alca(1));
    await tester.pumpAndSettle();
    expect(find.text('Mover para o topo'), findsOneWidget);
    expect(find.text('Mover para cima'), findsOneWidget);
    expect(find.text('Mover para baixo'), findsOneWidget);
    await tester.tap(find.text('Mover para baixo'));
    await tester.pumpAndSettle();

    await tester.tap(_alca(0));
    await tester.pumpAndSettle();
    expect(find.text('Mover para cima'), findsNothing);
    expect(find.text('Mover para o topo'), findsNothing);
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();

    await tester.tap(_alca(3));
    await tester.pumpAndSettle();
    expect(find.text('Mover para baixo'), findsNothing);
    await tester.tap(find.text('Mover para o topo'));
    await tester.pumpAndSettle();

    expect(movimentos, [(1, 2), (3, 0)]);
  }, variant: _plataformas);

  testWidgets('desabilitada enquanto salva não move nada', (tester) async {
    final movimentos = await _montar(tester, habilitada: false);

    await tester.drag(_alca(0), const Offset(0, 140));
    await tester.tap(_alca(0));
    await tester.pumpAndSettle();

    expect(movimentos, isEmpty);
    expect(find.text('Mover para baixo'), findsNothing);
  });
}

// No Safari do iPhone o Flutter web se apresenta como iOS.
final _plataformas =
    TargetPlatformVariant({TargetPlatform.iOS, TargetPlatform.android});
