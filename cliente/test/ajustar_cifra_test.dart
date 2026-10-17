import 'package:flutter_test/flutter_test.dart';
import 'package:toca_essa_app/dominio/ajustar_cifra.dart';

void main() {
  test('tabulação vira espaços até a próxima coluna de 8', () {
    expect(ajustarCifraColada('C7M\tD11'), 'C7M     D11');
    expect(ajustarCifraColada('\tG'), '        G');
    expect(ajustarCifraColada('A\t\tE'), 'A               E');
  });

  test('tira caracteres invisíveis e troca espaço especial por espaço', () {
    expect(ajustarCifraColada('﻿C7M​  D11'), 'C7M  D11');
    expect(ajustarCifraColada('G  D Em'), 'G  D Em');
  });

  test('padroniza fim de linha e tira espaços no fim', () {
    expect(ajustarCifraColada('G   D  \r\nLetra\rFim'), 'G   D\nLetra\nFim');
  });

  test('não mexe nos espaços que alinham o acorde com a letra', () {
    const cifra = '         D11\nPra não ver passar o tempo';
    expect(ajustarCifraColada(cifra), cifra);
  });
}
