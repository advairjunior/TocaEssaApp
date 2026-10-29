import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:toca_essa_app/telas/cifra_do_palco.dart';

// Uma linha de acordes em cima de cada linha de letra: "Linha N" é a linha
// N da letra.
final _cifra = [
  'Tom: G',
  for (var i = 0; i < 40; i++) ...['C        G', 'Linha $i'],
].join('\n');

Future<void> _abrir(WidgetTester tester, {ValueChanged<int>? aoLerALinha}) =>
    tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 400,
          height: 600,
          child: CifraDoPalco(
            trechos: [TrechoDaCifra(texto: _cifra)],
            pagina: 1,
            aoLerALinha: aoLerALinha,
          ),
        ),
      ),
    ));

/// A "Linha N" que está na altura da seta (ou a última acima dela).
int _linhaNaSeta(WidgetTester tester) {
  final alturaDaSeta = tester.getCenter(find.byKey(chaveDaSetaDaTv)).dy;
  var numero = -1;
  for (var i = 0; i < 40; i++) {
    final linha = find.text('Linha $i');
    if (linha.evaluate().isEmpty) continue;
    if (tester.getTopLeft(linha).dy <= alturaDaSeta) numero = i;
  }
  return numero;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('sem a Letra na TV, a cifra não tem seta', (tester) async {
    await _abrir(tester);
    await tester.pumpAndSettle();

    expect(find.byKey(chaveDaSetaDaTv), findsNothing);
  });

  testWidgets('a seta avisa a linha de letra que está passando nela',
      (tester) async {
    final lidas = <int>[];
    await _abrir(tester, aoLerALinha: lidas.add);
    await tester.pumpAndSettle();

    expect(find.byKey(chaveDaSetaDaTv), findsOneWidget);
    expect(lidas.last, _linhaNaSeta(tester));

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -500));
    await tester.pumpAndSettle();

    expect(lidas.last, greaterThan(lidas.first));
    expect(lidas.last, _linhaNaSeta(tester));
  });

  testWidgets('a mesma linha não é avisada duas vezes', (tester) async {
    final lidas = <int>[];
    await _abrir(tester, aoLerALinha: lidas.add);
    await tester.pumpAndSettle();
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -2));
    await tester.pumpAndSettle();

    expect(lidas.toSet().length, lidas.length);
  });
}
