import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:toca_essa_app/tema/tema_toca_essa.dart';

void main() {
  test('barra de progresso vazia não se confunde com a cheia', () {
    final tema = TemaTocaEssa.escuro.progressIndicatorTheme;

    expect(tema.linearTrackColor, isNotNull);
    expect(tema.linearTrackColor, isNot(tema.color));
    expect(tema.linearTrackColor, CoresTocaEssa.borda);
  });

  testWidgets('barra em 0% mostra só o trilho', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: TemaTocaEssa.escuro,
      home: const Scaffold(body: LinearProgressIndicator(value: 0)),
    ));

    final barra = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator));
    expect(barra.value, 0);
    expect(
      Theme.of(tester.element(find.byType(LinearProgressIndicator)))
          .progressIndicatorTheme
          .linearTrackColor,
      CoresTocaEssa.borda,
    );
  });
}
