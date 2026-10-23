import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// A marca é a primeira coisa que o público baixa ao ler o QR, muitas vezes
/// com a internet fraca do show.
const _tetoDeBytes = 150 * 1024;

void main() {
  test('nenhuma imagem da marca passa do teto de peso', () {
    final problemas = <String>[];
    final imagens = Directory('assets/marca')
        .listSync(recursive: true)
        .whereType<File>()
        .where((arquivo) => arquivo.path.endsWith('.png'));
    for (final imagem in imagens) {
      final caminho = imagem.path.replaceAll(r'\', '/');
      final bytes = imagem.lengthSync();
      if (bytes > _tetoDeBytes) problemas.add('$caminho: $bytes bytes');
    }

    expect(problemas, isEmpty,
        reason: 'Reduza a imagem ao tamanho em que ela aparece na tela.');
  });
}
