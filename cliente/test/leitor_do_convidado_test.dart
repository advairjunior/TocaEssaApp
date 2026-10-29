import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:toca_essa_app/infraestrutura/api_toca_essa.dart';
import 'package:toca_essa_app/telas/leitor_de_cifras.dart';
import 'package:toca_essa_app/telas/sequencia_do_palco.dart';

import 'apoio/pedidos_a_seguir_falsos.dart';

const _id = '44444444-4444-4444-4444-444444444444';
const _json = {'content-type': 'application/json; charset=utf-8'};
const _cifra = 'G    D\nQuando eu digo que deixei de te amar';

Map<String, Object?> _item(String id, String titulo, int ordem) => {
      'id': id,
      'apresentacaoId': _id,
      'titulo': titulo,
      'artista': 'Banda',
      'tom': null,
      'tocada': false,
      'ordem': ordem,
    };

/// O músico convidado lê no leitor as cifras que o dono preparou, pela
/// rota do evento, e não cola nem corrige: a cifra é do dono.
Future<List<http.Request>> _abrir(WidgetTester tester, String inicial) async {
  final requisicoes = <http.Request>[];
  final api = ApiTocaEssa(
    enderecoBase: 'http://teste',
    cliente: MockClient((requisicao) async {
      requisicoes.add(requisicao);
      final sequencia = responderPedidosASeguir(requisicao, []);
      if (sequencia != null) return sequencia;
      final caminho = requisicao.url.path;
      if (caminho.endsWith('/setlist')) {
        return http.Response(
            jsonEncode([
              _item('1', 'Evidências', 1),
              _item('2', 'Tempo Perdido', 2),
            ]),
            200,
            headers: _json);
      }
      if (caminho.endsWith('/cifras')) {
        final musica = requisicao.url.queryParameters['musica'];
        return http.Response(
            jsonEncode({
              'cifra': null,
              'urlPesquisa': 'https://busca',
              'texto': musica == 'Evidências' ? _cifra : null,
            }),
            200,
            headers: _json);
      }
      return http.Response('[]', 200, headers: _json);
    }),
  )..definirTokenArtista('TOKEN_DA_BIA');
  final sequencia =
      SequenciaDoConvidado(api: api, apresentacaoId: _id, codigo: 'RSN482');
  await tester.runAsync(sequencia.carregar);
  await tester.runAsync(() => sequencia.buscarCifras());
  await tester.pumpWidget(MaterialApp(
    home: LeitorDeCifras(
      sequencia: sequencia,
      musicaInicial: MusicaDoPalco.doSetlist(
          sequencia.itens.singleWhere((i) => i.titulo == inicial)),
      abrirUrl: (_) async {},
      manterTelaAcesa: () => () {},
    ),
  ));
  await tester.pumpAndSettle();
  return requisicoes;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('a cifra vem do dono pela rota do evento', (tester) async {
    final requisicoes = await _abrir(tester, 'Evidências');

    expect(find.text('Quando eu digo que deixei de te amar'), findsOneWidget);
    expect(
        requisicoes
            .where((r) => r.url.path == '/api/apresentacoes/$_id/cifras'),
        isNotEmpty);
    expect(requisicoes.where((r) => r.url.path.contains('/api/artista/cifras')),
        isEmpty);
  });

  testWidgets('o convidado não cola, não corrige e não compartilha a cifra',
      (tester) async {
    await _abrir(tester, 'Evidências');

    expect(find.byTooltip('Colar ou corrigir cifra'), findsNothing);
    expect(find.byTooltip('Compartilhar'), findsNothing);
  });

  testWidgets('música sem cifra do dono não oferece colar', (tester) async {
    await _abrir(tester, 'Tempo Perdido');

    expect(find.textContaining('Colar'), findsNothing);
  });
}
