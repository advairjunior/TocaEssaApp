import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:toca_essa_app/infraestrutura/api_toca_essa.dart';
import 'package:toca_essa_app/telas/stories_do_show.dart';

const _json = {'content-type': 'application/json; charset=utf-8'};

Map<String, dynamic> _envio(String id,
        {String? nome,
        bool escondido = false,
        bool doArtista = false,
        String criadoEm = '2026-10-17T21:04:00Z',
        Duration expiraEm = const Duration(days: 6, hours: 1)}) =>
    {
      'id': id,
      'tipo': 'Foto',
      'nome': nome,
      'criadoEm': criadoEm,
      'expiraEm': DateTime.now().add(expiraEm).toUtc().toIso8601String(),
      'escondido': escondido,
      'tipoDeConteudo': 'image/jpeg',
      'doArtista': doArtista,
      'url': 'http://teste/arquivo/$id',
    };

class _Servidor {
  _Servidor(this.envios);
  List<Map<String, dynamic>> envios;
  final requisicoes = <http.Request>[];

  late final cliente = MockClient((requisicao) async {
    requisicoes.add(requisicao);
    final caminho = requisicao.url.path;
    if (requisicao.method == 'GET' && caminho.endsWith('/envios')) {
      return http.Response(jsonEncode(envios), 200, headers: _json);
    }
    if (requisicao.method == 'DELETE') {
      envios = envios.where((e) => !caminho.endsWith('/${e['id']}')).toList();
      return http.Response('', 204);
    }
    if (caminho.endsWith('/mostrar')) {
      for (final envio in envios) {
        if (caminho.contains('/${envio['id']}/')) envio['escondido'] = false;
      }
      return http.Response('', 204);
    }
    return http.Response('', 404);
  });

  Iterable<http.Request> doCaminho(String metodo, String fim) => requisicoes
      .where((r) => r.method == metodo && r.url.path.endsWith(fim));
}

ApiTocaEssa _api(_Servidor servidor) =>
    ApiTocaEssa(cliente: servidor.cliente, enderecoBase: 'http://teste')
      ..definirTokenArtista('TOKEN');

Future<void> _assentar(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 350));
}

Future<List<StoryDoShow>> _abrir(WidgetTester tester, _Servidor servidor) async {
  final salvos = <StoryDoShow>[];
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: StoriesDoArtista(
          api: _api(servidor),
          apresentacaoId: 'show-1',
          salvar: (_, story) async => salvos.add(story),
        ),
      ),
    ),
  ));
  await _assentar(tester);
  return salvos;
}

Future<void> _menu(WidgetTester tester, String nome, String opcao) async {
  await tester.tap(find.text(nome));
  await _assentar(tester);
  await tester.tap(find.byTooltip('Mais'));
  await _assentar(tester);
  await tester.tap(find.text(opcao));
  await _assentar(tester);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('lista os stories do show com o token do artista',
      (tester) async {
    final servidor = _Servidor([
      _envio('a', nome: 'Ana'),
      _envio('b'),
      _envio('c', nome: 'Duo Aurora', doArtista: true),
    ]);
    await _abrir(tester, servidor);

    final lista = servidor.doCaminho('GET', '/envios').single;
    expect(lista.url.path, '/api/apresentacoes/show-1/envios');
    expect(lista.headers['Authorization'], 'Bearer TOKEN');
    expect(find.byType(BlocoDeStory), findsNWidgets(3));
    expect(find.text('Ana'), findsOneWidget);
    expect(find.text('Público'), findsOneWidget);
    expect(find.text('Postar nos stories do show'), findsOneWidget);
  });

  testWidgets('sem stories mostra só o botão de postar', (tester) async {
    await _abrir(tester, _Servidor([]));

    expect(find.byType(BlocoDeStory), findsNothing);
    expect(find.text('Postar nos stories do show'), findsOneWidget);
  });

  testWidgets('tela cheia mostra quanto falta para sumir', (tester) async {
    await _abrir(tester, _Servidor([_envio('a', nome: 'Ana')]));

    await tester.tap(find.text('Ana'));
    await _assentar(tester);

    expect(find.text('some em 6 dias'), findsOneWidget);
  });

  testWidgets('apagar pede confirmação, apaga e some da grade',
      (tester) async {
    final servidor =
        _Servidor([_envio('a', nome: 'Ana'), _envio('b', nome: 'Leo')]);
    await _abrir(tester, servidor);

    await _menu(tester, 'Ana', 'Apagar');
    await tester.tap(find.widgetWithText(FilledButton, 'Apagar'));
    await _assentar(tester);
    await _assentar(tester);

    final apagar = servidor.doCaminho('DELETE', '/envios/a').single;
    expect(apagar.url.path, '/api/apresentacoes/show-1/envios/a');
    expect(apagar.headers['Authorization'], 'Bearer TOKEN');
    expect(find.byType(TelaDeStories), findsNothing);
    expect(find.byType(BlocoDeStory), findsOneWidget);
    expect(find.text('Ana'), findsNothing);
  });

  testWidgets('escondido por denúncia aparece marcado e volta ao público',
      (tester) async {
    final servidor = _Servidor([_envio('a', nome: 'Ana', escondido: true)]);
    await _abrir(tester, servidor);
    expect(find.text('Escondido'), findsOneWidget);

    await _menu(tester, 'Ana', 'Mostrar de novo');

    final mostrar = servidor.doCaminho('POST', '/mostrar').single;
    expect(mostrar.url.path, '/api/apresentacoes/show-1/envios/a/mostrar');
    expect(mostrar.headers['Authorization'], 'Bearer TOKEN');
    await tester.tap(find.byTooltip('Fechar'));
    await _assentar(tester);
    expect(find.text('Escondido'), findsNothing);
  });

  testWidgets('mostrar de novo só aparece no escondido', (tester) async {
    await _abrir(tester, _Servidor([_envio('a', nome: 'Ana')]));
    await tester.tap(find.text('Ana'));
    await _assentar(tester);
    await tester.tap(find.byTooltip('Mais'));
    await _assentar(tester);

    expect(find.text('Mostrar de novo'), findsNothing);
    expect(find.text('Denunciar'), findsNothing);
    expect(find.text('Salvar no celular'), findsOneWidget);
  });

  testWidgets('salvar no celular entrega o story escolhido', (tester) async {
    final servidor =
        _Servidor([_envio('a', nome: 'Ana'), _envio('b', nome: 'Leo')]);
    final salvos = await _abrir(tester, servidor);

    await _menu(tester, 'Leo', 'Salvar no celular');

    expect(salvos.map((story) => story.id), ['b']);
    expect(find.byType(TelaDeStories), findsOneWidget);
  });

  testWidgets('selo conta os stories do público chegados desde a visita',
      (tester) async {
    final servidor = _Servidor([
      _envio('a', nome: 'Ana', criadoEm: '2026-10-17T21:00:00Z'),
      _envio('b', nome: 'Leo', criadoEm: '2026-10-17T21:05:00Z'),
      _envio('c', doArtista: true, criadoEm: '2026-10-17T21:10:00Z'),
    ]);
    Future<void> mostrarSelo() async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: IconeDosStoriesNovos(
            api: _api(servidor),
            apresentacaoId: 'show-1',
            icone: const Icon(Icons.more_horiz_rounded),
          ),
        ),
      ));
      await _assentar(tester);
    }

    await mostrarSelo();
    expect(find.text('2'), findsOneWidget);

    // Abrir a galeria zera o selo.
    await _abrir(tester, servidor);
    await mostrarSelo();
    expect(find.byType(Badge), findsOneWidget);
    expect(find.text('2'), findsNothing);
    expect(tester.widget<Badge>(find.byType(Badge)).isLabelVisible, isFalse);

    servidor.envios = [
      ...servidor.envios,
      _envio('d', nome: 'Bia', criadoEm: '2026-10-17T21:20:00Z'),
    ];
    // Com o painel aberto, o selo se atualiza sozinho.
    await tester.pump(const Duration(minutes: 1));
    await _assentar(tester);
    expect(find.text('1'), findsOneWidget);
  });

  testWidgets('falha ao buscar não mostra erro', (tester) async {
    final api = ApiTocaEssa(
        cliente: MockClient((_) async => http.Response('', 500)),
        enderecoBase: 'http://teste');
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: StoriesDoArtista(api: api, apresentacaoId: 'show-1'),
      ),
    ));
    await _assentar(tester);

    expect(find.byType(BlocoDeStory), findsNothing);
    expect(find.byType(SnackBar), findsNothing);
    expect(find.text('Postar nos stories do show'), findsOneWidget);
  });
}
