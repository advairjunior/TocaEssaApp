import 'package:flutter_test/flutter_test.dart';
import 'package:toca_essa_app/dominio/desenho_de_acorde.dart';

void main() {
  test('acha as posições dos acordes da cifra de exemplo', () {
    for (final acorde in ['E', 'E9', 'C#m', 'C#9', 'A', 'B', 'F#m', 'G']) {
      final posicoes = posicoesDoAcorde(acorde);
      expect(posicoes, isNotNull, reason: acorde);
      expect(posicoes, isNotEmpty, reason: acorde);
    }
  });

  test('bemol, baixo e sétima também têm desenho', () {
    for (final acorde in ['Bb', 'Eb', 'D/F#', 'Am7', 'G7', 'Dsus4']) {
      expect(posicoesDoAcorde(acorde), isNotEmpty, reason: acorde);
    }
  });

  test('acorde desconhecido não tem desenho', () {
    expect(posicoesDoAcorde('Xyz'), isNull);
    expect(posicoesDoAcorde(''), isNull);
  });

  test('descobre em qual acorde da linha o toque caiu', () {
    expect(acordeNaPosicao('G    D', 0), 'G');
    expect(acordeNaPosicao('G    D', 5), 'D');
    expect(acordeNaPosicao('G    D', 2), isNull);
    expect(acordeNaPosicao('[Intro] E9  C#m', 9), 'E9');
    expect(acordeNaPosicao('[Intro] E9  C#m', 3), isNull);
    expect(acordeNaPosicao('( E  C#m )', 2), 'E');
    expect(acordeNaPosicao('( E  C#m )', 6), 'C#m');
  });
}
