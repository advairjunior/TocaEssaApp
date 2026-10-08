import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:toca_essa_app/dominio/modelos.dart';
import 'package:toca_essa_app/infraestrutura/api_toca_essa.dart';
import 'package:toca_essa_app/telas/modo_palco.dart';

const _id = '33333333-3333-3333-3333-333333333333';
const _cifraSalva = 'https://www.cifraclub.com.br/banda/musica/';
const _json = {'content-type': 'application/json; charset=utf-8'};

Map<String, Object?> _item(String id, String titulo, int ordem,
        {bool tocada = false}) =>
    {
      'id': id,
      'apresentacaoId': _id,
      'titulo': titulo,
      'artista': 'Banda',
      'tom': null,
      'tocada': tocada,
      'ordem': ordem,
    };

Map<String, Object?> _grupo(String id, String musica, String status,
        {String tipo = 'Musica', String? destinatario, String? recado}) =>
    {
      'pedidoRepresentativoId': id,
      'pedidoIds': [id],
      'apresentacaoId': _id,
      'musica': musica,
      'solicitantes': ['Ana'],
      'quantidadePedidos': 1,
      'status': status,
      'criadoEm': '2026-09-10T12:00:00Z',
      'tipo': tipo,
      'destinatarioAlo': destinatario,
      'recado': recado,
    };

class _Palco {
  final requisicoes = <http.Request>[];
  final abertas = <Uri>[];
  var telaAcesa = 0;
  var telaLiberada = 0;
  List<Map<String, Object?>> grupos = [];

  Iterable<http.Request> status(String id) => requisicoes
      .where((r) => r.url.path.endsWith('/grupos-pedidos/$id/status'));
}

Future<_Palco> _abrir(
  WidgetTester tester, {
  List<Map<String, Object?>>? grupos,
}) async {
  SharedPreferences.setMockInitialValues({});
  final palco = _Palco();
  final itens = [
    _item('1', 'Garota de Ipanema', 1, tocada: true),
    _item('2', 'Velha Infância', 2),
    _item('3', 'Evidências', 3),
  ];
  final listaDeGrupos = palco.grupos = grupos ?? <Map<String, Object?>>[];
  final cliente = MockClient((requisicao) async {
    palco.requisicoes.add(requisicao);
    final caminho = requisicao.url.path;
    if (caminho.endsWith('/setlist')) {
      return http.Response(jsonEncode(itens), 200, headers: _json);
    }
    if (caminho.endsWith('/grupos-pedidos')) {
      return http.Response(jsonEncode(listaDeGrupos), 200, headers: _json);
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
          headers: _json);
    }
    if (caminho.endsWith('/tocada')) {
      final corpo = jsonDecode(requisicao.body) as Map<String, dynamic>;
      final item = itens.firstWhere((i) => caminho.contains('/${i['id']}/'));
      return http.Response(
          jsonEncode({...item, 'tocada': corpo['tocada']}), 200,
          headers: _json);
    }
    if (caminho.endsWith('/cifras/consulta')) {
      return http.Response(
        jsonEncode({
          'cifra': {
            'id': 'c1',
            'artistaId': '22222222-2222-2222-2222-222222222222',
            'musica': requisicao.url.queryParameters['musica'],
            'artista': 'Banda',
            'url': _cifraSalva,
            'fonte': 'Manual',
            'criadaEm': '2026-09-10T12:00:00Z',
            'atualizadaEm': '2026-09-10T12:00:00Z',
          },
          'urlPesquisa': 'https://www.google.com/search?q=cifra',
        }),
        200,
        headers: _json,
      );
    }
    return http.Response('[]', 200, headers: _json);
  });
  final api = ApiTocaEssa(cliente: cliente, enderecoBase: 'http://teste')
    ..definirTokenArtista('TOKEN');
  final apresentacao = Apresentacao(
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
  );
  await tester.pumpWidget(MaterialApp(
    home: Builder(
      builder: (context) => Scaffold(
        body: TextButton(
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => ModoPalco(
              api: api,
              apresentacao: apresentacao,
              abrirUrl: (url) async => palco.abertas.add(url),
              prepararAbertura: () => (url) async {
                if (url != null) palco.abertas.add(url);
              },
              manterTelaAcesa: () {
                palco.telaAcesa++;
                return () => palco.telaLiberada++;
              },
            ),
          )),
          child: const Text('Abrir palco'),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('Abrir palco'));
  await tester.pumpAndSettle();
  return palco;
}

void main() {
  testWidgets('mantém a tela acesa e libera ao sair', (tester) async {
    final palco = await _abrir(tester);
    expect(palco.telaAcesa, 1);
    expect(palco.telaLiberada, 0);

    await tester.tap(find.byTooltip('Sair do modo palco'));
    await tester.pumpAndSettle();

    expect(find.text('Abrir palco'), findsOneWidget);
    expect(palco.telaLiberada, 1);
  });

  testWidgets('tocar abre a cifra e mostra a música em tocando agora',
      (tester) async {
    final palco = await _abrir(tester);
    expect(find.text('Próxima: Velha Infância'), findsOneWidget);
    expect(find.text('Toque em Tocar para começar.'), findsOneWidget);

    await tester.tap(find.text('Tocar'));
    await tester.pumpAndSettle();

    expect(palco.abertas, [Uri.parse(_cifraSalva)]);
    expect(find.text('Velha Infância'), findsOneWidget);
    expect(find.text('Próxima: Evidências'), findsOneWidget);
  });

  testWidgets('pedido que já está tocando aparece ao abrir', (tester) async {
    await _abrir(tester, grupos: [_grupo('p9', 'Asa Branca', 'TocandoAgora')]);

    expect(find.text('Asa Branca'), findsOneWidget);
    expect(find.text('Toque em Tocar para começar.'), findsNothing);
  });

  testWidgets('aceitar pedido novo e colocá-lo para tocar a seguir',
      (tester) async {
    final palco =
        await _abrir(tester, grupos: [_grupo('p2', 'Sozinho', 'Aguardando')]);
    expect(find.text('Pedidos novos'), findsOneWidget);

    await tester.tap(find.text('Aceitar'));
    await tester.pumpAndSettle();
    expect(palco.status('p2').single.body, contains('"status":"Aceito"'));

    await tester.tap(find.text('Tocar a seguir'));
    await tester.pumpAndSettle();
    expect(find.text('Próxima: Sozinho'), findsOneWidget);
    expect(find.text('Tirar da sequência'), findsOneWidget);
  });

  testWidgets('recusar pedido novo tira o pedido da tela', (tester) async {
    final palco =
        await _abrir(tester, grupos: [_grupo('p2', 'Sozinho', 'Aguardando')]);

    await tester.tap(find.text('Recusar'));
    await tester.pumpAndSettle();

    expect(
        palco.status('p2').single.body, contains('"status":"NaoConhecemos"'));
    expect(find.text('Sozinho'), findsNothing);
  });

  testWidgets('alô pendente mostra o recado e pode ser dado', (tester) async {
    final palco = await _abrir(tester, grupos: [
      _grupo('a1', 'Alô', 'Aguardando',
          tipo: 'Alo', destinatario: 'Bia', recado: 'Feliz aniversário!'),
    ]);

    expect(find.text('Alô para Bia'), findsOneWidget);
    expect(find.text('“Feliz aniversário!”'), findsOneWidget);

    await tester.tap(find.text('Alô dado'));
    await tester.pumpAndSettle();

    expect(palco.status('a1').single.body, contains('"status":"Finalizado"'));
    expect(find.text('Alô para Bia'), findsNothing);
  });

  testWidgets('pedido novo aparece sem precisar reabrir a tela',
      (tester) async {
    final palco = await _abrir(tester);
    expect(find.text('Pedidos novos'), findsNothing);

    palco.grupos.add(_grupo('p2', 'Sozinho', 'Aguardando'));
    await tester.pump(const Duration(seconds: 30));
    await tester.pumpAndSettle();

    expect(find.text('Sozinho'), findsOneWidget);
  });

  testWidgets('modo palco cabe em celular de 360px', (tester) async {
    addTearDown(tester.view.reset);
    tester.view.devicePixelRatio = 3;
    tester.view.physicalSize = const Size(360, 740) * 3;
    await _abrir(tester, grupos: [
      _grupo('p2', 'Uma música com um nome bem comprido mesmo', 'Aguardando'),
      _grupo('p3', 'Sozinho', 'Aceito'),
      _grupo('a1', 'Alô', 'Aguardando',
          tipo: 'Alo', destinatario: 'Bia', recado: 'Feliz aniversário!'),
    ]);

    expect(tester.takeException(), isNull);
  });
}
