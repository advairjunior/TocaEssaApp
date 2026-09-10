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

    expect(find.text('Pendentes 1'), findsOneWidget);
    expect(find.text('Fila 1'), findsOneWidget);
    expect(find.text('Histórico 1'), findsOneWidget);
    expect(find.text('Música na fila'), findsOneWidget);
    expect(find.text('Pedido pendente'), findsNothing);
    expect(find.text('Música finalizada'), findsNothing);

    await tester.tap(find.text('Pendentes 1'));
    await tester.pumpAndSettle();
    expect(find.text('Pedido pendente'), findsOneWidget);
    expect(find.text('Música na fila'), findsNothing);

    await tester.tap(find.text('Histórico 1'));
    await tester.pumpAndSettle();
    expect(find.text('Música finalizada'), findsOneWidget);
    expect(find.text('Pedido pendente'), findsNothing);
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
    "id":"10000000-0000-0000-0000-000000000001",
    "apresentacaoId":"33333333-3333-3333-3333-333333333333",
    "musica":"Pedido pendente",
    "artista":"Artista A",
    "nomeSolicitante":"Ana",
    "status":"Aguardando",
    "criadoEm":"2026-09-10T12:00:00Z",
    "tipo":"Musica"
  },
  {
    "id":"10000000-0000-0000-0000-000000000002",
    "apresentacaoId":"33333333-3333-3333-3333-333333333333",
    "musica":"Música na fila",
    "artista":"Artista B",
    "nomeSolicitante":"Bia",
    "status":"Aceito",
    "posicao":1,
    "criadoEm":"2026-09-10T12:01:00Z",
    "tipo":"Musica"
  },
  {
    "id":"10000000-0000-0000-0000-000000000003",
    "apresentacaoId":"33333333-3333-3333-3333-333333333333",
    "musica":"Música finalizada",
    "artista":"Artista C",
    "nomeSolicitante":"Caio",
    "status":"Finalizado",
    "criadoEm":"2026-09-10T12:02:00Z",
    "tipo":"Musica"
  }
]
''';
