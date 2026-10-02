import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:toca_essa_app/infraestrutura/api_toca_essa.dart';
import 'package:toca_essa_app/dominio/modelos.dart';
import 'package:toca_essa_app/telas/area_do_publico.dart';
import 'package:toca_essa_app/tema/tema_toca_essa.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('publico abre perfil e gera apoio pix', (tester) async {
    final cliente = MockClient((requisicao) async {
      if (requisicao.url.path.endsWith('/fila')) {
        return http.Response('[]', 200);
      }
      if (requisicao.url.path.endsWith('/apoio-pix')) {
        expect(requisicao.url.queryParameters['valor'], '10.00');
        return http.Response(
          '{"valor":10,"pixCopiaECola":'
          '"00020101021126580014BR.GOV.BCB.PIX6304ABCD",'
          '"mensagem":"Obrigado pelo apoio"}',
          200,
        );
      }
      return http.Response(
        '{"id":"22222222-2222-2222-2222-222222222222",'
        '"nome":"Noite Acústica","data":"2026-09-20",'
        '"local":"Café Central","codigo":"A1B2C3",'
        '"perfilArtistico":{"id":"11111111-1111-1111-1111-111111111111",'
        '"nomeArtistico":"Duo Aurora","bio":"Voz e violão",'
        '"instagram":"duoaurora","whatsapp":"5511999999999",'
        '"apoioPixDisponivel":true},"pedidosAbertos":true,'
        '"status":"EmAndamento","tipo":"Publica"}',
        200,
      );
    });

    await tester.pumpWidget(MaterialApp(
      home: AreaDoPublico(
        api: ApiTocaEssa(cliente: cliente, enderecoBase: 'http://teste'),
        codigoInicial: 'A1B2C3',
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Ver perfil do artista'), findsNothing);
    expect(find.text('Artista'), findsOneWidget);
    await tester.tap(find.text('Artista'));
    await tester.pumpAndSettle();
    expect(find.text('Sobre o artista'), findsOneWidget);
    expect(find.text('Instagram'), findsOneWidget);
    expect(find.text('WhatsApp'), findsOneWidget);

    await tester.ensureVisible(find.text('Apoiar o artista'));
    await tester.tap(find.text('Apoiar o artista'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('R\$ 10'));
    await tester.pumpAndSettle();

    expect(find.text('Copiar código Pix'), findsOneWidget);
    expect(find.textContaining('não garante'), findsOneWidget);
  });

  testWidgets('valor escolhido fica marcado e copiar vira ação principal',
      (tester) async {
    final semantica = tester.ensureSemantics();
    await _abrirFolha(tester);

    await tester.tap(find.text('R\$ 10'));
    await tester.pumpAndSettle();

    expect(
      tester.getSemantics(find.text('R\$ 10')),
      containsSemantics(isSelected: true),
    );
    expect(
      tester.getSemantics(find.text('R\$ 5')),
      containsSemantics(isSelected: false),
    );
    expect(
        find.ancestor(
          of: find.text('Copiar código Pix'),
          matching: find.byWidgetPredicate((w) => w is FilledButton),
        ),
        findsOneWidget);
    expect(find.text('Pix de R\$ 10,00'), findsOneWidget);
    semantica.dispose();
  });

  testWidgets('valor inválido mostra erro na cor do tema', (tester) async {
    await _abrirFolha(tester);

    await tester.enterText(find.byType(TextField), '5000');
    await tester.tap(find.byTooltip('Gerar Pix com outro valor'));
    await tester.pumpAndSettle();

    final erro = tester
        .widget<Text>(find.text('Informe um valor entre R\$ 1 e R\$ 1.000.'));
    expect(erro.style?.color, CoresTocaEssa.rosa);
  });
}

Future<void> _abrirFolha(WidgetTester tester) async {
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: ApoioPixArtista(
        carregar: (valor) async => ApoioPix(
          valor: valor,
          pixCopiaECola: '00020101021126580014BR.GOV.BCB.PIX6304ABCD',
          mensagem: 'Obrigado pelo apoio',
        ),
      ),
    ),
  ));
  await tester.pumpAndSettle();
}
