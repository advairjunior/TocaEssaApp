import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:toca_essa_app/infraestrutura/api_toca_essa.dart';
import 'package:toca_essa_app/telas/convite_do_musico.dart';
import 'package:toca_essa_app/telas/convites_do_musico.dart';
import 'package:toca_essa_app/telas/leitor_de_cifras.dart';
import 'package:toca_essa_app/telas/noite_do_musico.dart';
import 'package:toca_essa_app/tema/tema_toca_essa.dart';

import 'apoio/pedidos_a_seguir_falsos.dart';

const _id = '44444444-4444-4444-4444-444444444444';
const _json = {'content-type': 'application/json; charset=utf-8'};

final _resenha = {
  'apresentacaoId': _id,
  'nome': 'Resenha House',
  'data': '2026-10-30',
  'local': 'Casa',
  'tipo': 'ResenhaEntreAmigos',
  'status': 'EmAndamento',
  'codigo': 'RSN482',
  'dono': 'Advair',
};

late List<http.Request> _pedidos;

ApiTocaEssa _api({List<Object> convites = const []}) {
  _pedidos = [];
  return ApiTocaEssa(
    enderecoBase: 'http://teste',
    cliente: MockClient((pedido) async {
      _pedidos.add(pedido);
      final sequencia = responderPedidosASeguir(pedido, []);
      if (sequencia != null) return sequencia;
      final caminho = pedido.url.path;
      if (pedido.method == 'DELETE') return http.Response('', 204);
      if (caminho == '/api/convites') {
        return http.Response(jsonEncode(convites), 200, headers: _json);
      }
      if (caminho.endsWith('/setlist')) {
        return http.Response(
            jsonEncode([
              {
                'id': '1',
                'apresentacaoId': _id,
                'titulo': 'Evidências',
                'artista': 'Banda',
                'tom': 'A',
                'tocada': false,
                'ordem': 1,
              }
            ]),
            200,
            headers: _json);
      }
      if (caminho.endsWith('/cifras')) {
        return http.Response(
            jsonEncode({
              'cifra': null,
              'urlPesquisa': 'https://busca',
              'texto': 'A  E\nQuando eu digo',
            }),
            200,
            headers: _json);
      }
      return http.Response('[]', 200, headers: _json);
    }),
  )..definirTokenArtista('TOKEN_DA_BIA');
}

Future<void> _abrirConvites(WidgetTester tester, ApiTocaEssa api,
    {Map<String, Object> guardado = const {}}) async {
  SharedPreferences.setMockInitialValues(guardado);
  await tester.pumpWidget(MaterialApp(
    theme: TemaTocaEssa.escuro,
    home: Scaffold(
      body: ListView(children: [
        ConvitesDoMusico(api: api, artistaId: 'bia', abrirUrl: (_) async {}),
      ]),
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('os Convites mostram o evento do outro artista e abrem a noite',
      (tester) async {
    await _abrirConvites(tester, _api(convites: [_resenha]));

    expect(find.text('Convites'), findsOneWidget);
    expect(find.text('Resenha House'), findsOneWidget);
    expect(find.textContaining('de Advair'), findsOneWidget);

    await tester.tap(find.text('Resenha House'));
    await tester.pumpAndSettle();

    expect(find.byType(NoiteDoMusico), findsOneWidget);
    expect(find.text('Evidências'), findsOneWidget);
  });

  testWidgets('sem convites, a seção não aparece', (tester) async {
    await _abrirConvites(tester, _api());

    expect(find.text('Convites'), findsNothing);
  });

  testWidgets('convite aberto antes de entrar na conta abre ao chegar',
      (tester) async {
    await _abrirConvites(tester, _api(), guardado: const {
      'convite_pendente': 'ABC123',
      'token_do_artista': 'TOKEN_DA_BIA'
    });

    expect(find.byType(ConviteDoMusico), findsOneWidget);
  });

  testWidgets('na noite, tocar numa música abre o leitor com a cifra do dono',
      (tester) async {
    await _abrirConvites(tester, _api(convites: [_resenha]));
    await tester.tap(find.text('Resenha House'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Evidências'));
    await tester.pumpAndSettle();

    expect(find.byType(LeitorDeCifras), findsOneWidget);
    expect(find.text('Quando eu digo'), findsOneWidget);
  });

  testWidgets('sair do evento tira o músico e volta', (tester) async {
    await _abrirConvites(tester, _api(convites: [_resenha]));
    await tester.tap(find.text('Resenha House'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Sair do evento'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sair'));
    await tester.pumpAndSettle();

    expect(
        _pedidos.any((p) =>
            p.method == 'DELETE' &&
            p.url.path == '/api/apresentacoes/$_id/musicos/bia'),
        isTrue);
    expect(find.byType(NoiteDoMusico), findsNothing);
  });
}
