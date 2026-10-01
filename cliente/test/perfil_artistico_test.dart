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
const _configuracaoJson =
    '{"perfil":{"id":"11111111-1111-1111-1111-111111111111","nomeArtistico":"Duo Aurora","bio":"Voz e violão","fotoUrl":null},'
    '"instagram":"duoaurora","exibirInstagram":true,"whatsapp":null,"exibirWhatsapp":false,"pixAtivo":false}';

Finder campo(String rotulo) => find.descendant(
      of: find.widgetWithText(CampoTexto, rotulo),
      matching: find.byType(TextField),
    );

bool _podeSalvar(WidgetTester tester) => tester
    .widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Salvar alterações'))
    .enabled;

Future<void> _abrirPerfil(WidgetTester tester,
    {String configuracao = _configuracaoJson}) async {
  SharedPreferences.setMockInitialValues({'token_do_artista': 'TOKEN'});
  final cliente = MockClient((requisicao) async {
    if (requisicao.url.path == '/api/artista/conta') {
      return http.Response(_contaArtistaJson, 200);
    }
    if (requisicao.url.path == '/api/perfil-artistico') {
      return http.Response(configuracao, 200);
    }
    return http.Response('[]', 200);
  });
  await tester.pumpWidget(TocaEssaApp(
    api: ApiTocaEssa(cliente: cliente, enderecoBase: 'http://teste'),
  ));
  final acessarPainel = find.text('Sou artista');
  await tester.ensureVisible(acessarPainel);
  await tester.tap(acessarPainel);
  await tester.pumpAndSettle();
  await tester.tap(find.byTooltip('Minha conta'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Perfil artístico'));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('salvar só habilita com alteração e a prévia acompanha',
      (tester) async {
    await _abrirPerfil(tester);

    expect(_podeSalvar(tester), isFalse);
    expect(find.text('Como o público vê'), findsOneWidget);

    await tester.enterText(campo('Nome artístico'), 'Trio Aurora');
    await tester.pump();

    expect(_podeSalvar(tester), isTrue);
    // Campo e prévia mostram o novo nome.
    expect(find.text('Trio Aurora'), findsNWidgets(2));
  });

  testWidgets('campo mantém o foco quando o botão de salvar habilita',
      (tester) async {
    await _abrirPerfil(tester);
    final nome = campo('Nome artístico');
    await tester.showKeyboard(nome);
    await tester.pump();

    await tester.enterText(nome, 'Duo Aurora e');
    await tester.pumpAndSettle();
    expect(_podeSalvar(tester), isTrue);

    final editavel = tester.state<EditableTextState>(
      find.descendant(of: nome, matching: find.byType(EditableText)),
    );
    expect(editavel.widget.focusNode.hasFocus, isTrue);
  });

  testWidgets('sair com alterações pede confirmação e descarta',
      (tester) async {
    await _abrirPerfil(tester);
    await tester.enterText(campo('Nome artístico'), 'Trio Aurora');
    await tester.pump();

    await tester.tap(find.byTooltip('Voltar ao início'));
    await tester.pumpAndSettle();
    expect(find.text('Descartar alterações?'), findsOneWidget);
    await tester.tap(find.text('Descartar'));
    await tester.pumpAndSettle();

    expect(find.text('Olá, Duo Aurora'), findsOneWidget);
    await tester.tap(find.byTooltip('Minha conta'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Perfil artístico'));
    await tester.pumpAndSettle();
    expect(find.text('Trio Aurora'), findsNothing);
    expect(_podeSalvar(tester), isFalse);
  });

  testWidgets('perfil usa seções leves e foto com botão de câmera',
      (tester) async {
    await _abrirPerfil(tester);

    expect(find.byTooltip('Adicionar foto'), findsOneWidget);
    expect(find.text('Identidade artística'), findsOneWidget);
    expect(find.text('Sua jornada'), findsOneWidget);
    expect(find.text('Gerenciar repertórios'), findsNothing);
    expect(find.text('ana@artista.com'), findsOneWidget);
  });

  testWidgets('perfil com Pix aberto cabe em celular de 360px', (tester) async {
    addTearDown(tester.view.reset);
    tester.view.devicePixelRatio = 3;
    tester.view.physicalSize = const Size(360, 740) * 3;
    await _abrirPerfil(
      tester,
      configuracao: _configuracaoJson.replaceFirst(
        '"pixAtivo":false',
        '"pixAtivo":true,"pixChave":"chave","pixNomeBeneficiario":"DUO AURORA",'
            '"pixCidadeBeneficiario":"SAO PAULO"',
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.widgetWithText(CampoTexto, 'Beneficiário'), findsOneWidget);
    expect(_podeSalvar(tester), isFalse);
  });
}
