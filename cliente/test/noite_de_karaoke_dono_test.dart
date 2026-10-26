import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:toca_essa_app/dominio/modelos.dart';
import 'package:toca_essa_app/infraestrutura/api_toca_essa.dart';
import 'package:toca_essa_app/telas/noite_de_karaoke_dono.dart';

const _json = {'content-type': 'application/json; charset=utf-8'};
const _rota = '/api/apresentacoes/k1/karaoke';

Map<String, dynamic> _pessoa(String id, String nome) =>
    {'publicoId': id, 'nome': nome, 'fotoUrl': null};

Map<String, dynamic> _noite({
  bool sorteada = false,
  bool podeSortearDeNovo = true,
  String modo = 'Livre',
  List<Map<String, dynamic>>? ordem,
  List<Map<String, dynamic>> foraDaOrdem = const [],
}) =>
    {
      'repertorioId': 'r1',
      'modo': modo,
      'sorteada': sorteada,
      'podeSortearDeNovo': podeSortearDeNovo,
      'ordem': ordem ?? [_pessoa('p1', 'Ana'), _pessoa('p2', 'Bia')],
      'foraDaOrdem': foraDaOrdem,
    };

final _repertorios = [
  {
    'id': 'r1',
    'artistaId': 'a1',
    'nome': 'Karaokê',
    'musicas': [
      {
        'id': 'm1',
        'repertorioId': 'r1',
        'titulo': 'Evidências',
        'ordem': 1,
        'linkDoVideo': 'https://www.youtube.com/watch?v=abc'
      },
    ],
  },
  {'id': 'r2', 'artistaId': 'a1', 'nome': 'Sertanejo', 'musicas': []},
];

final _noiteDeSexta = Apresentacao.deJson({
  'id': 'k1',
  'nome': 'Karaokê de sexta',
  'data': '2026-10-30',
  'local': 'Casa',
  'codigo': 'KARA01',
  'perfilArtistico': {'id': 'pa', 'nomeArtistico': 'Advair'},
  'tipo': 'Karaoke',
});

Future<List<http.Request>> _abrir(WidgetTester tester,
    {Map<String, http.Response Function(http.Request)> respostas =
        const {}}) async {
  final requisicoes = <http.Request>[];
  final cliente = MockClient((requisicao) async {
    requisicoes.add(requisicao);
    final chave = '${requisicao.method} ${requisicao.url.path}';
    if (respostas[chave] case final resposta?) return resposta(requisicao);
    if (requisicao.url.path == '/api/artista/repertorios') {
      return http.Response(jsonEncode(_repertorios), 200, headers: _json);
    }
    return http.Response(jsonEncode(_noite()), 200, headers: _json);
  });
  final api = ApiTocaEssa(cliente: cliente, enderecoBase: 'http://teste')
    ..definirTokenArtista('TOKEN');
  await tester.pumpWidget(MaterialApp(
      home: Scaffold(
          body: NoiteDeKaraokeDoDono(api: api, apresentacao: _noiteDeSexta))));
  await tester.pumpAndSettle();
  return requisicoes;
}

http.Response Function(http.Request) _devolver(Map<String, dynamic> noite) =>
    (_) => http.Response(jsonEncode(noite), 200, headers: _json);

void main() {
  testWidgets('antes do sorteio mostra a galera, o modo e a playlist',
      (tester) async {
    await _abrir(tester);

    expect(find.text('Na galera · 2'), findsOneWidget);
    expect(find.text('Ana'), findsOneWidget);
    expect(find.text('Bia'), findsOneWidget);
    expect(find.text('Karaokê · 1 música'), findsOneWidget);
    expect(find.text('Sortear a ordem'), findsOneWidget);
  });

  testWidgets('sortear mostra a ordem da noite e o sortear de novo',
      (tester) async {
    final requisicoes = await _abrir(tester, respostas: {
      'POST $_rota/sorteio': _devolver(_noite(
          sorteada: true, ordem: [_pessoa('p2', 'Bia'), _pessoa('p1', 'Ana')])),
    });

    await tester.tap(find.text('Sortear a ordem'));
    await tester.pumpAndSettle();

    expect(
        requisicoes.where((r) => r.url.path == '$_rota/sorteio'), hasLength(1));
    expect(find.text('Ordem da noite'), findsOneWidget);
    expect(find.text('1º'), findsOneWidget);
    expect(find.text('Sortear de novo'), findsOneWidget);
    expect(tester.getTopLeft(find.text('Bia')).dy,
        lessThan(tester.getTopLeft(find.text('Ana')).dy));
  });

  testWidgets('depois que alguém cantou não dá para sortear de novo',
      (tester) async {
    await _abrir(tester, respostas: {
      'GET $_rota': _devolver(_noite(sorteada: true, podeSortearDeNovo: false)),
    });

    expect(find.text('Sortear de novo'), findsNothing);
    expect(find.text('Sortear a ordem'), findsNothing);
  });

  testWidgets('escolher a roleta guarda o modo com a playlist', (tester) async {
    final requisicoes = await _abrir(tester, respostas: {
      'PUT $_rota/configuracao': _devolver(_noite(modo: 'Roleta')),
    });

    await tester.tap(find.text('Roleta'));
    await tester.pumpAndSettle();

    final envio =
        requisicoes.singleWhere((r) => r.url.path == '$_rota/configuracao');
    expect(jsonDecode(envio.body), {'repertorioId': 'r1', 'modo': 'Roleta'});
    expect(find.textContaining('O app sorteia a música'), findsOneWidget);
  });

  testWidgets('trocar a playlist da noite', (tester) async {
    final requisicoes = await _abrir(tester);

    await tester.tap(find.text('Karaokê · 1 música'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sertanejo').last);
    await tester.pumpAndSettle();

    final envio =
        requisicoes.singleWhere((r) => r.url.path == '$_rota/configuracao');
    expect(jsonDecode(envio.body), {'repertorioId': 'r2', 'modo': 'Livre'});
  });

  testWidgets('passar a vez, tirar e devolver quem está na noite',
      (tester) async {
    final requisicoes = await _abrir(tester, respostas: {
      'DELETE $_rota/ordem/p1': _devolver(_noite(
          ordem: [_pessoa('p2', 'Bia')], foraDaOrdem: [_pessoa('p1', 'Ana')])),
    });

    await tester.tap(find.byTooltip('Opções de Ana'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Passar a vez'));
    await tester.pumpAndSettle();
    expect(
        requisicoes.where((r) =>
            r.method == 'POST' && r.url.path == '$_rota/ordem/p1/passar'),
        hasLength(1));

    await tester.tap(find.byTooltip('Opções de Ana'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tirar da ordem'));
    await tester.pumpAndSettle();
    expect(find.text('Fora da ordem'), findsOneWidget);

    await tester.tap(find.text('Devolver'));
    await tester.pumpAndSettle();
    expect(
        requisicoes.where(
            (r) => r.method == 'POST' && r.url.path == '$_rota/ordem/p1'),
        hasLength(1));
  });

  testWidgets('sem ninguém na galera explica como a galera entra',
      (tester) async {
    await _abrir(tester, respostas: {
      'GET $_rota': _devolver(_noite(ordem: [])),
    });

    expect(find.textContaining('QR'), findsOneWidget);
    expect(find.text('Sortear a ordem'), findsNothing);
  });
}
