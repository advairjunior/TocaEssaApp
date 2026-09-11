import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:toca_essa_app/dominio/modelos.dart';
import 'package:toca_essa_app/infraestrutura/api_toca_essa.dart';
import 'package:toca_essa_app/telas/estatisticas_da_apresentacao.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('envia foto do Perfil Artístico como formulário', () async {
    final cliente = MockClient((requisicao) async {
      expect(requisicao.method, 'POST');
      expect(requisicao.url.path, '/api/perfil-artistico/foto');
      expect(
          requisicao.headers['content-type'], contains('multipart/form-data'));
      return http.Response(
        '{"id":"11111111-1111-1111-1111-111111111111","nomeArtistico":"Duo Aurora","bio":null,"fotoUrl":"/arquivos/perfil.jpg?v=1"}',
        200,
      );
    });

    final perfil = await ApiTocaEssa(
      cliente: cliente,
      enderecoBase: 'http://teste',
    ).enviarFotoPerfil([0xFF, 0xD8, 0xFF, 0xD9], 'foto.jpg');

    expect(perfil.fotoUrl, '/arquivos/perfil.jpg?v=1');
  });

  test('envia foto da retrospectiva como formulário autenticado', () async {
    final cliente = MockClient((requisicao) async {
      expect(requisicao.method, 'POST');
      expect(requisicao.url.path,
          '/api/apresentacoes/22222222-2222-2222-2222-222222222222/foto-retrospectiva');
      expect(requisicao.headers['authorization'], 'Bearer TOKEN');
      expect(
          requisicao.headers['content-type'], contains('multipart/form-data'));
      return http.Response(
        '{"id":"22222222-2222-2222-2222-222222222222","nome":"Resenha","data":"2026-09-03","local":"Casa","codigo":"A1B2C3","perfilArtistico":{"id":"11111111-1111-1111-1111-111111111111","nomeArtistico":"Duo Aurora"},"pedidosAbertos":true,"status":"EmAndamento","tipo":"ResenhaEntreAmigos","fotoRetrospectivaUrl":"/arquivos/resenha.jpg?v=1"}',
        200,
      );
    });
    final api = ApiTocaEssa(cliente: cliente, enderecoBase: 'http://teste')
      ..definirTokenArtista('TOKEN');

    final apresentacao = await api.enviarFotoRetrospectiva(
      '22222222-2222-2222-2222-222222222222',
      [0xFF, 0xD8, 0xFF, 0xD9],
      'galera.jpg',
    );

    expect(apresentacao.fotoRetrospectivaUrl, '/arquivos/resenha.jpg?v=1');
  });

  test('envia e interpreta as opções de participação da resenha', () async {
    final cliente = MockClient((requisicao) async {
      expect(requisicao.method, 'POST');
      expect(requisicao.body, contains('"formaParticipacao":"EuCanto"'));
      expect(requisicao.body, contains('"tomPreferido":"G"'));
      expect(requisicao.body, contains('"recado":"Essa é para a galera"'));
      return http.Response(
        '{"id":"33333333-3333-3333-3333-333333333333","apresentacaoId":"22222222-2222-2222-2222-222222222222","musica":"Evidências","artista":"Chitãozinho & Xororó","nomeSolicitante":"Ana","status":"Aguardando","posicao":null,"criadoEm":"2026-09-03T20:00:00Z","formaParticipacao":"EuCanto","tomPreferido":"G","recado":"Essa é para a galera"}',
        201,
      );
    });

    final pedido = await ApiTocaEssa(
      cliente: cliente,
      enderecoBase: 'http://teste',
    ).criarPedidoMusical(
      'A1B2C3',
      'Evidências',
      'Chitãozinho & Xororó',
      'Ana',
      formaParticipacao: FormaParticipacaoPedido.euCanto,
      tomPreferido: 'G',
      recado: 'Essa é para a galera',
    );

    expect(pedido.formaParticipacao, FormaParticipacaoPedido.euCanto);
    expect(pedido.tomPreferido, 'G');
    expect(pedido.recado, 'Essa é para a galera');
  });

  testWidgets('artista visualiza estatísticas e retrospectiva da Resenha',
      (tester) async {
    final cliente = MockClient((requisicao) async {
      if (requisicao.url.path.endsWith('/participantes')) {
        return http.Response(
          '[{"publicoId":"44444444-4444-4444-4444-444444444444","nome":"Ana Souza","fotoUrl":null,"pedidos":5,"pedidosTocados":3,"mediaAvaliacoes":4.5,"musicasMaisPedidas":[{"musica":"Evidências","quantidade":2}]}]',
          200,
        );
      }
      return http.Response(
        '{"totalPedidos":8,"aguardando":2,"aceitos":5,"tocados":4,"recusados":1,"avaliados":3,"mediaAvaliacoes":4.7,"musicasMaisPedidas":[{"musica":"Evidências","quantidade":3}]}',
        200,
      );
    });
    final apresentacao = Apresentacao(
      id: '22222222-2222-2222-2222-222222222222',
      nome: 'Noite Acústica',
      data: DateTime(2026, 9, 3),
      local: 'Café Central',
      codigo: 'A1B2C3',
      perfilArtistico: const PerfilArtistico(
        id: '11111111-1111-1111-1111-111111111111',
        nomeArtistico: 'Duo Aurora',
      ),
      pedidosAbertos: true,
      status: StatusApresentacao.emAndamento,
      tipo: TipoApresentacao.resenhaEntreAmigos,
    );

    await tester.pumpWidget(MaterialApp(
      home: EstatisticasDaApresentacaoTela(
        api: ApiTocaEssa(cliente: cliente, enderecoBase: 'http://teste'),
        apresentacao: apresentacao,
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('4.7'), findsWidgets);
    expect(find.text('8'), findsWidgets);
    expect(find.text('Evidências'), findsWidgets);
    expect(find.text('3x'), findsOneWidget);
    expect(find.text('RETROSPECTIVA DA RESENHA'), findsOneWidget);
    expect(find.text('Galera da resenha'), findsOneWidget);
    expect(find.text('Ana Souza'), findsOneWidget);
    expect(find.text('Salvar cartão em PNG'), findsOneWidget);
    final copiar = find.text('Copiar resumo em texto');
    await tester.ensureVisible(copiar);
    expect(copiar, findsOneWidget);
  });

}
