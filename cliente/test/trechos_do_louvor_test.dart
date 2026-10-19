import 'package:flutter_test/flutter_test.dart';
import 'package:toca_essa_app/dominio/modelos.dart';
import 'package:toca_essa_app/telas/trechos_do_louvor.dart';
import 'package:toca_essa_app/tema/tema_toca_essa.dart';

ParteDoHino _parte(TipoDaParte tipo, String texto, List<String> cantores) =>
    ParteDoHino(
        tipo: tipo, texto: texto, cantores: cantores, escolhidaAMao: false);

final _hino = HinoDoLouvor(
  itemId: 'h1',
  titulo: '80 · Por Cristo, resgatado',
  tom: 'G',
  tocado: false,
  temLetra: true,
  partes: [
    _parte(TipoDaParte.estrofe, 'G        Bm\nCristo Jesus', ['João']),
    _parte(TipoDaParte.refrao, 'G           Bm\nPor Cristo, resgatado', []),
    _parte(TipoDaParte.estrofe, 'G      Bm\nPreso estava', ['Ana']),
    _parte(TipoDaParte.refrao, 'G           Bm\nPor Cristo, resgatado', []),
  ],
);

void main() {
  test('cada parte vira um trecho com o nome de quem canta', () {
    final trechos = trechosDoHino(_hino, cantores: ['João', 'Ana']);

    expect(trechos.map((t) => t.rotulo), ['JOÃO', 'TODOS', 'ANA', 'TODOS']);
    expect(trechos.map((t) => t.destaque), everyElement(isFalse));
    expect(trechos.map((t) => t.aviso), everyElement(isNull));
    expect(trechos[1].cor, CoresTocaEssa.textoSecundario);
    expect(trechos[0].cor, isNot(trechos[2].cor));
    expect(trechos[0].cor, corDoCantor(['João', 'Ana'], 'João'));
  });

  test('sem acordes, só a letra; com acordes, a cifra no tom escolhido', () {
    final letra = trechosDoHino(_hino, cantores: ['João', 'Ana']);
    expect(letra[0].texto, 'Cristo Jesus');

    final cifra = trechosDoHino(_hino,
        cantores: ['João', 'Ana'], acordes: true, semitons: 2);
    expect(cifra[0].texto, 'A        C#m\nCristo Jesus');
  });

  test('a vez de quem está com o telefone fica em destaque e é avisada',
      () {
    final trechos =
        trechosDoHino(_hino, cantores: ['João', 'Ana'], quemSou: 'Ana');

    expect(trechos[2].rotulo, 'ANA · SUA VEZ');
    expect(trechos[2].destaque, isTrue);
    expect(trechos[1].aviso, 'você é o próximo');
    expect(trechos[0].aviso, isNull);
    expect(trechos[0].destaque, isFalse);
  });
}
