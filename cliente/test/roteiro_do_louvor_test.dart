import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:toca_essa_app/infraestrutura/api_toca_essa.dart';
import 'package:toca_essa_app/telas/area_do_publico.dart';
import 'package:toca_essa_app/telas/roteiro_do_louvor.dart';
import 'package:toca_essa_app/tema/tema_toca_essa.dart';

Map<String, Object?> _parte(String tipo, String texto, List<String> cantores) =>
    {
      'tipo': tipo,
      'texto': texto,
      'cantores': cantores,
      'definida': false,
    };

Map<String, Object?> _hino(String id, String titulo,
        {String? tom, bool tocado = false, List<Map<String, Object?>>? partes}) =>
    {
      'itemId': id,
      'titulo': titulo,
      'tom': tom,
      'tocado': tocado,
      'temLetra': partes != null,
      'partes': partes ?? <Object?>[],
    };

final _porCristo = _hino('h1', '80 · Por Cristo, resgatado', tom: 'G', partes: [
  _parte('Estrofe', 'G        Bm\nCristo Jesus, o santo Cordeiro', ['João']),
  _parte('Refrao', 'Por Cristo, resgatado', []),
  _parte('Estrofe', 'Preso estava na iniquidade', ['Ana']),
  _parte('Refrao', 'Por Cristo, resgatado', []),
  _parte('Estrofe', 'Tem minha alma grande alegria', []),
  _parte('Refrao', 'Por Cristo, resgatado', []),
]);

final _segundo = _hino('h2', '234 · O meu ser entrego a Cristo', tom: 'A',
    partes: [
      _parte('Estrofe', 'Primeira do segundo', ['Ana']),
      _parte('Estrofe', 'Última do segundo', []),
    ]);

final _semLetra = _hino('h3', '15 · Hino sem letra');

Map<String, Object?> _roteiro({String? atual}) => {
      'nome': 'Louvor de sábado',
      'cantores': ['João', 'Ana'],
      'solistas': [
        {'nome': 'José', 'instrumento': 'sax tenor'},
        {'nome': 'Ana', 'instrumento': 'flauta'},
      ],
      'hinoAtualId': atual,
      'hinos': [_porCristo, _segundo, _semLetra],
    };

var _noServidor = _roteiro();

Future<void> _abrir(WidgetTester tester) async {
  final api = ApiTocaEssa(
    enderecoBase: 'http://teste',
    cliente: MockClient((requisicao) async => http.Response(
        jsonEncode(_noServidor), 200,
        headers: {'content-type': 'application/json; charset=utf-8'})),
  );
  tester.view.physicalSize = const Size(430, 932);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    theme: TemaTocaEssa.escuro,
    home: RoteiroDoLouvorTela(api: api, codigo: 'ABC123'),
  ));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    _noServidor = _roteiro();
  });

  testWidgets('pergunta quem é e destaca a vez da pessoa', (tester) async {
    await _abrir(tester);

    expect(find.text('Quem é você?'), findsOneWidget);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Ana'));
    await tester.pumpAndSettle();

    expect(find.text('Quem é você?'), findsNothing);
    expect(find.text('80 · Por Cristo, resgatado'), findsOneWidget);
    expect(find.text('Tom G'), findsOneWidget);
    expect(find.text('Você canta 1 estrofe neste hino'), findsOneWidget);
    expect(find.text('JOÃO'), findsOneWidget);
    expect(find.text('ANA · SUA VEZ'), findsOneWidget);
    expect(find.text('TODOS'), findsNWidgets(4));
    expect(find.text('Cristo Jesus, o santo Cordeiro'), findsOneWidget);

    final preferencias = await SharedPreferences.getInstance();
    expect(preferencias.getString('louvor_quem_sou_ABC123'), 'Ana');
  });
  testWidgets('acordes aparecem só para quem pede e mudam de tom', (tester) async {
    SharedPreferences.setMockInitialValues({'louvor_quem_sou_ABC123': ''});
    await _abrir(tester);

    expect(find.text('Cristo Jesus, o santo Cordeiro'), findsOneWidget);
    expect(find.text('G        Bm'), findsNothing);
    expect(find.byTooltip('Subir meio tom'), findsNothing);

    await tester.tap(find.widgetWithText(FilterChip, 'Acordes'));
    await tester.pumpAndSettle();
    expect(find.text('G        Bm'), findsOneWidget);

    await tester.tap(find.byTooltip('Subir meio tom'));
    await tester.tap(find.byTooltip('Subir meio tom'));
    await tester.pumpAndSettle();
    expect(find.text('A        C#m'), findsOneWidget);
    expect(find.text('Tom A (+2)'), findsOneWidget);

    final preferencias = await SharedPreferences.getInstance();
    expect(preferencias.getBool('louvor_acordes'), isTrue);
  });

  testWidgets('a parte antes da sua avisa que você é o próximo', (tester) async {
    SharedPreferences.setMockInitialValues({'louvor_quem_sou_ABC123': 'Ana'});
    await _abrir(tester);

    expect(find.text('você é o próximo'), findsOneWidget);
  });


  testWidgets('quem só toca solos também está no Quem é você', (tester) async {
    await _abrir(tester);

    expect(find.widgetWithText(ChoiceChip, 'José'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, 'Ana'), findsOneWidget);
  });

  testWidgets('quem já escolheu entra direto e pode trocar', (tester) async {
    SharedPreferences.setMockInitialValues({'louvor_quem_sou_ABC123': 'João'});
    await _abrir(tester);

    expect(find.text('Quem é você?'), findsNothing);
    expect(find.text('JOÃO · SUA VEZ'), findsOneWidget);

    await tester.tap(find.byTooltip('Trocar quem sou eu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Só acompanhar'));
    await tester.pumpAndSettle();

    expect(find.textContaining('SUA VEZ'), findsNothing);
    expect(find.text('JOÃO'), findsOneWidget);
    expect(find.textContaining('Você canta'), findsNothing);
  });

  testWidgets('abre no hino atual e segue quando o hino muda', (tester) async {
    SharedPreferences.setMockInitialValues({'louvor_quem_sou_ABC123': 'Ana'});
    _noServidor = _roteiro(atual: 'h1');
    await _abrir(tester);

    expect(find.text('80 · Por Cristo, resgatado'), findsOneWidget);
    expect(find.text('Agora'), findsOneWidget);

    _noServidor = _roteiro(atual: 'h2');
    await tester.pump(const Duration(seconds: 16));
    await tester.pumpAndSettle();

    expect(find.text('234 · O meu ser entrego a Cristo'), findsOneWidget);
    expect(find.text('Tom A'), findsOneWidget);
    expect(find.text('Agora'), findsOneWidget);
  });

  mainDaEntradaPeloCodigo();

  testWidgets('navega pelos hinos e volta ao atual', (tester) async {
    SharedPreferences.setMockInitialValues({'louvor_quem_sou_ABC123': ''});
    _noServidor = _roteiro(atual: 'h1');
    await _abrir(tester);

    await tester.tap(find.byTooltip('Próximo hino'));
    await tester.pumpAndSettle();
    expect(find.text('234 · O meu ser entrego a Cristo'), findsOneWidget);
    expect(find.text('Agora'), findsNothing);

    await tester.tap(find.text('Voltar ao hino de agora'));
    await tester.pumpAndSettle();
    expect(find.text('80 · Por Cristo, resgatado'), findsOneWidget);

    await tester.tap(find.byTooltip('Lista de hinos'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('15 · Hino sem letra'));
    await tester.pumpAndSettle();
    expect(find.text('A letra deste hino ainda não foi colada.'), findsOneWidget);
  });
}

const _louvorJson =
    '{"id":"22222222-2222-2222-2222-222222222222","nome":"Louvor de sábado","data":"2026-10-24","local":"Casa da Bia","codigo":"ABC123","perfilArtistico":{"id":"11111111-1111-1111-1111-111111111111","nomeArtistico":"Advair","bio":null},"pedidosAbertos":true,"status":"Agendada","tipo":"Louvor"}';

void mainDaEntradaPeloCodigo() {
  testWidgets('quem entra pelo código de um louvor vê o roteiro, sem pedidos',
      (tester) async {
    SharedPreferences.setMockInitialValues({'louvor_quem_sou_ABC123': 'Ana'});
    final api = ApiTocaEssa(
      enderecoBase: 'http://teste',
      cliente: MockClient((requisicao) async {
        final caminho = requisicao.url.path;
        final corpo = caminho.endsWith('/roteiro')
            ? jsonEncode(_roteiro(atual: 'h1'))
            : caminho.endsWith('/fila')
                ? '[]'
                : _louvorJson;
        return http.Response(corpo, 200,
            headers: {'content-type': 'application/json; charset=utf-8'});
      }),
    );
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      theme: TemaTocaEssa.escuro,
      home: AreaDoPublico(api: api, codigoInicial: 'abc123'),
    ));
    await tester.pumpAndSettle();

    expect(find.byType(RoteiroDoLouvorTela), findsOneWidget);
    expect(find.text('ANA · SUA VEZ'), findsOneWidget);
    expect(find.text('Pedir'), findsNothing);
    expect(find.text('Fila'), findsNothing);
  });
}
