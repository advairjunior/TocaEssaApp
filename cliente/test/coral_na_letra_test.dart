import 'package:flutter_test/flutter_test.dart';
import 'package:toca_essa_app/dominio/coral_na_letra.dart';
import 'package:toca_essa_app/dominio/modelos.dart';
import 'package:toca_essa_app/telas/trechos_do_louvor.dart';

const _estrofe3 = '''G             D
Tem minha alma grande alegria
Sem esperança sempre vivia
(Coral)
G            D
Glória a Jesus que me resgatou
D'Ele agora sou
(Fim do coral)
Só mais uma linha''';

ParteDoHino _parte(TipoDaParte tipo, String texto, List<String> cantores,
        {bool coral = false}) =>
    ParteDoHino(
        tipo: tipo,
        texto: texto,
        cantores: cantores,
        definida: true,
        coral: coral);

// Estrofe 1 (João), Refrão (Todos), Estrofe 2 (João, com coral nas linhas).
final _hino = HinoDoLouvor(
  itemId: 'h1',
  titulo: '80 · Por Cristo, resgatado',
  tom: 'G',
  tocado: false,
  temLetra: true,
  partes: [
    _parte(TipoDaParte.estrofe, 'Cristo Jesus', ['João']),
    _parte(TipoDaParte.refrao, 'Por Cristo, resgatado', []),
    _parte(TipoDaParte.estrofe, _estrofe3, ['João']),
  ],
);

const _cantores = ['João', 'Ana', 'Bia'];

void main() {
  group('marcas do coral na letra', () {
    test('(Coral) e (Fim do coral) separam as linhas do coral', () {
      final pedacos = pedacosDoCoral(_estrofe3);

      expect([for (final pedaco in pedacos) pedaco.coral], [false, true, false]);
      expect(pedacos[0].texto,
          'G             D\nTem minha alma grande alegria\nSem esperança sempre vivia');
      expect(pedacos[1].texto,
          "G            D\nGlória a Jesus que me resgatou\nD'Ele agora sou");
      expect(pedacos[2].texto, 'Só mais uma linha');
    });

    test('sem marca de fim, o coral vai até o fim da parte', () {
      final pedacos = pedacosDoCoral('Primeira\n[Coral]\nSegunda\nTerceira');

      expect([for (final pedaco in pedacos) pedaco.coral], [false, true]);
      expect(pedacos[1].texto, 'Segunda\nTerceira');
    });

    test('vale maiúscula, acento e os jeitos de escrever o fim', () {
      for (final (inicio, fim) in [
        ('(coral)', '(Coral fim)'),
        ('CORAL:', '(fim coral)'),
        ('[Coral]', '[Fim do Coral]'),
      ]) {
        final pedacos = pedacosDoCoral('Um\n$inicio\nDois\n$fim\nTrês');
        expect([for (final pedaco in pedacos) pedaco.coral], [false, true, false],
            reason: '$inicio … $fim');
      }
    });

    test('sem marcas, a parte inteira é um pedaço só, sem coral', () {
      final pedacos = pedacosDoCoral('Linha um\nLinha dois');

      expect(pedacos, hasLength(1));
      expect(pedacos.single.coral, isFalse);
      expect(pedacos.single.texto, 'Linha um\nLinha dois');
      expect(temCoralNaLetra('Linha um\nCoral de anjos'), isFalse);
      expect(temCoralNaLetra(_estrofe3), isTrue);
    });
  });

  group('na letra de cada um', () {
    test('quem é do coral canta só as linhas marcadas da estrofe', () {
      final daBia = trechosDoHino(_hino, cantores: _cantores, quemSou: 'Bia');

      expect([for (final trecho in daBia) trecho.rotulo], [
        'JOÃO',
        'TODOS · SUA VEZ',
        'JOÃO',
        'JOÃO + CORAL · SUA VEZ',
        'JOÃO',
      ]);
      expect([for (final trecho in daBia) trecho.apagado],
          [true, false, true, false, true]);
      expect([for (final trecho in daBia) trecho.aviso],
          ['coral entra', 'depois, para', 'coral entra', 'depois, para', null]);
      // As linhas de marcação não aparecem para ninguém.
      expect(daBia.any((trecho) => trecho.texto.contains('(Coral)')), isFalse);
      expect(daBia[3].texto, "Glória a Jesus que me resgatou\nD'Ele agora sou");
    });

    test('quem está no microfone vê onde o coral entra com ele', () {
      final doJoao = trechosDoHino(_hino, cantores: _cantores, quemSou: 'João');

      expect(doJoao[3].rotulo, 'JOÃO + CORAL · SUA VEZ');
      expect(doJoao[2].rotulo, 'JOÃO · SUA VEZ');
      expect([for (final trecho in doJoao) trecho.aviso].whereType<String>(),
          isEmpty);
    });

    test('com os acordes, cada pedaço leva os seus', () {
      final comAcordes = trechosDoHino(_hino,
          cantores: _cantores, quemSou: 'Bia', acordes: true, semitons: 2);

      expect(comAcordes[3].texto.split('\n').first.trim(), 'A            E');
    });

    test('o topo diz que é parte da estrofe', () {
      expect(partesNoCoral(_hino, 'Bia', cantores: _cantores),
          'Refrão e parte da Estrofe 2');
      expect(partesNoCoral(_hino, 'João', cantores: _cantores), 'Refrão');
    });
  });
}
