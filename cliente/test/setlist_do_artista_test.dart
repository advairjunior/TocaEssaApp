import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:toca_essa_app/dominio/modelos.dart';
import 'package:toca_essa_app/infraestrutura/api_toca_essa.dart';
import 'package:toca_essa_app/telas/setlist_do_artista.dart';

const _id = '33333333-3333-3333-3333-333333333333';

Map<String, Object?> _item(String id, String titulo, int ordem,
        {bool tocada = false, String? tom}) =>
    {
      'id': id,
      'apresentacaoId': _id,
      'titulo': titulo,
      'artista': 'Banda $id',
      'tom': tom,
      'tocada': tocada,
      'ordem': ordem,
    };

Map<String, Object?> _cifra(String url) => {
      'id': 'c1',
      'artistaId': '22222222-2222-2222-2222-222222222222',
      'musica': 'Velha Infância',
      'artista': 'Banda 2',
      'url': url,
      'fonte': 'Manual',
      'criadaEm': '2026-09-10T12:00:00Z',
      'atualizadaEm': '2026-09-10T12:00:00Z',
    };

const _cifraSalva = 'https://www.cifraclub.com.br/banda-2/velha-infancia/';

Future<List<http.Request>> _abrir(
  WidgetTester tester, {
  List<Map<String, Object?>>? itens,
  List<Uri>? abertas,
  bool comCifraSalva = true,
}) async {
  final requisicoes = <http.Request>[];
  final lista = itens ??
      [
        _item('1', 'Garota de Ipanema', 1, tocada: true),
        _item('2', 'Velha Infância', 2, tom: 'G'),
        _item('3', 'Evidências', 3),
      ];
  final cliente = MockClient((requisicao) async {
    requisicoes.add(requisicao);
    final caminho = requisicao.url.path;
    if (caminho.endsWith('/setlist')) {
      return http.Response(jsonEncode(lista), 200,
          headers: {'content-type': 'application/json; charset=utf-8'});
    }
    if (caminho.endsWith('/grupos-pedidos')) {
      return http.Response(
        jsonEncode([
          {
            'pedidoRepresentativoId': 'p1',
            'pedidoIds': ['p1', 'p2'],
            'apresentacaoId': _id,
            'musica': 'Evidências',
            'solicitantes': ['Ana', 'Beto'],
            'quantidadePedidos': 2,
            'status': 'Aceito',
            'criadoEm': '2026-09-10T12:00:00Z',
            'tipo': 'Musica',
          }
        ]),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    }
    if (caminho.endsWith('/tocada')) {
      final corpo = jsonDecode(requisicao.body) as Map<String, dynamic>;
      final item = lista.firstWhere((i) => caminho.contains('/${i['id']}/'));
      return http.Response(
        jsonEncode({...item, 'tocada': corpo['tocada']}),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    }
    if (caminho.endsWith('/cifras/consulta')) {
      return http.Response(
        jsonEncode({
          'cifra': comCifraSalva ? _cifra(_cifraSalva) : null,
          'urlPesquisa': 'https://www.google.com/search?q=cifra',
        }),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    }
    if (caminho.endsWith('/cifras') && requisicao.method == 'PUT') {
      final corpo = jsonDecode(requisicao.body) as Map<String, dynamic>;
      return http.Response(jsonEncode(_cifra(corpo['url'] as String)), 200,
          headers: {'content-type': 'application/json; charset=utf-8'});
    }
    if (requisicao.method == 'DELETE') return http.Response('', 204);
    return http.Response('[]', 200);
  });
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: SetlistDoArtista(
        api: ApiTocaEssa(cliente: cliente, enderecoBase: 'http://teste')
          ..definirTokenArtista('TOKEN'),
        apresentacao: Apresentacao(
          id: _id,
          nome: 'Show',
          data: DateTime(2026, 9, 10),
          local: 'Bar',
          codigo: 'ABC123',
          perfilArtistico: const PerfilArtistico(
              id: '22222222-2222-2222-2222-222222222222',
              nomeArtistico: 'Duo Aurora'),
          pedidosAbertos: true,
          status: StatusApresentacao.emAndamento,
          tipo: TipoApresentacao.publica,
        ),
        incorporada: true,
        abrirUrl: (url) async => abertas?.add(url),
        prepararAbertura: () => (url) async {
          if (url != null) abertas?.add(url);
        },
      ),
    ),
  ));
  await tester.pumpAndSettle();
  return requisicoes;
}

void main() {
  testWidgets('setlist mostra progresso, próxima e pedidos na fila',
      (tester) async {
    await _abrir(tester);

    expect(find.byType(Card), findsNothing);
    expect(find.byType(Checkbox), findsNothing);
    expect(find.text('1 de 3 tocadas'), findsOneWidget);
    expect(find.text('Trocar repertório'), findsOneWidget);
    expect(find.text('Próxima'), findsOneWidget);
    expect(find.text('Banda 2 · Tom G'), findsOneWidget);
    expect(find.text('2 pedidos na fila'), findsOneWidget);
  });

  testWidgets('tocar na linha marca a música como tocada', (tester) async {
    final requisicoes = await _abrir(tester);

    await tester.tap(find.text('Velha Infância'));
    await tester.pumpAndSettle();

    final marcacao = requisicoes.singleWhere((r) => r.method == 'PATCH');
    expect(marcacao.url.path, '/api/apresentacoes/$_id/setlist/2/tocada');
    expect(marcacao.body, contains('"tocada":true'));
    expect(find.text('2 de 3 tocadas'), findsOneWidget);
  });

  testWidgets('linha da música é anunciada como marcável', (tester) async {
    final semantica = tester.ensureSemantics();
    await _abrir(tester);

    expect(
      tester.getSemantics(find.text('Garota de Ipanema')),
      containsSemantics(hasCheckedState: true, isChecked: true),
    );
    semantica.dispose();
  });

  testWidgets('cifra já salva pode ser trocada pela setlist', (tester) async {
    final requisicoes = await _abrir(tester);

    await tester.tap(find.byTooltip('Escolher ou trocar cifra').at(1));
    await tester.pumpAndSettle();

    expect(find.text('Escolher cifra'), findsOneWidget);
    expect(find.text(_cifraSalva), findsOneWidget);

    const nova = 'https://www.cifras.com.br/cifra/banda-2/velha-infancia';
    await tester.enterText(find.byType(TextField), nova);
    await tester.tap(find.text('Confirmar cifra'));
    await tester.pumpAndSettle();

    final salvamento = requisicoes.singleWhere((r) => r.method == 'PUT');
    expect(salvamento.url.path, '/api/artista/cifras');
    expect(salvamento.body, contains(nova));
    expect(salvamento.body, contains('Velha Infância'));
    expect(find.text('Cifra salva.'), findsOneWidget);
  });

  testWidgets('link da cifra pode ser removido pela setlist', (tester) async {
    final requisicoes = await _abrir(tester);

    await tester.tap(find.byTooltip('Escolher ou trocar cifra').at(1));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remover link'));
    await tester.pumpAndSettle();

    final remocao = requisicoes.singleWhere((r) => r.method == 'DELETE');
    expect(remocao.url.path, '/api/artista/cifras/c1');
    expect(find.text('Link da cifra removido.'), findsOneWidget);
  });

  testWidgets('barra fixa mostra a próxima música para tocar', (tester) async {
    await _abrir(tester);

    expect(find.text('Próxima: Velha Infância'), findsOneWidget);
    expect(find.text('Tocar'), findsOneWidget);
  });

  testWidgets('cifra da próxima música é buscada antes do toque',
      (tester) async {
    final requisicoes = await _abrir(tester);

    final consultas =
        requisicoes.where((r) => r.url.path.endsWith('/cifras/consulta'));
    expect(consultas.single.url.queryParameters['musica'], 'Velha Infância');
  });

  testWidgets('tocar abre a cifra da próxima e marca como tocada',
      (tester) async {
    final abertas = <Uri>[];
    final requisicoes = await _abrir(tester, abertas: abertas);

    await tester.tap(find.text('Tocar'));
    await tester.pumpAndSettle();

    expect(abertas, [Uri.parse(_cifraSalva)]);
    final marcacao = requisicoes.singleWhere((r) => r.method == 'PATCH');
    expect(marcacao.url.path, '/api/apresentacoes/$_id/setlist/2/tocada');
    expect(marcacao.body, contains('"tocada":true'));
    expect(find.text('2 de 3 tocadas'), findsOneWidget);
    expect(find.text('Próxima: Evidências'), findsOneWidget);
  });

  testWidgets('desfazer volta a música para a próxima', (tester) async {
    final requisicoes = await _abrir(tester, abertas: []);

    await tester.tap(find.text('Tocar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Desfazer'));
    await tester.pumpAndSettle();

    final desmarcacao = requisicoes.where((r) => r.method == 'PATCH').last;
    expect(desmarcacao.url.path, '/api/apresentacoes/$_id/setlist/2/tocada');
    expect(desmarcacao.body, contains('"tocada":false'));
    expect(find.text('1 de 3 tocadas'), findsOneWidget);
    expect(find.text('Próxima: Velha Infância'), findsOneWidget);
  });

  testWidgets('próxima sem cifra salva marca e oferece escolher a cifra',
      (tester) async {
    final abertas = <Uri>[];
    final requisicoes =
        await _abrir(tester, abertas: abertas, comCifraSalva: false);

    await tester.tap(find.text('Tocar'));
    await tester.pumpAndSettle();

    expect(abertas, isEmpty);
    expect(requisicoes.where((r) => r.method == 'PATCH'), hasLength(1));
    expect(find.text('Escolher cifra'), findsOneWidget);
  });

  testWidgets('setlist completa não mostra a barra de próxima', (tester) async {
    await _abrir(tester, itens: [
      _item('1', 'Garota de Ipanema', 1, tocada: true),
    ]);

    expect(find.text('Tocar'), findsNothing);
  });

  testWidgets('sem repertório, convida a importar', (tester) async {
    await _abrir(tester, itens: []);

    expect(find.text('Nenhum repertório nesta apresentação'), findsOneWidget);
    expect(find.text('Importar repertório'), findsOneWidget);
  });

  testWidgets('setlist cabe em celular de 360px', (tester) async {
    addTearDown(tester.view.reset);
    tester.view.devicePixelRatio = 3;
    tester.view.physicalSize = const Size(360, 740) * 3;
    await _abrir(tester);

    expect(tester.takeException(), isNull);
  });
}
