import 'package:guitar_chord_library/guitar_chord_library.dart';

import 'transpor_cifra.dart';

export 'package:guitar_chord_library/guitar_chord_library.dart'
    show ChordPosition;

/// Posições do acorde no violão, ou nulo quando a biblioteca não o conhece.
/// Se a forma exata não existe, tenta uma mais simples: sem o baixo
/// (`D/F#` → `D`) e sem o que vem entre parênteses (`E7(9)` → `E7`).
List<ChordPosition>? posicoesDoAcorde(String acorde) {
  final nome = acorde
      .trim()
      .replaceAll(RegExp('[º°]'), 'dim')
      .replaceAll('+', 'aug');
  if (nome.isEmpty) return null;
  final violao = GuitarChordLibrary.instrument(InstrumentType.guitar);
  for (final tentativa in [
    nome,
    nome.replaceAll(RegExp(r'\([^)]*\)'), ''),
    nome.replaceAll(RegExp(r'\([^)]*\)'), '').split('/').first,
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
    final acorde = palavra.group(0)!.replaceAll(RegExp(r'^\(+|\)+$'), '');
    return linhaDeAcordes(acorde) && !acorde.startsWith('[') ? acorde : null;
  }
  return null;
}
