import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:toca_essa_app/dominio/modelos.dart';
import 'package:toca_essa_app/infraestrutura/api_toca_essa.dart';
import 'package:toca_essa_app/telas/escala_do_louvor.dart';
import 'package:toca_essa_app/tema/tema_toca_essa.dart';

const _id = '22222222-2222-2222-2222-222222222222';

final _apresentacao = Apresentacao.deJson(jsonDecode(
    '{"id":"$_id","nome":"Louvor de sábado","data":"2026-10-24","local":"Casa da Bia","codigo":"ABC123","perfilArtistico":{"id":"11111111-1111-1111-1111-111111111111","nomeArtistico":"Advair","bio":null},"pedidosAbertos":true,"status":"Agendada","tipo":"Louvor"}')
    as Map<String, dynamic>);

Map<String, Object?> _parte(String tipo, String texto, List<String> cantores,
        {bool aMao = false}) =>
    {
      'tipo': tipo,
      'texto': texto,
      'cantores': cantores,
      'escolhidaAMao': aMao,
    };

Map<String, Object?> _louvor(List<String> cantores) => {
      'cantores': cantores,
      'placar': [
        for (final nome in cantores) {'nome': nome, 'estrofes': 1},
      ],
      'hinos': [
        {
          'itemId': 'h1',
          'titulo': '80 · Por Cristo, resgatado',
          'artista': null,
          'tom': 'G',
          'tocado': false,
          'temLetra': true,
          'partes': [
            _parte('Estrofe',
                'G        Bm\nCristo Jesus, o santo Cordeiro\nDeu Sua vida',
                ['João']),
            _parte('Refrao', 'Por Cristo, resgatado', []),
            _parte('Estrofe', 'Preso estava na iniquidade', ['Ana'],
                aMao: true),
            _parte('Refrao', 'Por Cristo, resgatado', []),
            {
              'tipo': 'Instrumental',
              'texto': 'G   D',
              'cantores': <String>[],
              'escolhidaAMao': false,
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
          'tocado': false,
          'temLetra': false,
          'partes': <Object?>[],
        },
      ],
    };

Future<List<http.Request>> _abrir(WidgetTester tester,
    {Future<String?> Function(String titulo)? pedirLetra}) async {
  final requisicoes = <http.Request>[];
  var cantores = ['João', 'Ana'];
  final api = ApiTocaEssa(
    enderecoBase: 'http://teste',
    cliente: MockClient((requisicao) async {
      requisicoes.add(requisicao);
      final caminho = requisicao.url.path;
      if (caminho.endsWith('/louvor/cantores')) {
        cantores = [
          for (final nome in (jsonDecode(requisicao.body)
              as Map<String, dynamic>)['nomes'] as List<dynamic>)
            nome as String,
        ];
      }
      final corpo = caminho.endsWith('/cifras/texto')
          ? jsonEncode({'cifra': null, 'urlPesquisa': 'x', 'texto': 'a'})
          : jsonEncode(_louvor(cantores));
      return http.Response(corpo, 200,
          headers: {'content-type': 'application/json; charset=utf-8'});
    }),
  )..definirTokenArtista('token');
  tester.view.physicalSize = const Size(430, 1400);
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

void main() {
  testWidgets('mostra o placar e quem canta cada parte dos hinos',
      (tester) async {
    await _abrir(tester);

    expect(find.text('João · 1'), findsOneWidget);
    expect(find.text('Ana · 1'), findsOneWidget);
    expect(find.text('80 · Por Cristo, resgatado'), findsOneWidget);
    expect(find.text('Tom G'), findsOneWidget);
    expect(find.text('Estrofe 1'), findsOneWidget);
    expect(find.text('Estrofe 2'), findsOneWidget);
    expect(find.text('Refrão'), findsNWidgets(2));
    expect(find.text('Cristo Jesus, o santo Cordeiro'), findsOneWidget);
    expect(find.text('João'), findsOneWidget);
    expect(find.text('Ana'), findsOneWidget);
    expect(find.text('Todos'), findsNWidgets(2));
    expect(find.byTooltip('Escolhida à mão'), findsOneWidget);
    expect(find.text('Sem letra'), findsOneWidget);
  });

  testWidgets('acrescenta e tira cantores', (tester) async {
    final requisicoes = await _abrir(tester);

    await tester.tap(find.text('Adicionar'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '  Pedro ');
    await tester.tap(find.widgetWithText(FilledButton, 'Adicionar'));
    await tester.pumpAndSettle();

    final adicionou = requisicoes.lastWhere(
        (r) => r.url.path == '/api/apresentacoes/$_id/louvor/cantores');
    expect(_corpo(adicionou)['nomes'], ['João', 'Ana', 'Pedro']);
    expect(find.text('Pedro · 1'), findsOneWidget);

    await tester.tap(find.byTooltip('Tirar João'));
    await tester.pumpAndSettle();

    final tirou = requisicoes.lastWhere(
        (r) => r.url.path == '/api/apresentacoes/$_id/louvor/cantores');
    expect(_corpo(tirou)['nomes'], ['Ana', 'Pedro']);
  });

  testWidgets('escolhe quem canta, deixa com Todos ou volta à escala',
      (tester) async {
    final requisicoes = await _abrir(tester);
    List<http.Request> partes() => requisicoes
        .where((r) => r.url.path == '/api/apresentacoes/$_id/louvor/partes')
        .toList();

    await tester.tap(find.text('Cristo Jesus, o santo Cordeiro'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilterChip, 'Ana'));
    await tester.tap(find.widgetWithText(FilterChip, 'João'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Salvar'));
    await tester.pumpAndSettle();
    expect(_corpo(partes().last),
        {'itemId': 'h1', 'indice': 0, 'cantores': ['Ana']});

    await tester.tap(find.text('Preso estava na iniquidade'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OutlinedButton, 'Todos'));
    await tester.pumpAndSettle();
    expect(_corpo(partes().last),
        {'itemId': 'h1', 'indice': 2, 'cantores': <Object?>[]});

    await tester.tap(find.text('Preso estava na iniquidade'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Automático'));
    await tester.pumpAndSettle();
    expect(_corpo(partes().last),
        {'itemId': 'h1', 'indice': 2, 'cantores': null});
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
    final salvou =
        requisicoes.singleWhere((r) => r.url.path == '/api/artista/cifras/texto');
    expect(_corpo(salvou), {
      'musica': '234 · O meu ser entrego a Cristo',
      'artista': 'CCB',
      'texto': 'Estrofe colada',
    });
    expect(requisicoes.last.url.path, '/api/apresentacoes/$_id/louvor');
  });

  testWidgets('o solo aparece com o instrumento e sem cantor', (tester) async {
    await _abrir(tester);

    expect(find.text('Solo sax tenor · 2x'), findsOneWidget);
    expect(find.text('—'), findsOneWidget);
  });

  testWidgets('o sumário das marcações fica à mão na escala', (tester) async {
    await _abrir(tester);

    await tester.tap(find.text('Como marcar as partes'));
    await tester.pumpAndSettle();

    expect(find.text('(Coro 2x)'), findsOneWidget);
    expect(find.text('(Introdução)'), findsOneWidget);
  });
}
