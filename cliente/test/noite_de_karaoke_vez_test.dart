import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:toca_essa_app/infraestrutura/api_toca_essa.dart';
import 'package:toca_essa_app/telas/componentes_formulario.dart';
import 'package:toca_essa_app/telas/noite_de_karaoke_galera.dart';

const _json = {'content-type': 'application/json; charset=utf-8'};
const _rota = '/api/publico/apresentacoes/KARA01/karaoke';
const _video = 'https://www.youtube.com/watch?v=abc';

Map<String, dynamic> _pessoa(String id, String nome,
        {String? musica, String? link}) =>
    {
      'publicoId': id,
      'nome': nome,
      'fotoUrl': null,
      'musica': musica == null ? null : {'titulo': musica, 'linkDoVideo': link},
    };

/// Ana (p1, quem usa o celular) é a primeira da ordem.
Map<String, dynamic> _noite({
  String modo = 'Livre',
  String? musicaDaAna,
  String? linkDaAna,
  Map<String, dynamic>? cantando,
  String? proximo = 'p1',
}) =>
    {
      'repertorioId': 'r1',
      'modo': modo,
      'sorteada': true,
      'podeSortearDeNovo': cantando == null,
      'ordem': [
        _pessoa('p1', 'Ana', musica: musicaDaAna, link: linkDaAna),
        _pessoa('p2', 'Bia'),
      ],
      'foraDaOrdem': [],
      'cantando': cantando,
      'proximo': proximo,
    };

Map<String, dynamic> _cantando(String id, String nome, String musica) => {
      'publicoId': id,
      'nome': nome,
      'musica': {'titulo': musica, 'linkDoVideo': null},
      'comecouEm': '2026-10-30T23:00:00Z',
    };

typedef _Resposta = Map<String, dynamic> Function(http.Request);

Future<({List<http.Request> requisicoes, List<Uri> abertas})> _abrir(
  WidgetTester tester, {
  required Map<String, dynamic> noite,
  Map<String, _Resposta> respostas = const {},
}) async {
  SharedPreferences.setMockInitialValues({'token_do_publico': 'TOKEN-ANA'});
  final requisicoes = <http.Request>[];
  final abertas = <Uri>[];
  final cliente = MockClient((requisicao) async {
    requisicoes.add(requisicao);
    final chave = '${requisicao.method} ${requisicao.url.path}';
    if (respostas[chave] case final resposta?) {
      return http.Response(jsonEncode(resposta(requisicao)), 200,
          headers: _json);
    }
    return switch (requisicao.url.path) {
      '/api/publico/perfil' => http.Response(
          jsonEncode({
            'id': 'p1',
            'nome': 'Ana',
            'email': 'ana@teste.com',
            'criadoEm': '2026-10-01T00:00:00Z'
          }),
          200,
          headers: _json),
      _rota => http.Response(jsonEncode(noite), 200, headers: _json),
      '$_rota/playlist' => http.Response(
          jsonEncode([
            {'id': 'm1', 'titulo': 'Evidências'},
            {'id': 'm2', 'titulo': 'Trem-Bala'},
          ]),
          200,
          headers: _json),
      '/api/publico/apresentacoes/KARA01' => http.Response(
          jsonEncode({
            'id': 'k1',
            'nome': 'Karaokê de sexta',
            'data': '2026-10-30',
            'local': 'Casa',
            'codigo': 'KARA01',
            'perfilArtistico': {'id': 'pa', 'nomeArtistico': 'Advair'},
            'tipo': 'Karaoke',
          }),
          200,
          headers: _json),
      _ => http.Response('', 204),
    };
  });
  await tester.pumpWidget(MaterialApp(
    home: NoiteDeKaraokeDaGalera(
      api: ApiTocaEssa(cliente: cliente, enderecoBase: 'http://teste'),
      codigo: 'KARA01',
      abrirUrl: abertas.add,
    ),
  ));
  await tester.pumpAndSettle();
  return (requisicoes: requisicoes, abertas: abertas);
}

Iterable<http.Request> _enviadas(List<http.Request> requisicoes, String rota) =>
    requisicoes.where((r) => r.method == 'POST' && r.url.path == rota);

Finder _campo(String rotulo) => find.descendant(
    of: find.widgetWithText(CampoTexto, rotulo),
    matching: find.byType(TextField));

void main() {
  testWidgets('na vez sem música pede para escolher antes de tocar',
      (tester) async {
    await _abrir(tester, noite: _noite());

    expect(find.text('Sua vez!'), findsOneWidget);
    expect(find.text('Escolher minha música'), findsOneWidget);
    expect(find.text('Tocar na TV'), findsNothing);
  });

  testWidgets('escolher da playlist com busca', (tester) async {
    final teste = await _abrir(tester, noite: _noite(), respostas: {
      'POST $_rota/musica': (_) =>
          _noite(musicaDaAna: 'Trem-Bala', linkDaAna: _video),
    });

    await tester.tap(find.text('Escolher minha música'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'trem');
    await tester.pumpAndSettle();
    expect(find.text('Evidências'), findsNothing);
    await tester.tap(find.text('Trem-Bala'));
    await tester.pumpAndSettle();

    final envio = _enviadas(teste.requisicoes, '$_rota/musica').single;
    expect(jsonDecode(envio.body), {'musicaId': 'm2'});
    expect(find.text('Trem-Bala'), findsOneWidget);
    expect(find.text('Tocar na TV'), findsOneWidget);
  });

  testWidgets('outra música fora da playlist, com o link do YouTube',
      (tester) async {
    final teste = await _abrir(tester, noite: _noite(), respostas: {
      'POST $_rota/musica': (_) => _noite(musicaDaAna: 'Anunciação'),
    });

    await tester.tap(find.text('Escolher minha música'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Outra música'));
    await tester.pumpAndSettle();
    await tester.enterText(_campo('Música'), 'Anunciação');
    await tester.enterText(_campo('Link do YouTube'), 'https://youtu.be/xyz');
    await tester.tap(find.text('Escolher'));
    await tester.pumpAndSettle();

    final envio = _enviadas(teste.requisicoes, '$_rota/musica').single;
    expect(jsonDecode(envio.body),
        {'titulo': 'Anunciação', 'linkDoVideo': 'https://youtu.be/xyz'});
  });

  testWidgets('Tocar na TV abre o vídeo na hora e começa a vez',
      (tester) async {
    final teste = await _abrir(tester,
        noite: _noite(musicaDaAna: 'Evidências', linkDaAna: _video),
        respostas: {
          'POST $_rota/vez': (_) => _noite(
              cantando: _cantando('p1', 'Ana', 'Evidências'), proximo: 'p2'),
        });

    await tester.tap(find.text('Tocar na TV'));
    await tester.pumpAndSettle();

    expect(teste.abertas, [Uri.parse(_video)]);
    expect(_enviadas(teste.requisicoes, '$_rota/vez'), hasLength(1));
    expect(find.text('Você está cantando!'), findsOneWidget);
    expect(find.text('Terminei'), findsOneWidget);
  });

  testWidgets('sem link, Tocar na TV procura o karaokê no YouTube',
      (tester) async {
    final teste =
        await _abrir(tester, noite: _noite(musicaDaAna: 'Tempo Perdido'));

    await tester.tap(find.text('Tocar na TV'));
    await tester.pumpAndSettle();

    final aberta = teste.abertas.single;
    expect(aberta.host, 'www.youtube.com');
    expect(aberta.queryParameters['search_query'], 'Tempo Perdido karaoke');
  });

  testWidgets('quem está cantando termina a vez', (tester) async {
    final teste = await _abrir(tester,
        noite: _noite(
            cantando: _cantando('p1', 'Ana', 'Evidências'), proximo: 'p2'),
        respostas: {'POST $_rota/vez/fim': (_) => _noite(proximo: 'p2')});

    await tester.tap(find.text('Terminei'));
    await tester.pumpAndSettle();

    expect(_enviadas(teste.requisicoes, '$_rota/vez/fim'), hasLength(1));
  });

  testWidgets('a galera vê quem está cantando e o próximo se prepara',
      (tester) async {
    await _abrir(tester,
        noite: _noite(
            musicaDaAna: 'Evidências',
            cantando: _cantando('p2', 'Bia', 'Trem-Bala')));

    expect(find.text('Cantando agora: Bia · Trem-Bala'), findsOneWidget);
    expect(find.text('Você é o próximo'), findsOneWidget);
    expect(find.text('Tocar na TV'), findsOneWidget);
  });

  testWidgets('na roleta, gira, troca a que não conhece e confirma',
      (tester) async {
    var giros = 0;
    final teste =
        await _abrir(tester, noite: _noite(modo: 'Roleta'), respostas: {
      'POST $_rota/roleta': (_) => _noite(
          modo: 'Roleta',
          musicaDaAna: ++giros == 1 ? 'Evidências' : 'Exagerado',
          linkDaAna: _video),
    });

    await tester.tap(find.text('Girar a roleta'));
    await tester.pumpAndSettle();
    expect(find.text('Evidências'), findsOneWidget);
    await tester.tap(find.text('Não conheço, sortear outra'));
    await tester.pumpAndSettle();
    expect(find.text('Exagerado'), findsOneWidget);
    await tester.tap(find.text('Conheço, vou cantar!'));
    await tester.pumpAndSettle();

    expect(_enviadas(teste.requisicoes, '$_rota/roleta'), hasLength(2));
    expect(find.text('Não conheço, sortear outra'), findsNothing);
    expect(find.text('Tocar na TV'), findsOneWidget);
  });
}
