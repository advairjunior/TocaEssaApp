import 'package:guitar_chord_library/guitar_chord_library.dart';

import 'transpor_cifra.dart';

export 'package:guitar_chord_library/guitar_chord_library.dart'
    show ChordPosition;

/// Posições do acorde no violão, ou nulo quando a biblioteca não o conhece.
/// Se a forma exata não existe, tenta uma mais simples: sem o baixo
/// (`D/F#` → `D`), sem o que vem entre parênteses (`E7(9)` → `E7`) e, por
/// último, só a nota com o menor (`Am7(11)` → `Am`). O `7M` da cifra
/// brasileira vira o `maj7` da biblioteca.
List<ChordPosition>? posicoesDoAcorde(String acorde) {
  final nome = acorde
      .trim()
      .replaceAll(RegExp('[º°]'), 'dim')
      .replaceAll('7M', 'maj7')
      .replaceAll('+', 'aug');
  if (nome.isEmpty) return null;
  final semParenteses = nome.replaceAll(RegExp(r'\([^)]*\)'), '');
  final base = RegExp(r'^[A-G][#b]?(m(?!aj))?').firstMatch(nome)?.group(0);
  final violao = GuitarChordLibrary.instrument(InstrumentType.guitar);
  for (final tentativa in [
    nome,
    semParenteses,
    semParenteses.split('/').first,
    if (base != null) base,
  ]) {
    final posicoes = violao.getPositionsByName(tentativa);
    if (posicoes != null && posicoes.isNotEmpty) return posicoes;
  }
  return null;
}

/// Acorde de uma linha de acordes que ocupa a coluna [coluna], ou nulo
/// quando a coluna cai num espaço, num rótulo como `[Intro]` ou numa linha
/// de letra.
String? acordeNaPosicao(String linha, int coluna) {
  if (!linhaDeAcordes(linha)) return null;
  for (final palavra in RegExp(r'\S+').allMatches(linha)) {
    if (coluna < palavra.start || coluna >= palavra.end) continue;
    final texto = palavra.group(0)!;
    return texto.startsWith('[') ? null : acordeDaPalavra(texto);
  }
  return null;
}
