import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:toca_essa_app/dominio/modelos.dart';
import 'package:toca_essa_app/infraestrutura/api_toca_essa.dart';
import 'package:toca_essa_app/infraestrutura/camera_do_app.dart';
import 'package:toca_essa_app/telas/camera_do_cartao.dart';
import 'package:toca_essa_app/telas/estatisticas_da_apresentacao.dart';

import 'apoio/camera_falsa.dart';

const _noiteCheia =
    '{"totalPedidos":40,"aguardando":0,"aceitos":32,"tocados":32,"recusados":3,'
    '"avaliados":12,"mediaAvaliacoes":4.8,"pessoasNoEvento":80,'
    '"pessoasQuePediram":30,"musicasRecusadas":[],'
    '"musicasMaisPedidas":[{"musica":"Evidências","quantidade":5}]}';

const _noiteFraca =
    '{"totalPedidos":2,"aguardando":0,"aceitos":1,"tocados":1,"recusados":1,'
    '"avaliados":1,"mediaAvaliacoes":2.0,"pessoasNoEvento":3,'
    '"pessoasQuePediram":2,"musicasRecusadas":[],'
    '"musicasMaisPedidas":[{"musica":"Evidências","quantidade":1}]}';

const _resenha =
    '{"totalPedidos":9,"aguardando":0,"aceitos":4,"tocados":4,"recusados":3,'
    '"avaliados":3,"mediaAvaliacoes":2.5,"pessoasNoEvento":7,'
    '"pessoasQuePediram":3,'
    '"musicasRecusadas":[{"musica":"Macarena","quantidade":2}],'
    '"musicasMaisPedidas":[{"musica":"Evidências","quantidade":4}]}';

const _galera = '['
    '{"publicoId":"p1","nome":"Bia","pedidos":5,"pedidosTocados":2,'
    '"pedidosRecusados":3,"musicasMaisPedidas":[]},'
    '{"publicoId":"p2","nome":"Caio","pedidos":3,"pedidosTocados":3,'
    '"musicasMaisPedidas":[]},'
    '{"publicoId":"p3","nome":"Edu","pedidos":0,"pedidosTocados":0,'
    '"musicasMaisPedidas":[]}]';

Future<void> _abrir(
  WidgetTester tester, {
  required String estatisticas,
  TipoApresentacao tipo = TipoApresentacao.publica,
  StatusApresentacao status = StatusApresentacao.encerrada,
  String? instagram = 'duoaurora',
  List<http.Request>? requisicoes,
}) async {
  final cliente = MockClient((requisicao) async {
    requisicoes?.add(requisicao);
    if (requisicao.url.path.endsWith('/participantes')) {
      return http.Response(_galera, 200);
    }
    if (requisicao.url.path.endsWith('/foto-retrospectiva')) {
      return http.Response(
        '{"id":"22222222-2222-2222-2222-222222222222","nome":"Noite Acústica",'
        '"data":"2026-10-03","local":"Café Central","codigo":"A1B2C3",'
        '"perfilArtistico":{"id":"11111111-1111-1111-1111-111111111111",'
        '"nomeArtistico":"Duo Aurora"},"pedidosAbertos":false,'
        '"status":"Encerrada","tipo":"${tipo.paraJson}",'
        '"fotoRetrospectivaUrl":"/fotos/selfie.jpg"}',
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    }
    return http.Response(estatisticas, 200);
  });
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: EstatisticasDaApresentacaoTela(
        api: ApiTocaEssa(cliente: cliente, enderecoBase: 'http://teste'),
        apresentacao: Apresentacao(
          id: '22222222-2222-2222-2222-222222222222',
          nome: 'Noite Acústica',
          data: DateTime(2026, 10, 3),
          local: 'Café Central',
          codigo: 'A1B2C3',
          perfilArtistico: PerfilArtistico(
            id: '11111111-1111-1111-1111-111111111111',
            nomeArtistico: 'Duo Aurora',
            instagram: instagram,
          ),
          pedidosAbertos: false,
          status: status,
          tipo: tipo,
        ),
        incorporada: true,
      ),
    ),
  ));
  await tester.pumpAndSettle();
}

Finder _noCartao(String texto) => find.descendant(
      of: find.byKey(const ValueKey('cartao-retrospectiva')),
      matching: find.text(texto),
    );

void main() {
  testWidgets('show público também tem retrospectiva para divulgar',
      (tester) async {
    await _abrir(tester, estatisticas: _noiteCheia);

    expect(find.text('RETROSPECTIVA DO SHOW'), findsOneWidget);
    expect(_noCartao('Duo Aurora'), findsOneWidget);
    expect(_noCartao('@duoaurora'), findsOneWidget);
    expect(_noCartao('80'), findsOneWidget);
    expect(_noCartao('pessoas no app'), findsOneWidget);
    expect(_noCartao('“Evidências” foi a favorita da galera.'), findsOneWidget);
  });

  testWidgets('noite fraca no show não expõe números ruins no cartão',
      (tester) async {
    await _abrir(tester, estatisticas: _noiteFraca, instagram: null);

    expect(_noCartao('3'), findsNothing);
    expect(_noCartao('2.0'), findsNothing);
    expect(_noCartao('pessoas no app'), findsNothing);
    expect(_noCartao('Valeu, Café Central!'), findsOneWidget);
    expect(find.textContaining('@'), findsNothing);
  });

  testWidgets('resenha mostra números completos e prêmios da noite',
      (tester) async {
    await _abrir(tester,
        estatisticas: _resenha, tipo: TipoApresentacao.resenhaEntreAmigos);

    expect(find.text('RETROSPECTIVA DA RESENHA'), findsOneWidget);
    expect(_noCartao('recusados'), findsOneWidget);
    expect(_noCartao('2.5'), findsOneWidget);
    expect(_noCartao('Pidão da noite'), findsOneWidget);
    expect(find.text('Prêmios da noite'), findsOneWidget);
    for (final premio in [
      'Polêmica da noite',
      'Ignorado da noite',
      'Pontaria certeira',
      'Só veio pela resenha',
    ]) {
      await tester.scrollUntilVisible(find.text(premio).last, 200);
      expect(find.text(premio), findsWidgets);
    }
  });

  testWidgets('evento encerrado abre direto na retrospectiva', (tester) async {
    await _abrir(tester, estatisticas: _noiteCheia);

    double topo(Finder alvo) => tester.getTopLeft(alvo).dy;
    expect(topo(find.text('RETROSPECTIVA DO SHOW')),
        lessThan(topo(find.text('Músicas mais pedidas'))));
  });

  testWidgets('foto da retrospectiva oferece selfie nos dois tipos',
      (tester) async {
    for (final tipo in TipoApresentacao.values) {
      await _abrir(tester, estatisticas: _noiteCheia, tipo: tipo);
      final botao = find.text('Adicionar foto ou selfie');
      await tester.ensureVisible(botao);
      await tester.tap(botao);
      await tester.pumpAndSettle();

      expect(find.text('Tirar uma selfie'), findsOneWidget);
      expect(find.text('Fotografar a galera'), findsOneWidget);
      expect(find.text('Escolher da galeria'), findsOneWidget);
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
    }
  });

  testWidgets('selfie abre a câmera do app dentro do cartão e envia a foto',
      (tester) async {
    final camera = CameraFalsa();
    fabricaDeCamera = () => camera;
    addTearDown(() => fabricaDeCamera = CameraDoPlugin.new);
    final requisicoes = <http.Request>[];
    await _abrir(tester, estatisticas: _noiteCheia, requisicoes: requisicoes);

    final botao = find.text('Adicionar foto ou selfie');
    await tester.ensureVisible(botao);
    await tester.tap(botao);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tirar uma selfie'));
    await tester.pumpAndSettle();

    expect(camera.iniciadas, [LenteDaCamera.frontal]);
    expect(
      find.descendant(
          of: find.byType(CameraDoCartao), matching: find.text('Duo Aurora')),
      findsOneWidget,
    );
    await tester.tap(find.byTooltip('Tirar foto'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Usar foto'));
    await tester.pumpAndSettle();

    expect(find.byType(CameraDoCartao), findsNothing);
    expect(
      requisicoes.where((r) =>
          r.method == 'POST' && r.url.path.endsWith('/foto-retrospectiva')),
      hasLength(1),
    );
    expect(find.text('Trocar foto ou selfie'), findsOneWidget);
  });

  testWidgets('fotografar a galera abre a câmera traseira', (tester) async {
    final camera = CameraFalsa();
    fabricaDeCamera = () => camera;
    addTearDown(() => fabricaDeCamera = CameraDoPlugin.new);
    await _abrir(tester,
        estatisticas: _resenha, tipo: TipoApresentacao.resenhaEntreAmigos);

    final botao = find.text('Adicionar foto ou selfie');
    await tester.ensureVisible(botao);
    await tester.tap(botao);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Fotografar a galera'));
    await tester.pumpAndSettle();

    expect(camera.iniciadas, [LenteDaCamera.traseira]);
    expect(
      find.descendant(
          of: find.byType(CameraDoCartao),
          matching: find.text('RETROSPECTIVA DA RESENHA')),
      findsOneWidget,
    );
  });

  group('resumo em texto', () {
    Apresentacao evento(TipoApresentacao tipo) => Apresentacao(
          id: 'a1',
          nome: 'Noite Acústica',
          data: DateTime(2026, 10, 3),
          local: 'Café Central',
          codigo: 'A1B2C3',
          perfilArtistico: const PerfilArtistico(
              id: 'p', nomeArtistico: 'Duo Aurora', instagram: 'duoaurora'),
          pedidosAbertos: false,
          status: StatusApresentacao.encerrada,
          tipo: tipo,
        );

    test('show fraco divulga o artista sem números ruins', () {
      final texto = textoDaRetrospectiva(
        evento(TipoApresentacao.publica),
        EstatisticasDaApresentacao.deJson(jsonDecode(_noiteFraca)),
        const [],
      );

      expect(texto, contains('Duo Aurora'));
      expect(texto, contains('@duoaurora'));
      expect(texto, isNot(contains('2.0')));
      expect(texto, isNot(contains('pedidos')));
    });

    test('show cheio leva os destaques', () {
      final texto = textoDaRetrospectiva(
        evento(TipoApresentacao.publica),
        EstatisticasDaApresentacao.deJson(jsonDecode(_noiteCheia)),
        const [],
      );

      expect(texto, contains('80 pessoas no app'));
      expect(texto, contains('Evidências'));
    });

    test('resenha leva números e prêmios', () {
      final texto = textoDaRetrospectiva(
        evento(TipoApresentacao.resenhaEntreAmigos),
        EstatisticasDaApresentacao.deJson(jsonDecode(_resenha)),
        [
          for (final item in jsonDecode(_galera) as List<dynamic>)
            ParticipanteDaResenha.deJson(item as Map<String, dynamic>)
        ],
      );

      expect(texto, contains('3 recusados'));
      expect(texto, contains('🎤 Pidão da noite: Bia'));
      expect(texto, contains('🚫 Polêmica da noite: Macarena'));
    });
  });

  testWidgets('cartões cabem em celular de 360px', (tester) async {
    addTearDown(tester.view.reset);
    tester.view.devicePixelRatio = 3;
    tester.view.physicalSize = const Size(360, 740) * 3;

    await _abrir(tester, estatisticas: _noiteCheia);
    expect(tester.takeException(), isNull);
    await _abrir(tester,
        estatisticas: _resenha, tipo: TipoApresentacao.resenhaEntreAmigos);
    expect(tester.takeException(), isNull);
  });
}
