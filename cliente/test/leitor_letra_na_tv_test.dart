import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:toca_essa_app/dominio/letra_da_tela.dart';
import 'package:toca_essa_app/dominio/modelos.dart';
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

// Hino "Fim de tarde": a estrofe é do João, o coro de todos.
final _louvor = {
  'cantores': ['João', 'Ana'],
  'solistas': <Object?>[],
  'placar': <Object?>[],
  'hinos': [
    {
      'itemId': '1',
      'titulo': 'Fim de tarde',
      'tom': 'G',
      'tocado': false,
      'temLetra': true,
      'partes': [
        {
          'tipo': 'Estrofe',
          'texto': 'G    D\nO sol desceu devagar',
          'cantores': ['João'],
          'definida': true,
        },
        {
          'tipo': 'Refrao',
          'texto': 'Em   C\nCavaco afinado',
          'cantores': <String>[],
          'definida': true,
        },
      ],
    },
  ],
};

Future<_TvFalsa> _abrir(WidgetTester tester,
    {bool comPedido = false, bool noLouvor = false}) async {
  final tv = _TvFalsa();
  final cliente = MockClient((requisicao) async {
    final aSeguir = responderPedidosASeguir(requisicao, [if (comPedido) 'p1']);
    if (aSeguir != null) return aSeguir;
    final caminho = requisicao.url.path;
    if (caminho.endsWith('/louvor') && noLouvor) {
      return http.Response(jsonEncode(_louvor), 200, headers: _json);
    }
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
  final sequencia = SequenciaDoPalco(
      api: api,
      apresentacaoId: _id,
      codigo: 'RSN482',
      vocabulario: noLouvor ? Vocabulario.louvor : Vocabulario.musical);
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

  testWidgets(
      'no louvor, a seta aparece e a TV recebe o nome de quem canta '
      'cada parte, sem o "sua vez" de quem está com o celular', (tester) async {
    SharedPreferences.setMockInitialValues({
      'letra_na_tv': true,
      'louvor_quem_sou_artista_$_id': 'João',
    });

    final tv = await _abrir(tester, noLouvor: true);

    expect(find.byKey(chaveDaSetaDaTv), findsOneWidget);
    final letra = LetraDaTela.doTexto(tv.mostradas.last.texto);
    expect(letra.partes.map((parte) => parte.rotulo), ['JOÃO', 'TODOS']);
    expect(letra.partes.expand((parte) => parte.linhas).map((l) => l.texto),
        ['O sol desceu devagar', 'Cavaco afinado']);
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
