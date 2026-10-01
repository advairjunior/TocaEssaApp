import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:toca_essa_app/infraestrutura/api_toca_essa.dart';
import 'package:toca_essa_app/main.dart';
import 'package:toca_essa_app/telas/componentes_formulario.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({
        'token_do_artista': 'TOKEN',
      }));

  testWidgets('artista configura contatos publicos e apoio pix',
      (tester) async {
    final cliente = MockClient((requisicao) async {
      if (requisicao.url.path == '/api/artista/conta') {
        return http.Response(
          '{"id":"aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa",'
          '"nome":"Ana","email":"ana@artista.com",'
          '"criadoEm":"2026-09-03T20:00:00Z"}',
          200,
        );
      }
      if (requisicao.url.path == '/api/perfil-artistico') {
        return http.Response(
          '{"perfil":{"id":"11111111-1111-1111-1111-111111111111",'
          '"nomeArtistico":"Duo Aurora","bio":"Voz e violão",'
          '"instagram":"duoaurora","whatsapp":null,'
          '"apoioPixDisponivel":true},'
          '"instagram":"duoaurora","exibirInstagram":true,'
          '"whatsapp":"5511999999999","exibirWhatsapp":false,'
          '"pixAtivo":true,"pixChave":"chave-aleatoria",'
          '"pixNomeBeneficiario":"DUO AURORA",'
          '"pixCidadeBeneficiario":"SAO PAULO",'
          '"pixMensagem":"Obrigado pelo apoio"}',
          200,
        );
      }
      return http.Response('[]', 200);
    });

    await tester.pumpWidget(TocaEssaApp(
      api: ApiTocaEssa(cliente: cliente, enderecoBase: 'http://teste'),
    ));
    final acessar = find.text('Sou artista');
    await tester.ensureVisible(acessar);
    await tester.tap(acessar);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Minha conta'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Perfil artístico'));
    await tester.pumpAndSettle();

    expect(find.text('Contatos públicos'), findsOneWidget);
    expect(find.text('Exibir Instagram ao público'), findsOneWidget);
    expect(find.text('Aceitar contribuições'), findsOneWidget);
    expect(find.widgetWithText(CampoTexto, 'Chave Pix'), findsOneWidget);
    expect(find.text('Prefira uma chave aleatória'), findsOneWidget);
  });
}
