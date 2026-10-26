import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:toca_essa_app/dominio/modelos.dart';
import 'package:toca_essa_app/infraestrutura/api_toca_essa.dart';
import 'package:toca_essa_app/telas/adicionar_ao_repertorio.dart';

const _comoJson = {'content-type': 'application/json; charset=utf-8'};

Map<String, Object?> _repertorio(
        String id, String nome, List<String> titulos) =>
    {
      'id': id,
      'artistaId': 'a1',
      'nome': nome,
      'musicas': [
        for (final (i, titulo) in titulos.indexed)
          {
            'id': '$id-$i',
            'repertorioId': id,
            'titulo': titulo,
            'artista': null,
            'tom': null,
            'ordem': i + 1,
          },
      ],
    };

/// Abre a folha por um botão e devolve as requisições feitas.
Future<List<http.Request>> _abrir(
  WidgetTester tester, {
  required List<MusicaParaRepertorio> musicas,
  String nomeSugerido = 'Show · 10/09',
  Vocabulario vocabulario = Vocabulario.musical,
  int jaEstavam = 0,
}) async {
  final requisicoes = <http.Request>[];
  final cliente = MockClient((requisicao) async {
    requisicoes.add(requisicao);
    if (requisicao.method == 'GET') {
      return http.Response(
          jsonEncode([
            _repertorio('r1', 'Barzinho', ['Evidências', 'Tempo Perdido']),
            _repertorio('r2', 'Sertanejo', ['Galopeira']),
          ]),
          200,
          headers: _comoJson);
    }
    final corpo = jsonDecode(requisicao.body) as Map<String, dynamic>;
    final nome = corpo['nomeNovo'] as String? ??
        {'r1': 'Barzinho', 'r2': 'Sertanejo'}[corpo['repertorioId']]!;
    return http.Response(
        jsonEncode({
          'repertorio': _repertorio('r9', nome, []),
          'adicionadas': (corpo['musicas'] as List).length - jaEstavam,
          'jaEstavam': jaEstavam,
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
          onPressed: () => adicionarAoRepertorio(context,
              api: api,
              musicas: musicas,
              nomeSugerido: nomeSugerido,
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

const _duas = <MusicaParaRepertorio>[
  (titulo: 'evidencias', artista: null, tom: 'G', linkDoVideo: null),
  (titulo: 'Nova', artista: 'Banda', tom: null, linkDoVideo: null),
];

void main() {
  testWidgets('lista os repertórios e conta as que já estão em cada um',
      (tester) async {
    await _abrir(tester, musicas: _duas);

    expect(find.text('Adicionar 2 músicas a…'), findsOneWidget);
    expect(find.text('2 músicas · 1 já está'), findsOneWidget);
    expect(find.text('1 música'), findsOneWidget);
  });

  testWidgets('escolher um repertório envia as músicas e avisa',
      (tester) async {
    final requisicoes = await _abrir(tester, musicas: _duas, jaEstavam: 1);

    await tester.tap(find.text('Barzinho'));
    await tester.pumpAndSettle();

    final envio = requisicoes.singleWhere((r) => r.method == 'POST');
    expect(envio.url.path, '/api/artista/repertorios/musicas');
    expect(jsonDecode(envio.body), {
      'repertorioId': 'r1',
      'musicas': [
        {'titulo': 'evidencias', 'artista': null, 'tom': 'G'},
        {'titulo': 'Nova', 'artista': 'Banda', 'tom': null},
      ],
    });
    expect(find.text('Adicionar 2 músicas a…'), findsNothing);
    expect(find.text('1 música foi para "Barzinho" · 1 já estava'),
        findsOneWidget);
  });

  testWidgets('cria repertório novo com o nome sugerido', (tester) async {
    final requisicoes = await _abrir(tester, musicas: _duas);

    expect(find.widgetWithText(TextField, 'Show · 10/09'), findsOneWidget);
    await tester.tap(find.text('Criar'));
    await tester.pumpAndSettle();

    final envio = requisicoes.singleWhere((r) => r.method == 'POST');
    expect((jsonDecode(envio.body) as Map)['nomeNovo'], 'Show · 10/09');
    expect(find.text('2 músicas foram para "Show · 10/09"'), findsOneWidget);
  });

  testWidgets('sem nome não cria', (tester) async {
    final requisicoes = await _abrir(tester, musicas: _duas, nomeSugerido: '');

    await tester.tap(find.text('Criar'));
    await tester.pumpAndSettle();

    expect(requisicoes.where((r) => r.method == 'POST'), isEmpty);
  });

  testWidgets('quando todas já estavam, diz que não mudou nada',
      (tester) async {
    await _abrir(tester,
        musicas: [
          (titulo: 'Evidências', artista: null, tom: null, linkDoVideo: null)
        ],
        jaEstavam: 1);

    expect(find.text('Adicionar "Evidências" a…'), findsOneWidget);
    expect(find.text('2 músicas · já está'), findsOneWidget);
    await tester.tap(find.text('Barzinho'));
    await tester.pumpAndSettle();

    expect(find.text('Já estava em "Barzinho"'), findsOneWidget);
  });

  testWidgets('no louvor fala de hinos', (tester) async {
    await _abrir(tester,
        musicas: _duas, vocabulario: Vocabulario.louvor, jaEstavam: 0);

    expect(find.text('Adicionar 2 hinos a…'), findsOneWidget);
    expect(find.text('2 hinos · 1 já está'), findsOneWidget);
    await tester.tap(find.text('Sertanejo'));
    await tester.pumpAndSettle();

    expect(find.text('2 hinos foram para "Sertanejo"'), findsOneWidget);
  });
}
