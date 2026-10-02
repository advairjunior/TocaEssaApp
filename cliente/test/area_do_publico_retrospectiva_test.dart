import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:toca_essa_app/infraestrutura/api_toca_essa.dart';
import 'package:toca_essa_app/telas/area_do_publico.dart';

const _resenhaJson =
    '{"id":"22222222-2222-2222-2222-222222222222","nome":"Resenha de sexta","data":"2026-09-03","local":"Casa da Ana","codigo":"A1B2C3","perfilArtistico":{"id":"11111111-1111-1111-1111-111111111111","nomeArtistico":"Duo Aurora","bio":null},"pedidosAbertos":true,"status":"EmAndamento","tipo":"ResenhaEntreAmigos"}';

Future<void> _abrirNestaResenha(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({'token_do_publico': 'TOKEN'});
  final cliente = MockClient((requisicao) async {
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
        '{"participacoes":1,"pedidos":2,"pedidosTocados":1,"avaliacoesRealizadas":0,"mediaAvaliacoes":null,"musicasMaisPedidas":[]}',
        200,
      );
    }
    if (caminho.endsWith('/participantes')) {
      return http.Response(
        '[{"publicoId":"44444444-4444-4444-4444-444444444444","nome":"Ana Souza","fotoUrl":null,"pedidos":2,"pedidosTocados":1,"mediaAvaliacoes":null,"musicasMaisPedidas":[{"musica":"Evidências","quantidade":2}]}]',
        200,
      );
    }
    return http.Response(_resenhaJson, 200);
  });
  await tester.pumpWidget(MaterialApp(
    home: AreaDoPublico(
      api: ApiTocaEssa(cliente: cliente, enderecoBase: 'http://teste'),
      codigoInicial: 'A1B2C3',
    ),
  ));
  await tester.pumpAndSettle();
  await tester.tap(find.byTooltip('Meu perfil'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Nesta resenha'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('perfil da resenha usa abas de texto e não repete o artista',
      (tester) async {
    await _abrirNestaResenha(tester);

    expect(find.byType(SegmentedButton<bool>), findsNothing);
    expect(find.byTooltip('Ver perfil do artista'), findsNothing);
    expect(find.text('Sua participação'), findsOneWidget);
    expect(find.text('Minha retrospectiva'), findsOneWidget);
  });

  testWidgets('sem foto, o cartão convida a tocar e salvar fica desabilitado',
      (tester) async {
    await _abrirNestaResenha(tester);

    final placeholder = find.text('Toque para colocar sua foto');
    await tester.ensureVisible(placeholder);
    expect(placeholder, findsOneWidget);
    final salvar = tester.widget<FilledButton>(find.ancestor(
      of: find.text('Salvar imagem para compartilhar'),
      matching: find.byWidgetPredicate((w) => w is FilledButton),
    ));
    expect(salvar.onPressed, isNull);
  });
}
