import 'package:flutter_test/flutter_test.dart';
import 'package:toca_essa_app/dominio/quebrar_cifra.dart';

void main() {
  test('linha que cabe fica como está', () {
    expect(quebrarCifra('C   G\nLetra curta', 20), ['C   G', 'Letra curta']);
  });

  test('letra sozinha quebra entre palavras', () {
    expect(quebrarCifra('Quando eu digo que deixei de te amar', 20),
        ['Quando eu digo que', 'deixei de te amar']);
  });

  test('acordes e letra quebram juntos e o acorde segue na sílaba certa', () {
    const cifra = 'C              G          Am\n'
        'Quando eu digo que deixei de te amar';

    expect(quebrarCifra(cifra, 20), [
      'C              G',
      'Quando eu digo que',
      '       Am',
      'deixei de te amar',
    ]);
  });

  test('quebra no meio da palavra não corta o acorde ao meio', () {
    expect(quebrarCifra('     F#m7\nabcdefghijklmn', 7), [
      'abcde',
      'F#m7',
      'fghijkl',
      'mn',
    ]);
  });

  test('acorde depois do fim da letra também desce', () {
    // G em cima do "m" de "demais"; D depois do fim da letra.
    expect(quebrarCifra('C        G       D\nTe amo demais', 10), [
      'C',
      'Te amo',
      '  G',
      'demais',
      'D',
    ]);
  });

  test('linha só de acordes quebra entre acordes', () {
    expect(quebrarCifra('[Intro] C  G  Am  F  C  G', 12),
        ['[Intro] C  G', 'Am  F  C  G']);
  });

  test('linha em branco e linha seguinte de acordes não viram par', () {
    expect(quebrarCifra('C   G\n\nD   A', 20), ['C   G', '', 'D   A']);
  });
}
