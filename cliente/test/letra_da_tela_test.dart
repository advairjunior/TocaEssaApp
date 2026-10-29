import 'package:flutter_test/flutter_test.dart';
import 'package:toca_essa_app/dominio/letra_da_tela.dart';

void main() {
  const cifra = 'Tom: G\n'
      '[Intro] G D Em C\n'
      '\n'
      '[Primeira Parte]\n'
      'G              D\n'
      'O sol desceu devagar\n'
      '         Em\n'
      'Cavaco afinado\n'
      '\n'
      '[Refrão]\n'
      'C         G\n'
      'Canta comigo\n'
      'Ninguém fica de fora\n'
      '\n'
      'E|---3---2---|\n'
      'B|-----------|\n'
      '\n'
      'Hoje ninguém tem hora';

  test('numera só as linhas de letra, sem acordes, marcas e vazias', () {
    final letra = LetraDaTela.doTexto(cifra);

    expect(letra.total, 5);
    expect(
        letra.partes.expand((parte) => parte.linhas).map((l) => l.texto), [
      'O sol desceu devagar',
      'Cavaco afinado',
      'Canta comigo',
      'Ninguém fica de fora',
      'Hoje ninguém tem hora',
    ]);
    expect(letra.partes.expand((parte) => parte.linhas).map((l) => l.numero),
        [0, 1, 2, 3, 4]);
  });

  test('a linha "Tom:" do topo não é letra', () {
    expect(LetraDaTela.doTexto('Tom: E\nLetra').total, 1);
  });

  test('separa as partes pelas marcas e pelas linhas em branco', () {
    final letra = LetraDaTela.doTexto(cifra);

    expect(letra.partes.map((parte) => parte.rotulo),
        ['Primeira Parte', 'Refrão', null]);
    expect(letra.partes.map((parte) => parte.linhas.length), [2, 2, 1]);
  });

  test('marcas com parênteses ou dois-pontos também dão nome à parte', () {
    final letra =
        LetraDaTela.doTexto('(Estrofe 1)\nPrimeira\n\nRefrão:\nSegunda');

    expect(letra.partes.map((parte) => parte.rotulo), ['Estrofe 1', 'Refrão']);
  });

  test('cada linha do texto sabe o número dela na letra', () {
    final letra = LetraDaTela.doTexto('[Refrão]\nC   G\nCanta\n\nFora');

    expect(letra.numeroDaLinhaDoTexto(0), isNull);
    expect(letra.numeroDaLinhaDoTexto(1), isNull);
    expect(letra.numeroDaLinhaDoTexto(2), 0);
    expect(letra.numeroDaLinhaDoTexto(4), 1);
    expect(letra.numeroDaLinhaDoTexto(99), isNull);
  });

  test('acha a parte de uma linha e a parte seguinte', () {
    final letra = LetraDaTela.doTexto(cifra);

    expect(letra.parteDaLinha(3)?.rotulo, 'Refrão');
    expect(letra.parteDaLinha(99)?.rotulo, isNull);
    expect(letra.parteDaLinha(99), letra.partes.last);
    expect(letra.parteDepois(letra.partes.first)?.rotulo, 'Refrão');
    expect(letra.parteDepois(letra.partes.last), isNull);
  });

  test('texto sem letra não tem partes', () {
    final letra = LetraDaTela.doTexto('G D Em C\n\n');

    expect(letra.total, 0);
    expect(letra.partes, isEmpty);
    expect(letra.parteDaLinha(0), isNull);
  });
}
