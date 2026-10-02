import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:toca_essa_app/infraestrutura/api_toca_essa.dart';
import 'package:toca_essa_app/telas/area_do_publico.dart';

const _apresentacaoJson =
    '{"id":"22222222-2222-2222-2222-222222222222","nome":"Noite Acústica","data":"2026-09-03","local":"Café Central","codigo":"A1B2C3","perfilArtistico":{"id":"11111111-1111-1111-1111-111111111111","nomeArtistico":"Duo Aurora","bio":null},"pedidosAbertos":true,"status":"EmAndamento","tipo":"Publica"}';

String _pedido(String id, String musica, String status,
        {int? posicao, List<String> solicitantes = const []}) =>
    '{"id":"30000000-0000-0000-0000-00000000000$id","apresentacaoId":"22222222-2222-2222-2222-222222222222","musica":"$musica","artista":"Banda $id","nomeSolicitante":null,"status":"$status","posicao":${posicao ?? 'null'},"criadoEm":"2026-09-03T20:0$id:00Z","quantidadeAvaliacoes":0,"solicitantes":[${solicitantes.map((s) => '"$s"').join(',')}]}';

Future<void> _abrirFila(WidgetTester tester, String fila) async {
  final cliente = MockClient((requisicao) async {
    if (requisicao.url.path.endsWith('/fila')) {
      return http.Response(fila, 200);
    }
    return http.Response(_apresentacaoJson, 200);
  });
  await tester.pumpWidget(MaterialApp(
    home: AreaDoPublico(
      api: ApiTocaEssa(cliente: cliente, enderecoBase: 'http://teste'),
      codigoInicial: 'A1B2C3',
    ),
  ));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Fila').last);
  await tester.pumpAndSettle();
}

final _filaCompleta = '[${_pedido('1', 'Agora', 'TocandoAgora', solicitantes: [
      'Ana'
    ])},${_pedido('2', 'Depois', 'Aceito', posicao: 1)},'
    '${_pedido('3', 'Mais tarde', 'Aceito', posicao: 2)},'
    '${_pedido('4', 'Anterior', 'Finalizado')}]';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('fila não repete o cartão da apresentação do topo',
      (tester) async {
    await _abrirFila(tester, _filaCompleta);

    expect(find.text('Fila Musical'), findsNothing);
    expect(find.text('Café Central'), findsNothing);
    // O código continua à mão, agora no topo.
    expect(find.byTooltip('Copiar código'), findsOneWidget);
  });

  testWidgets('música tocando ganha destaque com quem pediu', (tester) async {
    await _abrirFila(tester, _filaCompleta);

    expect(find.text('Tocando agora'), findsOneWidget);
    expect(find.text('Agora'), findsOneWidget);
    expect(find.text('Pedido por Ana'), findsOneWidget);
    expect(find.text('Próximas músicas'), findsOneWidget);
    expect(find.text('≈ 6 min'), findsOneWidget);
    expect(find.text('Já tocadas'), findsOneWidget);
  });

  testWidgets('fila vazia convida a fazer o primeiro pedido', (tester) async {
    await _abrirFila(tester, '[]');

    expect(find.text('A fila ainda está vazia'), findsOneWidget);
    await tester.tap(find.text('Fazer um pedido'));
    await tester.pumpAndSettle();
    expect(find.text('O que você quer ouvir?'), findsOneWidget);
  });

  testWidgets('fila cabe em celular de 360px', (tester) async {
    addTearDown(tester.view.reset);
    tester.view.devicePixelRatio = 3;
    tester.view.physicalSize = const Size(360, 740) * 3;
    await _abrirFila(tester, _filaCompleta);

    expect(tester.takeException(), isNull);
  });
}
