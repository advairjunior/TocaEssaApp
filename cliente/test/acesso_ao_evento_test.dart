import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:toca_essa_app/dominio/modelos.dart';
import 'package:toca_essa_app/infraestrutura/api_toca_essa.dart';
import 'package:toca_essa_app/telas/area_do_publico.dart';

const _apresentacaoJson =
    '{"id":"22222222-2222-2222-2222-222222222222","nome":"Noite Acústica","data":"2026-09-03","local":"Café Central","codigo":"A1B2C3","perfilArtistico":{"id":"11111111-1111-1111-1111-111111111111","nomeArtistico":"Duo Aurora","bio":null},"pedidosAbertos":true,"status":"EmAndamento","tipo":"Publica"}';

Future<List<http.Request>> _abrirEvento(
  WidgetTester tester, {
  int respostaDoAcesso = 204,
}) async {
  final requisicoes = <http.Request>[];
  final cliente = MockClient((requisicao) async {
    requisicoes.add(requisicao);
    if (requisicao.url.path.endsWith('/acessos')) {
      return http.Response('', respostaDoAcesso);
    }
    if (requisicao.url.path.endsWith('/fila')) return http.Response('[]', 200);
    return http.Response(_apresentacaoJson, 200);
  });
  await tester.pumpWidget(MaterialApp(
    home: AreaDoPublico(
      api: ApiTocaEssa(cliente: cliente, enderecoBase: 'http://teste'),
      codigoInicial: 'A1B2C3',
    ),
  ));
  await tester.pumpAndSettle();
  return requisicoes;
}

void main() {
  testWidgets('abrir o evento registra o aparelho com o identificador salvo',
      (tester) async {
    SharedPreferences.setMockInitialValues(
        {'identificador_avaliador': 'aparelho-da-bia'});

    final requisicoes = await _abrirEvento(tester);

    final acessos = requisicoes
        .where((item) =>
            item.method == 'POST' && item.url.path.endsWith('/acessos'))
        .toList();
    expect(acessos, hasLength(1));
    expect(acessos.single.url.path,
        '/api/publico/apresentacoes/A1B2C3/acessos');
    expect(jsonDecode(acessos.single.body), {'visitante': 'aparelho-da-bia'});
  });

  testWidgets('falha ao registrar o acesso não atrapalha o público',
      (tester) async {
    SharedPreferences.setMockInitialValues({});

    await _abrirEvento(tester, respostaDoAcesso: 500);

    expect(tester.takeException(), isNull);
    expect(find.text('Duo Aurora'), findsWidgets);
  });

  test('estatísticas e participante leem os campos novos da retrospectiva',
      () {
    final estatisticas = EstatisticasDaApresentacao.deJson(jsonDecode(
        '{"totalPedidos":8,"aguardando":0,"aceitos":5,"tocados":5,"recusados":2,'
        '"avaliados":3,"mediaAvaliacoes":4.7,"musicasMaisPedidas":[],'
        '"pessoasNoEvento":42,"pessoasQuePediram":12,'
        '"musicasRecusadas":[{"musica":"Macarena","quantidade":2}]}'));
    final antigas = EstatisticasDaApresentacao.deJson(jsonDecode(
        '{"totalPedidos":0,"aguardando":0,"aceitos":0,"tocados":0,'
        '"recusados":0,"avaliados":0,"musicasMaisPedidas":[]}'));
    final participante = ParticipanteDaResenha.deJson(jsonDecode(
        '{"publicoId":"p1","nome":"Bia","pedidos":0,"pedidosTocados":0,'
        '"musicasMaisPedidas":[],"pedidosRecusados":2}'));

    expect(estatisticas.pessoasNoEvento, 42);
    expect(estatisticas.pessoasQuePediram, 12);
    expect(estatisticas.musicasRecusadas.single.musica, 'Macarena');
    expect(antigas.pessoasNoEvento, 0);
    expect(antigas.musicasRecusadas, isEmpty);
    expect(participante.pedidosRecusados, 2);
  });
}
