import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:toca_essa_app/dominio/modelos.dart';
import 'package:toca_essa_app/telas/cartao_pedido_artista.dart';

void main() {
  testWidgets('grupo repetido mostra contagem e solicitantes', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: CartaoGrupoPedidoArtista(
          grupo: _grupo(3, const ['Ana', 'Beto', 'Carla']),
          alterar: (_) {},
        ),
      ),
    ));

    expect(find.text('3 pedidos'), findsOneWidget);
    expect(find.textContaining('Ana, Beto e mais 1'), findsOneWidget);
  });

  testWidgets('pedido unico nao recebe destaque coletivo', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: CartaoGrupoPedidoArtista(
          grupo: _grupo(1, const ['Ana']),
          alterar: (_) {},
        ),
      ),
    ));

    expect(find.text('1 pedido'), findsNothing);
    expect(find.text('Pedido por Ana'), findsOneWidget);
  });
}

GrupoPedidoMusical _grupo(int quantidade, List<String> solicitantes) =>
    GrupoPedidoMusical(
      pedidoRepresentativoId: '10000000-0000-0000-0000-000000000001',
      pedidoIds: List.generate(quantidade, (indice) => 'pedido-$indice'),
      apresentacaoId: '20000000-0000-0000-0000-000000000001',
      musica: 'Evidências',
      artista: 'Chitãozinho & Xororó',
      status: StatusPedidoMusical.aguardando,
      criadoEm: DateTime(2026, 9, 14),
      quantidadePedidos: quantidade,
      solicitantes: solicitantes,
      tipo: TipoPedido.musica,
    );
