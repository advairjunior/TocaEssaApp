import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_guitar_chord/flutter_guitar_chord.dart';
import 'package:toca_essa_app/infraestrutura/api_toca_essa.dart';
import 'package:toca_essa_app/telas/leitor_de_cifras.dart';
import 'package:toca_essa_app/telas/sequencia_do_palco.dart';
import 'package:toca_essa_app/tema/tema_toca_essa.dart';

import 'apoio/pedidos_a_seguir_falsos.dart';

const _id = '44444444-4444-4444-4444-444444444444';
const _json = {'content-type': 'application/json; charset=utf-8'};
const _cifraVelha = 'G    D\nQuando eu digo que deixei de te amar\nEm   C\nÉ porque eu te amo';
const _linkEvidencias = 'https://www.cifraclub.com.br/banda/evidencias/';

Map<String, Object?> _item(String id, String titulo, int ordem,
        {bool tocada = false, String? tom}) =>
    {
      'id': id,
      'apresentacaoId': _id,
      'titulo': titulo,
      'artista': 'Banda',
      'tom': tom,
      'tocada': tocada,
      'ordem': ordem,
    };

class _Palco {
  final requisicoes = <http.Request>[];
  final abertas = <Uri>[];
  var telaAcesa = 0;
  // música → texto colado no servidor falso
  final textos = <String, String>{'Velha Infância': _cifraVelha};
  final itens = [
    _item('1', 'Garota de Ipanema', 1, tocada: true),
    _item('2', 'Velha Infância', 2, tom: 'G'),
    _item('3', 'Evidências', 3),
  ];
}

Future<_Palco> _abrir(WidgetTester tester,
    {String inicial = '2', String? cifraDaVelha}) async {
  final palco = _Palco();
  if (cifraDaVelha != null) palco.textos['Velha Infância'] = cifraDaVelha;
  final cliente = MockClient((requisicao) async {
    palco.requisicoes.add(requisicao);
    final sequencia = responderPedidosASeguir(requisicao, []);
    if (sequencia != null) return sequencia;
    final caminho = requisicao.url.path;
    if (caminho.endsWith('/setlist')) {
      return http.Response(jsonEncode(palco.itens), 200, headers: _json);
    }
    if (caminho.endsWith('/tocada')) {
      final corpo = jsonDecode(requisicao.body) as Map<String, dynamic>;
      final indice =
          palco.itens.indexWhere((i) => caminho.contains('/${i['id']}/'));
      palco.itens[indice] = {...palco.itens[indice], 'tocada': corpo['tocada']};
      return http.Response(jsonEncode(palco.itens[indice]), 200,
          headers: _json);
    }
    if (caminho.endsWith('/cifras/texto')) {
      final corpo = jsonDecode(requisicao.body) as Map<String, dynamic>;
      palco.textos[corpo['musica'] as String] = corpo['texto'] as String;
    }
    if (caminho.endsWith('/cifras/consulta') ||
        caminho.endsWith('/cifras/texto')) {
      final musica = requisicao.method == 'PUT'
          ? (jsonDecode(requisicao.body) as Map<String, dynamic>)['musica']
          : requisicao.url.queryParameters['musica'];
      return http.Response(
        jsonEncode({
          'cifra': musica == 'Evidências'
              ? {
                  'id': 'c1',
                  'artistaId': 'a',
                  'musica': musica,
                  'artista': 'Banda',
                  'url': _linkEvidencias,
                  'fonte': 'cifraclub.com.br',
                  'criadaEm': '2026-10-13T12:00:00Z',
                  'atualizadaEm': '2026-10-13T12:00:00Z',
                }
              : null,
          'urlPesquisa': 'https://www.google.com/search?q=cifra',
          'texto': palco.textos[musica],
        }),
        200,
        headers: _json,
      );
    }
    return http.Response('[]', 200, headers: _json);
  });
  final api = ApiTocaEssa(cliente: cliente, enderecoBase: 'http://teste')
    ..definirTokenArtista('TOKEN');
  final sequencia = SequenciaDoPalco(api: api, apresentacaoId: _id);
  await tester.runAsync(sequencia.carregar);
  await tester.runAsync(() => sequencia.buscarCifras());
  final musica = MusicaDoPalco.doSetlist(
      sequencia.itens.singleWhere((i) => i.id == inicial));
  await tester.pumpWidget(MaterialApp(
    home: LeitorDeCifras(
      sequencia: sequencia,
      musicaInicial: musica,
      abrirUrl: (url) async => palco.abertas.add(url),
      manterTelaAcesa: () {
        palco.telaAcesa++;
        return () {};
      },
    ),
  ));
  await tester.pumpAndSettle();
  return palco;
}

Iterable<http.Request> _marcacoes(_Palco palco) =>
    palco.requisicoes.where((r) => r.url.path.endsWith('/tocada'));

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('abre na música com a cifra colada, o tom e a próxima',
      (tester) async {
    final palco = await _abrir(tester);

    expect(find.text('Velha Infância'), findsOneWidget);
    expect(find.text('Tom G'), findsOneWidget);
    expect(find.text('Quando eu digo que deixei de te amar'), findsOneWidget);
    expect(find.text('Depois: Evidências'), findsOneWidget);
    expect(find.text('Tocar'), findsOneWidget);
    expect(palco.telaAcesa, 1);
  });

  testWidgets('linhas de acordes aparecem em destaque', (tester) async {
    await _abrir(tester);

    final acordes = tester.widget<Text>(find.text('G    D'));
    final letra =
        tester.widget<Text>(find.text('Quando eu digo que deixei de te amar'));
    expect(acordes.style?.color, CoresTocaEssa.roxoClaro);
    expect(letra.style?.color, isNot(CoresTocaEssa.roxoClaro));
  });

  testWidgets('setas trocam de música sem marcar nada', (tester) async {
    final palco = await _abrir(tester);

    await tester.tap(find.byTooltip('Próxima música'));
    await tester.pumpAndSettle();
    expect(find.text('Evidências'), findsOneWidget);
    expect(find.text('Sem cifra no app'), findsOneWidget);

    await tester.tap(find.byTooltip('Música anterior'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Música anterior'));
    await tester.pumpAndSettle();
    expect(find.text('Garota de Ipanema'), findsOneWidget);

    expect(_marcacoes(palco), isEmpty);
  });

  testWidgets('pedal ou teclado vira a página', (tester) async {
    await _abrir(tester);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(find.text('Evidências'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.pageUp);
    await tester.pumpAndSettle();
    expect(find.text('Velha Infância'), findsOneWidget);
  });

  testWidgets('tocar marca a música e o botão mostra que está tocando',
      (tester) async {
    final palco = await _abrir(tester);

    await tester.tap(find.text('Tocar'));
    await tester.pumpAndSettle();

    expect(_marcacoes(palco).single.url.path,
        '/api/apresentacoes/$_id/setlist/2/tocada');
    expect(find.text('Tocando ✓'), findsOneWidget);

    await tester.tap(find.byTooltip('Próxima música'));
    await tester.pumpAndSettle();
    expect(find.text('Tocar'), findsOneWidget);
    await tester.tap(find.byTooltip('Música anterior'));
    await tester.pumpAndSettle();
    expect(find.text('Tocando ✓'), findsOneWidget);
  });

  testWidgets('sem cifra colada, abre o link do site', (tester) async {
    final palco = await _abrir(tester, inicial: '3');

    await tester.tap(find.text('Abrir no site'));
    await tester.pumpAndSettle();

    expect(palco.abertas, [Uri.parse(_linkEvidencias)]);
  });

  testWidgets('colar a cifra salva no servidor e já mostra', (tester) async {
    final palco = await _abrir(tester, inicial: '3');

    await tester.tap(find.text('Colar cifra'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byType(TextField), 'A    E\nChego a mudar de calçada');
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();

    final salvo = palco.requisicoes
        .singleWhere((r) => r.url.path.endsWith('/cifras/texto'));
    expect(jsonDecode(salvo.body), {
      'musica': 'Evidências',
      'artista': 'Banda',
      'texto': 'A    E\nChego a mudar de calçada',
    });
    expect(find.text('Chego a mudar de calçada'), findsOneWidget);
  });

  testWidgets('lápis corrige a cifra que já existe', (tester) async {
    await _abrir(tester);

    await tester.tap(find.byTooltip('Colar ou corrigir cifra'));
    await tester.pumpAndSettle();

    expect(find.text(_cifraVelha), findsOneWidget);
  });

  group('desenho do acorde', () {
    Future<void> tocarNoComecoDe(WidgetTester tester, String linha) async {
      final caixa = tester.getRect(find.text(linha));
      await tester.tapAt(caixa.centerLeft + const Offset(2, 0));
      await tester.pumpAndSettle();
    }

    testWidgets('tocar no acorde mostra o desenho e outras posições',
        (tester) async {
      await _abrir(tester);

      await tocarNoComecoDe(tester, 'G    D');

      expect(find.byType(FlutterGuitarChord), findsOneWidget);
      expect(find.text('G'), findsWidgets);
      expect(find.textContaining('1 de '), findsOneWidget);
      await tester.tap(find.byTooltip('Próxima posição'));
      await tester.pumpAndSettle();
      expect(find.textContaining('2 de '), findsOneWidget);
    });

    testWidgets('com o tom trocado, o desenho é do acorde na tela',
        (tester) async {
      await _abrir(tester);
      await tester.tap(find.byTooltip('Subir meio tom'));
      await tester.pumpAndSettle();

      await tocarNoComecoDe(tester, 'G#   D#');

      expect(
          tester
              .widget<FlutterGuitarChord>(find.byType(FlutterGuitarChord))
              .chordName,
          'G#');
    });

    testWidgets('tocar na letra não abre nada', (tester) async {
      await _abrir(tester);

      await tocarNoComecoDe(tester, 'Quando eu digo que deixei de te amar');

      expect(find.byType(FlutterGuitarChord), findsNothing);
    });
  });

  group('trocar de tom', () {
    testWidgets('subir meio tom muda acordes e tom, não a letra',
        (tester) async {
      await _abrir(tester);

      await tester.tap(find.byTooltip('Subir meio tom'));
      await tester.pumpAndSettle();

      expect(find.text('G#   D#'), findsOneWidget);
      expect(find.text('Tom G# (+1)'), findsOneWidget);
      expect(find.text('Quando eu digo que deixei de te amar'), findsOneWidget);
    });

    testWidgets('descer dois semitons', (tester) async {
      await _abrir(tester);

      await tester.tap(find.byTooltip('Baixar meio tom'));
      await tester.tap(find.byTooltip('Baixar meio tom'));
      await tester.pumpAndSettle();

      expect(find.text('F    C'), findsOneWidget);
      expect(find.text('Tom F (-2)'), findsOneWidget);
    });

    testWidgets('o tom escolhido fica guardado para a música',
        (tester) async {
      await _abrir(tester);
      await tester.tap(find.byTooltip('Subir meio tom'));
      await tester.pumpAndSettle();

      // Outra música começa no tom original.
      await tester.tap(find.byTooltip('Próxima música'));
      await tester.pumpAndSettle();
      expect(find.textContaining('(+'), findsNothing);

      // Reabrir o leitor mantém o tom escolhido na música.
      await tester.pumpWidget(const SizedBox());
      await _abrir(tester);
      expect(find.text('G#   D#'), findsOneWidget);
    });
  });

  group('rolagem automática', () {
    final cifraLonga = [
      for (var verso = 1; verso <= 60; verso++) ...['G    D', 'Verso $verso'],
    ].join('\n');

    double rolagem(WidgetTester tester) => tester
        .state<ScrollableState>(find.byType(Scrollable).first)
        .position
        .pixels;

    testWidgets('▶ rola a cifra e um toque na cifra pausa', (tester) async {
      await _abrir(tester, cifraDaVelha: cifraLonga);

      await tester.tap(find.byTooltip('Rolar automaticamente'));
      await tester.pump(const Duration(seconds: 3));
      final rolou = rolagem(tester);
      expect(rolou, greaterThan(0));
      expect(find.text('1x'), findsOneWidget);

      await tester.tap(find.text('Verso 3'), warnIfMissed: false);
      await tester.pump(const Duration(seconds: 3));
      final parada = rolagem(tester);
      await tester.pump(const Duration(seconds: 3));
      expect(rolagem(tester), parada);
      expect(find.byTooltip('Rolar automaticamente'), findsOneWidget);
    });

    testWidgets('mais rápido rola mais e a velocidade fica guardada',
        (tester) async {
      await _abrir(tester, cifraDaVelha: cifraLonga);

      await tester.tap(find.byTooltip('Rolar automaticamente'));
      await tester.pump();
      await tester.tap(find.byTooltip('Mais rápido'));
      await tester.pump();
      expect(find.text('2x'), findsOneWidget);
      await tester.pump(const Duration(seconds: 2));
      expect(rolagem(tester), greaterThan(0));

      await tester.tap(find.byTooltip('Pausar rolagem'));
      await tester.pump();
      final preferencias = await SharedPreferences.getInstance();
      expect(preferencias.getInt('leitor_velocidade'), 2);
    });

    testWidgets('trocar de música pausa e volta ao topo', (tester) async {
      await _abrir(tester, cifraDaVelha: cifraLonga);
      await tester.tap(find.byTooltip('Rolar automaticamente'));
      await tester.pump(const Duration(seconds: 3));

      await tester.tap(find.byTooltip('Música anterior'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Próxima música'));
      await tester.pumpAndSettle();

      expect(rolagem(tester), 0);
      expect(find.byTooltip('Rolar automaticamente'), findsOneWidget);
    });
  });

  testWidgets('pinça aumenta a letra e o tamanho fica guardado',
      (tester) async {
    await _abrir(tester);
    double tamanho() =>
        tester.widget<Text>(find.text('É porque eu te amo')).style!.fontSize!;
    final antes = tamanho();

    final centro = tester.getCenter(find.text('Quando eu digo que deixei de te amar'));
    final um = await tester.startGesture(centro - const Offset(20, 0), pointer: 1);
    final dois = await tester.startGesture(centro + const Offset(20, 0), pointer: 2);
    await tester.pump();
    for (var passo = 0; passo < 5; passo++) {
      await um.moveBy(const Offset(-10, 0));
      await dois.moveBy(const Offset(10, 0));
      await tester.pump();
    }
    await um.up();
    await dois.up();
    await tester.pumpAndSettle();

    expect(tamanho(), greaterThan(antes));
    final preferencias = await SharedPreferences.getInstance();
    expect(preferencias.getDouble('leitor_escala'), greaterThan(1));
    // Letra grande quebra a linha em vez de sumir pela direita.
    expect(find.text('Quando eu digo que deixei de te amar'), findsNothing);
    expect(find.text('Quando eu digo que'), findsOneWidget);
    expect(find.text('deixei de te amar'), findsOneWidget);
    expect(
        find.byWidgetPredicate((w) =>
            w is SingleChildScrollView && w.scrollDirection == Axis.horizontal),
        findsNothing);
  });

  test('reconhece linhas de acordes de uma cifra real do Cifra Club', () {
    for (final acordes in [
      'E               C#m  C#9',
      ' A   B         E  B',
      '( E  C#m  C#9 )',
      '[Intro] E9  C#m  C#9',
      '        E9  C#m  C#9',
      'F#m                      B',
      'A',
    ]) {
      expect(linhaDeAcordes(acordes), isTrue, reason: acordes);
    }
    for (final letra in [
      '  Nunca vi ninguém',
      'Deus e eu no sertão',
      'E|-4-7---4----------------------------------| ',
      'Tom:  E',
      '[Primeira Parte]',
      'Em casa',
    ]) {
      expect(linhaDeAcordes(letra), isFalse, reason: letra);
    }
  });

  test('a fonte se ajusta para a linha mais larga caber na tela', () {
    expect(tamanhoDaFonteDaCifra(largura: 300, maiorLinha: 50), 10);
    expect(tamanhoDaFonteDaCifra(largura: 300, maiorLinha: 25), 20);
    expect(tamanhoDaFonteDaCifra(largura: 900, maiorLinha: 10), 24);
  });

  testWidgets('leitor cabe em celular de 360px', (tester) async {
    addTearDown(tester.view.reset);
    tester.view.devicePixelRatio = 3;
    tester.view.physicalSize = const Size(360, 740) * 3;

    await _abrir(tester);

    expect(tester.takeException(), isNull);
  });
}
