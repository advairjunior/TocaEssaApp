import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:toca_essa_app/infraestrutura/api_toca_essa.dart';
import 'package:toca_essa_app/telas/area_do_publico.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets('resenha exige e cria Perfil do Público', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final cliente = MockClient((requisicao) async {
      if (requisicao.url.path.endsWith('/fila') ||
          requisicao.url.path.endsWith('/meus-pedidos')) {
        return http.Response('[]', 200);
      }
      if (requisicao.url.path.endsWith('/contas')) {
        expect(requisicao.body, contains('Ana Souza'));
        return http.Response(
          '{"perfil":{"id":"44444444-4444-4444-4444-444444444444","nome":"Ana Souza","email":"ana@example.com","fotoUrl":null,"criadoEm":"2026-09-03T20:00:00Z"},"token":"TOKEN-DA-ANA"}',
          201,
        );
      }
      if (requisicao.url.path.endsWith('/estatisticas')) {
        return http.Response(
          '{"participacoes":2,"pedidos":5,"pedidosTocados":3,"avaliacoesRealizadas":2,"mediaAvaliacoes":4.5,"musicasMaisPedidas":[{"musica":"Evidências","quantidade":2}]}',
          200,
        );
      }
      if (requisicao.url.path.endsWith('/participantes')) {
        expect(requisicao.headers['authorization'], 'Bearer TOKEN-DA-ANA');
        return http.Response(
          '[{"publicoId":"44444444-4444-4444-4444-444444444444","nome":"Ana Souza","fotoUrl":null,"pedidos":5,"pedidosTocados":3,"mediaAvaliacoes":4.5,"musicasMaisPedidas":[{"musica":"Evidências","quantidade":2}]}]',
          200,
        );
      }
      if (requisicao.url.path.endsWith('/participacoes')) {
        expect(requisicao.method, 'POST');
        expect(requisicao.headers['authorization'], 'Bearer TOKEN-DA-ANA');
        return http.Response('', 204);
      }
      return http.Response(
        '{"id":"22222222-2222-2222-2222-222222222222","nome":"Resenha de sexta","data":"2026-09-03","local":"Casa da Ana","codigo":"A1B2C3","perfilArtistico":{"id":"11111111-1111-1111-1111-111111111111","nomeArtistico":"Duo Aurora","bio":null},"pedidosAbertos":true,"status":"EmAndamento","tipo":"ResenhaEntreAmigos"}',
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

    expect(find.text('Entre na resenha'), findsOneWidget);
    final alternarCadastro = find.text('Criar meu Perfil do Público');
    await tester.ensureVisible(alternarCadastro);
    await tester.tap(alternarCadastro);
    await tester.pumpAndSettle();
    await tester.enterText(
        find.widgetWithText(TextField, 'Seu nome'), 'Ana Souza');
    await tester.enterText(
        find.widgetWithText(TextField, 'E-mail'), 'ana@example.com');
    await tester.enterText(find.widgetWithText(TextField, 'Senha'), 'senha123');
    final criar = find.text('Criar perfil e entrar');
    await tester.ensureVisible(criar);
    await tester.tap(criar);
    await tester.pumpAndSettle();

    expect(find.text('Enviando como Ana Souza'), findsOneWidget);
    await tester.tap(find.text('Galera').last);
    await tester.pumpAndSettle();
    expect(find.text('Galera da resenha'), findsOneWidget);
    expect(find.text('Ana Souza'), findsOneWidget);
    expect(find.text('Você'), findsOneWidget);
    await tester.tap(find.text('Perfil').last);
    await tester.pumpAndSettle();
    expect(find.text('Músicas favoritas'), findsOneWidget);
    expect(find.text('Evidências'), findsWidgets);
    expect(find.text('Minha retrospectiva'), findsNothing);
    expect(find.text('Conquistas'), findsOneWidget);
    expect(find.text('Primeiro pedido'), findsOneWidget);
    expect(find.text('Copiar meu resumo'), findsOneWidget);
    await tester.tap(find.text('Nesta resenha'));
    await tester.pumpAndSettle();
    expect(find.text('Minha retrospectiva'), findsOneWidget);
    expect(find.text('Colocar minha foto'), findsOneWidget);
    expect(find.text('Conquistas'), findsNothing);
    expect(find.text('Copiar meu resumo'), findsNothing);
    await tester.tap(find.text('Perfil geral'));
    await tester.pumpAndSettle();
    expect(find.text('Conquistas'), findsOneWidget);
    expect(find.text('Minha retrospectiva'), findsNothing);
    final preferencias = await SharedPreferences.getInstance();
    expect(preferencias.getString('token_do_publico'), 'TOKEN-DA-ANA');
  });

  testWidgets('apresentação pública oferece perfil sem obrigar cadastro',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    var tentouCriarConta = false;
    final cliente = MockClient((requisicao) async {
      if (requisicao.url.path.endsWith('/fila')) {
        return http.Response('[]', 200);
      }
      if (requisicao.url.path.endsWith('/contas')) {
        tentouCriarConta = true;
        return http.Response('{}', 400);
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

    expect(find.text('Seu nome (opcional)'), findsOneWidget);
    expect(find.text('Perfil do Público'), findsNothing);
    await tester.tap(find.text('Perfil').last);
    await tester.pumpAndSettle();
    expect(find.text('Perfil do Público'), findsOneWidget);
    expect(find.text('Use seu Perfil do Público'), findsOneWidget);
    expect(find.text('Continuar como convidado'), findsOneWidget);

    final criarPerfil = find.text('Criar meu Perfil do Público');
    await tester.ensureVisible(criarPerfil);
    await tester.tap(criarPerfil);
    await tester.pumpAndSettle();
    await tester.enterText(
        find.widgetWithText(TextField, 'Seu nome'), 'Deborah');
    await tester.enterText(
        find.widgetWithText(TextField, 'E-mail'), 'deborah@gmail.com');
    await tester.enterText(find.widgetWithText(TextField, 'Senha'), '123');
    final criarEEntrar = find.text('Criar perfil e entrar');
    await tester.ensureVisible(criarEEntrar);
    await tester.tap(criarEEntrar);
    await tester.pump();

    expect(
        find.text('A senha deve ter pelo menos 6 caracteres.'), findsOneWidget);
    expect(tentouCriarConta, isFalse);
  });

  testWidgets('atualização automática preserva campo e posição da tela',
      (tester) async {
    final cliente = MockClient((requisicao) async {
      if (requisicao.url.path.endsWith('/fila')) {
        return http.Response('[]', 200);
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

    final campoMusica = find.widgetWithText(TextField, 'Música');
    await tester.ensureVisible(campoMusica);
    await tester.tap(campoMusica);
    await tester.enterText(campoMusica, 'Minha música favorita');
    final editavel = find.descendant(
      of: campoMusica,
      matching: find.byType(EditableText),
    );
    final focoAntes =
        tester.state<EditableTextState>(editavel).widget.focusNode;
    final pagina = find
        .descendant(
          of: find.byType(SingleChildScrollView).first,
          matching: find.byType(Scrollable),
        )
        .first;
    final rolagemAntes = tester.state<ScrollableState>(pagina).position.pixels;

    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    expect(find.text('Minha música favorita'), findsOneWidget);
    expect(focoAntes.hasFocus, isTrue);
    expect(tester.state<ScrollableState>(pagina).position.pixels, rolagemAntes);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
}
