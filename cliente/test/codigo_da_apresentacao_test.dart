import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:toca_essa_app/infraestrutura/api_toca_essa.dart';
import 'package:toca_essa_app/main.dart';

const _contaArtistaJson =
    '{"id":"aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa","nome":"Ana","email":"ana@artista.com","criadoEm":"2026-09-03T20:00:00Z"}';
const _apresentacaoJson =
    '{"id":"20000000-0000-0000-0000-000000000001","nome":"Show de sábado","data":"2026-09-05","local":"Bar do Zé","codigo":"COD001","perfilArtistico":{"id":"11111111-1111-1111-1111-111111111111","nomeArtistico":"Duo Aurora","bio":"Voz e violão. MPB, bossa nova e pop rock para noites tranquilas."},"pedidosAbertos":true,"status":"Agendada","tipo":"Publica"}';

/// Abre o painel, entra no show agendado (aba Mais) e toca no código.
Future<void> _abrirCodigo(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({'token_do_artista': 'TOKEN'});
  final cliente = MockClient((requisicao) async {
    if (requisicao.url.path == '/api/artista/conta') {
      return http.Response(_contaArtistaJson, 200);
    }
    if (requisicao.url.path == '/api/perfil-artistico') {
      return http.Response(
        '{"id":"11111111-1111-1111-1111-111111111111","nomeArtistico":"Duo Aurora","bio":"Voz e violão. MPB, bossa nova e pop rock para noites tranquilas."}',
        200,
      );
    }
    if (requisicao.url.path == '/api/apresentacoes') {
      return http.Response('[$_apresentacaoJson]', 200);
    }
    return http.Response('[]', 200);
  });
  await tester.pumpWidget(TocaEssaApp(
    api: ApiTocaEssa(cliente: cliente, enderecoBase: 'http://teste'),
  ));
  final acessar = find.text('Sou artista');
  await tester.ensureVisible(acessar);
  await tester.tap(acessar);
  await tester.pumpAndSettle();
  await tester.tap(find.text('Show de sábado'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('COD001'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('código de um show existente não finge que acabou de criar',
      (tester) async {
    await _abrirCodigo(tester);

    expect(find.text('Apresentação criada!'), findsNothing);
    expect(find.text('Código e link'), findsOneWidget);
    expect(find.text('Baixar cartão'), findsOneWidget);
    expect(find.text('Copiar link'), findsOneWidget);
  });

  testWidgets('modo telão mostra QR e código grandes em tela cheia',
      (tester) async {
    await _abrirCodigo(tester);

    final telao = find.text('Mostrar em tela cheia');
    await tester.ensureVisible(telao);
    await tester.tap(telao);
    await tester.pumpAndSettle();

    expect(find.text('Aponte a câmera para pedir sua música'), findsOneWidget);
    expect(find.text('COD001'), findsOneWidget);
    expect(find.byType(QrImageView), findsOneWidget);
    await tester.tap(find.byTooltip('Fechar tela cheia'));
    await tester.pumpAndSettle();
    expect(find.text('Código e link'), findsOneWidget);
  });

  testWidgets('cartão do código cabe em celular de 360px', (tester) async {
    addTearDown(tester.view.reset);
    tester.view.devicePixelRatio = 3;
    tester.view.physicalSize = const Size(360, 740) * 3;
    await _abrirCodigo(tester);

    expect(tester.takeException(), isNull);
  });
}
