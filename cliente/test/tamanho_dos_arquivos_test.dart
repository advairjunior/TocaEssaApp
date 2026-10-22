import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Arquivo menor é mais fácil de ler e de mudar sem quebrar o vizinho.
const _tetoDeLinhas = 350;

/// Os que já passavam do teto quando a régua chegou (2026-10-22), com o
/// tamanho daquele dia: podem diminuir, nunca crescer. Ao dividir um deles,
/// tire-o daqui.
const _acimaDoTeto = <String, int>{
  'lib/dominio/modelos.dart': 515,
  'lib/telas/camera_do_cartao.dart': 425,
  'lib/telas/cartao_pedido_artista.dart': 408,
  'lib/telas/cifra_do_palco.dart': 572,
  'lib/telas/codigo_da_apresentacao.dart': 457,
  'lib/telas/componentes_formulario.dart': 465,
  'lib/telas/componentes_painel_inicio.dart': 378,
  'lib/telas/conta_do_publico_resenhas.dart': 549,
  'lib/telas/escala_do_louvor.dart': 363,
  'lib/telas/escala_do_louvor_hinos.dart': 454,
  'lib/telas/estatisticas_da_apresentacao_retrospectiva.dart': 632,
  'lib/telas/fila_musical_artista.dart': 351,
  'lib/telas/gerenciar_repertorios_detalhe.dart': 566,
  'lib/telas/leitor_de_cifras.dart': 562,
  'lib/telas/memoria_da_resenha.dart': 532,
  'lib/telas/montar_setlist.dart': 471,
  'lib/telas/painel_do_artista_aba_perfil.dart': 355,
  'lib/telas/painel_do_artista_estado.dart': 444,
  'lib/telas/perfil_participante.dart': 359,
  'lib/telas/roteiro_do_louvor.dart': 591,
  'lib/telas/sequencia_do_palco.dart': 452,
  'lib/telas/stories_do_show.dart': 673,
  'lib/telas/tela_de_stories.dart': 579,
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
