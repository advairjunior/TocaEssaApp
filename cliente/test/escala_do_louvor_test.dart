import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:toca_essa_app/dominio/modelos.dart';
import 'package:toca_essa_app/infraestrutura/api_toca_essa.dart';
import 'package:toca_essa_app/telas/escala_do_louvor.dart';
import 'package:toca_essa_app/telas/trechos_do_louvor.dart';
import 'package:toca_essa_app/tema/tema_toca_essa.dart';

const _id = '22222222-2222-2222-2222-222222222222';

final _apresentacao = Apresentacao.deJson(jsonDecode(
        '{"id":"$_id","nome":"Louvor de sábado","data":"2026-10-24","local":"Casa da Bia","codigo":"ABC123","perfilArtistico":{"id":"11111111-1111-1111-1111-111111111111","nomeArtistico":"Advair","bio":null},"pedidosAbertos":true,"status":"Agendada","tipo":"Louvor"}')
    as Map<String, dynamic>);

Map<String, Object?> _parte(String tipo, String texto, List<String> cantores,
        {bool definida = true}) =>
    {
      'tipo': tipo,
      'texto': texto,
      'cantores': cantores,
      'definida': definida,
    };

Map<String, Object?> _louvor(List<String> cantores,
        [List<Map<String, Object?>> solistas = const [],
        Set<String> tocados = const {},
        bool comTerceiroHino = false]) =>
    {
      'cantores': cantores,
      'solistas': solistas,
      'placarDosSolos': [
        for (final solista in solistas) {'nome': solista['nome'], 'solos': 1},
      ],
      'placar': [
        for (final nome in cantores) {'nome': nome, 'pontos': 1},
      ],
      'hinos': [
        {
          'itemId': 'h1',
          'titulo': '80 · Por Cristo, resgatado',
          'artista': null,
          'tom': 'G',
          'tocado': tocados.contains('h1'),
          'temLetra': true,
          'partes': [
            _parte(
                'Estrofe',
                'G        Bm\nCristo Jesus, o santo Cordeiro\nDeu Sua vida',
                ['João']),
            _parte('Refrao', 'Por Cristo, resgatado', []),
            _parte('Estrofe', 'Preso estava na iniquidade', ['Ana'],
                definida: true),
            _parte('Refrao', 'Por Cristo, resgatado', []),
            {
              'tipo': 'Instrumental',
              'texto': 'G   D',
              'cantores': <String>[],
              'definida': false,
              'nome': 'Solo sax tenor',
              'vezes': 2,
            },
          ],
        },
        {
          'itemId': 'h2',
          'titulo': '234 · O meu ser entrego a Cristo',
          'artista': 'CCB',
          'tom': null,
          'tocado': tocados.contains('h2'),
          'temLetra': false,
          'partes': <Object?>[],
        },
        if (comTerceiroHino)
          {
            'itemId': 'h3',
            'titulo': '12 · Hino de louvor',
            'artista': null,
            'tom': 'D',
            'tocado': false,
            'temLetra': true,
            'partes': [
              _parte('Estrofe', 'Louvai', ['Ana'])
            ],
          },
      ],
    };

Future<List<http.Request>> _abrir(WidgetTester tester,
    {Future<String?> Function(String titulo)? pedirLetra,
    double largura = 430,
    Set<String> tocados = const {},
    bool comTerceiroHino = false}) async {
  final requisicoes = <http.Request>[];
  var cantores = ['João', 'Ana'];
  var solistas = <Map<String, Object?>>[
    {'nome': 'José', 'instrumento': 'sax tenor'},
  ];
  Map<String, dynamic>? configuracao;
  final api = ApiTocaEssa(
    enderecoBase: 'http://teste',
    cliente: MockClient((requisicao) async {
      requisicoes.add(requisicao);
      final caminho = requisicao.url.path;
      if (caminho.endsWith('/louvor/configuracao')) {
        configuracao = _corpo(requisicao);
        return http.Response(
            jsonEncode({
              ..._louvor(cantores, solistas, tocados, comTerceiroHino),
              'configuracao': configuracao,
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'});
      }
      if (caminho.endsWith('/louvor/solistas')) {
        solistas = [
          for (final solista in (jsonDecode(requisicao.body)
              as Map<String, dynamic>)['solistas'] as List<dynamic>)
            Map<String, Object?>.from(solista as Map),
        ];
      }
      if (caminho.endsWith('/louvor/cantores')) {
        cantores = [
          for (final nome in (jsonDecode(requisicao.body)
              as Map<String, dynamic>)['nomes'] as List<dynamic>)
            nome as String,
        ];
      }
      final corpo = caminho.endsWith('/cifras/texto')
          ? jsonEncode({'cifra': null, 'urlPesquisa': 'x', 'texto': 'a'})
          : jsonEncode(_louvor(cantores, solistas, tocados, comTerceiroHino));
      return http.Response(corpo, 200,
          headers: {'content-type': 'application/json; charset=utf-8'});
    }),
  )..definirTokenArtista('token');
  tester.view.physicalSize = Size(largura, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    theme: TemaTocaEssa.escuro,
    home: Scaffold(
      body: EscalaDoLouvor(
        api: api,
        apresentacao: _apresentacao,
        pedirLetra: pedirLetra ?? (_) async => null,
      ),
    ),
  ));
  await tester.pumpAndSettle();
  return requisicoes;
}

Map<String, dynamic> _corpo(http.Request requisicao) =>
    jsonDecode(requisicao.body) as Map<String, dynamic>;

Future<void> _irParaPessoas(WidgetTester tester) async {
  await tester.tap(find.text('Pessoas'));
  await tester.pumpAndSettle();
}

Future<void> _abrirHino(WidgetTester tester) async {
  await tester.tap(find.text('80 · Por Cristo, resgatado'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('os hinos aparecem fechados, com ordem, tom e resumo',
      (tester) async {
    await _abrir(tester);

    expect(find.text('1'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('80 · Por Cristo, resgatado'), findsOneWidget);
    expect(find.text('Tom G'), findsOneWidget);
    expect(find.text('João · Ana · 1 sem escala'), findsOneWidget);
    expect(find.text('Estrofe 1'), findsNothing);
    expect(find.text('Sem letra'), findsOneWidget);
    expect(find.text('Quem canta no microfone'), findsNothing);
  });

  testWidgets('tocar no hino abre as partes e quem canta cada uma',
      (tester) async {
    await _abrir(tester);
    await _abrirHino(tester);

    expect(find.text('Estrofe 1'), findsOneWidget);
    expect(find.text('Estrofe 2'), findsOneWidget);
    expect(find.text('Refrão'), findsNWidgets(2));
    expect(find.text('Cristo Jesus, o santo Cordeiro'), findsOneWidget);
    expect(find.widgetWithText(ListTile, 'João'), findsOneWidget);
    expect(find.widgetWithText(ListTile, 'Ana'), findsOneWidget);
    expect(find.widgetWithText(ListTile, 'Todos'), findsNWidgets(2));
    expect(find.text('Solo sax tenor · 2x'), findsOneWidget);
    expect(find.text('—'), findsOneWidget);
    expect(find.text('Escalar automático'), findsOneWidget);

    await _abrirHino(tester);
    expect(find.text('Estrofe 1'), findsNothing);
  });

  testWidgets('cada pessoa tem a sua cor, com legenda no filtro e em Pessoas',
      (tester) async {
    await _abrir(tester);
    const cantores = ['João', 'Ana'];
    Finder bolinha(Finder dono, Color cor) => find.descendant(
        of: dono,
        matching: find.byWidgetPredicate((widget) =>
            widget is Container &&
            widget.decoration is BoxDecoration &&
            (widget.decoration! as BoxDecoration).shape == BoxShape.circle &&
            (widget.decoration! as BoxDecoration).color == cor));

    expect(
        bolinha(find.widgetWithText(ChoiceChip, 'Ana'),
            corDoCantor(cantores, 'Ana')),
        findsOneWidget);
    expect(
        bolinha(find.widgetWithText(ChoiceChip, 'José'),
            corDaPessoa(['João', 'Ana', 'José'], 'José')),
        findsOneWidget);

    await _abrirHino(tester);
    final nome = tester.widget<Text>(
        find.descendant(of: find.byType(ListTile), matching: find.text('Ana')));
    expect(nome.style?.color, corDoCantor(cantores, 'Ana'));

    await _irParaPessoas(tester);
    expect(
        bolinha(find.widgetWithText(Chip, 'João · 1 pt'),
            corDoCantor(cantores, 'João')),
        findsOneWidget);
    expect(
        bolinha(find.widgetWithText(Chip, 'José · sax tenor · 1 solo'),
            corDaPessoa(['João', 'Ana', 'José'], 'José')),
        findsOneWidget);
  });

  testWidgets('o topo resume o que falta e os pontos de cada um',
      (tester) async {
    await _abrir(tester);

    expect(find.text('2 hinos · 1 sem letra · 1 parte sem escala'),
        findsOneWidget);
    // Começa fechado, para os hinos aparecerem logo; um toque abre as barras.
    expect(find.text('Pontos: 1 cada'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(find.text('Solos: José 1'), findsNothing);

    await tester.tap(find.text('Pontos: 1 cada'));
    await tester.pumpAndSettle();

    expect(find.text('1 pt'), findsNWidgets(2));
    expect(find.text('Solos: José 1'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNWidgets(2));
  });

  testWidgets('Escalar todos fica no resumo, sem botão cheio no meio',
      (tester) async {
    await _abrir(tester);

    expect(
        find.descendant(
            of: find.byKey(const ValueKey('resumo-da-escala')),
            matching: find.text('Escalar todos')),
        findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Escalar todos'), findsNothing);
  });

  testWidgets('cada hino tem uma faixa com um pedaço por parte',
      (tester) async {
    await _abrir(tester);

    final faixa = find.byKey(const ValueKey('faixa-h1'));
    expect(faixa, findsOneWidget);
    expect(find.descendant(of: faixa, matching: find.byType(Expanded)),
        findsNWidgets(5));
    expect(find.byKey(const ValueKey('faixa-h2')), findsNothing);
  });

  testWidgets('o hino de agora aparece marcado', (tester) async {
    await _abrir(tester, tocados: {'h1'});

    expect(find.text('Agora'), findsOneWidget);
  });

  testWidgets('ver por pessoa mostra as partes de cada um', (tester) async {
    await _abrir(tester);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Ana'));
    await tester.pumpAndSettle();

    expect(find.text('Ana: 1 parte em 1 hino'), findsOneWidget);
    expect(find.text('Ana: Estrofe 2'), findsOneWidget);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Todos'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Ana:'), findsNothing);
    // Sem ✓ em nenhum filtro: "Todos" fica igual aos nomes.
    expect(
        tester
            .widgetList<ChoiceChip>(find.byType(ChoiceChip))
            .every((chip) => chip.showCheckmark == false),
        isTrue);
  });

  testWidgets('pessoas ficam na aba Pessoas, com os pontos', (tester) async {
    await _abrir(tester);
    await _irParaPessoas(tester);

    expect(find.text('Quem canta no microfone'), findsOneWidget);
    expect(find.text('João · 1 pt'), findsOneWidget);
    expect(find.text('Ana · 1 pt'), findsOneWidget);
    // "1 pt" já diz o que é o número; sem parágrafo de explicação.
    expect(find.textContaining('O número é de'), findsNothing);
    expect(find.textContaining('Vale para os próximos'), findsNothing);
    expect(find.text('80 · Por Cristo, resgatado'), findsNothing);
  });

  testWidgets('tirar alguém só no Editar, longe de um toque sem querer',
      (tester) async {
    await _abrir(tester);
    await _irParaPessoas(tester);

    expect(find.byTooltip('Tirar João'), findsNothing);
    expect(find.byTooltip('Tirar José dos solos'), findsNothing);

    await tester.tap(find.text('Editar'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Tirar João'), findsOneWidget);
    expect(find.byTooltip('Tirar José dos solos'), findsOneWidget);

    await tester.tap(find.text('Concluir'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Tirar João'), findsNothing);
  });

  testWidgets('acrescenta e tira cantores', (tester) async {
    final requisicoes = await _abrir(tester);
    await _irParaPessoas(tester);

    await tester.tap(find.text('Adicionar'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '  Pedro ');
    await tester.tap(find.widgetWithText(FilledButton, 'Adicionar'));
    await tester.pumpAndSettle();

    final adicionou = requisicoes.lastWhere(
        (r) => r.url.path == '/api/apresentacoes/$_id/louvor/cantores');
    expect(_corpo(adicionou)['nomes'], ['João', 'Ana', 'Pedro']);
    expect(find.text('Pedro · 1 pt'), findsOneWidget);

    await tester.tap(find.text('Editar'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Tirar João'));
    await tester.pumpAndSettle();

    final tirou = requisicoes.lastWhere(
        (r) => r.url.path == '/api/apresentacoes/$_id/louvor/cantores');
    expect(_corpo(tirou)['nomes'], ['Ana', 'Pedro']);
  });

  testWidgets('escolhe quem canta, deixa com Todos ou limpa a parte',
      (tester) async {
    final requisicoes = await _abrir(tester);
    await _abrirHino(tester);
    List<http.Request> partes() => requisicoes
        .where((r) => r.url.path == '/api/apresentacoes/$_id/louvor/partes')
        .toList();

    await tester.tap(find.text('Cristo Jesus, o santo Cordeiro'));
    await tester.pumpAndSettle();
    // Os pontos ao lado do nome ajudam a escolher quem tem menos.
    expect(
        find.descendant(
            of: find.widgetWithText(FilterChip, 'Ana'),
            matching: find.text('1 pt')),
        findsOneWidget);
    await tester.tap(find.widgetWithText(FilterChip, 'Ana'));
    await tester.tap(find.widgetWithText(FilterChip, 'João'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Salvar'));
    await tester.pumpAndSettle();
    expect(_corpo(partes().last), {
      'itemId': 'h1',
      'indice': 0,
      'cantores': ['Ana']
    });

    await tester.tap(find.text('Preso estava na iniquidade'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OutlinedButton, 'Todos cantam'));
    await tester.pumpAndSettle();
    expect(_corpo(partes().last),
        {'itemId': 'h1', 'indice': 2, 'cantores': <Object?>[]});

    await tester.tap(find.text('Preso estava na iniquidade'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Deixar sem escala'));
    await tester.pumpAndSettle();
    expect(
        _corpo(partes().last), {'itemId': 'h1', 'indice': 2, 'cantores': null});
  });

  testWidgets('cola a letra do hino que ainda não tem', (tester) async {
    String? pedidoPara;
    final requisicoes = await _abrir(tester, pedirLetra: (titulo) async {
      pedidoPara = titulo;
      return 'Estrofe colada';
    });

    await tester.tap(find.text('Colar letra'));
    await tester.pumpAndSettle();

    expect(pedidoPara, '234 · O meu ser entrego a Cristo');
    final salvou = requisicoes
        .singleWhere((r) => r.url.path == '/api/artista/cifras/texto');
    expect(_corpo(salvou), {
      'musica': '234 · O meu ser entrego a Cristo',
      'artista': 'CCB',
      'texto': 'Estrofe colada',
    });
    expect(requisicoes.last.url.path, '/api/apresentacoes/$_id/louvor');
  });

  testWidgets('o sumário das marcações fica na aba Pessoas', (tester) async {
    await _abrir(tester);
    await _irParaPessoas(tester);

    await tester.tap(find.text('Como marcar as partes'));
    await tester.pumpAndSettle();

    expect(find.text('(Coro 2x)'), findsOneWidget);
    expect(find.text('(Introdução)'), findsOneWidget);
  });

  testWidgets('configura quantos cantam por hino e os coros com Todos',
      (tester) async {
    final requisicoes = await _abrir(tester);
    await _irParaPessoas(tester);
    Map<String, dynamic> configuracao() => _corpo(requisicoes.lastWhere(
        (r) => r.url.path == '/api/apresentacoes/$_id/louvor/configuracao'));
    bool selecionado(String rotulo) => tester
        .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, rotulo))
        .selected;

    expect(find.text('Como escalar'), findsOneWidget);
    expect(selecionado('Sem limite'), isTrue);

    await tester.ensureVisible(find.widgetWithText(ChoiceChip, '2'));
    await tester.tap(find.widgetWithText(ChoiceChip, '2'));
    await tester.pumpAndSettle();

    expect(
        configuracao(), {'maximoDeCantoresPorHino': 2, 'corosComTodos': false});
    expect(selecionado('2'), isTrue);
    expect(selecionado('Sem limite'), isFalse);

    await tester.ensureVisible(find.text('Todos cantam os coros'));
    await tester.tap(find.text('Todos cantam os coros'));
    await tester.pumpAndSettle();

    expect(
        configuracao(), {'maximoDeCantoresPorHino': 2, 'corosComTodos': true});

    await tester.tap(find.widgetWithText(ChoiceChip, 'Sem limite'));
    await tester.pumpAndSettle();
    expect(configuracao(),
        {'maximoDeCantoresPorHino': null, 'corosComTodos': true});
  });

  testWidgets('mostra, acrescenta e tira quem toca os solos', (tester) async {
    final requisicoes = await _abrir(tester);
    await _irParaPessoas(tester);
    List<http.Request> solistas() => requisicoes
        .where((r) => r.url.path == '/api/apresentacoes/$_id/louvor/solistas')
        .toList();

    expect(find.text('Quem toca os solos'), findsOneWidget);
    expect(find.text('José · sax tenor · 1 solo'), findsOneWidget);

    await tester.tap(find.text('Adicionar solista'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Nome'), 'Pedro');
    await tester.enterText(
        find.widgetWithText(TextField, 'Instrumento'), 'trompete');
    await tester.tap(find.widgetWithText(FilledButton, 'Adicionar'));
    await tester.pumpAndSettle();

    expect(_corpo(solistas().last)['solistas'], [
      {'nome': 'José', 'instrumento': 'sax tenor'},
      {'nome': 'Pedro', 'instrumento': 'trompete'},
    ]);
    expect(find.text('Pedro · trompete · 1 solo'), findsOneWidget);

    await tester.tap(find.text('Editar'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Tirar José dos solos'));
    await tester.pumpAndSettle();
    expect(_corpo(solistas().last)['solistas'], [
      {'nome': 'Pedro', 'instrumento': 'trompete'},
    ]);
  });

  testWidgets('no solo, a escolha oferece quem toca os solos', (tester) async {
    await _abrir(tester);
    await _abrirHino(tester);

    await tester.tap(find.text('Solo sax tenor · 2x'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(FilterChip, 'José'), findsOneWidget);
    expect(
        find.descendant(
            of: find.widgetWithText(FilterChip, 'José'),
            matching: find.text('1 solo')),
        findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Banda toda'), findsOneWidget);
    expect(find.widgetWithText(FilterChip, 'Ana'), findsNothing);
  });

  testWidgets('o botão do hino escala as partes pelos pontos', (tester) async {
    final requisicoes = await _abrir(tester);
    await _abrirHino(tester);

    await tester.tap(find.text('Escalar automático'));
    await tester.pumpAndSettle();

    final escalou = requisicoes.where((r) =>
        r.method == 'POST' &&
        r.url.path == '/api/apresentacoes/$_id/louvor/hinos/h1/escalar');
    expect(escalou, hasLength(1));
  });

  testWidgets('cabe num celular de 360px, aberto e com filtro', (tester) async {
    await _abrir(tester, largura: 360, tocados: {'h1'});
    await _abrirHino(tester);
    await tester.tap(find.widgetWithText(ChoiceChip, 'João'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Escalar automático'), findsOneWidget);
  });

  testWidgets('escalar todos os hinos pede confirmação e escala a lista',
      (tester) async {
    final requisicoes = await _abrir(tester, comTerceiroHino: true);
    List<http.Request> escalou() => requisicoes
        .where((r) =>
            r.method == 'POST' &&
            r.url.path == '/api/apresentacoes/$_id/louvor/escalar')
        .toList();

    await tester.tap(find.text('Escalar todos'));
    await tester.pumpAndSettle();
    expect(find.text('Escalar quais hinos?'), findsOneWidget);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(escalou(), isEmpty);

    await tester.tap(find.text('Escalar todos'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Escalar (2)'));
    await tester.pumpAndSettle();
    expect(_corpo(escalou().last)['itens'], ['h1', 'h3']);
  });

  testWidgets('escala só os hinos marcados', (tester) async {
    final requisicoes = await _abrir(tester, comTerceiroHino: true);
    Finder noDialogo(String texto) => find.descendant(
        of: find.byType(AlertDialog), matching: find.text(texto));

    await tester.tap(find.text('Escalar todos'));
    await tester.pumpAndSettle();
    // Hino sem letra não aparece: não tem o que escalar.
    expect(noDialogo('234 · O meu ser entrego a Cristo'), findsNothing);

    await tester.tap(noDialogo('80 · Por Cristo, resgatado'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Escalar (1)'));
    await tester.pumpAndSettle();

    final escalou = requisicoes.lastWhere((r) =>
        r.method == 'POST' &&
        r.url.path == '/api/apresentacoes/$_id/louvor/escalar');
    expect(_corpo(escalou)['itens'], ['h3']);
  });

  testWidgets('Todos desmarca e marca a lista inteira', (tester) async {
    await _abrir(tester, comTerceiroHino: true);
    await tester.tap(find.text('Escalar todos'));
    await tester.pumpAndSettle();
    FilledButton botao() => tester
        .widget<FilledButton>(find.widgetWithText(FilledButton, 'Escalar (0)'));

    final todos = find.descendant(
        of: find.byType(AlertDialog), matching: find.text('Todos'));
    await tester.tap(todos);
    await tester.pumpAndSettle();
    expect(botao().onPressed, isNull);

    await tester.tap(todos);
    await tester.pumpAndSettle();
    expect(find.widgetWithText(FilledButton, 'Escalar (2)'), findsOneWidget);
  });
}
