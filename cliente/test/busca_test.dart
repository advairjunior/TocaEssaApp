import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:toca_essa_app/dominio/modelos.dart';
import 'package:toca_essa_app/telas/componentes.dart';

void main() {
  group('combinaComBusca', () {
    test('ignora acento, maiúscula e espaços', () {
      expect(combinaComBusca('  EVIDENCIAS ', ['Evidências', null]), isTrue);
      expect(combinaComBusca('cancao', ['Canção 2']), isTrue);
    });

    test('procura em qualquer um dos campos, inclusive juntos', () {
      expect(combinaComBusca('xororo', ['Evidências', 'Chitãozinho & Xororó']),
          isTrue);
      expect(
          combinaComBusca(
              'evidencias chitaozinho', ['Evidências', 'Chitãozinho & Xororó']),
          isTrue);
      expect(combinaComBusca('garcom', ['Evidências', null]), isFalse);
    });

    test('busca vazia combina com tudo', () {
      expect(combinaComBusca('   ', ['Evidências']), isTrue);
    });
  });

  testWidgets('CampoDeBusca mostra o X só com texto e limpa', (tester) async {
    final controlador = TextEditingController();
    final mudancas = <String>[];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: CampoDeBusca(
          controlador: controlador,
          dica: 'Buscar música',
          aoMudar: mudancas.add,
        ),
      ),
    ));

    expect(find.widgetWithText(TextField, 'Buscar música'), findsOneWidget);
    expect(find.byTooltip('Limpar busca'), findsNothing);

    await tester.enterText(find.byType(TextField), 'evid');
    await tester.pump();
    expect(find.byTooltip('Limpar busca'), findsOneWidget);

    await tester.tap(find.byTooltip('Limpar busca'));
    await tester.pump();
    expect(controlador.text, '');
    expect(mudancas, ['evid', '']);
    expect(find.byTooltip('Limpar busca'), findsNothing);
  });
}
