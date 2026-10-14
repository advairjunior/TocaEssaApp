import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:toca_essa_app/dominio/modelos.dart';
import 'package:toca_essa_app/infraestrutura/api_toca_essa.dart';
import 'package:toca_essa_app/telas/componentes_palco.dart';
import 'package:toca_essa_app/telas/setlist_do_artista.dart';
import 'package:toca_essa_app/tema/tema_toca_essa.dart';

import 'apoio/pedidos_a_seguir_falsos.dart';

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

Map<String, Object?> _grupo(String id, String musica, String status,
        {int quantidade = 1}) =>
    {
      'pedidoRepresentativoId': id,
      'pedidoIds': [id],
      'apresentacaoId': _id,
      'musica': musica,
      'solicitantes': ['Ana'],
      'quantidadePedidos': quantidade,
      'status': status,
      'criadoEm': '2026-09-10T12:00:00Z',
      'tipo': 'Musica',
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

// Sequência "tocar a seguir" guardada no servidor falso.
var _aSeguirNoServidor = <String>[];

// Setlist guardada no servidor falso, para simular o celular do colega.
var _itensNoServidor = <Map<String, Object?>>[];

/// O colega marca a música como tocada no celular dele.
void _outroAparelhoTocou(String itemId) {
  final indice = _itensNoServidor.indexWhere((i) => i['id'] == itemId);
  _itensNoServidor[indice] = {..._itensNoServidor[indice], 'tocada': true};
}

Future<List<http.Request>> _abrir(
  WidgetTester tester, {
  List<Map<String, Object?>>? itens,
  List<Uri>? abertas,
  bool comCifraSalva = true,
  Set<String> musicasSemCifra = const {},
  Set<String> musicasComTexto = const {},
  List<Map<String, Object?>>? grupos,
  List<String> pedidosASeguir = const [],
  VoidCallback? abrirFila,
  StatusApresentacao status = StatusApresentacao.emAndamento,
  Map<String, Object?>? relogio,
}) async {
  _aSeguirNoServidor = [...pedidosASeguir];
  final requisicoes = <http.Request>[];
  final salvas = <String>{};
  // música → cifra colada no servidor falso
  final textos = {
    for (final musica in musicasComTexto) musica: 'G   D\nLetra de $musica',
  };
  final listaDeGrupos =
      grupos ?? [_grupo('p1', 'Evidências', 'Aceito', quantidade: 2)];
  final lista = _itensNoServidor = [
    ...itens ??
        [
          _item('1', 'Garota de Ipanema', 1, tocada: true),
          _item('2', 'Velha Infância', 2, tom: 'G'),
          _item('3', 'Evidências', 3),
        ],
  ];
  final cliente = MockClient((requisicao) async {
    requisicoes.add(requisicao);
    final sequencia = responderPedidosASeguir(requisicao, _aSeguirNoServidor);
    if (sequencia != null) return sequencia;
    final caminho = requisicao.url.path;
    if (caminho.endsWith('/relogio') && relogio != null) {
      return http.Response(jsonEncode(relogio), 200,
          headers: {'content-type': 'application/json; charset=utf-8'});
    }
    if (caminho.endsWith('/setlist')) {
      return http.Response(jsonEncode(lista), 200,
          headers: {'content-type': 'application/json; charset=utf-8'});
    }
    if (caminho.endsWith('/grupos-pedidos')) {
      return http.Response(jsonEncode(listaDeGrupos), 200,
          headers: {'content-type': 'application/json; charset=utf-8'});
    }
    if (caminho.contains('/grupos-pedidos/') && caminho.endsWith('/status')) {
      final corpo = jsonDecode(requisicao.body) as Map<String, dynamic>;
      final indice = listaDeGrupos.indexWhere(
          (g) => caminho.contains('/${g['pedidoRepresentativoId']}/'));
      listaDeGrupos[indice] = {
        ...listaDeGrupos[indice],
        'status': corpo['status'],
      };
      return http.Response(jsonEncode(listaDeGrupos[indice]), 200,
          headers: {'content-type': 'application/json; charset=utf-8'});
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
      final musica = requisicao.url.queryParameters['musica'];
      final temCifra = salvas.contains(musica) ||
          (comCifraSalva && !musicasSemCifra.contains(musica));
      return http.Response(
        jsonEncode({
          'cifra': temCifra ? _cifra(_cifraSalva) : null,
          'urlPesquisa': 'https://www.google.com/search?q=cifra',
          'texto': textos[musica],
        }),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    }
    if (caminho.endsWith('/cifras/texto')) {
      final corpo = jsonDecode(requisicao.body) as Map<String, dynamic>;
      textos[corpo['musica'] as String] = corpo['texto'] as String;
      // Como o servidor: o "Tom:" da cifra passa para a música da setlist.
      final tom = RegExp(r'^Tom: (\S+)', multiLine: true)
          .firstMatch(corpo['texto'] as String)
          ?.group(1);
      if (tom != null) {
        for (final (i, item) in lista.indexed.toList()) {
          if (item['titulo'] == corpo['musica']) lista[i] = {...item, 'tom': tom};
        }
      }
      return http.Response(
        jsonEncode({
          'cifra': null,
          'urlPesquisa': 'https://www.google.com/search?q=cifra',
          'texto': corpo['texto'],
        }),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    }
    if (caminho.endsWith('/cifras') && requisicao.method == 'PUT') {
      final corpo = jsonDecode(requisicao.body) as Map<String, dynamic>;
      salvas.add(corpo['musica'] as String);
      return http.Response(jsonEncode(_cifra(corpo['url'] as String)), 200,
          headers: {'content-type': 'application/json; charset=utf-8'});
    }
    const comoJson = {'content-type': 'application/json; charset=utf-8'};
    if (requisicao.method == 'DELETE' && caminho.endsWith('/setlist')) {
      lista.clear();
      return http.Response('', 204);
    }
    if (requisicao.method == 'DELETE' && caminho.contains('/setlist/')) {
      lista.removeWhere((i) => caminho.endsWith('/${i['id']}'));
      return http.Response(jsonEncode(lista), 200, headers: comoJson);
    }
    if (caminho.endsWith('/setlist/ordem')) {
      final ids = (jsonDecode(requisicao.body)['itemIds'] as List).cast<String>();
      final faltam = ids.map((id) => lista.firstWhere((i) => i['id'] == id));
      final fila = faltam.toList();
      final nova = [
        for (final item in lista) item['tocada'] == true ? item : fila.removeAt(0)
      ];
      lista
        ..clear()
        ..addAll(nova);
      return http.Response(jsonEncode(lista), 200, headers: comoJson);
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
          status: status,
          tipo: TipoApresentacao.publica,
        ),
        incorporada: true,
        abrirFila: abrirFila,
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
    expect(find.byTooltip('Montar setlist'), findsOneWidget);
    expect(find.text('Trocar repertório'), findsNothing);
    expect(find.text('Próxima'), findsOneWidget);
    expect(find.text('Banda 2 · Tom G'), findsOneWidget);
    expect(find.byTooltip('2 pedidos na fila'), findsOneWidget);
  });

  group('linha da música', () {
    testWidgets('tocar no círculo marca a música como tocada',
        (tester) async {
      final requisicoes = await _abrir(tester);

      await tester.tap(find.byTooltip('Marcar como tocada').first);
      await tester.pumpAndSettle();

      final marcacao = requisicoes.singleWhere((r) => r.method == 'PATCH');
      expect(marcacao.url.path, '/api/apresentacoes/$_id/setlist/2/tocada');
      expect(marcacao.body, contains('"tocada":true'));
      expect(find.text('2 de 3 tocadas'), findsOneWidget);
    });

    testWidgets('círculo é anunciado como marcável', (tester) async {
      final semantica = tester.ensureSemantics();
      await _abrir(tester);

      expect(
        tester.getSemantics(find.byTooltip('Desmarcar')),
        isSemantics(hasCheckedState: true, isChecked: true),
      );
      semantica.dispose();
    });

    testWidgets('tocar na música abre a cifra no leitor sem marcar',
        (tester) async {
      final requisicoes = await _abrir(tester);

      await tester.tap(find.text('Evidências').first);
      await tester.pumpAndSettle();

      expect(find.byTooltip('Fechar leitor'), findsOneWidget);
      expect(requisicoes.where((r) => r.method == 'PATCH'), isEmpty);
    });

    testWidgets('ponto mostra quais músicas têm cifra no app',
        (tester) async {
      await _abrir(tester, musicasComTexto: {'Velha Infância'});

      expect(find.byTooltip('Cifra no app'), findsOneWidget);
      expect(find.byTooltip('Sem cifra no app'), findsNWidgets(2));
    });

    testWidgets('deslizar mostra Cifra e Remover; tocada não sai',
        (tester) async {
      await _abrir(tester);

      await tester.drag(find.text('Velha Infância'), const Offset(-300, 0));
      await tester.pumpAndSettle();
      expect(find.text('Cifra'), findsOneWidget);
      expect(find.text('Remover'), findsOneWidget);

      await tester.drag(find.text('Garota de Ipanema'), const Offset(-300, 0));
      await tester.pumpAndSettle();
      expect(find.text('Remover'), findsNothing);
    });

    testWidgets('remover pelo deslizar tira a música da setlist',
        (tester) async {
      final requisicoes = await _abrir(tester);

      await tester.drag(find.text('Velha Infância'), const Offset(-300, 0));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remover'));
      await tester.pumpAndSettle();

      expect(requisicoes.where((r) => r.method == 'DELETE').single.url.path,
          '/api/apresentacoes/$_id/setlist/2');
      expect(find.text('Velha Infância'), findsNothing);
    });

    testWidgets('Cifra começa por colar a cifra no app', (tester) async {
      final requisicoes = await _abrir(tester);

      await tester.drag(find.text('Velha Infância'), const Offset(-300, 0));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cifra'));
      await tester.pumpAndSettle();
      expect(find.text('Colar ou corrigir cifra'), findsOneWidget);
      expect(find.text('Link do site'), findsOneWidget);

      await tester.tap(find.text('Colar ou corrigir cifra'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'C   G\nNova letra');
      await tester.tap(find.text('Salvar'));
      await tester.pumpAndSettle();

      final salva = requisicoes
          .singleWhere((r) => r.url.path.endsWith('/cifras/texto'));
      expect(jsonDecode(salva.body), {
        'musica': 'Velha Infância',
        'artista': 'Banda 2',
        'texto': 'C   G\nNova letra',
      });
      expect(find.byTooltip('Cifra no app'), findsOneWidget);
    });

    testWidgets('trocar o "Tom:" da cifra mostra o tom novo na linha',
        (tester) async {
      await _abrir(tester);
      expect(find.text('Banda 2 · Tom G'), findsOneWidget);

      await tester.drag(find.text('Velha Infância'), const Offset(-300, 0));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cifra'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Colar ou corrigir cifra'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Tom: A\nA   E\nLetra');
      await tester.tap(find.text('Salvar'));
      await tester.pumpAndSettle();

      expect(find.text('Banda 2 · Tom A'), findsOneWidget);
    });

    testWidgets('Link do site continua como opção', (tester) async {
      final requisicoes = await _abrir(tester);

      await tester.drag(find.text('Velha Infância'), const Offset(-300, 0));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cifra'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Link do site'));
      await tester.pumpAndSettle();

      expect(find.text('Escolher cifra'), findsOneWidget);
      const nova = 'https://www.cifras.com.br/cifra/banda-2/velha-infancia';
      await tester.enterText(find.byType(TextField), nova);
      await tester.tap(find.text('Confirmar cifra'));
      await tester.pumpAndSettle();

      final salvamento = requisicoes.singleWhere(
          (r) => r.method == 'PUT' && r.url.path == '/api/artista/cifras');
      expect(salvamento.body, contains(nova));
    });
  });

  group('visual no jeito do iPhone', () {
    testWidgets('barra Próxima é translúcida e a lista passa por trás',
        (tester) async {
      await _abrir(tester);

      final barra = find.byType(BarraProximaMusica);
      expect(find.descendant(of: barra, matching: find.byType(BackdropFilter)),
          findsOneWidget);
      // A lista ocupa a tela toda; a barra fica por cima, no rodapé.
      expect(
        find.ancestor(of: barra, matching: find.byType(Stack)),
        findsWidgets,
      );
    });

    testWidgets('a próxima se destaca pelo rótulo, sem fundo colorido',
        (tester) async {
      await _abrir(tester);

      final fundo = tester.widget<Material>(find
          .ancestor(
              of: find.text('Velha Infância'),
              matching: find.byType(Material))
          .first);
      expect(fundo.color, Colors.transparent);
      expect(find.text('Próxima'), findsOneWidget);
    });

    testWidgets('selo de pedidos na fila é discreto, sem roxo',
        (tester) async {
      await _abrir(tester);

      final numero = tester.widget<Text>(find.descendant(
          of: find.byTooltip('2 pedidos na fila'), matching: find.text('2')));
      expect(numero.style?.color, CoresTocaEssa.textoSecundario);
    });
  });

  testWidgets('barra fixa mostra a próxima música para tocar', (tester) async {
    await _abrir(tester);

    expect(find.text('Próxima: Velha Infância'), findsOneWidget);
    expect(find.text('Tocar'), findsOneWidget);
  });

  testWidgets('cifras do setlist são buscadas antes do toque', (tester) async {
    final requisicoes = await _abrir(tester);

    final consultadas = requisicoes
        .where((r) => r.url.path.endsWith('/cifras/consulta'))
        .map((r) => r.url.queryParameters['musica'])
        .toSet();
    expect(consultadas, {'Garota de Ipanema', 'Velha Infância', 'Evidências'});
  });

  group('aviso de músicas sem cifra', () {
    testWidgets('conta as que faltam tocar sem cifra no app e leva a colar',
        (tester) async {
      await _abrir(tester, musicasComTexto: {'Garota de Ipanema'});

      expect(find.text('2 músicas sem cifra'), findsOneWidget);
      await tester.tap(find.text('Colar'));
      await tester.pumpAndSettle();

      expect(find.text('Colar cifras'), findsOneWidget);
      expect(find.text('1 de 2'), findsOneWidget);
    });

    testWidgets('com todas as cifras no app, não mostra o aviso',
        (tester) async {
      await _abrir(tester, musicasComTexto: {
        'Garota de Ipanema',
        'Velha Infância',
        'Evidências',
      });

      expect(find.textContaining('sem cifra'), findsNothing);
    });
  });

  testWidgets('barra mostra o tom da próxima e a música seguinte',
      (tester) async {
    await _abrir(tester);

    expect(find.text('Tom G · Depois: Evidências'), findsOneWidget);
  });

  testWidgets('na última música, a barra não mostra a seguinte',
      (tester) async {
    await _abrir(tester, itens: [
      _item('1', 'Garota de Ipanema', 1, tocada: true),
      _item('2', 'Velha Infância', 2),
    ]);

    expect(find.text('Próxima: Velha Infância'), findsOneWidget);
    expect(find.textContaining('Depois:'), findsNothing);
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

  testWidgets('depois de tocar, o desfazer fica na barra sem cobrir a próxima',
      (tester) async {
    await _abrir(tester, abertas: []);

    await tester.tap(find.text('Tocar'));
    await tester.pumpAndSettle();

    expect(find.byType(SnackBar), findsNothing);
    expect(find.text('Começou: Velha Infância'), findsOneWidget);
    expect(find.text('Próxima: Evidências').hitTestable(), findsOneWidget);
    expect(find.text('Desfazer').hitTestable(), findsOneWidget);
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

  testWidgets('pedido marcado para tocar a seguir vira a próxima',
      (tester) async {
    await _abrir(tester, pedidosASeguir: ['p1']);

    expect(find.text('Próxima: Evidências'), findsOneWidget);
    expect(find.text('2 pedidos · Depois: Velha Infância'), findsOneWidget);
  });

  testWidgets('pedido marcado que já não está aceito é ignorado',
      (tester) async {
    await _abrir(tester,
        pedidosASeguir: ['p1'],
        grupos: [_grupo('p1', 'Evidências', 'Finalizado')]);

    expect(find.text('Próxima: Velha Infância'), findsOneWidget);
  });

  testWidgets('tocar o pedido abre a cifra e coloca tocando agora',
      (tester) async {
    final abertas = <Uri>[];
    final requisicoes =
        await _abrir(tester, abertas: abertas, pedidosASeguir: ['p1']);

    await tester.tap(find.text('Tocar'));
    await tester.pumpAndSettle();

    expect(abertas, [Uri.parse(_cifraSalva)]);
    final status = requisicoes.singleWhere((r) =>
        r.url.path == '/api/apresentacoes/$_id/grupos-pedidos/p1/status');
    expect(status.body, contains('"status":"TocandoAgora"'));
    expect(_aSeguirNoServidor, isEmpty);
    expect(find.text('Começou: Evidências'), findsOneWidget);
    expect(find.text('Próxima: Velha Infância'), findsOneWidget);
  });

  testWidgets('pedido tocado também marca a mesma música no setlist',
      (tester) async {
    final requisicoes = await _abrir(tester, pedidosASeguir: ['p1']);

    await tester.tap(find.text('Tocar'));
    await tester.pumpAndSettle();

    final marcacao = requisicoes.singleWhere(
        (r) => r.method == 'PATCH' && r.url.path.endsWith('/tocada'));
    expect(marcacao.url.path, '/api/apresentacoes/$_id/setlist/3/tocada');
    expect(find.text('2 de 3 tocadas'), findsOneWidget);
  });

  testWidgets('desfazer devolve o pedido para a sequência', (tester) async {
    final requisicoes =
        await _abrir(tester, abertas: [], pedidosASeguir: ['p1']);

    await tester.tap(find.text('Tocar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Desfazer'));
    await tester.pumpAndSettle();

    final status = requisicoes
        .where((r) => r.url.path.endsWith('/grupos-pedidos/p1/status'))
        .last;
    expect(status.body, contains('"status":"Aceito"'));
    expect(_aSeguirNoServidor, ['p1']);
    expect(find.text('Próxima: Evidências'), findsOneWidget);
    expect(find.text('1 de 3 tocadas'), findsOneWidget);
  });

  testWidgets('tocar a próxima finaliza o pedido que estava tocando',
      (tester) async {
    final requisicoes = await _abrir(tester, abertas: [], grupos: [
      _grupo('p9', 'Asa Branca', 'TocandoAgora'),
    ]);

    await tester.tap(find.text('Tocar'));
    await tester.pumpAndSettle();

    final status = requisicoes
        .singleWhere((r) => r.url.path.endsWith('/grupos-pedidos/p9/status'));
    expect(status.body, contains('"status":"Finalizado"'));
  });

  testWidgets('topo limpo: sem modo palco nem botão de leitor',
      (tester) async {
    await _abrir(tester);

    expect(find.text('Modo palco'), findsNothing);
    expect(find.text('Leitor'), findsNothing);
    expect(find.byTooltip('Montar setlist'), findsOneWidget);
    expect(find.text('Editar'), findsOneWidget);
  });

  testWidgets('pedidos novos aparecem num selo que leva à fila',
      (tester) async {
    var abriuFila = false;
    await _abrir(tester,
        grupos: [_grupo('p9', 'Sozinho', 'Aguardando')],
        abrirFila: () => abriuFila = true);

    await tester.tap(find.text('1 pedido novo'));
    await tester.pumpAndSettle();

    expect(abriuFila, isTrue);
  });

  testWidgets('sem pedidos novos, não mostra o selo', (tester) async {
    await _abrir(tester, abrirFila: () {});

    expect(find.textContaining('pedido novo'), findsNothing);
    expect(find.textContaining('pedidos novos'), findsNothing);
  });

  group('com a banda em vários aparelhos', () {
    Future<void> atualizar(WidgetTester tester) async {
      await tester.pump(const Duration(seconds: 30));
      await tester.pumpAndSettle();
    }

    testWidgets('música marcada no outro celular atualiza a setlist',
        (tester) async {
      await _abrir(tester);

      _outroAparelhoTocou('2');
      await atualizar(tester);

      expect(find.text('2 de 3 tocadas'), findsOneWidget);
      expect(find.text('Próxima: Evidências'), findsOneWidget);
    });

    testWidgets('pedido marcado a seguir no outro celular vira a próxima',
        (tester) async {
      await _abrir(tester, grupos: [_grupo('p3', 'Sozinho', 'Aceito')]);
      expect(find.text('Próxima: Velha Infância'), findsOneWidget);

      _aSeguirNoServidor.add('p3');
      await atualizar(tester);

      expect(find.text('Próxima: Sozinho'), findsOneWidget);
    });

    testWidgets('quando o colega começa outra música, o desfazer some',
        (tester) async {
      await _abrir(tester);
      await tester.tap(find.text('Tocar'));
      await tester.pumpAndSettle();
      expect(find.text('Desfazer'), findsOneWidget);

      _outroAparelhoTocou('3');
      await atualizar(tester);

      expect(find.text('Desfazer'), findsNothing);
    });
  });

  testWidgets('setlist completa não mostra a barra de próxima', (tester) async {
    await _abrir(tester, itens: [
      _item('1', 'Garota de Ipanema', 1, tocada: true),
    ]);

    expect(find.text('Tocar'), findsNothing);
  });

  testWidgets('setlist vazia convida a montar com o acervo', (tester) async {
    await _abrir(tester, itens: []);

    expect(find.text('Setlist vazia'), findsOneWidget);
    await tester.tap(find.text('Montar setlist'));
    await tester.pumpAndSettle();

    expect(find.text('Buscar no acervo'), findsOneWidget);
  });

  group('editar a setlist', () {
    List<String> titulos(WidgetTester tester) => [
          for (final titulo in ['Garota de Ipanema', 'Velha Infância', 'Evidências'])
            if (find.text(titulo).evaluate().isNotEmpty) titulo
        ]..sort((a, b) => tester
            .getTopLeft(find.text(a).first)
            .dy
            .compareTo(tester.getTopLeft(find.text(b).first).dy));

    testWidgets('montar abre o acervo', (tester) async {
      await _abrir(tester);

      await tester.tap(find.byTooltip('Montar setlist'));
      await tester.pumpAndSettle();

      expect(find.text('Montar setlist'), findsOneWidget);
    });

    testWidgets('remove só as músicas que ainda não foram tocadas',
        (tester) async {
      final requisicoes = await _abrir(tester);

      await tester.tap(find.text('Editar'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Remover da setlist'), findsNWidgets(2));
      await tester.tap(find.byTooltip('Remover da setlist').first);
      await tester.pumpAndSettle();

      expect(
          requisicoes.where((r) => r.method == 'DELETE').single.url.path,
          '/api/apresentacoes/$_id/setlist/2');
      expect(find.text('Velha Infância'), findsNothing);
      expect(find.text('Evidências'), findsOneWidget);
    });

    testWidgets('mover para o topo reordena as que faltam', (tester) async {
      final requisicoes = await _abrir(tester);

      await tester.tap(find.text('Editar'));
      await tester.pumpAndSettle();
      // Só as que faltam têm alça.
      expect(find.bySemanticsLabel('Arrastar para reordenar'), findsNWidgets(2));
      await tester.tap(find.bySemanticsLabel('Arrastar para reordenar').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mover para cima'));
      await tester.pumpAndSettle();

      final ordem = requisicoes.singleWhere((r) => r.method == 'PUT');
      expect(ordem.url.path, '/api/apresentacoes/$_id/setlist/ordem');
      expect(jsonDecode(ordem.body), {
        'itemIds': ['3', '2']
      });
      expect(titulos(tester),
          ['Garota de Ipanema', 'Evidências', 'Velha Infância']);
    });

    testWidgets('limpar pede confirmação e esvazia a setlist', (tester) async {
      await _abrir(tester);

      await tester.tap(find.text('Editar'));
      await tester.pumpAndSettle();
      final limpar = find.text('Limpar setlist');
      await tester.ensureVisible(limpar);
      await tester.tap(limpar);
      await tester.pumpAndSettle();
      expect(find.text('Limpar a setlist?'), findsOneWidget);
      await tester.tap(find.text('Limpar'));
      await tester.pumpAndSettle();

      expect(find.text('Setlist vazia'), findsOneWidget);
    });

    testWidgets('concluir volta a marcar como tocada pela linha',
        (tester) async {
      await _abrir(tester);

      await tester.tap(find.text('Editar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Concluir'));
      await tester.pumpAndSettle();

      expect(find.byTooltip('Remover da setlist'), findsNothing);
      expect(find.text('Editar'), findsOneWidget);
    });
  });

  testWidgets('setlist cabe em celular de 360px', (tester) async {
    addTearDown(tester.view.reset);
    tester.view.devicePixelRatio = 3;
    tester.view.physicalSize = const Size(360, 740) * 3;
    await _abrir(tester);

    expect(tester.takeException(), isNull);
  });

  group('progresso e tempo numa linha', () {
    Map<String, Object?> relogio({int? duracao, int? ritmoMedio}) => {
          'duracaoContratadaMinutos': duracao,
          'intervaloPausaRelogio': false,
          'iniciadaEm': null,
          'emIntervaloDesde': null,
          'segundosEmIntervalo': 0,
          'musicasComecadas': 0,
          'musicasRestantes': 0,
          'agora': '2026-09-10T21:00:00Z',
          'ritmoMedioSegundos': ritmoMedio,
        };

    testWidgets('antes do show: tempo que falta e comparação com o contrato',
        (tester) async {
      await _abrir(tester,
          status: StatusApresentacao.agendada, relogio: relogio(duracao: 240));

      expect(find.text('1 de 3 tocadas'), findsOneWidget);
      expect(find.text(' · faltam ~6 min'), findsOneWidget);
      expect(
          find.text('estimativa: 3 min por música · '
              'contratado 4h → faltam ~3h54 de músicas'),
          findsOneWidget);
      expect(find.textContaining('≈'), findsNothing);
    });

    testWidgets('com histórico usa o ritmo médio e avisa se passa',
        (tester) async {
      await _abrir(tester,
          status: StatusApresentacao.agendada,
          itens: [
            for (var i = 1; i <= 20; i++) _item('$i', 'Música $i', i),
          ],
          relogio: relogio(duracao: 60, ritmoMedio: 240));

      expect(find.text('0 de 20 tocadas'), findsOneWidget);
      expect(find.text(' · faltam ~1h20'), findsOneWidget);
      expect(
          find.text('seu ritmo médio: 4 min por música · '
              'a setlist passa ~20 min do contratado'),
          findsOneWidget);
    });

    testWidgets('pout-pourri conta o tempo de cada música separada por barra',
        (tester) async {
      await _abrir(tester,
          status: StatusApresentacao.agendada,
          itens: [
            _item('1', 'Evidências / Página Virada', 1),
            _item('2', 'Pense em Mim/Fio de Cabelo/Saudade', 2),
            _item('3', '24/7', 3),
          ],
          relogio: relogio());

      expect(find.text('0 de 3 tocadas'), findsOneWidget);
      expect(find.text(' · faltam ~18 min'), findsOneWidget);
    });

    testWidgets('sem horas contratadas, a legenda mostra só o ritmo',
        (tester) async {
      await _abrir(tester,
          status: StatusApresentacao.agendada, relogio: relogio());

      expect(find.text(' · faltam ~6 min'), findsOneWidget);
      expect(find.text('estimativa: 3 min por música'), findsOneWidget);
    });

    testWidgets('ao vivo, só a linha; o contrato fica na faixa do cronômetro',
        (tester) async {
      await _abrir(tester, relogio: relogio(duracao: 240));

      expect(find.text(' · faltam ~6 min'), findsOneWidget);
      expect(find.textContaining('por música'), findsNothing);
    });

    testWidgets('setlist toda tocada diz que está completa', (tester) async {
      await _abrir(tester, itens: [
        _item('1', 'Garota de Ipanema', 1, tocada: true),
      ]);

      expect(find.text('1 de 1 tocadas'), findsOneWidget);
      expect(find.text(' · setlist completa'), findsOneWidget);
    });
  });
}
