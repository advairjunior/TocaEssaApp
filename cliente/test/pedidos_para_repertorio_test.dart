import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:toca_essa_app/dominio/modelos.dart';
import 'package:toca_essa_app/infraestrutura/api_toca_essa.dart';
import 'package:toca_essa_app/telas/fila_musical_artista.dart';

const _id = '33333333-3333-3333-3333-333333333333';
const _comoJson = {'content-type': 'application/json; charset=utf-8'};

Map<String, Object?> _grupo(String id, String musica, String status,
        {String? artista, int quantidade = 1, String tipo = 'Musica'}) =>
    {
      'pedidoRepresentativoId': id,
      'pedidoIds': [id],
      'apresentacaoId': _id,
      'musica': musica,
      'artista': artista,
      'solicitantes': ['Ana'],
      'quantidadePedidos': quantidade,
      'status': status,
      'criadoEm': '2026-09-10T12:00:00Z',
      'tipo': tipo,
      'tomPreferido': 'E',
      'destinatarioAlo': tipo == 'Alo' ? 'Noivos' : null,
    };

final _grupos = [
  _grupo('g1', 'Garçom', 'NaoConhecemos', artista: 'Reginaldo Rossi'),
  _grupo('g2', 'Evidências', 'Finalizado',
      artista: 'Chitãozinho', quantidade: 3),
  _grupo('g3', 'Trem-Bala', 'Aceito', quantidade: 2),
  _grupo('g4', 'Recado', 'Aceito', tipo: 'Alo'),
  _grupo('g5', 'Desistiu', 'CanceladoPeloPublico'),
];

Future<List<http.Request>> _abrir(WidgetTester tester,
    {StatusApresentacao status = StatusApresentacao.emAndamento}) async {
  final requisicoes = <http.Request>[];
  final barzinho = ['Evidencias'];
  final cliente = MockClient((requisicao) async {
    requisicoes.add(requisicao);
    final caminho = requisicao.url.path;
    if (caminho == '/api/artista/repertorios') {
      return http.Response(
          jsonEncode([
            {
              'id': 'r1',
              'artistaId': 'a1',
              'nome': 'Barzinho',
              'musicas': [
                for (final (i, titulo) in barzinho.indexed)
                  {
                    'id': 'm$i',
                    'repertorioId': 'r1',
                    'titulo': titulo,
                    'ordem': i + 1,
                  },
              ],
            },
          ]),
          200,
          headers: _comoJson);
    }
    if (caminho == '/api/artista/repertorios/musicas') {
      final corpo = jsonDecode(requisicao.body) as Map<String, dynamic>;
      final musicas = corpo['musicas'] as List;
      barzinho.addAll([for (final m in musicas) m['titulo'] as String]);
      return http.Response(
          jsonEncode({
            'repertorio': {
              'id': 'r1',
              'artistaId': 'a1',
              'nome': corpo['nomeNovo'] ?? 'Barzinho',
              'musicas': [],
            },
            'adicionadas': musicas.length,
            'jaEstavam': 0,
          }),
          200,
          headers: _comoJson);
    }
    if (caminho.endsWith('/grupos-pedidos')) {
      return http.Response(jsonEncode(_grupos), 200, headers: _comoJson);
    }
    return http.Response('[]', 200, headers: _comoJson);
  });
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: FilaMusicalArtista(
        api: ApiTocaEssa(cliente: cliente, enderecoBase: 'http://teste')
          ..definirTokenArtista('TOKEN'),
        apresentacao: Apresentacao(
          id: _id,
          nome: 'Bar do Zé',
          data: DateTime(2026, 9, 10),
          local: 'Bar',
          codigo: 'ABC123',
          perfilArtistico: const PerfilArtistico(
              id: '22222222-2222-2222-2222-222222222222',
              nomeArtistico: 'Duo Aurora'),
          pedidosAbertos: true,
          status: status,
          tipo: TipoApresentacao.publica,
        ),
        incorporada: true,
      ),
    ),
  ));
  await tester.pumpAndSettle();
  return requisicoes;
}

Future<void> _abrirEscolha(WidgetTester tester) async {
  final botao = find.text('Adicionar pedidos ao repertório');
  await tester.ensureVisible(botao);
  await tester.tap(botao);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('pedido fora do acervo mostra o selo e vai para o repertório',
      (tester) async {
    final requisicoes = await _abrir(tester);

    expect(find.text('Trem-Bala'), findsOneWidget);
    expect(find.text('Fora do acervo'), findsOneWidget);
    await tester.tap(find.text('Fora do acervo'));
    await tester.pumpAndSettle();
    expect(find.text('Adicionar "Trem-Bala" a…'), findsOneWidget);
    await tester.tap(find.text('Barzinho'));
    await tester.pumpAndSettle();

    final envio = requisicoes
        .singleWhere((r) => r.url.path == '/api/artista/repertorios/musicas');
    // O tom do pedido é o de quem pediu, não o da banda.
    expect(jsonDecode(envio.body), {
      'repertorioId': 'r1',
      'musicas': [
        {'titulo': 'Trem-Bala', 'artista': null, 'tom': null},
      ],
    });
    // Agora está no acervo: o selo some.
    expect(find.text('Fora do acervo'), findsNothing);
  });

  testWidgets('música que já está no acervo não tem selo', (tester) async {
    await _abrir(tester);

    await tester.tap(find.text('Histórico'));
    await tester.pumpAndSettle();

    expect(find.text('Evidências'), findsOneWidget);
    expect(find.text('Garçom'), findsOneWidget);
    // Só o Garçom, que não está em nenhum repertório.
    expect(find.text('Fora do acervo'), findsOneWidget);
  });

  testWidgets('do histórico leva os pedidos, com os de fora já marcados',
      (tester) async {
    final requisicoes = await _abrir(tester);

    await tester.tap(find.text('Histórico'));
    await tester.pumpAndSettle();
    await _abrirEscolha(tester);

    // Mais pedidas primeiro; sem alôs nem cancelados.
    final titulos = ['Evidências', 'Trem-Bala', 'Garçom']
        .map((t) => tester.getTopLeft(find.text(t)).dy)
        .toList();
    expect(titulos, [...titulos]..sort());
    expect(find.text('Recado'), findsNothing);
    expect(find.text('Desistiu'), findsNothing);
    expect(find.text('Chitãozinho · pedida 3x · já em "Barzinho"'),
        findsOneWidget);
    expect(find.text('pedida 2x · fora do acervo'), findsOneWidget);
    expect(find.text('Reginaldo Rossi · Não conhecemos · fora do acervo'),
        findsOneWidget);

    await tester.tap(find.text('Adicionar 2 músicas ao repertório'));
    await tester.pumpAndSettle();
    expect(
        find.widgetWithText(TextField, 'Pedidos · Bar do Zé'), findsOneWidget);
    await tester.tap(find.text('Criar'));
    await tester.pumpAndSettle();

    final envio = requisicoes
        .singleWhere((r) => r.url.path == '/api/artista/repertorios/musicas');
    expect([
      for (final m in (jsonDecode(envio.body) as Map)['musicas'] as List)
        m['titulo']
    ], [
      'Trem-Bala',
      'Garçom'
    ]);
  });

  testWidgets('show encerrado também leva os pedidos ao repertório',
      (tester) async {
    await _abrir(tester, status: StatusApresentacao.encerrada);

    expect(find.text('Memórias musicais'), findsOneWidget);
    await _abrirEscolha(tester);

    expect(find.text('Adicionar 2 músicas ao repertório'), findsOneWidget);
  });
}
