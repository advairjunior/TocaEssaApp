import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:toca_essa_app/infraestrutura/api_toca_essa.dart';
import 'package:toca_essa_app/main.dart';

const _contaArtistaJson =
    '{"id":"aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa","nome":"Ana","email":"ana@artista.com","criadoEm":"2026-09-03T20:00:00Z"}';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets('Painel do Artista separa eventos por momento', (tester) async {
    SharedPreferences.setMockInitialValues({'token_do_artista': 'TOKEN'});
    final cliente = MockClient((requisicao) async {
      if (requisicao.url.path == '/api/artista/conta') {
        return http.Response(_contaArtistaJson, 200);
      }
      if (requisicao.url.path.endsWith('/perfil-artistico')) {
        return http.Response(
          '{"id":"11111111-1111-1111-1111-111111111111","nomeArtistico":"Duo Aurora","bio":null}',
          200,
        );
      }
      return http.Response(
        '[{"id":"20000000-0000-0000-0000-000000000001","nome":"Show de hoje","data":"2026-09-04","local":"Praça","codigo":"HOJE01","perfilArtistico":{"id":"11111111-1111-1111-1111-111111111111","nomeArtistico":"Duo Aurora"},"pedidosAbertos":true,"status":"EmAndamento"},{"id":"20000000-0000-0000-0000-000000000002","nome":"Show de sábado","data":"2026-09-05","local":"Bar","codigo":"SABADO","perfilArtistico":{"id":"11111111-1111-1111-1111-111111111111","nomeArtistico":"Duo Aurora"},"pedidosAbertos":true,"status":"Agendada"},{"id":"20000000-0000-0000-0000-000000000003","nome":"Show anterior","data":"2026-09-01","local":"Clube","codigo":"ANTES1","perfilArtistico":{"id":"11111111-1111-1111-1111-111111111111","nomeArtistico":"Duo Aurora"},"pedidosAbertos":false,"status":"Encerrada"}]',
        200,
      );
    });

    await tester.pumpWidget(TocaEssaApp(
      api: ApiTocaEssa(cliente: cliente, enderecoBase: 'http://teste'),
    ));
    final acessarPainel = find.text('Acessar Painel do Artista');
    await tester.ensureVisible(acessarPainel);
    await tester.tap(acessarPainel);
    await tester.pumpAndSettle();

    expect(find.text('Show de hoje'), findsOneWidget);
    expect(find.text('Show de sábado'), findsNothing);
    await tester.tap(find.text('Agendadas'));
    await tester.pumpAndSettle();
    expect(find.text('Show de sábado'), findsOneWidget);
    expect(find.text('Show de hoje'), findsNothing);
    await tester.tap(find.text('Histórico'));
    await tester.pumpAndSettle();
    expect(find.text('Show anterior'), findsOneWidget);
    expect(find.text('Ver estatísticas'), findsNothing);
    expect(find.text('Estatísticas'), findsNothing);
  });

  testWidgets('mostra QR Code depois de criar apresentação', (tester) async {
    SharedPreferences.setMockInitialValues({'token_do_artista': 'TOKEN'});
    final cliente = MockClient((requisicao) async {
      if (requisicao.url.path == '/api/artista/conta') {
        return http.Response(_contaArtistaJson, 200);
      }
      if (requisicao.url.path.endsWith('/perfil-artistico')) {
        return http.Response(
          '{"id":"11111111-1111-1111-1111-111111111111","nomeArtistico":"Duo Aurora","bio":"Voz e violão"}',
          200,
        );
      }
      if (requisicao.method == 'GET') return http.Response('[]', 200);
      expect(requisicao.body, contains('"tipo":"ResenhaEntreAmigos"'));
      return http.Response(
        '{"apresentacao":{"id":"22222222-2222-2222-2222-222222222222","nome":"Noite Acústica","data":"2026-09-03","local":"Café Central","codigo":"A1B2C3","perfilArtistico":{"id":"11111111-1111-1111-1111-111111111111","nomeArtistico":"Duo Aurora","bio":"Voz e violão"},"pedidosAbertos":true,"tipo":"ResenhaEntreAmigos"},"linkPublico":"http://localhost:5173/#/publico/A1B2C3"}',
        201,
      );
    });
    final api = ApiTocaEssa(cliente: cliente, enderecoBase: 'http://teste');

    await tester.pumpWidget(TocaEssaApp(api: api));
    final acessarPainel = find.text('Acessar Painel do Artista');
    await tester.ensureVisible(acessarPainel);
    await tester.tap(acessarPainel);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Criar').last);
    await tester.pumpAndSettle();
    final tipoPublico = find.text('Apresentação Pública');
    await tester.ensureVisible(tipoPublico);
    await tester.tap(tipoPublico);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Resenha entre Amigos').last);
    await tester.pumpAndSettle();
    await tester.enterText(
        find.widgetWithText(TextField, 'Nome da apresentação'),
        'Noite Acústica');
    await tester.enterText(
        find.widgetWithText(TextField, 'Local'), 'Café Central');
    final criar = find.text('Criar Apresentação');
    await tester.ensureVisible(criar);
    await tester.tap(criar);
    await tester.pumpAndSettle();

    expect(find.text('Apresentação criada!'), findsOneWidget);
    expect(find.text('A1B2C3'), findsWidgets);
    expect(find.text('Concluir'), findsOneWidget);
  });

  testWidgets('artista edita uma apresentação existente', (tester) async {
    SharedPreferences.setMockInitialValues({'token_do_artista': 'TOKEN'});
    final cliente = MockClient((requisicao) async {
      if (requisicao.url.path == '/api/artista/conta') {
        return http.Response(_contaArtistaJson, 200);
      }
      if (requisicao.url.path.endsWith('/perfil-artistico')) {
        return http.Response(
          '{"id":"11111111-1111-1111-1111-111111111111","nomeArtistico":"Duo Aurora","bio":"Voz e violão"}',
          200,
        );
      }
      if (requisicao.method == 'GET') {
        return http.Response(
          '[{"id":"22222222-2222-2222-2222-222222222222","nome":"Noite Acústica","data":"2026-09-03","local":"Café Central","codigo":"A1B2C3","perfilArtistico":{"id":"11111111-1111-1111-1111-111111111111","nomeArtistico":"Duo Aurora","bio":"Voz e violão"},"pedidosAbertos":true}]',
          200,
        );
      }
      return http.Response(
        '{"id":"22222222-2222-2222-2222-222222222222","nome":"Especial de Sábado","data":"2026-09-03","local":"Praça Central","codigo":"A1B2C3","perfilArtistico":{"id":"11111111-1111-1111-1111-111111111111","nomeArtistico":"Duo Aurora","bio":"Voz e violão"},"pedidosAbertos":true}',
        200,
      );
    });

    await tester.pumpWidget(
      TocaEssaApp(
          api: ApiTocaEssa(cliente: cliente, enderecoBase: 'http://teste')),
    );
    final acessarPainel = find.text('Acessar Painel do Artista');
    await tester.ensureVisible(acessarPainel);
    await tester.tap(acessarPainel);
    await tester.pumpAndSettle();
    final opcoes = find.byTooltip('Opções da Apresentação');
    await tester.tap(find.text('Noite Acústica'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Apresentação').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(opcoes);
    await tester.tap(opcoes);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Editar'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, 'Nome da apresentação'),
      'Especial de Sábado',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Local'),
      'Praça Central',
    );
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();

    expect(find.text('Especial de Sábado'), findsWidgets);
    expect(find.textContaining('Praça Central'), findsOneWidget);
  });

  testWidgets('artista inicia uma apresentação agendada', (tester) async {
    SharedPreferences.setMockInitialValues({'token_do_artista': 'TOKEN'});
    final cliente = MockClient((requisicao) async {
      if (requisicao.url.path == '/api/artista/conta') {
        return http.Response(_contaArtistaJson, 200);
      }
      if (requisicao.url.path.endsWith('/perfil-artistico')) {
        return http.Response(
          '{"id":"11111111-1111-1111-1111-111111111111","nomeArtistico":"Duo Aurora","bio":null}',
          200,
        );
      }
      const apresentacao =
          '{"id":"22222222-2222-2222-2222-222222222222","nome":"Noite Acústica","data":"2026-09-03","local":"Café Central","codigo":"A1B2C3","perfilArtistico":{"id":"11111111-1111-1111-1111-111111111111","nomeArtistico":"Duo Aurora","bio":null},"pedidosAbertos":true,"status":"Agendada"}';
      if (requisicao.method == 'GET') {
        return http.Response('[$apresentacao]', 200);
      }
      return http.Response(
        apresentacao.replaceFirst('"Agendada"', '"EmAndamento"'),
        200,
      );
    });

    await tester.pumpWidget(
      TocaEssaApp(
          api: ApiTocaEssa(cliente: cliente, enderecoBase: 'http://teste')),
    );
    final acessarPainel = find.text('Acessar Painel do Artista');
    await tester.ensureVisible(acessarPainel);
    await tester.tap(acessarPainel);
    await tester.pumpAndSettle();
    final iniciar = find.text('Iniciar Apresentação');
    await tester.tap(find.text('Noite Acústica'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(iniciar);
    await tester.tap(iniciar);
    await tester.pumpAndSettle();

    expect(find.text('Apresentação Pública · Em andamento'), findsOneWidget);
    await tester.tap(find.byTooltip('Opções da Apresentação'));
    await tester.pumpAndSettle();
    expect(find.text('Encerrar Apresentação'), findsOneWidget);
  });

}
