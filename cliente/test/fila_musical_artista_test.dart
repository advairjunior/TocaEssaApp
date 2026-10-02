import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:toca_essa_app/dominio/modelos.dart';
import 'package:toca_essa_app/infraestrutura/api_toca_essa.dart';
import 'package:toca_essa_app/telas/fila_musical_artista.dart';

void main() {
  testWidgets('separa pendentes fila e historico sem empilhar os pedidos',
      (tester) async {
    final api = ApiTocaEssa(
      enderecoBase: 'https://tocaessa.test',
      cliente: MockClient((_) async => http.Response(_pedidosJson, 200)),
    )..definirTokenArtista('token-artista');

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: FilaMusicalArtista(
          api: api,
          apresentacao: _apresentacao(),
          incorporada: true,
        ),
      ),
    ));
    await tester.pumpAndSettle();

    // Incorporada no painel, o título e o status já ficam na barra superior.
    expect(find.text('Resenha de teste'), findsNothing);
    expect(find.text('Ao vivo'), findsNothing);
    expect(find.byType(SegmentedButton<int>), findsNothing);
    expect(find.text('Pendentes'), findsOneWidget);
    expect(find.text('Fila'), findsOneWidget);
    expect(find.text('Histórico'), findsOneWidget);
    // O status repetido sai das seções; só o histórico precisa dele.
    expect(find.text('Aceito'), findsNothing);
    expect(find.text('Música na fila'), findsOneWidget);
    expect(find.text('Pedido pendente'), findsNothing);
    expect(find.text('Música finalizada'), findsNothing);

    await tester.tap(find.text('Pendentes'));
    await tester.pumpAndSettle();
    expect(find.text('Pedido pendente'), findsOneWidget);
    expect(find.text('Música na fila'), findsNothing);

    await tester.tap(find.text('Histórico'));
    await tester.pumpAndSettle();
    expect(find.text('Música finalizada'), findsOneWidget);
    expect(find.text('Finalizado'), findsOneWidget);
    expect(find.text('Pedido pendente'), findsNothing);
  });

  testWidgets('abas da fila não quebram o texto em celular de 360px',
      (tester) async {
    addTearDown(tester.view.reset);
    tester.view.devicePixelRatio = 3;
    tester.view.physicalSize = const Size(360, 740) * 3;
    final api = ApiTocaEssa(
      enderecoBase: 'https://tocaessa.test',
      cliente: MockClient((_) async => http.Response(_pedidosJson, 200)),
    )..definirTokenArtista('token-artista');

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: FilaMusicalArtista(
          api: api,
          apresentacao: _apresentacao(),
          incorporada: true,
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    // Uma linha só: antes "Pendentes 1" virava "Pendent / es 1".
    final altura = tester.getSize(find.text('Pendentes')).height;
    final linha = tester.getSize(find.text('Fila')).height;
    expect(altura, linha);
  });
}

Apresentacao _apresentacao() => Apresentacao(
      id: '33333333-3333-3333-3333-333333333333',
      nome: 'Resenha de teste',
      data: DateTime(2026, 9, 10),
      local: 'Casa',
      codigo: 'ABC123',
      perfilArtistico: const PerfilArtistico(
        id: '22222222-2222-2222-2222-222222222222',
        nomeArtistico: 'Duo Aurora',
      ),
      pedidosAbertos: true,
      status: StatusApresentacao.emAndamento,
      tipo: TipoApresentacao.resenhaEntreAmigos,
    );

const _pedidosJson = '''
[
  {
    "pedidoRepresentativoId":"10000000-0000-0000-0000-000000000001",
    "pedidoIds":["10000000-0000-0000-0000-000000000001"],
    "apresentacaoId":"33333333-3333-3333-3333-333333333333",
    "musica":"Pedido pendente",
    "artista":"Artista A",
    "solicitantes":["Ana"],
    "quantidadePedidos":1,
    "status":"Aguardando",
    "criadoEm":"2026-09-10T12:00:00Z",
    "tipo":"Musica"
  },
  {
    "pedidoRepresentativoId":"10000000-0000-0000-0000-000000000002",
    "pedidoIds":["10000000-0000-0000-0000-000000000002"],
    "apresentacaoId":"33333333-3333-3333-3333-333333333333",
    "musica":"Música na fila",
    "artista":"Artista B",
    "solicitantes":["Bia"],
    "quantidadePedidos":1,
    "status":"Aceito",
    "posicao":1,
    "criadoEm":"2026-09-10T12:01:00Z",
    "tipo":"Musica"
  },
  {
    "pedidoRepresentativoId":"10000000-0000-0000-0000-000000000003",
    "pedidoIds":["10000000-0000-0000-0000-000000000003"],
    "apresentacaoId":"33333333-3333-3333-3333-333333333333",
    "musica":"Música finalizada",
    "artista":"Artista C",
    "solicitantes":["Caio"],
    "quantidadePedidos":1,
    "status":"Finalizado",
    "criadoEm":"2026-09-10T12:02:00Z",
    "tipo":"Musica"
  }
]
''';
