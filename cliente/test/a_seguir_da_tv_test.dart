import 'package:flutter_test/flutter_test.dart';
import 'package:toca_essa_app/dominio/a_seguir_da_tv.dart';

void main() {
  test('música da setlist vai só com o nome', () {
    expect(aSeguirDaTv('Lua de São Jorge', const []), 'Lua de São Jorge');
  });

  test('pedido diz quem pediu', () {
    expect(aSeguirDaTv('Lua de São Jorge', const ['Carla']),
        'Lua de São Jorge · pedida por Carla');
  });

  test('dois pedidos dizem os dois nomes', () {
    expect(aSeguirDaTv('Lua', const ['Carla', 'Bia']),
        'Lua · pedida por Carla e Bia');
  });

  test('mais de dois dizem o primeiro e quantos mais', () {
    expect(aSeguirDaTv('Lua', const ['Carla', 'Bia', 'Zé']),
        'Lua · pedida por Carla e mais 2');
  });

  test('nome em branco não conta', () {
    expect(aSeguirDaTv('Lua', const [' ', 'Carla']), 'Lua · pedida por Carla');
  });
}
