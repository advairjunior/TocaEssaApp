import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:toca_essa_app/infraestrutura/api_toca_essa.dart';
import 'package:toca_essa_app/telas/area_do_publico.dart';

String _apresentacao(String tipo) =>
    '{"id":"22222222-2222-2222-2222-222222222222","nome":"Noite Acústica","data":"2026-09-03","local":"Café Central","codigo":"A1B2C3","perfilArtistico":{"id":"11111111-1111-1111-1111-111111111111","nomeArtistico":"Duo Aurora","bio":null},"pedidosAbertos":true,"status":"EmAndamento","tipo":"$tipo"}';

String _pedido(String id, String status, {int? posicao}) =>
    '{"id":"$id","apresentacaoId":"22222222-2222-2222-2222-222222222222","musica":"Música $id","artista":"Banda","nomeSolicitante":"Ana","status":"$status","posicao":${posicao ?? 'null'},"criadoEm":"2026-09-03T20:00:00Z","formaParticipacao":"EuCanto","tomPreferido":"G"}';

Future<void> _abrir(WidgetTester tester, MockClient cliente) async {
  await tester.pumpWidget(MaterialApp(
    home: AreaDoPublico(
      api: ApiTocaEssa(cliente: cliente, enderecoBase: 'http://teste'),
      codigoInicial: 'A1B2C3',
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('seus pedidos aparecem em lista agrupada com posição na fila',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'pedidos_publico_A1B2C3': ['1', '2'],
    });
    await _abrir(
      tester,
      MockClient((requisicao) async {
        final caminho = requisicao.url.path;
        if (caminho.endsWith('/fila')) return http.Response('[]', 200);
        if (caminho.endsWith('/pedidos/1')) {
          return http.Response(_pedido('1', 'Aguardando'), 200);
        }
        if (caminho.endsWith('/pedidos/2')) {
          return http.Response(_pedido('2', 'Aceito', posicao: 2), 200);
        }
        return http.Response(_apresentacao('Publica'), 200);
      }),
    );

    expect(find.byType(Card), findsNothing);
    expect(find.text('Aguardando análise'), findsOneWidget);
    expect(find.text('Posição 2 na fila · ≈ 6 min'), findsOneWidget);
    expect(find.text('Eu canto · Tom G'), findsNWidgets(2));
    expect(find.text('Cancelar'), findsOneWidget);
  });

  testWidgets('galera aparece em lista agrupada destacando você',
      (tester) async {
    SharedPreferences.setMockInitialValues({'token_do_publico': 'TOKEN'});
    await _abrir(
      tester,
      MockClient((requisicao) async {
        final caminho = requisicao.url.path;
        if (caminho.endsWith('/fila') || caminho.endsWith('/meus-pedidos')) {
          return http.Response('[]', 200);
        }
        if (caminho.endsWith('/participacoes')) return http.Response('', 204);
        if (caminho == '/api/publico/perfil') {
          return http.Response(
            '{"id":"44444444-4444-4444-4444-444444444444","nome":"Ana Souza","email":"ana@example.com","fotoUrl":null,"criadoEm":"2026-09-03T20:00:00Z"}',
            200,
          );
        }
        if (caminho == '/api/publico/estatisticas') {
          return http.Response(
            '{"participacoes":1,"pedidos":1,"pedidosTocados":0,"avaliacoesRealizadas":0,"mediaAvaliacoes":null,"musicasMaisPedidas":[]}',
            200,
          );
        }
        if (caminho.endsWith('/participantes')) {
          return http.Response(
            '[{"publicoId":"44444444-4444-4444-4444-444444444444","nome":"Ana Souza","fotoUrl":null,"pedidos":5,"pedidosTocados":3,"mediaAvaliacoes":4.5,"musicasMaisPedidas":[{"musica":"Evidências","quantidade":2}]},'
            '{"publicoId":"55555555-5555-5555-5555-555555555555","nome":"Beto","fotoUrl":null,"pedidos":1,"pedidosTocados":0,"mediaAvaliacoes":null,"musicasMaisPedidas":[]}]',
            200,
          );
        }
        return http.Response(_apresentacao('ResenhaEntreAmigos'), 200);
      }),
    );
    await tester.tap(find.text('Galera'));
    await tester.pumpAndSettle();

    expect(find.byType(Card), findsNothing);
    expect(find.text('Você'), findsOneWidget);
    expect(find.text('Beto'), findsOneWidget);
    expect(find.text('5 pedidos · 3 tocados'), findsOneWidget);
    expect(find.text('Mais pedida: Evidências'), findsOneWidget);
  });
}
