import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:toca_essa_app/infraestrutura/api_toca_essa.dart';
import 'package:toca_essa_app/main.dart';

const _aviso = 'Carregando o aplicativo TocaEssa, aguarde…';

const _contaArtistaJson =
    '{"id":"aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa","nome":"Ana","email":"ana@artista.com","criadoEm":"2026-09-03T20:00:00Z"}';

/// Servidor do plano gratuito: dormindo, cada resposta demora [atraso]; o
/// cutucão no /api/saude fica contado à parte.
class _ServidorDormindo {
  _ServidorDormindo(
      {this.atraso = Duration.zero,
      this.resposta = '{"mensagem":"Não encontrado."}',
      this.status = 404});

  final Duration atraso;
  final String resposta;
  final int status;
  int acordou = 0;

  late final api = ApiTocaEssa(
    enderecoBase: 'http://teste',
    cliente: MockClient((requisicao) async {
      if (requisicao.url.path == '/api/saude') {
        acordou++;
        return http.Response('{"status":"ok"}', 200);
      }
      if (atraso > Duration.zero) await Future<void>.delayed(atraso);
      return http.Response(resposta, status);
    }),
  );
}

Future<void> _abrir(WidgetTester tester, _ServidorDormindo servidor,
    {String rota = '/'}) async {
  tester.binding.platformDispatcher.defaultRouteNameTestValue = rota;
  addTearDown(tester.binding.platformDispatcher.clearDefaultRouteNameTestValue);
  await tester.pumpWidget(TocaEssaApp(api: servidor.api));
}

/// Fecha o app e deixa terminar os pedidos que ainda esperam o servidor.
Future<void> _fechar(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 30));
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 30));
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('a página mostra que o TocaEssa está carregando antes de o Flutter abrir',
      () {
    final html = File('web/index.html').readAsStringSync();

    expect(html, contains('id="carregando-toca-essa"'));
    expect(html, contains('Carregando o aplicativo TocaEssa, aguarde…'));
    expect(html, contains('flutter-first-frame'));
  });

  testWidgets('abrir o início já acorda o servidor', (tester) async {
    final servidor = _ServidorDormindo();
    await _abrir(tester, servidor);
    await tester.pumpAndSettle();

    expect(servidor.acordou, 1);
  });

  testWidgets('abrir o acesso do artista já acorda o servidor',
      (tester) async {
    final servidor = _ServidorDormindo();
    await _abrir(tester, servidor, rota: '/artista');
    await tester.pumpAndSettle();

    expect(servidor.acordou, greaterThanOrEqualTo(1));
  });

  testWidgets('QR do show demorando avisa que o app está carregando',
      (tester) async {
    final servidor =
        _ServidorDormindo(atraso: const Duration(seconds: 20));
    await _abrir(tester, servidor, rota: '/publico/ABC123');

    await tester.pump(const Duration(seconds: 2));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text(_aviso), findsNothing);

    await tester.pump(const Duration(seconds: 2));
    expect(find.text(_aviso), findsOneWidget);

    await tester.pump(const Duration(seconds: 20));
    await tester.pump();
    expect(find.text(_aviso), findsNothing);
    expect(find.text('Código não encontrado'), findsOneWidget);
    await _fechar(tester);
  });

  testWidgets('painel com sessão salva demorando avisa que está carregando',
      (tester) async {
    SharedPreferences.setMockInitialValues({'token_do_artista': 'TOKEN'});
    final servidor =
        _ServidorDormindo(atraso: const Duration(seconds: 20));
    await _abrir(tester, servidor, rota: '/artista');

    await tester.pump(const Duration(seconds: 2));
    expect(find.text(_aviso), findsNothing);

    await tester.pump(const Duration(seconds: 2));
    expect(find.text(_aviso), findsOneWidget);
    await _fechar(tester);
  });

  testWidgets('entrar no painel demorando avisa que está carregando',
      (tester) async {
    final servidor = _ServidorDormindo(
        atraso: const Duration(seconds: 20),
        resposta: '{"conta":$_contaArtistaJson,"token":"TOKEN-ARTISTA"}',
        status: 200);
    await _abrir(tester, servidor, rota: '/artista');
    await tester.pumpAndSettle();
    await tester.enterText(
        find.widgetWithText(TextField, 'E-mail'), 'ana@artista.com');
    await tester.enterText(find.widgetWithText(TextField, 'Senha'), 'senha123');
    await tester.tap(find.byIcon(Icons.login_rounded));
    await tester.pump();

    await tester.pump(const Duration(seconds: 2));
    expect(find.text(_aviso), findsNothing);

    await tester.pump(const Duration(seconds: 2));
    expect(find.text(_aviso), findsOneWidget);
    await _fechar(tester);
  });
}
