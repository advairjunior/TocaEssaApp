import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Arquivo menor é mais fácil de ler e de mudar sem quebrar o vizinho.
const _tetoDeLinhas = 350;

void main() {
  test('nenhum arquivo do app passa do teto de linhas', () {
    final problemas = <String>[];
    final arquivos = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((arquivo) => arquivo.path.endsWith('.dart'));
    for (final arquivo in arquivos) {
      final caminho = arquivo.path.replaceAll(r'\', '/');
      final linhas = arquivo.readAsLinesSync().length;
      if (linhas > _tetoDeLinhas) problemas.add('$caminho: $linhas');
    }

    expect(problemas, isEmpty,
        reason: 'Divida por responsabilidade em vez de aumentar o teto.');
  });
}
