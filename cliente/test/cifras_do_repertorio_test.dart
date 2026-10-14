import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:toca_essa_app/infraestrutura/api_toca_essa.dart';
import 'package:toca_essa_app/telas/gerenciar_repertorios.dart';

const _json = {'content-type': 'application/json; charset=utf-8'};
const _linkSozinho = 'https://www.cifraclub.com.br/caetano/sozinho/';

const _repertorios =
    '[{"id":"r1","artistaId":"a1","nome":"Barzinho","musicas":['
    '{"id":"m1","repertorioId":"r1","titulo":"Evidências","artista":"Chitãozinho & Xororó","tom":"A","ordem":1},'
    '{"id":"m2","repertorioId":"r1","titulo":"Sozinho","artista":null,"tom":null,"ordem":2},'
    '{"id":"m3","repertorioId":"r1","titulo":"Trem-Bala","artista":null,"tom":null,"ordem":3}'
    ']}]';

class _Acervo {
  final requisicoes = <http.Request>[];
  final abertas = <Uri>[];
  // título → cifra colada no servidor falso
  final textos = <String, String>{'Evidências': 'A  E\nLetra antiga'};
  String? areaDeTransferencia;
  // músicas adicionadas durante o teste: id → título
  final adicionadas = <String, String>{};

  List<Map<String, Object?>> cifras() => [
        for (final (id, titulo, link) in [
          ('m1', 'Evidências', null),
          ('m2', 'Sozinho', _linkSozinho),
          ('m3', 'Trem-Bala', null),
          for (final MapEntry(key: id, value: titulo) in adicionadas.entries)
            (id, titulo, null),
        ])
          {
            'musicaId': id,
            'temTexto': textos.containsKey(titulo),
            'url': link,
            'urlPesquisa': 'https://www.google.com/search?q=$titulo',
          },
      ];
}

Future<_Acervo> _abrir(WidgetTester tester) async {
  final acervo = _Acervo();
  tester.binding.defaultBinaryMessenger
      .setMockMethodCallHandler(SystemChannels.platform, (chamada) async {
    if (chamada.method == 'Clipboard.getData') {
      return acervo.areaDeTransferencia == null
          ? null
          : {'text': acervo.areaDeTransferencia};
    }
    return null;
  });
  addTearDown(() => tester.binding.defaultBinaryMessenger
      .setMockMethodCallHandler(SystemChannels.platform, null));
  final cliente = MockClient((requisicao) async {
    acervo.requisicoes.add(requisicao);
    final caminho = requisicao.url.path;
    if (caminho.endsWith('/repertorios/r1/cifras')) {
      return http.Response(jsonEncode(acervo.cifras()), 200, headers: _json);
    }
    if (caminho.endsWith('/cifras/texto')) {
      final corpo = jsonDecode(requisicao.body) as Map<String, dynamic>;
      acervo.textos[corpo['musica'] as String] = corpo['texto'] as String;
      return http.Response(
          jsonEncode({'urlPesquisa': 'x', 'texto': corpo['texto']}), 200,
          headers: _json);
    }
    if (requisicao.method == 'POST' && caminho.endsWith('/r1/musicas')) {
      final corpo = jsonDecode(requisicao.body) as Map<String, dynamic>;
      final id = 'm${4 + acervo.adicionadas.length}';
      acervo.adicionadas[id] = corpo['titulo'] as String;
      return http.Response(
          jsonEncode({
            'id': id,
            'repertorioId': 'r1',
            'titulo': corpo['titulo'],
            'artista': corpo['artista'],
            'tom': corpo['tom'],
            'ordem': 3 + acervo.adicionadas.length,
          }),
          200,
          headers: _json);
    }
    if (caminho.endsWith('/cifras/consulta')) {
      final musica = requisicao.url.queryParameters['musica'];
      return http.Response(
          jsonEncode({'urlPesquisa': 'x', 'texto': acervo.textos[musica]}),
          200,
          headers: _json);
    }
    return http.Response(_repertorios, 200, headers: _json);
  });
  await tester.pumpWidget(MaterialApp(
    home: GerenciarRepertorios(
      api: ApiTocaEssa(cliente: cliente, enderecoBase: 'http://teste')
        ..definirTokenArtista('TOKEN'),
      abrirUrl: (url) async => acervo.abertas.add(url),
    ),
  ));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Barzinho'));
  await tester.pumpAndSettle();
  return acervo;
}

Iterable<http.Request> _salvas(_Acervo acervo) =>
    acervo.requisicoes.where((r) => r.url.path.endsWith('/cifras/texto'));

void main() {
  testWidgets('repertório mostra quais músicas têm cifra e quantas faltam',
      (tester) async {
    await _abrir(tester);

    expect(find.text('2 músicas sem cifra'), findsOneWidget);
    expect(find.byTooltip('Ver ou corrigir cifra'), findsOneWidget);
    expect(find.byTooltip('Colar cifra'), findsNWidgets(2));
  });

  testWidgets('música recém-adicionada já oferece colar cifra',
      (tester) async {
    await _abrir(tester);

    await tester.tap(find.byTooltip('Adicionar música'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Tocando em Frente');
    await tester.tap(find.text('Adicionar'));
    await tester.pumpAndSettle();

    expect(find.text('Tocando em Frente'), findsOneWidget);
    expect(find.byTooltip('Colar cifra'), findsNWidgets(3));
    expect(find.text('3 músicas sem cifra'), findsOneWidget);
  });

  testWidgets('ícone abre a cifra da música para corrigir', (tester) async {
    final acervo = await _abrir(tester);

    await tester.tap(find.byTooltip('Ver ou corrigir cifra'));
    await tester.pumpAndSettle();
    expect(find.text('A  E\nLetra antiga'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'A  E\nLetra nova');
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();

    expect(jsonDecode(_salvas(acervo).single.body), {
      'musica': 'Evidências',
      'artista': 'Chitãozinho & Xororó',
      'texto': 'A  E\nLetra nova',
    });
  });

  testWidgets('colar e próxima passa pelas músicas sem cifra',
      (tester) async {
    final acervo = await _abrir(tester);

    await tester.tap(find.text('Colar agora'));
    await tester.pumpAndSettle();
    expect(find.text('Sozinho'), findsOneWidget);
    expect(find.text('1 de 2'), findsOneWidget);

    await tester.tap(find.text('Abrir no Cifra Club'));
    await tester.pumpAndSettle();
    expect(acervo.abertas, [Uri.parse(_linkSozinho)]);

    acervo.areaDeTransferencia = 'C  G\nLetra de Sozinho';
    await tester.tap(find.text('Colar e próxima'));
    await tester.pumpAndSettle();
    expect(jsonDecode(_salvas(acervo).single.body), {
      'musica': 'Sozinho',
      'artista': null,
      'texto': 'C  G\nLetra de Sozinho',
    });
    expect(find.text('Trem-Bala'), findsOneWidget);
    expect(find.text('2 de 2'), findsOneWidget);

    // Sem nada copiado, não salva e avisa.
    acervo.areaDeTransferencia = null;
    await tester.tap(find.text('Colar e concluir'));
    await tester.pumpAndSettle();
    expect(find.text('Copie a cifra antes de colar.'), findsOneWidget);
    expect(_salvas(acervo), hasLength(1));

    // Sem link salvo, abre a pesquisa pronta.
    await tester.tap(find.text('Abrir no Cifra Club'));
    await tester.pumpAndSettle();
    expect(acervo.abertas.last.toString(), contains('google.com'));

    await tester.tap(find.text('Pular'));
    await tester.pumpAndSettle();
    expect(find.text('1 música sem cifra'), findsOneWidget);
  });

  testWidgets('repertório com cifras cabe em celular de 360px', (tester) async {
    addTearDown(tester.view.reset);
    tester.view.devicePixelRatio = 3;
    tester.view.physicalSize = const Size(360, 740) * 3;

    await _abrir(tester);

    expect(tester.takeException(), isNull);
    expect(find.text('Colar agora'), findsOneWidget);
  });
}
