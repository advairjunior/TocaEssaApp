import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:toca_essa_app/infraestrutura/api_toca_essa.dart';
import 'package:toca_essa_app/telas/stories_do_show.dart';

const _json = {'content-type': 'application/json; charset=utf-8'};

Map<String, dynamic> _story(String id,
        {String tipo = 'Foto', String? nome, bool doArtista = false}) =>
    {
      'id': id,
      'tipo': tipo,
      'nome': nome,
      'criadoEm': '2026-10-17T21:04:00',
      'tipoDeConteudo': tipo == 'Foto' ? 'image/jpeg' : 'video/mp4',
      'url': 'http://teste/arquivo/$id',
      'doArtista': doArtista,
    };

class _Servidor {
  _Servidor(this.stories);
  List<Map<String, dynamic>> stories;
  final requisicoes = <http.Request>[];

  late final cliente = MockClient((requisicao) async {
    requisicoes.add(requisicao);
    if (requisicao.url.path.endsWith('/stories')) {
      return http.Response(jsonEncode(stories), 200, headers: _json);
    }
    return http.Response('', 204);
  });

  Iterable<http.Request> doCaminho(String fim) =>
      requisicoes.where((r) => r.url.path.endsWith(fim));
}

/// Vídeo falso: mostra o endereço e termina quando o teste manda.
class _Videos {
  final terminar = <String, VoidCallback>{};
  final pausados = <String, bool>{};

  Widget construir({
    required Uri url,
    required bool pausado,
    required ValueChanged<double> aoProgredir,
    required VoidCallback aoTerminar,
  }) {
    terminar[url.toString()] = aoTerminar;
    pausados[url.toString()] = pausado;
    return Center(child: Text('vídeo $url'));
  }
}

Future<void> _abrir(WidgetTester tester, _Servidor servidor,
    {_Videos? videos}) async {
  final api = ApiTocaEssa(cliente: servidor.cliente, enderecoBase: 'http://teste');
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: StoriesDoShow(
        api: api,
        codigo: 'ABC123',
        nome: 'Ana',
        construtorDeVideo: (videos ?? _Videos()).construir,
      ),
    ),
  ));
  await _assentar(tester);
}

/// A foto corre sozinha: o tempo anda só o da transição.
Future<void> _assentar(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 350));
}

Future<void> _tocarNaDireita(WidgetTester tester) async {
  final tamanho = tester.getSize(find.byType(TelaDeStories));
  await tester.tapAt(Offset(tamanho.width * .9, tamanho.height / 2));
  await _assentar(tester);
}

Future<void> _tocarNaEsquerda(WidgetTester tester) async {
  final tamanho = tester.getSize(find.byType(TelaDeStories));
  await tester.tapAt(Offset(tamanho.width * .1, tamanho.height / 2));
  await _assentar(tester);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('sem stories mostra só o envio', (tester) async {
    await _abrir(tester, _Servidor([]));

    expect(find.byType(BolinhaDeStory), findsNothing);
    expect(find.text('Enviar vídeo ou foto'), findsOneWidget);
  });

  testWidgets('envio sem explicações nem aviso', (tester) async {
    await _abrir(tester, _Servidor([]));

    expect(find.text('Todo mundo do show vê os stories'), findsNothing);
    await tester.tap(find.text('Enviar vídeo ou foto'));
    await _assentar(tester);
    expect(find.text('Entendi'), findsNothing);
    expect(find.text('Gravar vídeo'), findsOneWidget);
  });

  testWidgets('fileira mostra quem postou, com o artista primeiro',
      (tester) async {
    final servidor = _Servidor([
      _story('a', nome: 'Ana'),
      _story('b'),
      _story('c', nome: 'Duo Aurora', doArtista: true),
    ]);
    await _abrir(tester, servidor);

    expect(servidor.doCaminho('/api/publico/apresentacoes/ABC123/stories'),
        hasLength(1));
    final nomes = tester
        .widgetList<BolinhaDeStory>(find.byType(BolinhaDeStory))
        .map((bolinha) => bolinha.story.id)
        .toList();
    expect(nomes, ['c', 'a', 'b']);
    expect(find.text('Duo Aurora'), findsOneWidget);
    expect(find.text('Ana'), findsOneWidget);
  });

  testWidgets('tocar abre em tela cheia, avança, volta e fecha no fim',
      (tester) async {
    await _abrir(tester,
        _Servidor([_story('a', nome: 'Ana'), _story('b', nome: 'Leo')]));

    await tester.tap(find.text('Ana'));
    await _assentar(tester);
    expect(find.byType(TelaDeStories), findsOneWidget);
    expect(find.descendant(of: find.byType(TelaDeStories), matching: find.text('Ana')),
        findsOneWidget);
    expect(find.text('21:04'), findsOneWidget);

    await _tocarNaDireita(tester);
    expect(find.descendant(of: find.byType(TelaDeStories), matching: find.text('Leo')),
        findsOneWidget);

    await _tocarNaEsquerda(tester);
    expect(find.descendant(of: find.byType(TelaDeStories), matching: find.text('Ana')),
        findsOneWidget);

    await _tocarNaDireita(tester);
    await _tocarNaDireita(tester);
    expect(find.byType(TelaDeStories), findsNothing);
  });

  testWidgets('foto passa sozinha em 5 s', (tester) async {
    await _abrir(tester,
        _Servidor([_story('a', nome: 'Ana'), _story('b', nome: 'Leo')]));
    await tester.tap(find.text('Ana'));
    await _assentar(tester);

    await tester.pump(const Duration(seconds: 4));
    expect(find.descendant(of: find.byType(TelaDeStories), matching: find.text('Ana')),
        findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    await _assentar(tester);
    expect(find.descendant(of: find.byType(TelaDeStories), matching: find.text('Leo')),
        findsOneWidget);
  });

  testWidgets('vídeo passa quando termina e pausa ao segurar',
      (tester) async {
    final videos = _Videos();
    await _abrir(
        tester,
        _Servidor([
          _story('a', nome: 'Ana', tipo: 'Video'),
          _story('b', nome: 'Leo'),
        ]),
        videos: videos);
    await tester.tap(find.text('Ana'));
    await _assentar(tester);
    expect(find.text('vídeo http://teste/arquivo/a'), findsOneWidget);

    // Vídeo não tem tempo fixo: só passa quando acaba.
    await tester.pump(const Duration(seconds: 10));
    expect(find.text('vídeo http://teste/arquivo/a'), findsOneWidget);

    final gesto = await tester.startGesture(
        tester.getCenter(find.byType(TelaDeStories)));
    await tester.pump(const Duration(seconds: 1));
    expect(videos.pausados['http://teste/arquivo/a'], isTrue);
    await gesto.up();
    await tester.pump();
    expect(videos.pausados['http://teste/arquivo/a'], isFalse);

    videos.terminar['http://teste/arquivo/a']!();
    await _assentar(tester);
    expect(find.descendant(of: find.byType(TelaDeStories), matching: find.text('Leo')),
        findsOneWidget);
  });

  testWidgets('arrastar para baixo fecha', (tester) async {
    await _abrir(tester, _Servidor([_story('a', nome: 'Ana')]));
    await tester.tap(find.text('Ana'));
    await _assentar(tester);

    await tester.fling(find.byType(TelaDeStories), const Offset(0, 400), 1500);
    await _assentar(tester);

    expect(find.byType(TelaDeStories), findsNothing);
  });

  testWidgets('story visto perde o anel neste aparelho', (tester) async {
    await _abrir(tester,
        _Servidor([_story('a', nome: 'Ana'), _story('b', nome: 'Leo')]));
    bool novo(String id) => tester
        .widgetList<BolinhaDeStory>(find.byType(BolinhaDeStory))
        .singleWhere((bolinha) => bolinha.story.id == id)
        .novo;
    expect(novo('a'), isTrue);

    await tester.tap(find.text('Ana'));
    await _assentar(tester);
    await tester.tap(find.byTooltip('Fechar'));
    await _assentar(tester);

    expect(novo('a'), isFalse);
    expect(novo('b'), isTrue);

    // Continua visto depois de abrir a tela de novo.
    await tester.pumpWidget(const SizedBox());
    await _abrir(tester,
        _Servidor([_story('a', nome: 'Ana'), _story('b', nome: 'Leo')]));
    expect(novo('a'), isFalse);
  });

  testWidgets('denunciar manda o aparelho e passa para o próximo',
      (tester) async {
    final servidor =
        _Servidor([_story('a', nome: 'Ana'), _story('b', nome: 'Leo')]);
    await _abrir(tester, servidor);
    await tester.tap(find.text('Ana'));
    await _assentar(tester);

    await tester.tap(find.byTooltip('Mais'));
    await _assentar(tester);
    await tester.tap(find.text('Denunciar'));
    await _assentar(tester);

    final denuncia = servidor.doCaminho('/stories/a/denuncia').single;
    expect(denuncia.url.path, '/api/publico/apresentacoes/ABC123/stories/a/denuncia');
    expect(denuncia.headers['Authorization'], isNull);
    expect((jsonDecode(denuncia.body) as Map)['aparelho'], isNotEmpty);
    expect(find.text('Denúncia enviada.'), findsWidgets);
    expect(find.descendant(of: find.byType(TelaDeStories), matching: find.text('Leo')),
        findsOneWidget);
  });

  testWidgets('story do artista não tem denúncia', (tester) async {
    await _abrir(tester,
        _Servidor([_story('c', nome: 'Duo Aurora', doArtista: true)]));
    await tester.tap(find.text('Duo Aurora'));
    await _assentar(tester);

    expect(find.byTooltip('Mais'), findsNothing);
  });

  testWidgets('lista é buscada de novo a cada minuto', (tester) async {
    final servidor = _Servidor([]);
    await _abrir(tester, servidor);
    servidor.stories = [_story('a', nome: 'Ana')];

    await tester.pump(const Duration(minutes: 1));
    await _assentar(tester);

    expect(find.text('Ana'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('falha ao buscar não mostra erro', (tester) async {
    final api = ApiTocaEssa(
        cliente: MockClient((_) async => http.Response('', 500)),
        enderecoBase: 'http://teste');
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: StoriesDoShow(api: api, codigo: 'ABC123', nome: null),
      ),
    ));
    await _assentar(tester);

    expect(find.byType(BolinhaDeStory), findsNothing);
    expect(find.byType(SnackBar), findsNothing);
    expect(find.text('Enviar vídeo ou foto'), findsOneWidget);
  });
}
