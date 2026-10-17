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

  group('acordes com sétima maior e extensões', () {
    test('reconhece as linhas da cifra colada com C7M e D11', () {
      for (final linha in [
        '[Intro] C7M  D11',
        'C7M',
        'C7M                 D11',
        '         D11',
        '       Em7',
        '                  Am7',
      ]) {
        expect(linhaDeAcordes(linha), isTrue, reason: linha);
      }
    });

    test('reconhece as formas comuns no Brasil', () {
      for (final acorde in [
        'C7M', 'G7M(9)', 'Am7M', 'C7M(9)/E', 'D7sus4', 'Dsus2/F#', 'C6/9',
        'E7/9', 'A7+', 'Bm7-5', 'Bm7(b5)', 'C#m7(5-)', 'Gmaj7', 'Cmaj9',
        'Fadd9', 'G(add9)', 'A4(7)', 'E7(#9)', 'D7(9/11)', 'Bº', 'C°7',
        'Bø', 'Cm7M', 'F7M/A', 'Bbm7', 'Ebdim', 'G13', 'A7(b13)', 'D/F#',
      ]) {
        expect(linhaDeAcordes(acorde), isTrue, reason: acorde);
      }
    });

    test('marcação de repetição não atrapalha a linha', () {
      expect(linhaDeAcordes('C7M  D11  (2x)'), isTrue);
      expect(linhaDeAcordes('G  D  x2'), isTrue);
    });

    test('letra que começa com nota continua sendo letra', () {
      for (final letra in [
        'Amor perfeito no meu peito',
        'Anjo bom',
        'Deus e eu no sertão',
        'Bom dia',
        'Em casa eu fico',
        'E|-4-7---4---|',
        'Dado',
        'E, então',
      ]) {
        expect(linhaDeAcordes(letra), isFalse, reason: letra);
      }
    });

    test('transpõe sétima maior e extensões mantendo o resto do acorde', () {
      expect(transporCifra('[Intro] C7M  D11', 2), '[Intro] D7M  E11');
      expect(transporCifra('C7M                 D11', -1),
          'B7M                 C#11');
      expect(transporCifra('G7M(9)/B  Am7M', 1), 'G#7M(9)/C Bbm7M');
    });

    test('acorde com símbolo desconhecido ainda muda a nota', () {
      expect(linhaDeAcordes('C7M*  D11'), isTrue);
      expect(transporCifra('C7M*  D11', 2), 'D7M*  E11');
    });
  });

  test('aponta o que parece acorde mas não foi entendido', () {
    expect(acordesNaoReconhecidos('C7M  D11  G7?'), isEmpty);
    expect(acordesNaoReconhecidos('C  G  Lá  D'), ['Lá']);
    expect(acordesNaoReconhecidos('Amor perfeito no meu peito'), isEmpty);
    expect(acordesNaoReconhecidos('E eu'), isEmpty);
  });

  test('acorde colado no parêntese da linha também muda de tom', () {
    expect(linhaDeAcordes('(E  C#m  C#9)'), isTrue);
    expect(transporCifra('(E  C#m  C#9)', 1), '(F  Dm   D9)');
    expect(linhaDeAcordes('G7(9)  E7(9)'), isTrue);
    expect(transporCifra('G7(9)  E7(9)', 2), 'A7(9)  F#7(9)');
  });

  test('transpõe o nome de um tom', () {
    expect(transporTom('G', 1), 'G#');
    expect(transporTom('Bb', -1), 'A');
    expect(transporTom('Em', 2), 'F#m');
  });
}
