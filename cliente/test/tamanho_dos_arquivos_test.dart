import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Arquivo menor é mais fácil de ler e de mudar sem quebrar o vizinho.
const _tetoDeLinhas = 350;

/// Os que já passavam do teto quando a régua chegou (2026-10-22), com o
/// tamanho daquele dia: podem diminuir, nunca crescer. Ao dividir um deles,
/// tire-o daqui.
const _acimaDoTeto = <String, int>{
  'lib/telas/cartao_pedido_artista.dart': 408,
  'lib/telas/fila_musical_artista.dart': 351,
  'lib/telas/gerenciar_repertorios_detalhe.dart': 566,
  'lib/telas/painel_do_artista_aba_perfil.dart': 355,
  'lib/telas/painel_do_artista_estado.dart': 444,
  'lib/telas/sequencia_do_palco.dart': 452,
};

void main() {
  test('nenhum arquivo do app cresce além do teto de linhas', () {
    final problemas = <String>[];
    final arquivos = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((arquivo) => arquivo.path.endsWith('.dart'));
    for (final arquivo in arquivos) {
      final caminho = arquivo.path.replaceAll(r'\', '/');
      final linhas = arquivo.readAsLinesSync().length;
      final limite = _acimaDoTeto[caminho] ?? _tetoDeLinhas;
      if (linhas > limite) problemas.add('$caminho: $linhas (limite $limite)');
    }

    expect(problemas, isEmpty,
        reason: 'Divida por responsabilidade em vez de aumentar o limite.');
  });
}
