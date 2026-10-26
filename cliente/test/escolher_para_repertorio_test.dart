import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:toca_essa_app/dominio/modelos.dart';
import 'package:toca_essa_app/infraestrutura/api_toca_essa.dart';
import 'package:toca_essa_app/telas/escolher_para_repertorio.dart';

const _comoJson = {'content-type': 'application/json; charset=utf-8'};

OpcaoParaRepertorio _opcao(String titulo,
        {String? detalhe, bool marcada = true}) =>
    OpcaoParaRepertorio(
      musica: (titulo: titulo, artista: null, tom: null, linkDoVideo: null),
      detalhe: detalhe,
      marcada: marcada,
    );

Future<List<http.Request>> _abrir(
  WidgetTester tester,
  List<OpcaoParaRepertorio> opcoes, {
  Vocabulario vocabulario = Vocabulario.musical,
}) async {
  final requisicoes = <http.Request>[];
  final cliente = MockClient((requisicao) async {
    requisicoes.add(requisicao);
    if (requisicao.method == 'GET') return http.Response('[]', 200);
    final corpo = jsonDecode(requisicao.body) as Map<String, dynamic>;
    return http.Response(
        jsonEncode({
          'repertorio': {
            'id': 'r9',
            'artistaId': 'a1',
            'nome': corpo['nomeNovo'],
            'musicas': [],
          },
          'adicionadas': (corpo['musicas'] as List).length,
          'jaEstavam': 0,
        }),
        200,
        headers: _comoJson);
  });
  final api = ApiTocaEssa(cliente: cliente, enderecoBase: 'http://teste')
    ..definirTokenArtista('TOKEN');
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: Builder(
        builder: (context) => TextButton(
          onPressed: () => escolherParaRepertorio(context,
              api: api,
              titulo: 'Levar ao repertório',
              opcoes: opcoes,
              nomeSugerido: 'Show · 10/09',
              vocabulario: vocabulario),
          child: const Text('Abrir'),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('Abrir'));
  await tester.pumpAndSettle();
  return requisicoes;
}

void main() {
  testWidgets('mostra as opções marcadas de início e o detalhe',
      (tester) async {
    await _abrir(tester, [
      _opcao('Evidências', detalhe: 'pedida 3x · fora do acervo'),
      _opcao('Garçom', marcada: false, detalhe: 'já no Barzinho'),
    ]);

    expect(find.text('Levar ao repertório'), findsOneWidget);
    expect(find.text('pedida 3x · fora do acervo'), findsOneWidget);
    expect(find.text('Adicionar 1 música ao repertório'), findsOneWidget);

    await tester.tap(find.text('Garçom'));
    await tester.pump();
    expect(find.text('Adicionar 2 músicas ao repertório'), findsOneWidget);
  });

  testWidgets('Todas marca e desmarca tudo; sem nenhuma, não adiciona',
      (tester) async {
    await _abrir(tester, [_opcao('Evidências'), _opcao('Garçom')]);

    await tester.tap(find.text('Todas'));
    await tester.pump();
    final botao = find.widgetWithText(FilledButton, 'Nada marcado');
    expect(tester.widget<FilledButton>(botao).onPressed, isNull);

    await tester.tap(find.text('Todas'));
    await tester.pump();
    expect(find.text('Adicionar 2 músicas ao repertório'), findsOneWidget);
  });

  testWidgets('leva só as marcadas e fecha a tela', (tester) async {
    final requisicoes = await _abrir(tester, [
      _opcao('Evidências'),
      _opcao('Garçom'),
      _opcao('Trem-Bala', marcada: false),
    ]);

    await tester.tap(find.text('Garçom'));
    await tester.pump();
    await tester.tap(find.text('Adicionar 1 música ao repertório'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Criar'));
    await tester.pumpAndSettle();

    final envio = requisicoes.singleWhere((r) => r.method == 'POST');
    expect([
      for (final m in (jsonDecode(envio.body) as Map)['musicas'] as List)
        m['titulo']
    ], [
      'Evidências'
    ]);
    expect(find.text('Levar ao repertório'), findsNothing);
    expect(find.text('1 música foi para "Show · 10/09"'), findsOneWidget);
  });

  testWidgets('com muitas, a busca filtra sem perder as marcadas',
      (tester) async {
    final requisicoes = await _abrir(tester, [
      for (var i = 1; i <= 11; i++) _opcao('Canção $i', marcada: false),
      _opcao('Evidências', marcada: false),
    ]);

    await tester.enterText(
        find.widgetWithText(TextField, 'Buscar música'), 'evidencias');
    await tester.pumpAndSettle();
    expect(find.text('Canção 2'), findsNothing);
    await tester.tap(find.text('Evidências'));
    await tester.enterText(
        find.widgetWithText(TextField, 'Buscar música'), 'cancao 2');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Canção 2'));
    await tester.pump();
    await tester.tap(find.text('Adicionar 2 músicas ao repertório'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Criar'));
    await tester.pumpAndSettle();

    final envio = requisicoes.singleWhere((r) => r.method == 'POST');
    expect([
      for (final m in (jsonDecode(envio.body) as Map)['musicas'] as List)
        m['titulo']
    ], [
      'Canção 2',
      'Evidências'
    ]);
  });

  testWidgets('no louvor fala de hinos', (tester) async {
    await _abrir(tester, [_opcao('Castelo Forte')],
        vocabulario: Vocabulario.louvor);

    expect(find.text('Adicionar 1 hino ao repertório'), findsOneWidget);
  });
}
