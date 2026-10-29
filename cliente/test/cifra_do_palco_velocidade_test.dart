import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:toca_essa_app/telas/cifra_do_palco.dart';

final _cifra = [for (var i = 0; i < 60; i++) 'Linha $i'].join('\n');

Widget _cifraDa(String musica) => MaterialApp(
      home: Scaffold(
        body: CifraDoPalco(
          trechos: [TrechoDaCifra(texto: _cifra)],
          pagina: musica,
          chaveDaVelocidade: musica,
        ),
      ),
    );

Future<void> _mostrarControle(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Rolar automaticamente'));
  await tester.pump();
}

void main() {
  testWidgets('a música abre na velocidade que ficou nela', (tester) async {
    SharedPreferences.setMockInitialValues({
      'leitor_velocidade_vezes': 1.0,
      'leitor_velocidade_vezes|fim de tarde': 3.0,
    });

    await tester.pumpWidget(_cifraDa('fim de tarde'));
    await tester.pumpAndSettle();
    await _mostrarControle(tester);

    expect(find.text('3x'), findsOneWidget);
  });

  testWidgets('música nunca rolada começa na última velocidade usada',
      (tester) async {
    SharedPreferences.setMockInitialValues({'leitor_velocidade_vezes': 2.0});

    await tester.pumpWidget(_cifraDa('lua'));
    await tester.pumpAndSettle();
    await _mostrarControle(tester);

    expect(find.text('2x'), findsOneWidget);
  });

  testWidgets('mudar a velocidade guarda nela e trocar de música lê a outra',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'leitor_velocidade_vezes|lua': 0.5,
    });
    await tester.pumpWidget(_cifraDa('fim de tarde'));
    await tester.pumpAndSettle();
    await _mostrarControle(tester);

    await tester.tap(find.byTooltip('Mais rápido'));
    await tester.pump();
    final preferencias = await SharedPreferences.getInstance();
    expect(preferencias.getDouble('leitor_velocidade_vezes|fim de tarde'), 2);
    expect(preferencias.getDouble('leitor_velocidade_vezes'), 2);

    await tester.tap(find.byTooltip('Pausar rolagem'));
    await tester.pumpWidget(_cifraDa('lua'));
    await tester.pumpAndSettle();
    await _mostrarControle(tester);
    expect(find.text('0,5x'), findsOneWidget);
  });
}
