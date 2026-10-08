import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:toca_essa_app/infraestrutura/pedidos_a_seguir.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('sem pedidos marcados, a lista começa vazia', () async {
    expect(await PedidosASeguir.ler('show-1'), isEmpty);
  });

  test('alternar marca na ordem e desmarca o pedido', () async {
    await PedidosASeguir.alternar('show-1', 'p1');
    await PedidosASeguir.alternar('show-1', 'p2');
    expect(await PedidosASeguir.ler('show-1'), ['p1', 'p2']);

    await PedidosASeguir.alternar('show-1', 'p1');
    expect(await PedidosASeguir.ler('show-1'), ['p2']);
  });

  test('cada apresentação tem a própria lista', () async {
    await PedidosASeguir.alternar('show-1', 'p1');

    expect(await PedidosASeguir.ler('show-2'), isEmpty);
  });

  test('remover tira o pedido e ignora pedido que não estava', () async {
    await PedidosASeguir.alternar('show-1', 'p1');
    await PedidosASeguir.remover('show-1', 'p1');
    await PedidosASeguir.remover('show-1', 'p9');

    expect(await PedidosASeguir.ler('show-1'), isEmpty);
  });
}
