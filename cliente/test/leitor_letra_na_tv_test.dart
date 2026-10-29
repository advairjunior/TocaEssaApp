import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:toca_essa_app/dominio/tela_da_tv.dart';
import 'package:toca_essa_app/dominio/transmissor_da_letra.dart';
import 'package:toca_essa_app/infraestrutura/api_toca_essa.dart';
import 'package:toca_essa_app/telas/cifra_do_palco.dart';
import 'package:toca_essa_app/telas/leitor_de_cifras.dart';
import 'package:toca_essa_app/telas/sequencia_do_palco.dart';

import 'apoio/pedidos_a_seguir_falsos.dart';

const _id = '44444444-4444-4444-4444-444444444444';
const _json = {'content-type': 'application/json; charset=utf-8'};
const _cifra = 'G    D\nO sol desceu devagar\nEm   C\nCavaco afinado';

class _TvFalsa implements SaidaDaTela {
  final mostradas = <ConteudoParaTv>[];
  final linhas = <int>[];

  @override
  Future<void> mostrar(ConteudoParaTv conteudo) async =>
      mostradas.add(conteudo);

  @override
  Future<void> irParaALinha(int linha) async => linhas.add(linha);

  @override
  Future<void> limpar() async {}
}

Map<String, Object?> _item(String id, String titulo, int ordem,
        {bool tocada = false}) =>
    {
      'id': id,
      'apresentacaoId': _id,
      'titulo': titulo,
      'artista': 'Turma',
      'tom': null,
      'tocada': tocada,
      'ordem': ordem,
    };

// Pedido aceito e marcado para tocar a seguir.
final _pedidoDaCarla = {
  'pedidoRepresentativoId': 'p1',
  'pedidoIds': ['p1'],
  'apresentacaoId': _id,
  'musica': 'Trem-Bala',
  'solicitantes': ['Carla'],
  'quantidadePedidos': 1,
  'status': 'Aceito',
  'criadoEm': '2026-10-29T20:00:00Z',
  'tipo': 'Musica',
};

Future<_TvFalsa> _abrir(WidgetTester tester, {bool comPedido = false}) async {
  final tv = _TvFalsa();
  final cliente = MockClient((requisicao) async {
    final aSeguir = responderPedidosASeguir(requisicao, [if (comPedido) 'p1']);
    if (aSeguir != null) return aSeguir;
    final caminho = requisicao.url.path;
    if (caminho.endsWith('/grupos-pedidos') && comPedido) {
      return http.Response(jsonEncode([_pedidoDaCarla]), 200, headers: _json);
    }
    if (caminho.endsWith('/setlist')) {
      // Com o pedido, a primeira já foi tocada: o pedido entra logo depois.
      return http.Response(
          jsonEncode([
            _item('1', 'Fim de tarde', 1, tocada: comPedido),
            _item('2', 'Lua de São Jorge', 2),
          ]),
          200,
          headers: _json);
    }
    if (caminho.endsWith('/cifras/consulta')) {
      final musica = requisicao.url.queryParameters['musica'];
      return http.Response(
          jsonEncode({
            'cifra': null,
            'urlPesquisa': 'https://www.google.com/search?q=cifra',
            'texto': musica == 'Fim de tarde' ? _cifra : null,
          }),
          200,
          headers: _json);
    }
    return http.Response('[]', 200, headers: _json);
  });
  final api = ApiTocaEssa(cliente: cliente, enderecoBase: 'http://teste')
    ..definirTokenArtista('TOKEN');
  final sequencia =
      SequenciaDoPalco(api: api, apresentacaoId: _id, codigo: 'RSN482');
  await tester.runAsync(sequencia.carregar);
  await tester.runAsync(() => sequencia.buscarCifras());
  await tester.pumpWidget(MaterialApp(
    home: LeitorDeCifras(
      sequencia: sequencia,
      musicaInicial: MusicaDoPalco.doSetlist(sequencia.itens.first),
      abrirUrl: (_) async {},
      compartilhar: (_, __) async => true,
      manterTelaAcesa: () => () {},
      saidaDaTela: tv,
    ),
  ));
  await tester.pumpAndSettle();
  return tv;
}

void main() {
  testWidgets(
      'com a Letra na TV ligada, a cifra tem a seta e a música vai '
      'para a TV com a próxima e o código', (tester) async {
    SharedPreferences.setMockInitialValues({'letra_na_tv': true});

    final tv = await _abrir(tester);

    expect(find.byKey(chaveDaSetaDaTv), findsOneWidget);
    final mostrada = tv.mostradas.single;
    expect(mostrada.titulo, 'Fim de tarde');
    expect(mostrada.subtitulo, 'Turma');
    expect(mostrada.texto, _cifra);
    expect(mostrada.aSeguir, 'Lua de São Jorge');
    expect(mostrada.codigo, 'RSN482');
    expect(mostrada.linha, 0);
  });

  testWidgets('pedido a seguir vai para a TV com quem pediu', (tester) async {
    SharedPreferences.setMockInitialValues({'letra_na_tv': true});

    final tv = await _abrir(tester, comPedido: true);

    expect(tv.mostradas.single.aSeguir, 'Trem-Bala · pedida por Carla');
  });

  testWidgets('com a Letra na TV desligada, nada de seta nem de TV',
      (tester) async {
    SharedPreferences.setMockInitialValues({});

    final tv = await _abrir(tester);

    expect(find.byKey(chaveDaSetaDaTv), findsNothing);
    expect(tv.mostradas, isEmpty);
  });

  testWidgets('música sem cifra colada não vai para a TV', (tester) async {
    SharedPreferences.setMockInitialValues({'letra_na_tv': true});
    final tv = await _abrir(tester);

    await tester.tap(find.byTooltip('Próxima música'));
    await tester.pumpAndSettle();

    expect(tv.mostradas.map((conteudo) => conteudo.titulo), ['Fim de tarde']);
  });
}
