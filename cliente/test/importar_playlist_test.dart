import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:toca_essa_app/infraestrutura/api_toca_essa.dart';
import 'package:toca_essa_app/telas/componentes_formulario.dart';
import 'package:toca_essa_app/telas/gerenciar_repertorios.dart';

const _json = {'content-type': 'application/json; charset=utf-8'};
const _falta = 'https://www.youtube.com/watch?v=xKPaBwlI16o';
const _desejo = 'https://www.youtube.com/watch?v=aorrMojEBcw';
const _link =
    'https://youtube.com/playlist?list=PLeHLlswxpAUNM5fn1gwmNLloimGhIAfsh&si=x';

Future<List<http.Request>> _abrir(WidgetTester tester,
    {http.Response? playlist}) async {
  final requisicoes = <http.Request>[];
  final cliente = MockClient((requisicao) async {
    requisicoes.add(requisicao);
    final caminho = requisicao.url.path;
    if (caminho == '/api/artista/repertorios/playlist') {
      return playlist ??
          http.Response(
              jsonEncode({
                'titulo': 'karaoke',
                'musicas': [
                  {'titulo': 'Thiaguinho - Falta Você', 'linkDoVideo': _falta},
                  {
                    'titulo': 'Desejo Imortal - Gusttavo Lima',
                    'linkDoVideo': _desejo
                  },
                ],
              }),
              200,
              headers: _json);
    }
    if (caminho == '/api/artista/repertorios/musicas') {
      final corpo = jsonDecode(requisicao.body) as Map<String, dynamic>;
      return http.Response(
          jsonEncode({
            'repertorio': {
              'id': 'r9',
              'artistaId': 'a1',
              'nome': corpo['nomeNovo'],
              'musicas': [],
            },
            'adicionadas': (corpo['musicas'] as List).length,
            'jaEstavam': 0,
          }),
          200,
          headers: _json);
    }
    return http.Response('[]', 200, headers: _json);
  });
  final api = ApiTocaEssa(cliente: cliente, enderecoBase: 'http://teste')
    ..definirTokenArtista('TOKEN');
  await tester.pumpWidget(MaterialApp(home: GerenciarRepertorios(api: api)));
  await tester.pumpAndSettle();
  return requisicoes;
}

Future<void> _colarLink(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Importar playlist do YouTube'));
  await tester.pumpAndSettle();
  await tester.enterText(
      find.descendant(
          of: find.widgetWithText(CampoTexto, 'Link da playlist'),
          matching: find.byType(TextField)),
      _link);
  await tester.tap(find.text('Ler playlist'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a playlist vira um repertório com o vídeo de cada música',
      (tester) async {
    final requisicoes = await _abrir(tester);

    await _colarLink(tester);
    final leitura = requisicoes
        .singleWhere((r) => r.url.path == '/api/artista/repertorios/playlist');
    expect(jsonDecode(leitura.body), {'link': _link});
    expect(find.text('Thiaguinho - Falta Você'), findsOneWidget);
    expect(find.text('Desejo Imortal - Gusttavo Lima'), findsOneWidget);

    await tester.tap(find.text('Adicionar 2 músicas ao repertório'));
    await tester.pumpAndSettle();
    // O nome da playlist já vem sugerido para o repertório novo.
    await tester.tap(find.text('Criar'));
    await tester.pumpAndSettle();

    final envio = requisicoes
        .singleWhere((r) => r.url.path == '/api/artista/repertorios/musicas');
    final corpo = jsonDecode(envio.body) as Map<String, dynamic>;
    expect(corpo['nomeNovo'], 'karaoke');
    expect([for (final m in corpo['musicas'] as List) m['linkDoVideo']],
        [_falta, _desejo]);
  });

  testWidgets('playlist privada ou link errado mostra o motivo',
      (tester) async {
    await _abrir(tester,
        playlist: http.Response(
            jsonEncode({
              'mensagem':
                  'Playlist não encontrada. Ela precisa ser pública ou não listada.'
            }),
            404,
            headers: _json));

    await _colarLink(tester);

    expect(
        find.text(
            'Playlist não encontrada. Ela precisa ser pública ou não listada.'),
        findsOneWidget);
    expect(find.text('Adicionar 2 músicas ao repertório'), findsNothing);
  });
}
