import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:toca_essa_app/infraestrutura/api_toca_essa.dart';
import 'package:toca_essa_app/infraestrutura/cliente_http_com_reserva.dart';
import 'package:toca_essa_app/main.dart';

const _conta =
    '{"id":"aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa","nome":"Ana","email":"ana@artista.com","criadoEm":"2026-09-03T20:00:00Z"}';
const _perfil =
    '{"id":"11111111-1111-1111-1111-111111111111","nomeArtistico":"Duo Aurora","bio":null}';

/// Servidor do artista que pode ficar sem rede.
class _Rede {
  var online = true;
  late final cliente = MockClient((requisicao) async {
    if (!online) throw http.ClientException('sem rede', requisicao.url);
    return switch (requisicao.url.path) {
      '/api/artista/conta' => http.Response(_conta, 200),
      '/api/perfil-artistico' => http.Response(_perfil, 200),
      _ => http.Response('[]', 200),
    };
  });
}

Future<void> _abrirPainel(WidgetTester tester, ApiTocaEssa api) async {
  await tester.pumpWidget(TocaEssaApp(api: api));
  final acessar = find.textContaining('meu painel');
  await tester.ensureVisible(acessar);
  await tester.tap(acessar);
  await tester.pumpAndSettle();
}

void main() {
  setUp(() =>
      SharedPreferences.setMockInitialValues({'token_do_artista': 'TOKEN'}));

  testWidgets('sem rede ao recarregar, o login continua guardado',
      (tester) async {
    final rede = _Rede()..online = false;
    await _abrirPainel(
        tester, ApiTocaEssa(cliente: rede.cliente, enderecoBase: 'http://teste'));

    final preferencias = await SharedPreferences.getInstance();
    expect(preferencias.getString('token_do_artista'), 'TOKEN');
  });

  testWidgets('token recusado pelo servidor sai do aparelho', (tester) async {
    final cliente = MockClient((_) async =>
        http.Response('{"mensagem":"Sessão expirada."}', 401));
    await _abrirPainel(
        tester, ApiTocaEssa(cliente: cliente, enderecoBase: 'http://teste'));

    final preferencias = await SharedPreferences.getInstance();
    expect(preferencias.getString('token_do_artista'), isNull);
  });

  testWidgets('com dados guardados, o painel abre sem internet e avisa',
      (tester) async {
    final rede = _Rede();
    ApiTocaEssa api() => ApiTocaEssa(
        cliente: ClienteHttpComReserva(rede.cliente),
        enderecoBase: 'http://teste');
    await tester.runAsync(() async {
      await _abrirPainel(tester, api());
    });
    expect(find.text('Olá, Duo Aurora'), findsOneWidget);
    expect(find.textContaining('Sem internet'), findsNothing);

    // Recarregar a página sem internet.
    rede.online = false;
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(() async {
      await _abrirPainel(tester, api());
    });
    await tester.pumpAndSettle();

    expect(find.text('Olá, Duo Aurora'), findsOneWidget);
    expect(find.textContaining('Sem internet · dados salvos às'),
        findsOneWidget);
  });
}
