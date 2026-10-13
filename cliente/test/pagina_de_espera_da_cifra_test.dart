import 'package:flutter_test/flutter_test.dart';
import 'package:toca_essa_app/infraestrutura/pagina_de_espera_da_cifra.dart';

void main() {
  test('aba à espera da cifra é escura e diz o que está acontecendo', () {
    expect(paginaDeEsperaDaCifra, contains('background:#0B080F'));
    expect(paginaDeEsperaDaCifra, contains('Abrindo a cifra'));
    expect(paginaDeEsperaDaCifra, contains('volte para o TocaEssa'));
  });

  test('aba à espera da cifra não depende de script para aparecer', () {
    expect(paginaDeEsperaDaCifra.toLowerCase(), isNot(contains('<script')));
  });
}
