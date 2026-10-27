import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:toca_essa_app/dominio/modelos.dart';
import 'package:toca_essa_app/infraestrutura/api_toca_essa.dart';
import 'package:toca_essa_app/telas/noite_de_karaoke_galera.dart';

const _json = {'content-type': 'application/json; charset=utf-8'};

Map<String, dynamic> _pessoa(String id, String nome) =>
    {'publicoId': id, 'nome': nome, 'fotoUrl': null};

Map<String, dynamic> _noite(
        {bool sorteada = true, List<Map<String, dynamic>> placar = const []}) =>
    {
      'placar': placar,
      'vozDaNoite': placar.isEmpty ? null : placar.first['publicoId'],
      'repertorioId': 'r1',
      'modo': 'Livre',
      'sorteada': sorteada,
      'podeSortearDeNovo': true,
      'ordem': [
        _pessoa('p2', 'Bia'),
        _pessoa('p1', 'Ana'),
        _pessoa('p3', 'Caio'),
      ],
      'foraDaOrdem': [],
    };

Future<List<http.Request>> _abrir(WidgetTester tester,
    {String? token = 'TOKEN-ANA',
    bool sorteada = true,
    List<Map<String, dynamic>> placar = const [],
    String status = 'Agendada'}) async {
  SharedPreferences.setMockInitialValues(
      {if (token != null) 'token_do_publico': token});
  final requisicoes = <http.Request>[];
  final cliente = MockClient((requisicao) async {
    requisicoes.add(requisicao);
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
      '/api/publico/apresentacoes/KARA01/karaoke' => http.Response(
          jsonEncode(_noite(sorteada: sorteada, placar: placar)), 200,
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
            'status': status,
          }),
          200,
          headers: _json),
      _ => http.Response('', 204),
    };
  });
  final api = ApiTocaEssa(cliente: cliente, enderecoBase: 'http://teste');
  await tester.pumpWidget(
      MaterialApp(home: NoiteDeKaraokeDaGalera(api: api, codigo: 'KARA01')));
  await tester.pumpAndSettle();
  return requisicoes;
}

void main() {
  test('o tipo Karaokê vem do servidor e volta igual', () {
    expect(TipoApresentacao.deJson('Karaoke'), TipoApresentacao.karaoke);
    expect(TipoApresentacao.karaoke.paraJson, 'Karaoke');
    expect(TipoApresentacao.karaoke.rotuloCurto, 'Karaokê');
  });

  testWidgets('com conta entra na galera e vê a sua posição na ordem',
      (tester) async {
    final requisicoes = await _abrir(tester);

    final entrada = requisicoes.singleWhere(
        (r) => r.url.path == '/api/publico/apresentacoes/KARA01/participacoes');
    expect(entrada.headers['Authorization'], 'Bearer TOKEN-ANA');
    expect(find.text('Karaokê de sexta'), findsOneWidget);
    expect(find.text('Você é o 2º · falta 1 antes de você'), findsOneWidget);
    expect(find.text('Ordem da noite'), findsOneWidget);
    expect(find.text('Bia'), findsOneWidget);
    expect(find.text('Caio'), findsOneWidget);
  });

  testWidgets('antes do sorteio avisa que a ordem ainda vai ser sorteada',
      (tester) async {
    await _abrir(tester, sorteada: false);

    expect(find.text('Você está na galera'), findsOneWidget);
    expect(find.textContaining('ainda vai sortear'), findsOneWidget);
  });

  testWidgets('sem conta pede para entrar antes de participar', (tester) async {
    final requisicoes = await _abrir(tester, token: null);

    expect(find.text('Entrar para participar'), findsOneWidget);
    expect(requisicoes.where((r) => r.url.path.endsWith('/participacoes')),
        isEmpty);
  });
  testWidgets('quem já cantou ganha o cartão para compartilhar',
      (tester) async {
    await _abrir(tester, placar: _placar, status: 'Encerrada');
    await tester.scrollUntilVisible(find.text('Compartilhar imagem'), 300);

    expect(find.text('Meu cartão do karaokê'), findsOneWidget);
    expect(find.text('VOZ DA NOITE'), findsOneWidget);
    expect(find.text('Tirar uma selfie'), findsOneWidget);
  });

  testWidgets('quem ainda não cantou não vê o cartão', (tester) async {
    await _abrir(tester);

    expect(find.text('Meu cartão do karaokê'), findsNothing);
  });
}

const _placar = [
  {
    'publicoId': 'p1',
    'nome': 'Ana',
    'musicas': 1,
    'media': 4.8,
    'votos': 3,
    'melhorMusica': 'Evidências'
  },
];
