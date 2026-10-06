import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:toca_essa_app/infraestrutura/camera_do_app.dart';
import 'package:toca_essa_app/telas/camera_do_cartao.dart';

import 'apoio/camera_falsa.dart';

Widget _cartao(BuildContext context, Widget fundo) => Stack(
      key: const ValueKey('cartao'),
      fit: StackFit.expand,
      children: [fundo, const Center(child: Text('RETROSPECTIVA DO SHOW'))],
    );

Future<Future<RespostaDaCamera?>> _abrir(
  WidgetTester tester,
  CameraFalsa camera, {
  LenteDaCamera lente = LenteDaCamera.frontal,
}) async {
  late Future<RespostaDaCamera?> resultado;
  await tester.pumpWidget(MaterialApp(
    home: Builder(
      builder: (context) => TextButton(
        onPressed: () => resultado = Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CameraDoCartao(
              camera: camera,
              lenteInicial: lente,
              cartao: _cartao,
            ),
          ),
        ),
        child: const Text('abrir'),
      ),
    ),
  ));
  await tester.tap(find.text('abrir'));
  await tester.pumpAndSettle();
  return resultado;
}

void main() {
  testWidgets('enquadra a câmera dentro do próprio cartão', (tester) async {
    final camera = CameraFalsa();
    await _abrir(tester, camera);

    expect(camera.iniciadas, [LenteDaCamera.frontal]);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('cartao')),
        matching: find.byKey(const ValueKey('previa-falsa')),
      ),
      findsOneWidget,
    );
    expect(find.text('RETROSPECTIVA DO SHOW'), findsOneWidget);
  });

  testWidgets('troca entre selfie e câmera traseira', (tester) async {
    final camera = CameraFalsa();
    await _abrir(tester, camera);

    await tester.tap(find.byTooltip('Virar câmera'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Virar câmera'));
    await tester.pumpAndSettle();

    expect(camera.iniciadas, [
      LenteDaCamera.frontal,
      LenteDaCamera.traseira,
      LenteDaCamera.frontal,
    ]);
  });

  testWidgets('com uma lente só, não oferece virar a câmera', (tester) async {
    await _abrir(tester, CameraFalsa(lentes: {LenteDaCamera.frontal}));

    expect(find.byTooltip('Virar câmera'), findsNothing);
  });

  testWidgets('selfie com flash acende a tela, como no WhatsApp',
      (tester) async {
    final camera = CameraFalsa();
    final resultado = await _abrir(tester, camera);

    await tester.tap(find.byTooltip('Flash desligado'));
    await tester.pump();
    expect(find.byTooltip('Flash ligado'), findsOneWidget);
    await tester.tap(find.byTooltip('Tirar foto'));
    await tester.pump();
    expect(find.byKey(const ValueKey('flash-de-tela')), findsOneWidget);
    await tester.pumpAndSettle();

    expect(camera.capturas, 1);
    expect(camera.flashes, isEmpty);
    expect(find.byKey(const ValueKey('flash-de-tela')), findsNothing);
    await tester.tap(find.text('Usar foto'));
    await tester.pumpAndSettle();
    expect((await resultado)?.foto, pngMinimo);
  });

  testWidgets('câmera traseira usa a lanterna quando o aparelho tem',
      (tester) async {
    final camera = CameraFalsa(lanterna: true);
    await _abrir(tester, camera, lente: LenteDaCamera.traseira);

    await tester.tap(find.byTooltip('Flash desligado'));
    await tester.pump();
    await tester.tap(find.byTooltip('Tirar foto'));
    await tester.pumpAndSettle();

    expect(camera.flashes, [true, false]);
    expect(find.byKey(const ValueKey('flash-de-tela')), findsNothing);
  });

  testWidgets('traseira sem lanterna esconde o flash', (tester) async {
    await _abrir(tester, CameraFalsa(), lente: LenteDaCamera.traseira);

    expect(find.byTooltip('Flash desligado'), findsNothing);
  });

  testWidgets('pinça aproxima dentro do limite da câmera', (tester) async {
    final camera = CameraFalsa(zoomMaximo: 3);
    await _abrir(tester, camera);
    final centro = tester.getCenter(find.byKey(const ValueKey('cartao')));

    final dedo1 = await tester.startGesture(centro - const Offset(20, 0));
    final dedo2 =
        await tester.startGesture(centro + const Offset(20, 0), pointer: 2);
    await tester.pump();
    await dedo1.moveBy(const Offset(-200, 0));
    await dedo2.moveBy(const Offset(200, 0));
    await tester.pump();
    await dedo1.up();
    await dedo2.up();
    await tester.pumpAndSettle();

    expect(camera.zooms, isNotEmpty);
    expect(camera.zooms.last, 3);
    expect(camera.zooms.every((zoom) => zoom >= 1 && zoom <= 3), isTrue);
  });

  testWidgets('depois da foto dá para tirar outra', (tester) async {
    final camera = CameraFalsa();
    await _abrir(tester, camera);

    await tester.tap(find.byTooltip('Tirar foto'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('previa-falsa')), findsNothing);
    await tester.tap(find.text('Tirar outra'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('previa-falsa')), findsOneWidget);
  });

  testWidgets('tirar outra reabre a câmera na mesma lente, sem tela preta',
      (tester) async {
    final camera = CameraFalsa();
    await _abrir(tester, camera, lente: LenteDaCamera.traseira);

    await tester.tap(find.byTooltip('Tirar foto'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tirar outra'));
    await tester.pumpAndSettle();

    // No navegador, o vídeo que saiu da tela volta parado (preto); reabrir a
    // câmera é o que faz a prévia voltar, como ao virar a câmera.
    expect(camera.iniciadas, [LenteDaCamera.traseira, LenteDaCamera.traseira]);
  });

  testWidgets('fechar não devolve foto e desliga a câmera', (tester) async {
    final camera = CameraFalsa();
    final resultado = await _abrir(tester, camera);

    await tester.tap(find.byTooltip('Fechar câmera'));
    await tester.pumpAndSettle();

    expect(await resultado, isNull);
    expect(camera.encerrada, isTrue);
  });

  testWidgets('sem permissão, explica e oferece a câmera do sistema',
      (tester) async {
    final resultado = await _abrir(tester, CameraFalsa(falharAoIniciar: true));

    expect(find.text('Não foi possível abrir a câmera.'), findsOneWidget);
    await tester.tap(find.text('Usar a câmera do celular'));
    await tester.pumpAndSettle();

    final resposta = await resultado;
    expect(resposta?.usarCameraDoSistema, isTrue);
    expect(resposta?.foto, isNull);
    expect(find.byType(CameraDoCartao), findsNothing);
  });

  testWidgets('câmera cabe em celular de 360px', (tester) async {
    addTearDown(tester.view.reset);
    tester.view.devicePixelRatio = 3;
    tester.view.physicalSize = const Size(360, 740) * 3;

    await _abrir(tester, CameraFalsa(lanterna: true));

    expect(tester.takeException(), isNull);
  });
}
