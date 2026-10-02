import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:toca_essa_app/infraestrutura/rastros_locais_do_publico.dart';

void main() {
  test('limpar rastros apaga também as fotos de encontro já vistas', () async {
    SharedPreferences.setMockInitialValues({
      'nome_do_publico': 'Ana',
      'pedidos_publico_ABC': '[]',
      'fotos_vistas_do_publico': ['/fotos/a.png'],
      'token_do_artista': 'manter',
    });
    final preferencias = await SharedPreferences.getInstance();

    await limparRastrosLocaisDoPublico(preferencias);

    expect(preferencias.getKeys(), {'token_do_artista'});
  });
}
