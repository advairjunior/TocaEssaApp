import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:toca_essa_app/infraestrutura/api_toca_essa.dart';
import 'package:toca_essa_app/main.dart';
import 'package:toca_essa_app/telas/componentes_formulario.dart';

const _contaArtistaJson =
    '{"id":"aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa","nome":"Ana","email":"ana@artista.com","criadoEm":"2026-09-03T20:00:00Z"}';

Finder campo(String rotulo) => find.descendant(
      of: find.widgetWithText(CampoTexto, rotulo),
      matching: find.byType(TextField),
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('nova conta inicia vazia e cria o próprio perfil',
      (tester) async {
    SharedPreferences.setMockInitialValues({'token_do_artista': 'TOKEN-NOVO'});
    final cliente = MockClient((requisicao) async {
      expect(requisicao.headers['authorization'], 'Bearer TOKEN-NOVO');
      if (requisicao.url.path == '/api/artista/conta') {
        return http.Response(_contaArtistaJson, 200);
      }
      if (requisicao.url.path == '/api/perfil-artistico' &&
          requisicao.method == 'GET') {
        return http.Response('{"mensagem":"Perfil não encontrado."}', 404);
      }
      if (requisicao.url.path == '/api/apresentacoes') {
        return http.Response('[]', 200);
      }
      if (requisicao.url.path == '/api/perfil-artistico' &&
          requisicao.method == 'PUT') {
        expect(requisicao.body, contains('"nomeArtistico":"Novo Artista"'));
        return http.Response(
          '{"perfil":{"id":"11111111-1111-1111-1111-111111111111","nomeArtistico":"Novo Artista","bio":null,"fotoUrl":null},"exibirInstagram":false,"exibirWhatsapp":false,"pixAtivo":false}',
          200,
        );
      }
      return http.Response('Não encontrado', 404);
    });

    await tester.pumpWidget(TocaEssaApp(
      api: ApiTocaEssa(cliente: cliente, enderecoBase: 'http://teste'),
    ));
    final acessarPainel = find.text('Acessar Painel do Artista');
    await tester.ensureVisible(acessarPainel);
    await tester.tap(acessarPainel);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Criar perfil artístico'));
    await tester.pumpAndSettle();
    expect(find.text('Criar perfil artístico'), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextField, 'Nome artístico'),
      'Novo Artista',
    );
    final criarPerfil = find.text('Criar perfil artístico');
    await tester.ensureVisible(criarPerfil);
    await tester.tap(criarPerfil);
    await tester.pumpAndSettle();

    expect(find.text('Perfil Artístico salvo.'), findsOneWidget);
    expect(find.text('Salvar alterações'), findsOneWidget);
  });

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

    expect(find.text('Ao vivo agora'), findsOneWidget);
    expect(find.text('Show de hoje'), findsOneWidget);
    expect(find.text('Show de sábado'), findsOneWidget);
    expect(find.text('Show anterior'), findsNothing);
    await tester.tap(find.text('Histórico'));
    await tester.pumpAndSettle();
    expect(find.text('Show anterior'), findsOneWidget);
    expect(find.text('Show de sábado'), findsNothing);
    expect(find.text('Show de hoje'), findsOneWidget);
    expect(find.text('Ver estatísticas'), findsNothing);
    expect(find.text('Estatísticas'), findsNothing);
  });

  testWidgets('lista apresentações da mais recente para a mais antiga',
      (tester) async {
    SharedPreferences.setMockInitialValues({'token_do_artista': 'TOKEN'});
    String encerrada(String id, String nome, String data) =>
        '{"id":"20000000-0000-0000-0000-00000000000$id","nome":"$nome","data":"$data","local":"Clube","codigo":"COD00$id","perfilArtistico":{"id":"11111111-1111-1111-1111-111111111111","nomeArtistico":"Duo Aurora"},"pedidosAbertos":false,"status":"Encerrada"}';
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
        '[${encerrada('1', 'Show de agosto', '2026-08-10')},'
        '${encerrada('2', 'Show de setembro', '2026-09-20')},'
        '${encerrada('3', 'Show de julho', '2026-07-05')}]',
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

    final posicoes = [
      'Show de setembro',
      'Show de agosto',
      'Show de julho',
    ].map((nome) => tester.getTopLeft(find.text(nome)).dy).toList();
    expect(posicoes, orderedEquals([...posicoes]..sort()));
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
    await tester.tap(find.text('Nova apresentação'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Resenha'));
    await tester.pumpAndSettle();
    await tester.enterText(campo('Nome da apresentação'), 'Noite Acústica');
    await tester.enterText(campo('Local'), 'Café Central');
    final criar = find.text('Criar apresentação');
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
    await tester.tap(find.text('Noite Acústica'));
    await tester.pumpAndSettle();
    final editar = find.text('Editar apresentação');
    await tester.ensureVisible(editar);
    await tester.tap(editar);
    await tester.pumpAndSettle();

    await tester.enterText(campo('Nome da apresentação'), 'Especial de Sábado');
    await tester.enterText(campo('Local'), 'Praça Central');
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
    await tester.tap(find.text('Noite Acústica'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Iniciar'));
    await tester.pumpAndSettle();

    expect(find.text('Ao vivo'), findsOneWidget);
    expect(find.text('Encerrar'), findsOneWidget);
    expect(find.text('Iniciar'), findsNothing);
  });
}
