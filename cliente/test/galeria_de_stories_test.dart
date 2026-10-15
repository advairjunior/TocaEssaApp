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
        String criadoEm = '2026-10-17T21:04:00',
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

Future<List<StoryDoShow>> _abrir(WidgetTester tester, _Servidor servidor,
    {Widget? acima}) async {
  final salvos = <StoryDoShow>[];
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: Column(
        children: [
          if (acima != null) acima,
          StoriesDoArtista(
            api: _api(servidor),
            apresentacaoId: 'show-1',
            salvar: (_, story) async => salvos.add(story),
          ),
        ],
      ),
    ),
  ));
  await _assentar(tester);
  return salvos;
}

Finder _naTela(String texto) =>
    find.descendant(of: find.byType(TelaDeStories), matching: find.text(texto));

Future<void> _menu(WidgetTester tester, String opcao) async {
  await tester.tap(find.byTooltip('Mais'));
  await _assentar(tester);
  await tester.tap(find.text(opcao));
  await _assentar(tester);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('fileira compacta com postar e uma bolinha por pessoa',
      (tester) async {
    final servidor = _Servidor([
      _envio('a', nome: 'Ana'),
      _envio('b'),
      _envio('c', nome: 'Ana'),
      _envio('d', nome: 'Duo Aurora', doArtista: true),
    ]);
    await _abrir(tester, servidor);

    final lista = servidor.doCaminho('GET', '/envios').single;
    expect(lista.url.path, '/api/apresentacoes/show-1/envios');
    expect(lista.headers['Authorization'], 'Bearer TOKEN');
    expect(find.text('Postar'), findsOneWidget);
    expect(
        tester
            .widgetList<BolinhaDeStory>(find.byType(BolinhaDeStory))
            .map((bolinha) => bolinha.grupo.nome),
        ['Duo Aurora', 'Ana', 'Público']);
    // Uma fileira só, da altura de uma bolinha.
    expect(tester.getSize(find.byType(StoriesDoArtista)).height,
        lessThan(120));
  });

  testWidgets('sem stories mostra só o postar', (tester) async {
    await _abrir(tester, _Servidor([]));

    expect(find.byType(BolinhaDeStory), findsNothing);
    expect(find.text('Postar'), findsOneWidget);
  });

  testWidgets('tela cheia mostra quanto falta para sumir', (tester) async {
    await _abrir(tester, _Servidor([_envio('a', nome: 'Ana')]));

    await tester.tap(find.text('Ana'));
    await _assentar(tester);

    expect(find.text('some em 6 dias'), findsOneWidget);
  });

  testWidgets('apagar continua no story seguinte', (tester) async {
    final servidor = _Servidor([
      _envio('a', nome: 'Ana'),
      _envio('b', nome: 'Ana', criadoEm: '2026-10-17T21:06:00'),
      _envio('c', nome: 'Leo'),
    ]);
    await _abrir(tester, servidor);
    await tester.tap(find.text('Ana'));
    await _assentar(tester);

    await _menu(tester, 'Apagar');
    await tester.tap(find.widgetWithText(FilledButton, 'Apagar'));
    await _assentar(tester);
    await _assentar(tester);

    final apagar = servidor.doCaminho('DELETE', '/envios/a').single;
    expect(apagar.url.path, '/api/apresentacoes/show-1/envios/a');
    expect(apagar.headers['Authorization'], 'Bearer TOKEN');
    expect(find.byType(TelaDeStories), findsOneWidget);
    expect(_naTela('Ana'), findsOneWidget);
    expect(find.text('21:06'), findsOneWidget);

    // O último da pessoa apagado leva à próxima pessoa.
    await _menu(tester, 'Apagar');
    await tester.tap(find.widgetWithText(FilledButton, 'Apagar'));
    await _assentar(tester);
    await _assentar(tester);
    expect(_naTela('Leo'), findsOneWidget);

    // Apagar o único que sobrou fecha e a fileira fica vazia.
    await _menu(tester, 'Apagar');
    await tester.tap(find.widgetWithText(FilledButton, 'Apagar'));
    await _assentar(tester);
    await _assentar(tester);
    expect(find.byType(TelaDeStories), findsNothing);
    expect(find.byType(BolinhaDeStory), findsNothing);
  });

  testWidgets('cancelar o apagar não apaga', (tester) async {
    final servidor = _Servidor([_envio('a', nome: 'Ana')]);
    await _abrir(tester, servidor);
    await tester.tap(find.text('Ana'));
    await _assentar(tester);

    await _menu(tester, 'Apagar');
    await tester.tap(find.text('Cancelar'));
    await _assentar(tester);

    expect(servidor.doCaminho('DELETE', '/envios/a'), isEmpty);
    expect(_naTela('Ana'), findsOneWidget);
  });

  testWidgets('escondido aparece marcado e volta ao público na hora',
      (tester) async {
    final servidor = _Servidor([_envio('a', nome: 'Ana', escondido: true)]);
    await _abrir(tester, servidor);
    expect(find.byTooltip('Escondido por denúncias'), findsOneWidget);

    await tester.tap(find.text('Ana'));
    await _assentar(tester);
    expect(_naTela('Escondido'), findsOneWidget);
    await _menu(tester, 'Mostrar de novo');

    final mostrar = servidor.doCaminho('POST', '/mostrar').single;
    expect(mostrar.url.path, '/api/apresentacoes/show-1/envios/a/mostrar');
    expect(mostrar.headers['Authorization'], 'Bearer TOKEN');
    expect(_naTela('Escondido'), findsNothing);
    await tester.tap(find.byTooltip('Mais'));
    await _assentar(tester);
    expect(find.text('Mostrar de novo'), findsNothing);
    await tester.tapAt(Offset.zero);
    await _assentar(tester);

    await tester.tap(find.byTooltip('Fechar'));
    await _assentar(tester);
    expect(find.byTooltip('Escondido por denúncias'), findsNothing);
  });

  testWidgets('menu do artista: salvar e apagar, sem denunciar',
      (tester) async {
    await _abrir(tester, _Servidor([_envio('a', nome: 'Ana')]));
    await tester.tap(find.text('Ana'));
    await _assentar(tester);
    await tester.tap(find.byTooltip('Mais'));
    await _assentar(tester);

    expect(find.text('Salvar no celular'), findsOneWidget);
    expect(find.text('Apagar'), findsOneWidget);
    expect(find.text('Mostrar de novo'), findsNothing);
    expect(find.text('Denunciar'), findsNothing);
  });

  testWidgets('salvar no celular entrega o story aberto', (tester) async {
    final servidor =
        _Servidor([_envio('a', nome: 'Ana'), _envio('b', nome: 'Leo')]);
    final salvos = await _abrir(tester, servidor);
    await tester.tap(find.text('Leo'));
    await _assentar(tester);

    await _menu(tester, 'Salvar no celular');

    expect(salvos.map((story) => story.id), ['b']);
    expect(find.byType(TelaDeStories), findsOneWidget);
  });

  testWidgets('selo conta os stories do público ainda não assistidos',
      (tester) async {
    final servidor = _Servidor([
      _envio('a', nome: 'Ana'),
      _envio('b', nome: 'Leo'),
      _envio('c', doArtista: true),
    ]);
    final selo = IconeDosStoriesNovos(
      api: _api(servidor),
      apresentacaoId: 'show-1',
      icone: const Icon(Icons.more_horiz_rounded),
    );
    Badge badge() => tester.widget<Badge>(find.byType(Badge));

    await _abrir(tester, servidor, acima: selo);
    expect(find.text('2'), findsOneWidget);

    // Assistir a Ana desconta um; só abrir a aba não zera.
    await tester.tap(find.text('Ana'));
    await _assentar(tester);
    await tester.tap(find.byTooltip('Fechar'));
    await _assentar(tester);
    expect(find.text('1'), findsOneWidget);

    await tester.tap(find.text('Leo'));
    await _assentar(tester);
    await tester.tap(find.byTooltip('Fechar'));
    await _assentar(tester);
    expect(badge().isLabelVisible, isFalse);

    // Com o painel aberto, o selo se atualiza sozinho.
    servidor.envios = [...servidor.envios, _envio('d', nome: 'Bia')];
    await tester.pump(const Duration(minutes: 1));
    await _assentar(tester);
    expect(find.text('1'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
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

    expect(find.byType(BolinhaDeStory), findsNothing);
    expect(find.byType(SnackBar), findsNothing);
    expect(find.text('Postar'), findsOneWidget);
  });
}
