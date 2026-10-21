import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:toca_essa_app/dominio/modelos.dart';
import 'package:toca_essa_app/telas/trechos_do_louvor.dart';
import 'package:toca_essa_app/tema/tema_toca_essa.dart';

ParteDoHino _parte(TipoDaParte tipo, String texto, List<String> cantores) =>
    ParteDoHino(tipo: tipo, texto: texto, cantores: cantores, definida: false);

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
  test('até 12 cantores, cada um tem uma cor diferente', () {
    final cantores = [for (var i = 1; i <= 12; i++) 'Cantor $i'];
    final cores = {for (final nome in cantores) corDoCantor(cantores, nome)};

    expect(cores, hasLength(12));
    // Nenhuma se confunde com os solos nem com Todos.
    expect(cores, isNot(contains(corInstrumental)));
    expect(cores, isNot(contains(CoresTocaEssa.textoSecundario)));
  });

  test('cores sem limite: 40 pessoas, todas diferentes e legíveis', () {
    final pessoas = [for (var i = 1; i <= 40; i++) 'Pessoa $i'];
    final cores = [for (final nome in pessoas) corDaPessoa(pessoas, nome)];

    expect(cores.toSet(), hasLength(40));
    // As 12 de sempre continuam: ninguém que já usa troca de cor.
    expect(cores.first, CoresTocaEssa.roxoClaro);
    expect(cores[1], CoresTocaEssa.rosa);
    for (final cor in cores.skip(12)) {
      final hsl = HSLColor.fromColor(cor);
      // Longe do amarelo dos solos e clara o bastante no fundo escuro.
      expect(hsl.hue, isNot(inInclusiveRange(35, 70)));
      expect(cor.computeLuminance(), greaterThan(.2));
    }
    expect(cores, isNot(contains(corInstrumental)));
  });

  test('quem só toca ganha cor própria, depois dos cantores', () {
    const pessoas = ['João', 'Ana', 'José'];

    expect(corDaPessoa(pessoas, 'José'), isNot(corInstrumental));
    expect(corDaPessoa(pessoas, 'José'), isNot(corDaPessoa(pessoas, 'Ana')));
    // A cor de quem canta é a mesma na lista só de cantores.
    expect(corDaPessoa(pessoas, 'Ana'), corDoCantor(['João', 'Ana'], 'Ana'));
  });

  test('as partes de alguém saem pelo nome, juntas com "e"', () {
    expect(partesDaPessoa(_hino, 'Ana'), 'Estrofe 2');
    expect(partesDaPessoa(_hino, 'Pedro'), isNull);

    final varias = HinoDoLouvor(
      itemId: 'h2',
      titulo: 'Hino',
      tom: null,
      tocado: false,
      temLetra: true,
      partes: [
        _parte(TipoDaParte.estrofe, 'Um', ['Ana']),
        _parte(TipoDaParte.refrao, 'Coro', ['Ana']),
        _parte(TipoDaParte.estrofe, 'Dois', ['João']),
        _parte(TipoDaParte.estrofe, 'Três', ['Ana']),
      ],
    );
    expect(partesDaPessoa(varias, 'Ana'), 'Estrofe 1, Refrão e Estrofe 3');
  });

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

  test('a vez de quem está com o telefone fica em destaque e é avisada', () {
    final trechos =
        trechosDoHino(_hino, cantores: ['João', 'Ana'], quemSou: 'Ana');

    expect(trechos[2].rotulo, 'ANA · SUA VEZ');
    expect(trechos[2].destaque, isTrue);
    expect(trechos[1].aviso, 'você é o próximo');
    expect(trechos[0].aviso, isNull);
    expect(trechos[0].destaque, isFalse);
  });

  group('partes instrumentais', () {
    final comSolo = HinoDoLouvor(
      itemId: 'h2',
      titulo: '5 · Hino com solo',
      tom: 'G',
      tocado: false,
      temLetra: true,
      partes: [
        const ParteDoHino(
            tipo: TipoDaParte.refrao,
            texto: 'Coro',
            cantores: [],
            definida: false,
            vezes: 2),
        const ParteDoHino(
            tipo: TipoDaParte.instrumental,
            texto: 'G   D',
            cantores: [],
            definida: false,
            nome: 'Solo sax tenor',
            vezes: 2),
        const ParteDoHino(
            tipo: TipoDaParte.instrumental,
            texto: 'C   D',
            cantores: ['José'],
            definida: true,
            nome: 'Solo trompete'),
      ],
    );

    test('mostram o instrumento, quem toca e quantas vezes', () {
      final trechos = trechosDoHino(comSolo, cantores: ['João', 'José']);

      expect(trechos.map((t) => t.rotulo),
          ['TODOS · 2X', 'SOLO SAX TENOR · 2X', 'JOSÉ · SOLO TROMPETE']);
      expect(trechos[1].cor, corInstrumental);
      expect(trechos[2].cor, corInstrumental);
    });

    test('sem acordes avisam que é instrumental; com acordes, a cifra', () {
      expect(trechosDoHino(comSolo, cantores: [])[1].texto, 'instrumental');
      expect(trechosDoHino(comSolo, cantores: [], acordes: true)[1].texto,
          'G   D');
    });

    test('solo sem acordes escritos avisa que é instrumental no leitor', () {
      final soloVazio = HinoDoLouvor(
        itemId: 'h4',
        titulo: 'Hino',
        tom: 'G',
        tocado: false,
        temLetra: true,
        partes: [
          const ParteDoHino(
              tipo: TipoDaParte.instrumental,
              texto: '\n',
              cantores: ['Fabricio'],
              definida: true,
              nome: 'Solo'),
        ],
      );

      expect(trechosDoHino(soloVazio, cantores: [], acordes: true).single.texto,
          'instrumental');
    });

    test('o solista vê a vez dele e o aviso de próximo', () {
      final trechos =
          trechosDoHino(comSolo, cantores: ['José'], quemSou: 'José');

      expect(trechos[2].rotulo, 'JOSÉ · SOLO TROMPETE · SUA VEZ');
      expect(trechos[2].destaque, isTrue);
      expect(trechos[1].aviso, 'você é o próximo');
    });
  });
}
