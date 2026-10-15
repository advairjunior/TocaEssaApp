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
        {String tipo = 'Foto',
        String? nome,
        bool doArtista = false,
        String criadoEm = '2026-10-17T21:04:00'}) =>
    {
      'id': id,
      'tipo': tipo,
      'nome': nome,
      'criadoEm': criadoEm,
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

Finder _naTela(String texto) =>
    find.descendant(of: find.byType(TelaDeStories), matching: find.text(texto));

/// Quem aparece na fileira, na ordem.
List<String> _fileira(WidgetTester tester) => tester
    .widgetList<BolinhaDeStory>(find.byType(BolinhaDeStory))
    .map((bolinha) => bolinha.grupo.nome)
    .toList();

bool _novo(WidgetTester tester, String nome) => tester
    .widgetList<BolinhaDeStory>(find.byType(BolinhaDeStory))
    .singleWhere((bolinha) => bolinha.grupo.nome == nome)
    .novo;

/// Quantas barrinhas de progresso a tela cheia mostra.
int _barrinhas(WidgetTester tester) => find
    .descendant(
        of: find.byType(TelaDeStories),
        matching: find.byType(LinearProgressIndicator))
    .evaluate()
    .length;

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('frase convida a gravar um pedaço do show', (tester) async {
    await _abrir(tester, _Servidor([]));

    final frase = find.text('Curtindo o show? Grave um pedaço para a galera e o artista.');
    expect(frase, findsOneWidget);
    expect(tester.getTopLeft(frase).dy,
        lessThan(tester.getTopLeft(find.text('Enviar')).dy));
  });

  testWidgets('sem stories a fileira tem só o enviar', (tester) async {
    await _abrir(tester, _Servidor([]));

    expect(find.byType(BolinhaDeStory), findsNothing);
    expect(find.text('Enviar'), findsOneWidget);
  });

  testWidgets('enviar é a primeira bolinha e abre câmera e galeria',
      (tester) async {
    await _abrir(tester, _Servidor([_story('a', nome: 'Leo')]));

    final enviar = tester.getTopLeft(find.text('Enviar')).dx;
    expect(enviar, lessThan(tester.getTopLeft(find.text('Leo')).dx));
    await tester.tap(find.text('Enviar'));
    await _assentar(tester);
    expect(find.text('Gravar vídeo'), findsOneWidget);
  });

  testWidgets('uma bolinha por pessoa, com o artista primeiro',
      (tester) async {
    final servidor = _Servidor([
      _story('a', nome: 'Ana'),
      _story('b'),
      _story('c', nome: 'Ana'),
      _story('d', nome: 'Duo Aurora', doArtista: true),
      _story('e', nome: 'Leo'),
    ]);
    await _abrir(tester, servidor);

    expect(servidor.doCaminho('/api/publico/apresentacoes/ABC123/stories'),
        hasLength(1));
    expect(_fileira(tester), ['Duo Aurora', 'Ana', 'Público', 'Leo']);
  });

  testWidgets('a pessoa mostra só as barrinhas dela e passa para a próxima',
      (tester) async {
    await _abrir(
        tester,
        _Servidor([
          _story('a', nome: 'Ana'),
          _story('b', nome: 'Ana'),
          _story('c', nome: 'Leo'),
        ]));

    await tester.tap(find.text('Ana'));
    await _assentar(tester);
    expect(_naTela('Ana'), findsOneWidget);
    expect(_barrinhas(tester), 2);
    expect(find.text('21:04'), findsOneWidget);

    await _tocarNaDireita(tester);
    expect(_naTela('Ana'), findsOneWidget);
    await _tocarNaDireita(tester);
    expect(_naTela('Leo'), findsOneWidget);
    expect(_barrinhas(tester), 1);

    await _tocarNaEsquerda(tester);
    expect(_naTela('Ana'), findsOneWidget);

    await _tocarNaDireita(tester);
    await _tocarNaDireita(tester);
    expect(find.byType(TelaDeStories), findsNothing);
  });

  testWidgets('arrastar para o lado pula de pessoa', (tester) async {
    await _abrir(
        tester,
        _Servidor([
          _story('a', nome: 'Ana'),
          _story('b', nome: 'Ana'),
          _story('c', nome: 'Leo'),
        ]));
    await tester.tap(find.text('Ana'));
    await _assentar(tester);

    await tester.fling(
        find.byType(TelaDeStories), const Offset(-300, 0), 1500);
    await _assentar(tester);
    expect(_naTela('Leo'), findsOneWidget);

    await tester.fling(find.byType(TelaDeStories), const Offset(300, 0), 1500);
    await _assentar(tester);
    expect(_naTela('Ana'), findsOneWidget);
  });

  testWidgets('abre a pessoa no primeiro story ainda não visto',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'stories_vistos': ['a'],
    });
    final videos = _Videos();
    await _abrir(
        tester,
        _Servidor([
          _story('a', nome: 'Ana', tipo: 'Video'),
          _story('b', nome: 'Ana', tipo: 'Video'),
        ]),
        videos: videos);

    await tester.tap(find.text('Ana'));
    await _assentar(tester);

    expect(find.text('vídeo http://teste/arquivo/b'), findsOneWidget);
  });

  testWidgets('foto passa sozinha em 5 s', (tester) async {
    await _abrir(tester,
        _Servidor([_story('a', nome: 'Ana'), _story('b', nome: 'Leo')]));
    await tester.tap(find.text('Ana'));
    await _assentar(tester);

    await tester.pump(const Duration(seconds: 4));
    expect(_naTela('Ana'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    await _assentar(tester);
    expect(_naTela('Leo'), findsOneWidget);
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
    expect(_naTela('Leo'), findsOneWidget);
  });

  testWidgets('arrastar para baixo fecha', (tester) async {
    await _abrir(tester, _Servidor([_story('a', nome: 'Ana')]));
    await tester.tap(find.text('Ana'));
    await _assentar(tester);

    await tester.fling(find.byType(TelaDeStories), const Offset(0, 400), 1500);
    await _assentar(tester);

    expect(find.byType(TelaDeStories), findsNothing);
  });

  testWidgets('pessoa vista perde o anel e vai para o fim da fileira',
      (tester) async {
    await _abrir(tester,
        _Servidor([_story('a', nome: 'Ana'), _story('b', nome: 'Leo')]));
    expect(_novo(tester, 'Ana'), isTrue);

    await tester.tap(find.text('Ana'));
    await _assentar(tester);
    await tester.tap(find.byTooltip('Fechar'));
    await _assentar(tester);

    expect(_novo(tester, 'Ana'), isFalse);
    expect(_novo(tester, 'Leo'), isTrue);

    // Continua vista depois de abrir a tela de novo, e quem falta ver vem
    // antes.
    await tester.pumpWidget(const SizedBox());
    await _abrir(tester,
        _Servidor([_story('a', nome: 'Ana'), _story('b', nome: 'Leo')]));
    expect(_novo(tester, 'Ana'), isFalse);
    expect(_fileira(tester), ['Leo', 'Ana']);
  });

  testWidgets('denunciar tira o story da tela e mostra o seguinte',
      (tester) async {
    final servidor = _Servidor([
      _story('a', nome: 'Ana'),
      _story('b', nome: 'Ana', criadoEm: '2026-10-17T21:06:00'),
    ]);
    await _abrir(tester, servidor);
    await tester.tap(find.text('Ana'));
    await _assentar(tester);

    await tester.tap(find.byTooltip('Mais'));
    await _assentar(tester);
    await tester.tap(find.text('Denunciar'));
    await _assentar(tester);

    final denuncia = servidor.doCaminho('/stories/a/denuncia').single;
    expect(denuncia.url.path,
        '/api/publico/apresentacoes/ABC123/stories/a/denuncia');
    expect(denuncia.headers['Authorization'], isNull);
    expect((jsonDecode(denuncia.body) as Map)['aparelho'], isNotEmpty);
    expect(find.text('Denúncia enviada.'), findsWidgets);
    expect(find.text('21:06'), findsOneWidget);
    expect(_barrinhas(tester), 1);
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

  testWidgets('foto usa a imagem do navegador se o download direto falhar',
      (tester) async {
    // Sem CORS no armazenamento ou com foto HEIC do iPhone, só a <img> do
    // navegador mostra a foto.
    await _abrir(tester, _Servidor([_story('a', nome: 'Ana')]));
    await tester.tap(find.text('Ana'));
    await _assentar(tester);

    final imagem = tester.widget<Image>(find.descendant(
        of: find.byType(TelaDeStories), matching: find.byType(Image)));
    expect((imagem.image as NetworkImage).webHtmlElementStrategy,
        WebHtmlElementStrategy.fallback);
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
    expect(find.text('Enviar'), findsOneWidget);
  });
}
