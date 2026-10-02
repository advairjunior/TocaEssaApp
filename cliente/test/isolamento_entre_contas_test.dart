import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:toca_essa_app/infraestrutura/api_toca_essa.dart';
import 'package:toca_essa_app/telas/area_do_publico.dart';
import 'package:toca_essa_app/telas/componentes_formulario.dart';
import 'package:toca_essa_app/telas/conta_do_publico.dart';

const _idPedidoDaAna = '33333333-3333-3333-3333-333333333333';
const _idPedidoDaBia = '44444444-4444-4444-4444-444444444444';

const _rastrosDaAna = <String, Object>{
  'nome_do_publico': 'Ana',
  'identificador_avaliador': 'aparelho-da-ana',
  'pedidos_publico_A1B2C3': [_idPedidoDaAna],
};

Map<String, Object?> _pedido(String id, String musica, String nome) => {
      'id': id,
      'apresentacaoId': '22222222-2222-2222-2222-222222222222',
      'musica': musica,
      'artista': null,
      'nomeSolicitante': nome,
      'status': 'Aguardando',
      'posicao': null,
      'criadoEm': '2026-09-03T20:00:00Z',
    };

const _perfilDaBia = {
  'id': 'bia',
  'nome': 'Bia',
  'email': 'bia@teste.com',
  'criadoEm': '2026-09-01T00:00:00Z',
};

const _estatisticasVazias = {
  'participacoes': 0,
  'pedidos': 0,
  'pedidosTocados': 0,
  'avaliacoesRealizadas': 0,
  'musicasMaisPedidas': [],
};

http.Response _json(Object corpo, [int status = 200]) =>
    http.Response(jsonEncode(corpo), status,
        headers: {'content-type': 'application/json; charset=utf-8'});

/// Simula o servidor: cada conta só enxerga o que é dela pelo token.
MockClient _servidor() => MockClient((requisicao) async {
      final caminho = requisicao.url.path;
      if (caminho == '/api/publico/sessoes') {
        return _json({'perfil': _perfilDaBia, 'token': 'TOKEN_BIA'});
      }
      if (caminho == '/api/publico/sessoes/atual') {
        return http.Response('', 204);
      }
      if (caminho == '/api/publico/perfil') return _json(_perfilDaBia);
      if (caminho == '/api/publico/estatisticas') {
        return _json(_estatisticasVazias);
      }
      if (caminho == '/api/publico/historico') return _json([]);
      if (caminho.endsWith('/meus-pedidos')) {
        expect(requisicao.headers['authorization'], 'Bearer TOKEN_BIA');
        return _json([_pedido(_idPedidoDaBia, 'Música da Bia', 'Bia')]);
      }
      if (caminho.endsWith('/fila')) return _json([]);
      if (requisicao.method == 'POST' && caminho.endsWith('/pedidos')) {
        return _json(_pedido(_idPedidoDaBia, 'Nova da Bia', 'Bia'), 201);
      }
      if (caminho.contains('/pedidos/')) {
        return _json(_pedido(_idPedidoDaAna, 'Música da Ana', 'Ana'));
      }
      return _json({
        'id': '22222222-2222-2222-2222-222222222222',
        'nome': 'Noite Acústica',
        'data': '2026-09-03',
        'local': 'Café Central',
        'codigo': 'A1B2C3',
        'perfilArtistico': {
          'id': '11111111-1111-1111-1111-111111111111',
          'nomeArtistico': 'Duo Aurora',
          'bio': null,
        },
        'pedidosAbertos': true,
        'status': 'EmAndamento',
        'tipo': 'Publica',
      });
    });

void _esperarSemRastrosDaAna(SharedPreferences preferencias) {
  for (final chave in _rastrosDaAna.keys) {
    expect(preferencias.containsKey(chave), isFalse, reason: chave);
  }
}

void main() {
  testWidgets('conta logada não herda pedidos guardados no aparelho',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      ..._rastrosDaAna,
      'token_do_publico': 'TOKEN_BIA',
    });

    await tester.pumpWidget(MaterialApp(
      home: AreaDoPublico(
        api: ApiTocaEssa(cliente: _servidor(), enderecoBase: 'http://teste'),
        codigoInicial: 'A1B2C3',
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Música da Bia'), findsOneWidget);
    expect(find.text('Música da Ana'), findsNothing);
  });

  testWidgets('pedido feito com conta logada não fica gravado no aparelho',
      (tester) async {
    SharedPreferences.setMockInitialValues({'token_do_publico': 'TOKEN_BIA'});

    await tester.pumpWidget(MaterialApp(
      home: AreaDoPublico(
        api: ApiTocaEssa(cliente: _servidor(), enderecoBase: 'http://teste'),
        codigoInicial: 'A1B2C3',
      ),
    ));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.descendant(
          of: find.widgetWithText(CampoTexto, 'Música'),
          matching: find.byType(TextField),
        ),
        'Nova da Bia');
    final enviar = find.text('Enviar pedido');
    await tester.ensureVisible(enviar);
    await tester.tap(enviar);
    await tester.pumpAndSettle();

    expect(find.text('Nova da Bia'), findsWidgets);
    final preferencias = await SharedPreferences.getInstance();
    expect(preferencias.containsKey('pedidos_publico_A1B2C3'), isFalse);
    expect(preferencias.containsKey('nome_do_publico'), isFalse);
  });

  testWidgets('entrar na conta descarta rastros de quem usou o aparelho',
      (tester) async {
    SharedPreferences.setMockInitialValues(_rastrosDaAna);

    await tester.pumpWidget(MaterialApp(
      home: ContaDoPublico(
        api: ApiTocaEssa(cliente: _servidor(), enderecoBase: 'http://teste'),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.widgetWithText(CampoTexto, 'E-mail'), 'bia@teste.com');
    await tester.enterText(
        find.widgetWithText(CampoTexto, 'Senha'), 'senha123');
    await tester.ensureVisible(find.text('Entrar'));
    await tester.tap(find.text('Entrar'));
    await tester.pumpAndSettle();

    final preferencias = await SharedPreferences.getInstance();
    expect(preferencias.getString('token_do_publico'), 'TOKEN_BIA');
    _esperarSemRastrosDaAna(preferencias);
  });

  testWidgets('sair da conta descarta rastros deixados no aparelho',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      ..._rastrosDaAna,
      'token_do_publico': 'TOKEN_BIA',
    });

    await tester.pumpWidget(MaterialApp(
      home: ContaDoPublico(
        api: ApiTocaEssa(cliente: _servidor(), enderecoBase: 'http://teste'),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Meu perfil'));
    await tester.pumpAndSettle();
    final sair = find.text('Sair');
    await tester.ensureVisible(sair);
    await tester.tap(sair);
    await tester.pumpAndSettle();

    final preferencias = await SharedPreferences.getInstance();
    expect(preferencias.containsKey('token_do_publico'), isFalse);
    _esperarSemRastrosDaAna(preferencias);
  });
}
