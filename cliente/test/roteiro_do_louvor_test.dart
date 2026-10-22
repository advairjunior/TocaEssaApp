import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:toca_essa_app/infraestrutura/api_toca_essa.dart';
import 'package:toca_essa_app/main.dart';
import 'package:toca_essa_app/telas/area_do_publico.dart';
import 'package:toca_essa_app/telas/roteiro_do_louvor.dart';
import 'package:toca_essa_app/telas/trechos_do_louvor.dart';
import 'package:toca_essa_app/tema/tema_toca_essa.dart';

Map<String, Object?> _parte(String tipo, String texto, List<String> cantores) =>
    {
      'tipo': tipo,
      'texto': texto,
      'cantores': cantores,
      'definida': false,
    };

Map<String, Object?> _hino(String id, String titulo,
        {String? tom,
        bool tocado = false,
        List<Map<String, Object?>>? partes}) =>
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

final _segundo =
    _hino('h2', '234 · O meu ser entrego a Cristo', tom: 'A', partes: [
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

Future<void> _abrir(WidgetTester tester, {String? hinoInicial}) async {
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
    home: RoteiroDoLouvorTela(
        api: api, codigo: 'ABC123', hinoInicial: hinoInicial),
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
    await tester.tap(find.widgetWithText(OutlinedButton, 'Ana'));
    await tester.pumpAndSettle();

    expect(find.text('Quem é você?'), findsNothing);
    expect(find.text('80 · Por Cristo, resgatado'), findsOneWidget);
    expect(find.text('Tom G'), findsOneWidget);
    expect(find.text('Suas partes: Estrofe 2'), findsOneWidget);
    expect(find.text('JOÃO'), findsOneWidget);
    expect(find.text('ANA · SUA VEZ'), findsOneWidget);
    expect(find.text('TODOS'), findsNWidgets(4));
    expect(find.text('Cristo Jesus, o santo Cordeiro'), findsOneWidget);

    final preferencias = await SharedPreferences.getInstance();
    expect(preferencias.getString('louvor_quem_sou_ABC123'), 'Ana');
  });
  group('link compartilhado de um hino', () {
    testWidgets('pergunta quem é e abre nesse hino, com os acordes',
        (tester) async {
      _noServidor = _roteiro(atual: 'h1');
      await _abrir(tester, hinoInicial: 'h2');

      expect(find.text('Quem é você?'), findsOneWidget);
      await tester.tap(find.widgetWithText(OutlinedButton, 'Ana'));
      await tester.pumpAndSettle();

      expect(find.text('234 · O meu ser entrego a Cristo'), findsOneWidget);
      expect(find.text('Primeira do segundo'), findsOneWidget);
      // Quem recebe o link quer ver a cifra: os acordes já vêm ligados.
      expect(find.byTooltip('Esconder acordes'), findsOneWidget);
    });

    testWidgets('quem já escolheu esconder os acordes continua sem',
        (tester) async {
      SharedPreferences.setMockInitialValues({
        'louvor_quem_sou_ABC123': 'Ana',
        'louvor_acordes': false,
      });
      await _abrir(tester, hinoInicial: 'h2');

      expect(find.text('234 · O meu ser entrego a Cristo'), findsOneWidget);
      expect(find.byTooltip('Mostrar acordes'), findsOneWidget);
    });
  });

  testWidgets('acordes aparecem só para quem pede e mudam de tom',
      (tester) async {
    SharedPreferences.setMockInitialValues({'louvor_quem_sou_ABC123': ''});
    await _abrir(tester);

    expect(find.text('Cristo Jesus, o santo Cordeiro'), findsOneWidget);
    expect(find.text('G        Bm'), findsNothing);
    expect(find.byTooltip('Subir meio tom'), findsNothing);
    // Fica no topo, sem ocupar a letra de quem só canta.
    expect(find.widgetWithText(FilterChip, 'Acordes'), findsNothing);

    await tester.tap(find.byTooltip('Mostrar acordes'));
    await tester.pumpAndSettle();
    expect(find.text('G        Bm'), findsOneWidget);
    expect(find.byTooltip('Esconder acordes'), findsOneWidget);
    // Bemol e sustenido como na cifra (Bb, C#): não parece tamanho da letra.
    expect(find.text('b'), findsOneWidget);
    expect(find.text('#'), findsOneWidget);
    expect(find.byIcon(Icons.add_rounded), findsNothing);
    expect(find.byTooltip('Voltar ao tom original'), findsNothing);

    await tester.tap(find.byTooltip('Subir meio tom'));
    await tester.tap(find.byTooltip('Subir meio tom'));
    await tester.pumpAndSettle();
    expect(find.text('A        C#m'), findsOneWidget);
    expect(find.text('Tom A (+2)'), findsOneWidget);

    await tester.tap(find.byTooltip('Voltar ao tom original'));
    await tester.pumpAndSettle();
    expect(find.text('Tom G'), findsOneWidget);
    expect(find.text('G        Bm'), findsOneWidget);

    await tester.tap(find.byTooltip('Subir meio tom'));
    await tester.tap(find.byTooltip('Subir meio tom'));
    await tester.pumpAndSettle();

    final preferencias = await SharedPreferences.getInstance();
    expect(preferencias.getBool('louvor_acordes'), isTrue);
  });

  testWidgets('a parte antes da sua avisa que você é o próximo',
      (tester) async {
    SharedPreferences.setMockInitialValues({'louvor_quem_sou_ABC123': 'Ana'});
    await _abrir(tester);

    expect(find.text('você é o próximo'), findsOneWidget);
  });

  testWidgets('quem só toca solos também está no Quem é você', (tester) async {
    await _abrir(tester);

    expect(find.widgetWithText(OutlinedButton, 'José'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Ana'), findsOneWidget);
  });

  testWidgets('cada pessoa aparece na cor da sua faixa', (tester) async {
    await _abrir(tester);
    Color? cor(String nome) => tester
        .widget<Text>(find.descendant(
            of: find.byType(OutlinedButton), matching: find.text(nome)))
        .style
        ?.color;

    expect(cor('João'), corDoCantor(['João', 'Ana'], 'João'));
    expect(cor('Ana'), corDoCantor(['João', 'Ana'], 'Ana'));
    // Quem só toca tem cor própria, não o amarelo dos solos.
    expect(cor('José'), corDaPessoa(['João', 'Ana', 'José'], 'José'));
  });

  testWidgets('a barra de baixo avisa sua vez no próximo hino', (tester) async {
    SharedPreferences.setMockInitialValues({'louvor_quem_sou_ABC123': 'Ana'});
    _noServidor = _roteiro(atual: 'h1');
    await _abrir(tester);

    expect(
        find.text('Depois: 234 · O meu ser entrego a Cristo'), findsOneWidget);
    expect(find.text('sua vez: Estrofe 1'), findsOneWidget);

    await tester.tap(find.byTooltip('Trocar quem sou eu'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OutlinedButton, 'João'));
    await tester.pumpAndSettle();

    expect(find.textContaining('sua vez:'), findsNothing);
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
    expect(find.textContaining('Suas partes'), findsNothing);
  });

  testWidgets('abre no hino atual e segue quando o hino muda', (tester) async {
    SharedPreferences.setMockInitialValues({'louvor_quem_sou_ABC123': 'Ana'});
    _noServidor = _roteiro(atual: 'h1');
    await _abrir(tester);

    expect(find.text('80 · Por Cristo, resgatado'), findsOneWidget);
    expect(find.text('Agora'), findsOneWidget);
    // "Agora" fica na linha do título, longe do controle do tom.
    expect(
        find.descendant(
            of: find.byKey(const ValueKey('titulo-do-hino')),
            matching: find.text('Agora')),
        findsOneWidget);
    // Ao abrir não há aviso: só quando o hino muda.
    expect(find.textContaining('Agora: '), findsNothing);

    _noServidor = _roteiro(atual: 'h2');
    await tester.pump(const Duration(seconds: 16));
    await tester.pumpAndSettle();

    expect(
        find.text('Agora: 234 · O meu ser entrego a Cristo'), findsOneWidget);
    expect(find.text('234 · O meu ser entrego a Cristo'), findsOneWidget);
    expect(find.text('Tom A'), findsOneWidget);
    expect(find.text('Agora'), findsOneWidget);
  });

  group('meus hinos', () {
    Finder naFolha(String texto) => find.descendant(
        of: find.byType(BottomSheet), matching: find.text(texto));

    testWidgets('mostra só os hinos da pessoa, com as partes dela',
        (tester) async {
      SharedPreferences.setMockInitialValues({'louvor_quem_sou_ABC123': 'Ana'});
      await _abrir(tester);

      await tester.tap(find.byTooltip('Meus hinos'));
      await tester.pumpAndSettle();

      expect(naFolha('Hinos de Ana'), findsOneWidget);
      expect(naFolha('2 partes em 2 hinos'), findsOneWidget);
      expect(naFolha('80 · Por Cristo, resgatado'), findsOneWidget);
      expect(naFolha('Estrofe 2 · Tom G'), findsOneWidget);
      expect(naFolha('234 · O meu ser entrego a Cristo'), findsOneWidget);
      expect(naFolha('15 · Hino sem letra'), findsNothing);

      await tester.tap(naFolha('234 · O meu ser entrego a Cristo'));
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsNothing);
      expect(find.text('Primeira do segundo'), findsOneWidget);
    });

    testWidgets('quem só toca vê os solos dele', (tester) async {
      SharedPreferences.setMockInitialValues(
          {'louvor_quem_sou_ABC123': 'José'});
      _noServidor = {
        ..._roteiro(),
        'hinos': [
          _hino('h1', '80 · Por Cristo, resgatado', partes: [
            _parte('Estrofe', 'Cristo Jesus', ['João']),
            {
              ..._parte('Instrumental', '', ['José']),
              'nome': 'Solo sax'
            },
          ]),
        ],
      };
      await _abrir(tester);

      await tester.tap(find.byTooltip('Meus hinos'));
      await tester.pumpAndSettle();

      expect(naFolha('1 parte em 1 hino'), findsOneWidget);
      expect(naFolha('Solo sax'), findsOneWidget);
    });

    testWidgets('sem parte própria, faz parte do coral', (tester) async {
      SharedPreferences.setMockInitialValues(
          {'louvor_quem_sou_ABC123': 'José'});
      await _abrir(tester);

      await tester.tap(find.byTooltip('Meus hinos'));
      await tester.pumpAndSettle();

      expect(naFolha('José faz parte do coral'), findsOneWidget);
      expect(naFolha('Canta junto nas partes de Todos, em todos os hinos.'),
          findsOneWidget);
    });

    testWidgets('quem só acompanha não tem a opção', (tester) async {
      SharedPreferences.setMockInitialValues({'louvor_quem_sou_ABC123': ''});
      await _abrir(tester);

      expect(find.byTooltip('Meus hinos'), findsNothing);
    });
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
    expect(
        find.text('A letra deste hino ainda não foi colada.'), findsOneWidget);
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

  testWidgets('o link com ?hino= abre o roteiro nesse hino', (tester) async {
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
    tester.binding.platformDispatcher.defaultRouteNameTestValue =
        '/publico/ABC123?hino=h2';
    addTearDown(
        tester.binding.platformDispatcher.clearDefaultRouteNameTestValue);

    await tester.pumpWidget(TocaEssaApp(api: api));
    await tester.pumpAndSettle();

    expect(find.text('234 · O meu ser entrego a Cristo'), findsOneWidget);
    expect(find.text('Primeira do segundo'), findsOneWidget);
  });
}
