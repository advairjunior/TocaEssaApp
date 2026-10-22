import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('página do app nasce com o fundo escuro enquanto o Flutter carrega',
      () {
    final html = File('web/index.html').readAsStringSync();

    expect(html, contains('background-color: #0B080F'));
  });

  test('a página conhece a fonte da cifra para o campo do navegador', () {
    // No Safari do iPhone o cursor do editor é posto pelo campo do navegador;
    // com outra fonte, o toque num acorde caía algumas letras para o lado.
    final html = File('web/index.html').readAsStringSync();

    expect(html, contains("font-family: 'JetBrainsMono'"));
    expect(html, contains('assets/assets/fontes/JetBrainsMono.ttf'));
  });
}
