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
  testWidgets('exibe as entradas pública e do artista', (tester) async {
    await tester.pumpWidget(const TocaEssaApp());

    expect(find.text('Área do Público'), findsOneWidget);
    expect(find.text('Acessar Painel do Artista'), findsOneWidget);
    expect(find.text('Código da Apresentação'), findsOneWidget);
    expect(find.text('Feito por Advair'), findsOneWidget);
    expect(
      find.image(const AssetImage('assets/fundos/inicio_palco.png')),
      findsOneWidget,
    );
  });

  testWidgets('artista cria conta e acessa painel protegido', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final cliente = MockClient((requisicao) async {
      if (requisicao.url.path == '/api/artista/contas') {
        expect(requisicao.body, contains('ana@artista.com'));
        return http.Response(
          '{"conta":$_contaArtistaJson,"token":"TOKEN-ARTISTA"}',
          201,
        );
      }
      if (requisicao.url.path.endsWith('/perfil-artistico')) {
        expect(requisicao.headers['authorization'], 'Bearer TOKEN-ARTISTA');
        return http.Response(
          '{"id":"11111111-1111-1111-1111-111111111111","nomeArtistico":"Duo Aurora","bio":null}',
          200,
        );
      }
      return http.Response('[]', 200);
    });
    await tester.pumpWidget(TocaEssaApp(
      api: ApiTocaEssa(cliente: cliente, enderecoBase: 'http://teste'),
    ));
    final acessarPainel = find.text('Acessar Painel do Artista');
    await tester.ensureVisible(acessarPainel);
    await tester.tap(acessarPainel);
    await tester.pumpAndSettle();

    expect(
      find.image(const AssetImage('assets/fundos/bastidores.png')),
      findsOneWidget,
    );
    expect(find.text('Entre no seu painel'), findsOneWidget);
    await tester.tap(find.text('Primeiro acesso? Criar conta'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Seu nome'), 'Ana');
    await tester.enterText(
        find.widgetWithText(TextField, 'E-mail'), 'ana@artista.com');
    await tester.enterText(find.widgetWithText(TextField, 'Senha'), 'senha123');
    await tester.tap(find.text('Criar conta e entrar'));
    await tester.pumpAndSettle();

    expect(find.text('Painel do Artista'), findsOneWidget);
    expect(find.text('Nenhuma Apresentação ainda'), findsOneWidget);
    final preferencias = await SharedPreferences.getInstance();
    expect(preferencias.getString('token_do_artista'), 'TOKEN-ARTISTA');
  });

  testWidgets('painel autenticado preserva bastidores e navegação',
      (tester) async {
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
      return http.Response('[]', 200);
    });
    await tester.pumpWidget(TocaEssaApp(
      api: ApiTocaEssa(cliente: cliente, enderecoBase: 'http://teste'),
    ));
    final acessarPainel = find.text('Acessar Painel do Artista');
    await tester.ensureVisible(acessarPainel);
    await tester.tap(acessarPainel);
    await tester.pumpAndSettle();

    expect(
      find.image(const AssetImage('assets/fundos/bastidores.png')),
      findsOneWidget,
    );
    expect(find.text('Apresentações'), findsOneWidget);
    expect(find.text('Criar'), findsOneWidget);
    expect(find.text('Perfil geral'), findsOneWidget);
  });

  testWidgets('Painel separa Apresentações, Fila, Estatísticas e Perfil',
      (tester) async {
    SharedPreferences.setMockInitialValues({'token_do_artista': 'TOKEN'});
    final cliente = MockClient((requisicao) async {
      if (requisicao.url.path == '/api/artista/conta') {
        expect(requisicao.headers['authorization'], 'Bearer TOKEN');
        return http.Response(_contaArtistaJson, 200);
      }
      if (requisicao.url.path.endsWith('/perfil-artistico')) {
        return http.Response(
          '{"id":"11111111-1111-1111-1111-111111111111","nomeArtistico":"Duo Aurora","bio":"Voz e violão"}',
          200,
        );
      }
      return http.Response('[]', 200);
    });
    await tester.pumpWidget(TocaEssaApp(
      api: ApiTocaEssa(cliente: cliente, enderecoBase: 'http://teste'),
    ));
    final acessarPainel = find.text('Acessar Painel do Artista');
    await tester.ensureVisible(acessarPainel);
    await tester.tap(acessarPainel);
    await tester.pumpAndSettle();

    expect(find.text('Nenhuma Apresentação ainda'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Nome artístico'), findsNothing);
    expect(find.text('Fila'), findsNothing);
    expect(find.text('Galera'), findsNothing);
    await tester.tap(find.text('Criar').last);
    await tester.pumpAndSettle();
    expect(find.text('Nova Apresentação'), findsOneWidget);
    expect(find.text('Nenhuma Apresentação ainda'), findsNothing);
    await tester.tap(find.text('Perfil geral').last);
    await tester.pumpAndSettle();

    expect(find.text('Perfil Artístico'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Nome artístico'), findsOneWidget);
    expect(find.text('Estatísticas'), findsWidgets);
    expect(find.text('Conquistas'), findsOneWidget);
    expect(find.text('Nova Apresentação'), findsNothing);
  });

  testWidgets('artista acompanha a Galera e participa da resenha',
      (tester) async {
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
      if (requisicao.url.path.endsWith('/participantes')) {
        return http.Response(
          '[{"publicoId":"11111111-1111-1111-1111-111111111111","nome":"Duo Aurora","fotoUrl":null,"pedidos":0,"pedidosTocados":0,"mediaAvaliacoes":null,"musicasMaisPedidas":[],"ehArtista":true},{"publicoId":"44444444-4444-4444-4444-444444444444","nome":"Ana","fotoUrl":null,"pedidos":0,"pedidosTocados":0,"mediaAvaliacoes":null,"musicasMaisPedidas":[],"ehArtista":false}]',
          200,
        );
      }
      return http.Response(
        '[{"id":"22222222-2222-2222-2222-222222222222","nome":"Resenha de sexta","data":"2026-09-03","local":"Casa da Ana","codigo":"A1B2C3","perfilArtistico":{"id":"11111111-1111-1111-1111-111111111111","nomeArtistico":"Duo Aurora"},"pedidosAbertos":true,"status":"EmAndamento","tipo":"ResenhaEntreAmigos"}]',
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
    await tester.tap(find.text('Resenha de sexta'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Galera').last);
    await tester.pumpAndSettle();

    expect(find.text('Galera da resenha'), findsOneWidget);
    expect(find.text('Duo Aurora'), findsWidgets);
    expect(find.text('Artista'), findsOneWidget);
    expect(find.text('Ana'), findsOneWidget);
    expect(find.text('0 pedidos · 0 tocados'), findsOneWidget);
  });

}
