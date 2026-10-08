import 'package:flutter_test/flutter_test.dart';
import 'package:toca_essa_app/infraestrutura/abrir_url_externa.dart';

void main() {
  test('aba da cifra recusa link que não é HTTP ou HTTPS', () {
    expect(
      () => abrirNaAbaDaCifra(Uri.parse('javascript:alert(1)')),
      throwsArgumentError,
    );
  });

  test('aba da cifra recusa link de rede local', () {
    expect(
      () => prepararAberturaNaAbaDaCifra()(Uri.parse('http://192.168.0.1/')),
      throwsArgumentError,
    );
  });
}
