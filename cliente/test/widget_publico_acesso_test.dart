import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:toca_essa_app/infraestrutura/api_toca_essa.dart';
import 'package:toca_essa_app/telas/area_do_publico.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets('público recupera e cancela pedido ainda não analisado',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'nome_do_publico': 'Ana',
      'pedidos_publico_A1B2C3': ['33333333-3333-3333-3333-333333333333'],
    });
    final cliente = MockClient((requisicao) async {
      if (requisicao.url.path.endsWith('/fila')) {
        return http.Response('[]', 200);
      }
      if (requisicao.url.path.contains('/pedidos/')) {
        if (requisicao.method == 'PATCH') {
          return http.Response(
            '{"id":"33333333-3333-3333-3333-333333333333","apresentacaoId":"22222222-2222-2222-2222-222222222222","musica":"Evidências","artista":"Chitãozinho & Xororó","nomeSolicitante":"Ana","status":"CanceladoPeloPublico","posicao":null,"criadoEm":"2026-09-03T20:00:00Z"}',
            200,
          );
        }
        return http.Response(
          '{"id":"33333333-3333-3333-3333-333333333333","apresentacaoId":"22222222-2222-2222-2222-222222222222","musica":"Evidências","artista":"Chitãozinho & Xororó","nomeSolicitante":"Ana","status":"Aguardando","posicao":null,"criadoEm":"2026-09-03T20:00:00Z"}',
          200,
        );
      }
      return http.Response(
        '{"id":"22222222-2222-2222-2222-222222222222","nome":"Noite Acústica","data":"2026-09-03","local":"Café Central","codigo":"A1B2C3","perfilArtistico":{"id":"11111111-1111-1111-1111-111111111111","nomeArtistico":"Duo Aurora","bio":null},"pedidosAbertos":true,"status":"EmAndamento"}',
        200,
      );
    });

    await tester.pumpWidget(MaterialApp(
      home: AreaDoPublico(
        api: ApiTocaEssa(cliente: cliente, enderecoBase: 'http://teste'),
        codigoInicial: 'A1B2C3',
      ),
    ));
    await tester.pumpAndSettle();

    expect(
      find.image(const AssetImage('assets/fundos/atmosfera.png')),
      findsOneWidget,
    );
    expect(find.text('Área do Público'), findsOneWidget);
    final campoNome = tester.widget<TextField>(
      find.widgetWithText(TextField, 'Seu nome (opcional)'),
    );
    expect(campoNome.controller?.text, 'Ana');
    expect(find.text('Evidências'), findsOneWidget);
    expect(find.text('Aguardando análise'), findsOneWidget);
    final cancelar = find.text('Cancelar');
    await tester.ensureVisible(cancelar);
    await tester.tap(cancelar);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancelar pedido').last);
    await tester.pumpAndSettle();

    expect(find.text('Cancelado por você'), findsOneWidget);
    expect(find.text('Cancelar'), findsNothing);
  });

  testWidgets('tela de pedir resume históricos com muitos pedidos',
      (tester) async {
    final ids = List.generate(
      5,
      (indice) =>
          '33333333-3333-3333-3333-${(indice + 1).toString().padLeft(12, '0')}',
    );
    SharedPreferences.setMockInitialValues({
      'pedidos_publico_A1B2C3': ids,
    });
    final cliente = MockClient((requisicao) async {
      if (requisicao.url.path.endsWith('/fila')) {
        return http.Response('[]', 200);
      }
      if (requisicao.url.path.contains('/pedidos/')) {
        final indice = ids.indexOf(requisicao.url.pathSegments.last) + 1;
        return http.Response(
          '{"id":"${ids[indice - 1]}","apresentacaoId":"22222222-2222-2222-2222-222222222222","musica":"Música $indice","artista":null,"nomeSolicitante":null,"status":"Aceito","posicao":$indice,"criadoEm":"2026-09-03T20:00:00Z"}',
          200,
        );
      }
      return http.Response(
        '{"id":"22222222-2222-2222-2222-222222222222","nome":"Noite Acústica","data":"2026-09-03","local":"Café Central","codigo":"A1B2C3","perfilArtistico":{"id":"11111111-1111-1111-1111-111111111111","nomeArtistico":"Duo Aurora","bio":null},"pedidosAbertos":true,"status":"EmAndamento","tipo":"Publica"}',
        200,
      );
    });

    await tester.pumpWidget(MaterialApp(
      home: AreaDoPublico(
        api: ApiTocaEssa(cliente: cliente, enderecoBase: 'http://teste'),
        codigoInicial: 'A1B2C3',
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Novo pedido'), findsOneWidget);
    expect(find.text('Música 1'), findsOneWidget);
    expect(find.text('Música 2'), findsOneWidget);
    expect(find.text('Música 3'), findsNothing);
    expect(find.text('Música 4'), findsNothing);
    final verTodos = find.text('Ver todos os 5 pedidos');
    await tester.ensureVisible(verTodos);
    await tester.tap(verTodos);
    await tester.pumpAndSettle();

    expect(find.text('Música 4'), findsOneWidget);
    expect(find.text('Música 5'), findsOneWidget);
    expect(find.text('Mostrar somente os recentes'), findsOneWidget);
  });

  testWidgets('fila pública separa tocando próximas e já tocadas',
      (tester) async {
    final cliente = MockClient((requisicao) async {
      if (requisicao.url.path.endsWith('/fila')) {
        return http.Response(
          '[{"id":"30000000-0000-0000-0000-000000000001","apresentacaoId":"22222222-2222-2222-2222-222222222222","musica":"Agora","artista":null,"nomeSolicitante":null,"status":"TocandoAgora","posicao":null,"criadoEm":"2026-09-03T20:01:00Z"},{"id":"30000000-0000-0000-0000-000000000002","apresentacaoId":"22222222-2222-2222-2222-222222222222","musica":"Depois","artista":null,"nomeSolicitante":null,"status":"Aceito","posicao":1,"criadoEm":"2026-09-03T20:02:00Z"},{"id":"30000000-0000-0000-0000-000000000003","apresentacaoId":"22222222-2222-2222-2222-222222222222","musica":"Anterior","artista":null,"nomeSolicitante":null,"status":"Finalizado","posicao":null,"criadoEm":"2026-09-03T20:00:00Z"}]',
          200,
        );
      }
      return http.Response(
        '{"id":"22222222-2222-2222-2222-222222222222","nome":"Noite Acústica","data":"2026-09-03","local":"Café Central","codigo":"A1B2C3","perfilArtistico":{"id":"11111111-1111-1111-1111-111111111111","nomeArtistico":"Duo Aurora","bio":null},"pedidosAbertos":true,"status":"EmAndamento"}',
        200,
      );
    });

    await tester.pumpWidget(MaterialApp(
      home: AreaDoPublico(
        api: ApiTocaEssa(cliente: cliente, enderecoBase: 'http://teste'),
        codigoInicial: 'A1B2C3',
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Fila').last);
    await tester.pumpAndSettle();

    expect(find.text('Tocando agora'), findsWidgets);
    expect(find.text('Próximas músicas'), findsOneWidget);
    expect(find.text('Já tocadas'), findsOneWidget);
    expect(find.text('Agora'), findsOneWidget);
    expect(find.text('Depois'), findsOneWidget);
    expect(find.text('Anterior'), findsOneWidget);
  });

  testWidgets('público avalia pedido finalizado com estrelas', (tester) async {
    SharedPreferences.setMockInitialValues({
      'pedidos_publico_A1B2C3': ['33333333-3333-3333-3333-333333333333'],
    });
    final cliente = MockClient((requisicao) async {
      if (requisicao.url.path.endsWith('/fila')) {
        return http.Response(
          '[{"id":"33333333-3333-3333-3333-333333333333","apresentacaoId":"22222222-2222-2222-2222-222222222222","musica":"Evidências","artista":null,"nomeSolicitante":"Ana","status":"Finalizado","posicao":null,"criadoEm":"2026-09-03T20:00:00Z","quantidadeAvaliacoes":0,"solicitantes":["Ana"]}]',
          200,
        );
      }
      if (requisicao.url.path.contains('/pedidos/')) {
        final avaliacao = requisicao.method == 'PUT'
            ? ',"quantidadeAvaliacoes":1,"mediaAvaliacoes":5,"minhaAvaliacao":5'
            : '';
        if (requisicao.method == 'PUT') {
          expect(requisicao.body, contains('"estrelas":5'));
        }
        return http.Response(
          '{"id":"33333333-3333-3333-3333-333333333333","apresentacaoId":"22222222-2222-2222-2222-222222222222","musica":"Evidências","artista":null,"nomeSolicitante":"Ana","status":"Finalizado","posicao":null,"criadoEm":"2026-09-03T20:00:00Z"$avaliacao}',
          200,
        );
      }
      return http.Response(
        '{"id":"22222222-2222-2222-2222-222222222222","nome":"Noite Acústica","data":"2026-09-03","local":"Café Central","codigo":"A1B2C3","perfilArtistico":{"id":"11111111-1111-1111-1111-111111111111","nomeArtistico":"Duo Aurora","bio":null},"pedidosAbertos":true,"status":"EmAndamento","tipo":"Publica"}',
        200,
      );
    });

    await tester.pumpWidget(MaterialApp(
      home: AreaDoPublico(
        api: ApiTocaEssa(cliente: cliente, enderecoBase: 'http://teste'),
        codigoInicial: 'A1B2C3',
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Fila').last);
    await tester.pumpAndSettle();

    final cincoEstrelas = find.byTooltip('5 estrelas');
    await tester.ensureVisible(cincoEstrelas);
    await tester.tap(cincoEstrelas);
    await tester.pumpAndSettle();

    expect(find.text('Obrigado pela avaliação!'), findsOneWidget);
  });
}
