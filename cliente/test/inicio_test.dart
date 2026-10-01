import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:toca_essa_app/infraestrutura/api_toca_essa.dart';
import 'package:toca_essa_app/main.dart';
import 'package:toca_essa_app/telas/componentes_formulario.dart';

final _campoCodigo = find.descendant(
  of: find.byType(CampoCodigo),
  matching: find.byType(EditableText),
);

Future<List<String>> _abrirInicio(WidgetTester tester) async {
  final consultas = <String>[];
  final cliente = MockClient((requisicao) async {
    consultas.add(requisicao.url.path);
    return http.Response('{"mensagem":"Não encontrado."}', 404);
  });
  await tester.pumpWidget(TocaEssaApp(
    api: ApiTocaEssa(cliente: cliente, enderecoBase: 'http://teste'),
  ));
  await tester.pumpAndSettle();
  return consultas;
}

bool _podeEntrar(WidgetTester tester) => tester
    .widget<FilledButton>(find.widgetWithText(FilledButton, 'Entrar'))
    .enabled;

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('código completo entra sozinho na apresentação', (tester) async {
    final consultas = await _abrirInicio(tester);

    await tester.enterText(_campoCodigo, 'a1b2c3');
    await tester.pumpAndSettle();

    expect(consultas, contains('/api/publico/apresentacoes/A1B2C3'));
  });

  testWidgets('código aceita só letras e números em maiúsculas',
      (tester) async {
    await _abrirInicio(tester);

    await tester.enterText(_campoCodigo, 'a-1 b');
    await tester.pump();

    final campo = tester.widget<EditableText>(_campoCodigo);
    expect(campo.controller.text, 'A1B');
    expect(find.text('A'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    expect(_podeEntrar(tester), isFalse);
  });

  testWidgets('início tem links discretos para artista e resenhas',
      (tester) async {
    await _abrirInicio(tester);

    expect(find.text('Sou artista'), findsOneWidget);
    expect(find.text('Ver minhas resenhas'), findsOneWidget);
    expect(find.text('Código da apresentação'), findsOneWidget);
    expect(find.text('Feito por Advair'), findsOneWidget);
  });

  testWidgets('início cabe em celular de 360px', (tester) async {
    addTearDown(tester.view.reset);
    tester.view.devicePixelRatio = 3;
    tester.view.physicalSize = const Size(360, 740) * 3;
    await _abrirInicio(tester);

    expect(tester.takeException(), isNull);
  });
}
