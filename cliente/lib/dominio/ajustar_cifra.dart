/// Limpeza do texto copiado de sites de cifra, para os acordes continuarem
/// em cima da sílaba certa e serem reconhecidos.
library;

// Zero-width, marca de ordem de bytes e afins: não aparecem, mas grudam no
// acorde ("D11​") e empurram as colunas.
final _invisiveis = RegExp('[​-‍⁠﻿­]');
// Espaços especiais que viram espaço comum.
final _espacosEspeciais = RegExp('[  -   　]');

const _colunasDaTabulacao = 8;

/// Tira caracteres invisíveis, troca tabulação e espaços especiais por
/// espaços comuns, padroniza o fim de linha e tira espaços no fim. Os
/// espaços que alinham os acordes com a letra ficam.
String ajustarCifraColada(String texto) => texto
    .replaceAll('\r\n', '\n')
    .replaceAll('\r', '\n')
    .split('\n')
    .map((linha) => _trocarTabulacao(linha
            .replaceAll(_invisiveis, '')
            .replaceAll(_espacosEspeciais, ' '))
        .trimRight())
    .join('\n');

String _trocarTabulacao(String linha) {
  if (!linha.contains('\t')) return linha;
  final saida = StringBuffer();
  var coluna = 0;
  for (final letra in linha.split('')) {
    if (letra == '\t') {
      final espacos = _colunasDaTabulacao - coluna % _colunasDaTabulacao;
      saida.write(' ' * espacos);
      coluna += espacos;
    } else {
      saida.write(letra);
      coluna++;
    }
  }
  return saida.toString();
}
