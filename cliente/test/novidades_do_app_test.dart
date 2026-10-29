import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:toca_essa_app/dominio/novidades.dart';
import 'package:toca_essa_app/telas/novidades_do_app.dart';
import 'package:toca_essa_app/tema/tema_toca_essa.dart';

final _lista = [
  Novidade(
      data: DateTime(2026, 10, 29),
      tipo: TipoDeNovidade.novo,
      titulo: 'Letra na TV',
      texto: 'A letra deitada na TV da casa.'),
  Novidade(
      data: DateTime(2026, 10, 29),
      tipo: TipoDeNovidade.correcao,
      titulo: 'Link do louvor',
      texto: 'O voltar não leva mais para o início.'),
  Novidade(
      data: DateTime(2026, 10, 21),
      tipo: TipoDeNovidade.melhoria,
      titulo: 'Busca na setlist',
      texto: 'Procure pelo título ou cantor.'),
];

Future<void> _abrir(WidgetTester tester,
    {Map<String, Object> guardado = const {}}) async {
  SharedPreferences.setMockInitialValues(guardado);
  await tester.pumpWidget(MaterialApp(
    theme: TemaTocaEssa.escuro,
    home: Scaffold(
      body: Builder(
        builder: (context) => Column(children: [
          AvisoDeNovidades(novidades: _lista),
          TextButton(
              onPressed: () => abrirNovidades(context, novidades: _lista),
              child: const Text('Menu: Novidades')),
        ]),
      ),
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  test('as novidades do app vêm da mais nova para a mais velha', () {
    expect(novidadesDoApp, isNotEmpty);
    for (var i = 1; i < novidadesDoApp.length; i++) {
      expect(
          novidadesDoApp[i].data.isAfter(novidadesDoApp[i - 1].data), isFalse,
          reason: novidadesDoApp[i].titulo);
    }
    expect(
        novidadesDoApp.every((n) => n.titulo.isNotEmpty && n.texto.isNotEmpty),
        isTrue);
  });

  testWidgets('aviso aparece enquanto há novidade que a pessoa não viu',
      (tester) async {
    await _abrir(tester, guardado: {'novidades_vistas_ate': '2026-10-21'});

    expect(find.textContaining('Novidades no app'), findsOneWidget);
    expect(find.textContaining('2 novas'), findsOneWidget);
  });

  testWidgets('quem já viu tudo não vê o aviso', (tester) async {
    await _abrir(tester, guardado: {'novidades_vistas_ate': '2026-10-29'});

    expect(find.textContaining('Novidades no app'), findsNothing);
  });

  testWidgets('abrir mostra cada novidade com a data e o tipo, e some o aviso',
      (tester) async {
    await _abrir(tester);

    await tester.tap(find.textContaining('Novidades no app'));
    await tester.pumpAndSettle();

    expect(find.text('Letra na TV'), findsOneWidget);
    expect(find.text('A letra deitada na TV da casa.'), findsOneWidget);
    expect(find.text('Correção'), findsOneWidget);
    expect(find.text('Melhoria'), findsOneWidget);
    expect(find.text('29/10/2026'), findsOneWidget);
    expect(find.text('21/10/2026'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.textContaining('Novidades no app'), findsNothing);
    expect(
        (await SharedPreferences.getInstance())
            .getString('novidades_vistas_ate'),
        '2026-10-29');
  });

  testWidgets('pelo menu também abre, mesmo sem novidade nova', (tester) async {
    await _abrir(tester, guardado: {'novidades_vistas_ate': '2026-10-29'});

    await tester.tap(find.text('Menu: Novidades'));
    await tester.pumpAndSettle();

    expect(find.byType(NovidadesDoApp), findsOneWidget);
  });
}
