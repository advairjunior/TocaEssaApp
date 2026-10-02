import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:toca_essa_app/dominio/modelos.dart';
import 'package:toca_essa_app/infraestrutura/api_toca_essa.dart';
import 'package:toca_essa_app/telas/estatisticas_da_apresentacao.dart';

Future<void> _abrir(
  WidgetTester tester, {
  TipoApresentacao tipo = TipoApresentacao.publica,
  bool incorporada = false,
}) async {
  final cliente = MockClient((requisicao) async {
    if (requisicao.url.path.endsWith('/participantes')) {
      return http.Response(
        '[{"publicoId":"44444444-4444-4444-4444-444444444444","nome":"Ana Souza","fotoUrl":null,"pedidos":5,"pedidosTocados":3,"mediaAvaliacoes":4.5,"musicasMaisPedidas":[{"musica":"Evidências","quantidade":2}]}]',
        200,
      );
    }
    return http.Response(
      '{"totalPedidos":8,"aguardando":2,"aceitos":5,"tocados":4,"recusados":1,"avaliados":3,"mediaAvaliacoes":4.7,"musicasMaisPedidas":[{"musica":"Evidências","quantidade":3},{"musica":"Sozinho","quantidade":1}]}',
      200,
    );
  });
  final tela = EstatisticasDaApresentacaoTela(
    api: ApiTocaEssa(cliente: cliente, enderecoBase: 'http://teste'),
    apresentacao: Apresentacao(
      id: '22222222-2222-2222-2222-222222222222',
      nome: 'Noite Acústica',
      data: DateTime(2026, 9, 3),
      local: 'Café Central',
      codigo: 'A1B2C3',
      perfilArtistico: const PerfilArtistico(
        id: '11111111-1111-1111-1111-111111111111',
        nomeArtistico: 'Duo Aurora',
      ),
      pedidosAbertos: true,
      status: StatusApresentacao.emAndamento,
      tipo: tipo,
    ),
    incorporada: incorporada,
  );
  await tester.pumpWidget(MaterialApp(
    home: incorporada ? Scaffold(body: tela) : tela,
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('números em faixa única e ranking em lista, sem cards',
      (tester) async {
    await _abrir(tester);

    expect(find.byType(Card), findsNothing);
    expect(find.byType(ListTile), findsNothing);
    expect(find.text('4.7'), findsOneWidget);
    expect(find.text('3 avaliações recebidas'), findsOneWidget);
    for (final rotulo in [
      'pedidos',
      'tocados',
      'aguardando',
      'não atendidos'
    ]) {
      expect(find.text(rotulo), findsOneWidget);
    }
    expect(find.text('Músicas mais pedidas'), findsOneWidget);
    expect(find.text('3 pedidos'), findsOneWidget);
    expect(find.text('1 pedido'), findsOneWidget);
  });

  testWidgets('dentro do painel não repete nome e data do show',
      (tester) async {
    await _abrir(tester, incorporada: true);

    expect(find.text('Noite Acústica'), findsNothing);
    expect(find.text('03/09/2026 · Café Central'), findsNothing);
  });

  testWidgets('galera da resenha em lista agrupada, sem chips', (tester) async {
    await _abrir(tester, tipo: TipoApresentacao.resenhaEntreAmigos);
    await tester.scrollUntilVisible(find.text('Ana Souza'), 300);

    expect(find.byType(Chip), findsNothing);
    expect(find.text('5 pedidos · 3 tocados'), findsOneWidget);
    expect(find.text('Mais pedida: Evidências'), findsOneWidget);
  });

  testWidgets('na resenha, números vêm antes da retrospectiva', (tester) async {
    await _abrir(tester, tipo: TipoApresentacao.resenhaEntreAmigos);

    double topo(Finder alvo) => tester.getTopLeft(alvo).dy;
    expect(topo(find.text('não atendidos')),
        lessThan(topo(find.text('RETROSPECTIVA DA RESENHA'))));
    expect(find.text('Retrospectiva'), findsOneWidget);
  });

  testWidgets('estatísticas cabem em celular de 360px', (tester) async {
    addTearDown(tester.view.reset);
    tester.view.devicePixelRatio = 3;
    tester.view.physicalSize = const Size(360, 740) * 3;
    await _abrir(tester);

    expect(tester.takeException(), isNull);
  });
}
