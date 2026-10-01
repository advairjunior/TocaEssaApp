import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:toca_essa_app/infraestrutura/api_toca_essa.dart';
import 'package:toca_essa_app/main.dart';
import 'package:toca_essa_app/telas/componentes_formulario.dart';

const _contaArtistaJson =
    '{"id":"aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa","nome":"Ana","email":"ana@artista.com","criadoEm":"2026-09-03T20:00:00Z"}';
const _perfilJson =
    '{"id":"11111111-1111-1111-1111-111111111111","nomeArtistico":"Duo Aurora","bio":null}';

String _apresentacao({
  required String id,
  required String nome,
  required String data,
  String status = 'Agendada',
  String tipo = 'Publica',
  bool pedidosAbertos = true,
}) =>
    '{"id":"20000000-0000-0000-0000-00000000000$id","nome":"$nome","data":"$data","local":"Bar do Zé","codigo":"COD00$id","perfilArtistico":{"id":"11111111-1111-1111-1111-111111111111","nomeArtistico":"Duo Aurora"},"pedidosAbertos":$pedidosAbertos,"status":"$status","tipo":"$tipo"}';

Finder campo(String rotulo) => find.descendant(
      of: find.widgetWithText(CampoTexto, rotulo),
      matching: find.byType(TextField),
    );

Future<void> _abrirPainel(
  WidgetTester tester, {
  String? perfil = _perfilJson,
  String apresentacoes = '[]',
  Future<http.Response?> Function(http.Request)? outras,
}) async {
  SharedPreferences.setMockInitialValues({'token_do_artista': 'TOKEN'});
  final cliente = MockClient((requisicao) async {
    final resposta = await outras?.call(requisicao);
    if (resposta != null) return resposta;
    if (requisicao.url.path == '/api/artista/conta') {
      return http.Response(_contaArtistaJson, 200);
    }
    if (requisicao.url.path == '/api/perfil-artistico') {
      return perfil == null
          ? http.Response('{"mensagem":"Perfil não encontrado."}', 404)
          : http.Response(perfil, 200);
    }
    if (requisicao.url.path == '/api/apresentacoes') {
      return http.Response(apresentacoes, 200);
    }
    return http.Response('[]', 200);
  });
  await tester.pumpWidget(TocaEssaApp(
    api: ApiTocaEssa(cliente: cliente, enderecoBase: 'http://teste'),
  ));
  final acessarPainel = find.text('Acessar Painel do Artista');
  await tester.ensureVisible(acessarPainel);
  await tester.tap(acessarPainel);
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('início do painel não tem barra de abas e cumprimenta o artista',
      (tester) async {
    await _abrirPainel(tester);

    expect(find.byType(NavigationBar), findsNothing);
    expect(find.text('Olá, Duo Aurora'), findsOneWidget);
    expect(find.byTooltip('Minha conta'), findsOneWidget);
    expect(find.text('Nova apresentação'), findsOneWidget);
    expect(find.text('Nenhuma apresentação ainda'), findsOneWidget);
  });

  testWidgets('sem perfil artístico o painel orienta a criar o perfil',
      (tester) async {
    await _abrirPainel(tester, perfil: null);

    expect(find.text('Nova apresentação'), findsNothing);
    await tester.tap(find.text('Criar perfil artístico'));
    await tester.pumpAndSettle();
    expect(find.text('Identidade artística'), findsOneWidget);
  });

  testWidgets('menu da conta abre perfil artístico e volta ao início',
      (tester) async {
    await _abrirPainel(tester);

    await tester.tap(find.byTooltip('Minha conta'));
    await tester.pumpAndSettle();
    expect(find.text('Repertórios'), findsOneWidget);
    expect(find.text('Sair'), findsOneWidget);
    await tester.tap(find.text('Perfil artístico'));
    await tester.pumpAndSettle();

    expect(find.text('Identidade artística'), findsOneWidget);
    expect(find.text('Conquistas'), findsOneWidget);
    await tester.tap(find.byTooltip('Voltar ao início'));
    await tester.pumpAndSettle();
    expect(find.text('Olá, Duo Aurora'), findsOneWidget);
  });

  testWidgets('show ao vivo aparece em destaque e abre direto na fila',
      (tester) async {
    await _abrirPainel(
      tester,
      apresentacoes: '[${_apresentacao(
        id: '1',
        nome: 'Show de hoje',
        data: '2026-09-04',
        status: 'EmAndamento',
      )}]',
    );

    expect(find.text('Ao vivo agora'), findsOneWidget);
    expect(find.text('Show de hoje'), findsOneWidget);
    await tester.tap(find.text('Abrir fila'));
    await tester.pumpAndSettle();

    final barra = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(barra.destinations, hasLength(4));
    expect(find.text('Setlist'), findsOneWidget);
    expect(find.text('Mais'), findsOneWidget);
    expect(barra.selectedIndex, 0);
  });

  testWidgets('lista mostra data em bloco e tipo resumido', (tester) async {
    await _abrirPainel(
      tester,
      apresentacoes: '[${_apresentacao(
        id: '1',
        nome: 'Show de sábado',
        data: '2026-09-05',
        tipo: 'ResenhaEntreAmigos',
      )}]',
    );

    expect(find.text('SET'), findsOneWidget);
    expect(find.text('05'), findsOneWidget);
    expect(find.text('Bar do Zé · Resenha'), findsOneWidget);
  });

  testWidgets('leitores de tela anunciam itens e menu da conta como botões',
      (tester) async {
    final semantica = tester.ensureSemantics();
    await _abrirPainel(
      tester,
      apresentacoes: '[${_apresentacao(
        id: '1',
        nome: 'Show de sábado',
        data: '2026-09-05',
      )}]',
    );

    expect(
      tester.getSemantics(find.text('Show de sábado')),
      containsSemantics(isButton: true, hasTapAction: true),
    );
    expect(
      tester.getSemantics(find.byTooltip('Minha conta')),
      containsSemantics(isButton: true),
    );
    semantica.dispose();
  });

  testWidgets('nova apresentação usa cartões de tipo e campos sem menu',
      (tester) async {
    await _abrirPainel(tester);

    await tester.tap(find.text('Nova apresentação'));
    await tester.pumpAndSettle();

    expect(find.byType(DropdownButtonFormField<Object>), findsNothing);
    expect(find.text('Pública'), findsOneWidget);
    expect(find.text('Resenha'), findsOneWidget);
    expect(campo('Nome da apresentação'), findsOneWidget);
    expect(campo('Local'), findsOneWidget);
    expect(find.text('Criar apresentação'), findsOneWidget);
  });

  testWidgets('barra de status mostra controles da apresentação ao vivo',
      (tester) async {
    var pedidosAlterados = false;
    await _abrirPainel(
      tester,
      apresentacoes: '[${_apresentacao(
        id: '1',
        nome: 'Show de hoje',
        data: '2026-09-04',
        status: 'EmAndamento',
      )}]',
      outras: (requisicao) async {
        if (requisicao.url.path.endsWith('/pedidos') &&
            requisicao.method == 'PATCH') {
          pedidosAlterados = true;
          expect(requisicao.body, contains('"abertos":false'));
          return http.Response(
            _apresentacao(
              id: '1',
              nome: 'Show de hoje',
              data: '2026-09-04',
              status: 'EmAndamento',
              pedidosAbertos: false,
            ),
            200,
          );
        }
        return null;
      },
    );
    await tester.tap(find.text('Show de hoje'));
    await tester.pumpAndSettle();

    expect(find.text('Ao vivo'), findsOneWidget);
    expect(find.text('Encerrar'), findsOneWidget);
    await tester.tap(find.byTooltip('Receber pedidos'));
    await tester.pumpAndSettle();
    expect(pedidosAlterados, isTrue);
  });

  testWidgets('início e barra de status cabem em celular de 360px',
      (tester) async {
    addTearDown(tester.view.reset);
    tester.view.devicePixelRatio = 3;
    tester.view.physicalSize = const Size(360, 740) * 3;
    await _abrirPainel(
      tester,
      apresentacoes: '[${_apresentacao(
        id: '1',
        nome: 'Show de hoje com nome bem comprido',
        data: '2026-09-04',
        status: 'EmAndamento',
      )},${_apresentacao(
        id: '2',
        nome: 'Show de sábado',
        data: '2026-09-05',
        tipo: 'ResenhaEntreAmigos',
      )}]',
    );
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Show de sábado'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Iniciar'), findsOneWidget);
  });

  testWidgets('aba Mais reúne detalhes, código e exclusão', (tester) async {
    await _abrirPainel(
      tester,
      apresentacoes: '[${_apresentacao(
        id: '1',
        nome: 'Show de sábado',
        data: '2026-09-05',
      )}]',
    );
    await tester.tap(find.text('Show de sábado'));
    await tester.pumpAndSettle();

    expect(find.text('COD001'), findsOneWidget);
    expect(find.text('Bar do Zé'), findsOneWidget);
    expect(find.text('05/09/2026'), findsOneWidget);
    expect(find.text('Editar apresentação'), findsOneWidget);
    expect(find.text('Excluir apresentação'), findsOneWidget);
    expect(find.text('Iniciar'), findsOneWidget);
  });
}
