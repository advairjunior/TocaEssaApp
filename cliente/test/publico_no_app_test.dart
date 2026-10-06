import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:toca_essa_app/dominio/modelos.dart';
import 'package:toca_essa_app/infraestrutura/api_toca_essa.dart';
import 'package:toca_essa_app/telas/estatisticas_da_apresentacao.dart';
import 'package:toca_essa_app/telas/fila_musical_artista.dart';

String _estatisticas({required int pessoas, required int pediram}) =>
    '{"totalPedidos":$pediram,"aguardando":0,"aceitos":0,"tocados":0,'
    '"recusados":0,"avaliados":0,"musicasMaisPedidas":[],'
    '"pessoasNoEvento":$pessoas,"pessoasQuePediram":$pediram}';

Apresentacao _show({
  StatusApresentacao status = StatusApresentacao.emAndamento,
}) =>
    Apresentacao(
      id: '33333333-3333-3333-3333-333333333333',
      nome: 'Show de sexta',
      data: DateTime(2026, 10, 9),
      local: 'Bar',
      codigo: 'ABC123',
      perfilArtistico: const PerfilArtistico(
        id: '22222222-2222-2222-2222-222222222222',
        nomeArtistico: 'Duo Aurora',
      ),
      pedidosAbertos: true,
      status: status,
      tipo: TipoApresentacao.publica,
    );

ApiTocaEssa _api(String Function() estatisticas) => ApiTocaEssa(
      enderecoBase: 'https://tocaessa.test',
      cliente: MockClient((requisicao) async =>
          requisicao.url.path.endsWith('/estatisticas')
              ? http.Response(estatisticas(), 200)
              : http.Response('[]', 200)),
    )..definirTokenArtista('token-artista');

Future<void> _abrirFila(WidgetTester tester, ApiTocaEssa api,
    {StatusApresentacao status = StatusApresentacao.emAndamento}) async {
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: FilaMusicalArtista(
          api: api, apresentacao: _show(status: status), incorporada: true),
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('fila ao vivo mostra quantas pessoas estão no app',
      (tester) async {
    await _abrirFila(
        tester, _api(() => _estatisticas(pessoas: 42, pediram: 12)));

    expect(find.text('42 pessoas no app · 12 pediram música'), findsOneWidget);
    expect(find.textContaining('perguntar'), findsNothing);
  });

  testWidgets('gente no app sem pedidos sugere perguntar à galera',
      (tester) async {
    await _abrirFila(tester, _api(() => _estatisticas(pessoas: 8, pediram: 0)));

    expect(find.text('8 pessoas no app · ninguém pediu ainda'), findsOneWidget);
    expect(
      find.text('Vale perguntar à galera se o app está funcionando.'),
      findsOneWidget,
    );
  });

  testWidgets('ninguém no app sugere mostrar o QR Code', (tester) async {
    await _abrirFila(tester, _api(() => _estatisticas(pessoas: 0, pediram: 0)));

    expect(find.text('Ninguém abriu o evento pelo app ainda'), findsOneWidget);
    expect(find.text('Mostre o QR Code para a galera entrar.'), findsOneWidget);
  });

  testWidgets('uma pessoa no singular', (tester) async {
    await _abrirFila(tester, _api(() => _estatisticas(pessoas: 1, pediram: 1)));

    expect(find.text('1 pessoa no app · 1 pediu música'), findsOneWidget);
  });

  testWidgets('número acompanha quem entra durante o show', (tester) async {
    var pessoas = 3;
    await _abrirFila(
        tester, _api(() => _estatisticas(pessoas: pessoas, pediram: 1)));
    expect(find.text('3 pessoas no app · 1 pediu música'), findsOneWidget);

    pessoas = 5;
    // A fila se atualiza sozinha a cada 30 segundos (e por aviso em tempo real).
    await tester.pump(const Duration(seconds: 31));
    await tester.pumpAndSettle();

    expect(find.text('5 pessoas no app · 1 pediu música'), findsOneWidget);
  });

  testWidgets('falha ao buscar o público não atrapalha a fila', (tester) async {
    await _abrirFila(tester, _api(() => 'erro'));

    expect(tester.takeException(), isNull);
    expect(find.textContaining('no app'), findsNothing);
    expect(find.text('Pendentes'), findsOneWidget);
  });

  testWidgets('estatísticas também mostram o público no app', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: EstatisticasDaApresentacaoTela(
          api: _api(() => _estatisticas(pessoas: 42, pediram: 12)),
          apresentacao: _show(),
          incorporada: true,
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('42 pessoas no app · 12 pediram música'), findsOneWidget);
  });
}
