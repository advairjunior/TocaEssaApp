import 'package:flutter_test/flutter_test.dart';
import 'package:toca_essa_app/dominio/transpor_cifra.dart';

void main() {
  test('sobe meio tom mantendo os acordes em cima da mesma sílaba', () {
    expect(
      transporCifra('E               C#m  C#9\n  Nunca vi ninguém', 1),
      'F               Dm   D9\n  Nunca vi ninguém',
    );
  });

  test('acorde que cresce usa o espaço que vem depois', () {
    expect(transporCifra('C  G', 1), 'C# G#');
    expect(transporCifra('C/G', 1), 'C#/G#');
  });

  test('transpõe o baixo depois da barra', () {
    expect(transporCifra('D/F#  G', -2), 'C/E   F');
  });

  test('mantém bemol quando a cifra usa bemol e prefere Bb a A#', () {
    expect(transporCifra('Bb  Eb', 2), 'C   F');
    expect(transporCifra('Eb', 1), 'E');
    expect(transporCifra('A', 1), 'Bb');
    expect(transporCifra('C#m', 2), 'D#m');
  });

  test('entende acordes com rótulo da parte e entre parênteses', () {
    expect(transporCifra('[Intro] E9  C#m  C#9', 2), '[Intro] F#9 D#m  D#9');
    expect(transporCifra('( E  C#m  C#9 )', -1), '( D# Cm   C9 )');
  });

  test('transpõe o tom do cabeçalho e não mexe em letra nem tablatura', () {
    const original = 'Tom:  E\n'
        '[Primeira Parte]\n'
        'E|-4-7---4---|\n'
        'Em casa eu fico';
    expect(
      transporCifra(original, 1),
      'Tom:  F\n'
      '[Primeira Parte]\n'
      'E|-4-7---4---|\n'
      'Em casa eu fico',
    );
  });

  test('zero ou uma oitava inteira não mudam nada', () {
    const cifra = 'G   D\nQuando eu digo';
    expect(transporCifra(cifra, 0), cifra);
    expect(transporCifra(cifra, 12), cifra);
    expect(transporCifra(cifra, -12), cifra);
  });

  test('transpõe o nome de um tom', () {
    expect(transporTom('G', 1), 'G#');
    expect(transporTom('Bb', -1), 'A');
    expect(transporTom('Em', 2), 'F#m');
  });
}
