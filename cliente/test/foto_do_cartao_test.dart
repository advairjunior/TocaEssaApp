import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:toca_essa_app/telas/foto_do_cartao.dart';

Future<MemoryImage> _foto(WidgetTester tester, int largura, int altura) async {
  final bytes = await tester.runAsync(() async {
    final gravador = ui.PictureRecorder();
    Canvas(gravador).drawRect(
        Rect.fromLTWH(0, 0, largura.toDouble(), altura.toDouble()),
        Paint()..color = Colors.orange);
    final imagem = await gravador.endRecording().toImage(largura, altura);
    final dados = await imagem.toByteData(format: ui.ImageByteFormat.png);
    return dados!.buffer.asUint8List();
  });
  return MemoryImage(bytes!);
}

Future<void> _mostrar(WidgetTester tester, MemoryImage foto) async {
  await tester.pumpWidget(MaterialApp(
    home: Center(
      child: SizedBox(
          width: 90,
          height: 160,
          child: FotoDoCartao(endereco: null, imagem: foto)),
    ),
  ));
  // A imagem decodifica fora do relógio dos testes.
  await tester
      .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('foto deitada aparece inteira, com ela mesma desfocada atrás',
      (tester) async {
    await _mostrar(tester, await _foto(tester, 40, 30));

    expect(find.byType(ImageFiltered), findsOneWidget);
    final inteira = tester
        .widgetList<Image>(find.byType(Image))
        .where((imagem) => imagem.fit == BoxFit.contain);
    expect(inteira, hasLength(1));
  });

  testWidgets('foto em pé, como a selfie da hora, ocupa o cartão todo',
      (tester) async {
    await _mostrar(tester, await _foto(tester, 30, 40));

    expect(find.byType(ImageFiltered), findsNothing);
    expect(tester.widget<Image>(find.byType(Image)).fit, BoxFit.cover);
  });

  test('deitada é só quando é mais larga que alta', () {
    expect(fotoDeitada(const Size(1600, 1200)), isTrue);
    expect(fotoDeitada(const Size(1080, 1920)), isFalse);
    expect(fotoDeitada(const Size(1000, 1000)), isFalse);
  });
}
