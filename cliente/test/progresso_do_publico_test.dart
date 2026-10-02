import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:toca_essa_app/dominio/modelos.dart';
import 'package:toca_essa_app/telas/progresso_do_publico.dart';

const _dados = EstatisticasDoPublico(
  participacoes: 4,
  pedidos: 10,
  pedidosTocados: 5,
  avaliacoesRealizadas: 5,
  mediaAvaliacoes: 4.5,
  musicasMaisPedidas: [MusicaMaisPedida(musica: 'Evidências', quantidade: 3)],
);

Future<void> _montar(WidgetTester tester) async {
  await tester.pumpWidget(const MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(child: ProgressoDoPublico(dados: _dados)),
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('números do perfil ficam numa faixa única', (tester) async {
    await _montar(tester);

    expect(find.text('pedidos'), findsOneWidget);
    final faixa = find.ancestor(
      of: find.text('pedidos'),
      matching: find.byType(Row),
    );
    for (final rotulo in ['tocados', 'nota média', 'participações']) {
      expect(
        find.descendant(of: faixa.first, matching: find.text(rotulo)),
        findsOneWidget,
        reason: rotulo,
      );
      expect(tester.widget<Text>(find.text(rotulo)).maxLines, 1,
          reason: 'rótulo "$rotulo" não pode quebrar no meio da palavra');
    }
    expect(find.text('4,5'), findsOneWidget);
  });

  testWidgets('contagem de conquistas fica ao lado do título', (tester) async {
    await _montar(tester);

    final contagem = find.textContaining(RegExp(r'^\d+ de \d+$'));
    expect(contagem, findsOneWidget);
    final cabecalho = find.ancestor(
      of: find.text('Conquistas'),
      matching: find.byType(Row),
    );
    expect(find.descendant(of: cabecalho.first, matching: contagem),
        findsOneWidget);
  });

  testWidgets('progresso cabe em celular de 360px', (tester) async {
    addTearDown(tester.view.reset);
    tester.view.devicePixelRatio = 3;
    tester.view.physicalSize = const Size(360, 740) * 3;
    await _montar(tester);

    expect(tester.takeException(), isNull);
  });
}
