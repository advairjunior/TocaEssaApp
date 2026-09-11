import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:toca_essa_app/dominio/modelos.dart';
import 'package:toca_essa_app/infraestrutura/api_toca_essa.dart';
import 'package:toca_essa_app/main.dart';
import 'package:toca_essa_app/telas/area_do_publico.dart';
import 'package:toca_essa_app/telas/estatisticas_da_apresentacao.dart';

const _contaArtistaJson =
    '{"id":"aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa","nome":"Ana","email":"ana@artista.com","criadoEm":"2026-09-03T20:00:00Z"}';

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

  testWidgets('exibe as entradas pública e do artista', (tester) async {
    await tester.pumpWidget(const TocaEssaApp());

    expect(find.text('Área do Público'), findsOneWidget);
    expect(find.text('Acessar Painel do Artista'), findsOneWidget);
    expect(find.text('Código da Apresentação'), findsOneWidget);
    expect(find.text('Feito por Advair'), findsOneWidget);
  });

  testWidgets('artista cria conta e acessa painel protegido', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final cliente = MockClient((requisicao) async {
      if (requisicao.url.path == '/api/artista/contas') {
        expect(requisicao.body, contains('ana@artista.com'));
        return http.Response(
          '{"conta":$_contaArtistaJson,"token":"TOKEN-ARTISTA"}',
          201,
        );
      }
      if (requisicao.url.path.endsWith('/perfil-artistico')) {
        expect(requisicao.headers['authorization'], 'Bearer TOKEN-ARTISTA');
        return http.Response(
          '{"id":"11111111-1111-1111-1111-111111111111","nomeArtistico":"Duo Aurora","bio":null}',
          200,
        );
      }
      return http.Response('[]', 200);
    });
    await tester.pumpWidget(TocaEssaApp(
      api: ApiTocaEssa(cliente: cliente, enderecoBase: 'http://teste'),
    ));
    final acessarPainel = find.text('Acessar Painel do Artista');
    await tester.ensureVisible(acessarPainel);
    await tester.tap(acessarPainel);
    await tester.pumpAndSettle();

    expect(
      find.image(const AssetImage('assets/fundos/bastidores.png')),
      findsOneWidget,
    );
    expect(find.text('Entre no seu painel'), findsOneWidget);
    await tester.tap(find.text('Primeiro acesso? Criar conta'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Seu nome'), 'Ana');
    await tester.enterText(
        find.widgetWithText(TextField, 'E-mail'), 'ana@artista.com');
    await tester.enterText(find.widgetWithText(TextField, 'Senha'), 'senha123');
    await tester.tap(find.text('Criar conta e entrar'));
    await tester.pumpAndSettle();

    expect(find.text('Painel do Artista'), findsOneWidget);
    expect(find.text('Nenhuma Apresentação ainda'), findsOneWidget);
    final preferencias = await SharedPreferences.getInstance();
    expect(preferencias.getString('token_do_artista'), 'TOKEN-ARTISTA');
  });

  testWidgets('painel autenticado preserva bastidores e navegação',
      (tester) async {
    SharedPreferences.setMockInitialValues({'token_do_artista': 'TOKEN'});
    final cliente = MockClient((requisicao) async {
      if (requisicao.url.path == '/api/artista/conta') {
        return http.Response(_contaArtistaJson, 200);
      }
      if (requisicao.url.path.endsWith('/perfil-artistico')) {
        return http.Response(
          '{"id":"11111111-1111-1111-1111-111111111111","nomeArtistico":"Duo Aurora","bio":null}',
          200,
        );
      }
      return http.Response('[]', 200);
    });
    await tester.pumpWidget(TocaEssaApp(
      api: ApiTocaEssa(cliente: cliente, enderecoBase: 'http://teste'),
    ));
    final acessarPainel = find.text('Acessar Painel do Artista');
    await tester.ensureVisible(acessarPainel);
    await tester.tap(acessarPainel);
    await tester.pumpAndSettle();

    expect(
      find.image(const AssetImage('assets/fundos/bastidores.png')),
      findsOneWidget,
    );
    expect(find.text('Apresentações'), findsOneWidget);
    expect(find.text('Criar'), findsOneWidget);
    expect(find.text('Perfil geral'), findsOneWidget);
  });

  testWidgets('Painel separa Apresentações, Fila, Estatísticas e Perfil',
      (tester) async {
    SharedPreferences.setMockInitialValues({'token_do_artista': 'TOKEN'});
    final cliente = MockClient((requisicao) async {
      if (requisicao.url.path == '/api/artista/conta') {
        expect(requisicao.headers['authorization'], 'Bearer TOKEN');
        return http.Response(_contaArtistaJson, 200);
      }
      if (requisicao.url.path.endsWith('/perfil-artistico')) {
        return http.Response(
          '{"id":"11111111-1111-1111-1111-111111111111","nomeArtistico":"Duo Aurora","bio":"Voz e violão"}',
          200,
        );
      }
      return http.Response('[]', 200);
    });
    await tester.pumpWidget(TocaEssaApp(
      api: ApiTocaEssa(cliente: cliente, enderecoBase: 'http://teste'),
    ));
    final acessarPainel = find.text('Acessar Painel do Artista');
    await tester.ensureVisible(acessarPainel);
    await tester.tap(acessarPainel);
    await tester.pumpAndSettle();

    expect(find.text('Nenhuma Apresentação ainda'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Nome artístico'), findsNothing);
    expect(find.text('Fila'), findsNothing);
    expect(find.text('Galera'), findsNothing);
    await tester.tap(find.text('Criar').last);
    await tester.pumpAndSettle();
    expect(find.text('Nova Apresentação'), findsOneWidget);
    expect(find.text('Nenhuma Apresentação ainda'), findsNothing);
    await tester.tap(find.text('Perfil geral').last);
    await tester.pumpAndSettle();

    expect(find.text('Perfil Artístico'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Nome artístico'), findsOneWidget);
    expect(find.text('Estatísticas'), findsWidgets);
    expect(find.text('Conquistas'), findsOneWidget);
    expect(find.text('Nova Apresentação'), findsNothing);
  });

  testWidgets('artista acompanha a Galera e participa da resenha',
      (tester) async {
    SharedPreferences.setMockInitialValues({'token_do_artista': 'TOKEN'});
    final cliente = MockClient((requisicao) async {
      if (requisicao.url.path == '/api/artista/conta') {
        return http.Response(_contaArtistaJson, 200);
      }
      if (requisicao.url.path.endsWith('/perfil-artistico')) {
        return http.Response(
          '{"id":"11111111-1111-1111-1111-111111111111","nomeArtistico":"Duo Aurora","bio":null}',
          200,
        );
      }
      if (requisicao.url.path.endsWith('/participantes')) {
        return http.Response(
          '[{"publicoId":"11111111-1111-1111-1111-111111111111","nome":"Duo Aurora","fotoUrl":null,"pedidos":0,"pedidosTocados":0,"mediaAvaliacoes":null,"musicasMaisPedidas":[],"ehArtista":true},{"publicoId":"44444444-4444-4444-4444-444444444444","nome":"Ana","fotoUrl":null,"pedidos":0,"pedidosTocados":0,"mediaAvaliacoes":null,"musicasMaisPedidas":[],"ehArtista":false}]',
          200,
        );
      }
      return http.Response(
        '[{"id":"22222222-2222-2222-2222-222222222222","nome":"Resenha de sexta","data":"2026-09-03","local":"Casa da Ana","codigo":"A1B2C3","perfilArtistico":{"id":"11111111-1111-1111-1111-111111111111","nomeArtistico":"Duo Aurora"},"pedidosAbertos":true,"status":"EmAndamento","tipo":"ResenhaEntreAmigos"}]',
        200,
      );
    });
    await tester.pumpWidget(TocaEssaApp(
      api: ApiTocaEssa(cliente: cliente, enderecoBase: 'http://teste'),
    ));
    final acessarPainel = find.text('Acessar Painel do Artista');
    await tester.ensureVisible(acessarPainel);
    await tester.tap(acessarPainel);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Resenha de sexta'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Galera').last);
    await tester.pumpAndSettle();

    expect(find.text('Galera da resenha'), findsOneWidget);
    expect(find.text('Duo Aurora'), findsWidgets);
    expect(find.text('Artista'), findsOneWidget);
    expect(find.text('Ana'), findsOneWidget);
    expect(find.text('0 pedidos · 0 tocados'), findsOneWidget);
  });

  testWidgets('Painel do Artista separa eventos por momento', (tester) async {
    SharedPreferences.setMockInitialValues({'token_do_artista': 'TOKEN'});
    final cliente = MockClient((requisicao) async {
      if (requisicao.url.path == '/api/artista/conta') {
        return http.Response(_contaArtistaJson, 200);
      }
      if (requisicao.url.path.endsWith('/perfil-artistico')) {
        return http.Response(
          '{"id":"11111111-1111-1111-1111-111111111111","nomeArtistico":"Duo Aurora","bio":null}',
          200,
        );
      }
      return http.Response(
        '[{"id":"20000000-0000-0000-0000-000000000001","nome":"Show de hoje","data":"2026-09-04","local":"Praça","codigo":"HOJE01","perfilArtistico":{"id":"11111111-1111-1111-1111-111111111111","nomeArtistico":"Duo Aurora"},"pedidosAbertos":true,"status":"EmAndamento"},{"id":"20000000-0000-0000-0000-000000000002","nome":"Show de sábado","data":"2026-09-05","local":"Bar","codigo":"SABADO","perfilArtistico":{"id":"11111111-1111-1111-1111-111111111111","nomeArtistico":"Duo Aurora"},"pedidosAbertos":true,"status":"Agendada"},{"id":"20000000-0000-0000-0000-000000000003","nome":"Show anterior","data":"2026-09-01","local":"Clube","codigo":"ANTES1","perfilArtistico":{"id":"11111111-1111-1111-1111-111111111111","nomeArtistico":"Duo Aurora"},"pedidosAbertos":false,"status":"Encerrada"}]',
        200,
      );
    });

    await tester.pumpWidget(TocaEssaApp(
      api: ApiTocaEssa(cliente: cliente, enderecoBase: 'http://teste'),
    ));
    final acessarPainel = find.text('Acessar Painel do Artista');
    await tester.ensureVisible(acessarPainel);
    await tester.tap(acessarPainel);
    await tester.pumpAndSettle();

    expect(find.text('Show de hoje'), findsOneWidget);
    expect(find.text('Show de sábado'), findsNothing);
    await tester.tap(find.text('Agendadas'));
    await tester.pumpAndSettle();
    expect(find.text('Show de sábado'), findsOneWidget);
    expect(find.text('Show de hoje'), findsNothing);
    await tester.tap(find.text('Histórico'));
    await tester.pumpAndSettle();
    expect(find.text('Show anterior'), findsOneWidget);
    expect(find.text('Ver estatísticas'), findsNothing);
    expect(find.text('Estatísticas'), findsNothing);
  });

  testWidgets('mostra QR Code depois de criar apresentação', (tester) async {
    SharedPreferences.setMockInitialValues({'token_do_artista': 'TOKEN'});
    final cliente = MockClient((requisicao) async {
      if (requisicao.url.path == '/api/artista/conta') {
        return http.Response(_contaArtistaJson, 200);
      }
      if (requisicao.url.path.endsWith('/perfil-artistico')) {
        return http.Response(
          '{"id":"11111111-1111-1111-1111-111111111111","nomeArtistico":"Duo Aurora","bio":"Voz e violão"}',
          200,
        );
      }
      if (requisicao.method == 'GET') return http.Response('[]', 200);
      expect(requisicao.body, contains('"tipo":"ResenhaEntreAmigos"'));
      return http.Response(
        '{"apresentacao":{"id":"22222222-2222-2222-2222-222222222222","nome":"Noite Acústica","data":"2026-09-03","local":"Café Central","codigo":"A1B2C3","perfilArtistico":{"id":"11111111-1111-1111-1111-111111111111","nomeArtistico":"Duo Aurora","bio":"Voz e violão"},"pedidosAbertos":true,"tipo":"ResenhaEntreAmigos"},"linkPublico":"http://localhost:5173/#/publico/A1B2C3"}',
        201,
      );
    });
    final api = ApiTocaEssa(cliente: cliente, enderecoBase: 'http://teste');

    await tester.pumpWidget(TocaEssaApp(api: api));
    final acessarPainel = find.text('Acessar Painel do Artista');
    await tester.ensureVisible(acessarPainel);
    await tester.tap(acessarPainel);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Criar').last);
    await tester.pumpAndSettle();
    final tipoPublico = find.text('Apresentação Pública');
    await tester.ensureVisible(tipoPublico);
    await tester.tap(tipoPublico);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Resenha entre Amigos').last);
    await tester.pumpAndSettle();
    await tester.enterText(
        find.widgetWithText(TextField, 'Nome da apresentação'),
        'Noite Acústica');
    await tester.enterText(
        find.widgetWithText(TextField, 'Local'), 'Café Central');
    final criar = find.text('Criar Apresentação');
    await tester.ensureVisible(criar);
    await tester.tap(criar);
    await tester.pumpAndSettle();

    expect(find.text('Apresentação criada!'), findsOneWidget);
    expect(find.text('A1B2C3'), findsWidgets);
    expect(find.text('Concluir'), findsOneWidget);
  });

  testWidgets('artista edita uma apresentação existente', (tester) async {
    SharedPreferences.setMockInitialValues({'token_do_artista': 'TOKEN'});
    final cliente = MockClient((requisicao) async {
      if (requisicao.url.path == '/api/artista/conta') {
        return http.Response(_contaArtistaJson, 200);
      }
      if (requisicao.url.path.endsWith('/perfil-artistico')) {
        return http.Response(
          '{"id":"11111111-1111-1111-1111-111111111111","nomeArtistico":"Duo Aurora","bio":"Voz e violão"}',
          200,
        );
      }
      if (requisicao.method == 'GET') {
        return http.Response(
          '[{"id":"22222222-2222-2222-2222-222222222222","nome":"Noite Acústica","data":"2026-09-03","local":"Café Central","codigo":"A1B2C3","perfilArtistico":{"id":"11111111-1111-1111-1111-111111111111","nomeArtistico":"Duo Aurora","bio":"Voz e violão"},"pedidosAbertos":true}]',
          200,
        );
      }
      return http.Response(
        '{"id":"22222222-2222-2222-2222-222222222222","nome":"Especial de Sábado","data":"2026-09-03","local":"Praça Central","codigo":"A1B2C3","perfilArtistico":{"id":"11111111-1111-1111-1111-111111111111","nomeArtistico":"Duo Aurora","bio":"Voz e violão"},"pedidosAbertos":true}',
        200,
      );
    });

    await tester.pumpWidget(
      TocaEssaApp(
          api: ApiTocaEssa(cliente: cliente, enderecoBase: 'http://teste')),
    );
    final acessarPainel = find.text('Acessar Painel do Artista');
    await tester.ensureVisible(acessarPainel);
    await tester.tap(acessarPainel);
    await tester.pumpAndSettle();
    final opcoes = find.byTooltip('Opções da Apresentação');
    await tester.tap(find.text('Noite Acústica'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Apresentação').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(opcoes);
    await tester.tap(opcoes);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Editar'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, 'Nome da apresentação'),
      'Especial de Sábado',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Local'),
      'Praça Central',
    );
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();

    expect(find.text('Especial de Sábado'), findsWidgets);
    expect(find.textContaining('Praça Central'), findsOneWidget);
  });

  testWidgets('artista inicia uma apresentação agendada', (tester) async {
    SharedPreferences.setMockInitialValues({'token_do_artista': 'TOKEN'});
    final cliente = MockClient((requisicao) async {
      if (requisicao.url.path == '/api/artista/conta') {
        return http.Response(_contaArtistaJson, 200);
      }
      if (requisicao.url.path.endsWith('/perfil-artistico')) {
        return http.Response(
          '{"id":"11111111-1111-1111-1111-111111111111","nomeArtistico":"Duo Aurora","bio":null}',
          200,
        );
      }
      const apresentacao =
          '{"id":"22222222-2222-2222-2222-222222222222","nome":"Noite Acústica","data":"2026-09-03","local":"Café Central","codigo":"A1B2C3","perfilArtistico":{"id":"11111111-1111-1111-1111-111111111111","nomeArtistico":"Duo Aurora","bio":null},"pedidosAbertos":true,"status":"Agendada"}';
      if (requisicao.method == 'GET') {
        return http.Response('[$apresentacao]', 200);
      }
      return http.Response(
        apresentacao.replaceFirst('"Agendada"', '"EmAndamento"'),
        200,
      );
    });

    await tester.pumpWidget(
      TocaEssaApp(
          api: ApiTocaEssa(cliente: cliente, enderecoBase: 'http://teste')),
    );
    final acessarPainel = find.text('Acessar Painel do Artista');
    await tester.ensureVisible(acessarPainel);
    await tester.tap(acessarPainel);
    await tester.pumpAndSettle();
    final iniciar = find.text('Iniciar Apresentação');
    await tester.tap(find.text('Noite Acústica'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(iniciar);
    await tester.tap(iniciar);
    await tester.pumpAndSettle();

    expect(find.text('Apresentação Pública · Em andamento'), findsOneWidget);
    await tester.tap(find.byTooltip('Opções da Apresentação'));
    await tester.pumpAndSettle();
    expect(find.text('Encerrar Apresentação'), findsOneWidget);
  });

  testWidgets('público recupera e cancela pedido ainda não analisado',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'nome_do_publico': 'Ana',
      'pedidos_publico_A1B2C3': ['33333333-3333-3333-3333-333333333333'],
    });
    final cliente = MockClient((requisicao) async {
      if (requisicao.url.path.endsWith('/fila')) {
        return http.Response('[]', 200);
      }
      if (requisicao.url.path.contains('/pedidos/')) {
        if (requisicao.method == 'PATCH') {
          return http.Response(
            '{"id":"33333333-3333-3333-3333-333333333333","apresentacaoId":"22222222-2222-2222-2222-222222222222","musica":"Evidências","artista":"Chitãozinho & Xororó","nomeSolicitante":"Ana","status":"CanceladoPeloPublico","posicao":null,"criadoEm":"2026-09-03T20:00:00Z"}',
            200,
          );
        }
        return http.Response(
          '{"id":"33333333-3333-3333-3333-333333333333","apresentacaoId":"22222222-2222-2222-2222-222222222222","musica":"Evidências","artista":"Chitãozinho & Xororó","nomeSolicitante":"Ana","status":"Aguardando","posicao":null,"criadoEm":"2026-09-03T20:00:00Z"}',
          200,
        );
      }
      return http.Response(
        '{"id":"22222222-2222-2222-2222-222222222222","nome":"Noite Acústica","data":"2026-09-03","local":"Café Central","codigo":"A1B2C3","perfilArtistico":{"id":"11111111-1111-1111-1111-111111111111","nomeArtistico":"Duo Aurora","bio":null},"pedidosAbertos":true,"status":"EmAndamento"}',
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

    expect(
      find.image(const AssetImage('assets/fundos/atmosfera.png')),
      findsOneWidget,
    );
    expect(find.text('Área do Público'), findsOneWidget);
    final campoNome = tester.widget<TextField>(
      find.widgetWithText(TextField, 'Seu nome (opcional)'),
    );
    expect(campoNome.controller?.text, 'Ana');
    expect(find.text('Evidências'), findsOneWidget);
    expect(find.text('Aguardando análise'), findsOneWidget);
    final cancelar = find.text('Cancelar');
    await tester.ensureVisible(cancelar);
    await tester.tap(cancelar);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancelar pedido').last);
    await tester.pumpAndSettle();

    expect(find.text('Cancelado por você'), findsOneWidget);
    expect(find.text('Cancelar'), findsNothing);
  });

  testWidgets('tela de pedir resume históricos com muitos pedidos',
      (tester) async {
    final ids = List.generate(
      5,
      (indice) =>
          '33333333-3333-3333-3333-${(indice + 1).toString().padLeft(12, '0')}',
    );
    SharedPreferences.setMockInitialValues({
      'pedidos_publico_A1B2C3': ids,
    });
    final cliente = MockClient((requisicao) async {
      if (requisicao.url.path.endsWith('/fila')) {
        return http.Response('[]', 200);
      }
      if (requisicao.url.path.contains('/pedidos/')) {
        final indice = ids.indexOf(requisicao.url.pathSegments.last) + 1;
        return http.Response(
          '{"id":"${ids[indice - 1]}","apresentacaoId":"22222222-2222-2222-2222-222222222222","musica":"Música $indice","artista":null,"nomeSolicitante":null,"status":"Aceito","posicao":$indice,"criadoEm":"2026-09-03T20:00:00Z"}',
          200,
        );
      }
      return http.Response(
        '{"id":"22222222-2222-2222-2222-222222222222","nome":"Noite Acústica","data":"2026-09-03","local":"Café Central","codigo":"A1B2C3","perfilArtistico":{"id":"11111111-1111-1111-1111-111111111111","nomeArtistico":"Duo Aurora","bio":null},"pedidosAbertos":true,"status":"EmAndamento","tipo":"Publica"}',
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

    expect(find.text('Novo pedido'), findsOneWidget);
    expect(find.text('Música 1'), findsOneWidget);
    expect(find.text('Música 2'), findsOneWidget);
    expect(find.text('Música 3'), findsNothing);
    expect(find.text('Música 4'), findsNothing);
    final verTodos = find.text('Ver todos os 5 pedidos');
    await tester.ensureVisible(verTodos);
    await tester.tap(verTodos);
    await tester.pumpAndSettle();

    expect(find.text('Música 4'), findsOneWidget);
    expect(find.text('Música 5'), findsOneWidget);
    expect(find.text('Mostrar somente os recentes'), findsOneWidget);
  });

  testWidgets('fila pública separa tocando próximas e já tocadas',
      (tester) async {
    final cliente = MockClient((requisicao) async {
      if (requisicao.url.path.endsWith('/fila')) {
        return http.Response(
          '[{"id":"30000000-0000-0000-0000-000000000001","apresentacaoId":"22222222-2222-2222-2222-222222222222","musica":"Agora","artista":null,"nomeSolicitante":null,"status":"TocandoAgora","posicao":null,"criadoEm":"2026-09-03T20:01:00Z"},{"id":"30000000-0000-0000-0000-000000000002","apresentacaoId":"22222222-2222-2222-2222-222222222222","musica":"Depois","artista":null,"nomeSolicitante":null,"status":"Aceito","posicao":1,"criadoEm":"2026-09-03T20:02:00Z"},{"id":"30000000-0000-0000-0000-000000000003","apresentacaoId":"22222222-2222-2222-2222-222222222222","musica":"Anterior","artista":null,"nomeSolicitante":null,"status":"Finalizado","posicao":null,"criadoEm":"2026-09-03T20:00:00Z"}]',
          200,
        );
      }
      return http.Response(
        '{"id":"22222222-2222-2222-2222-222222222222","nome":"Noite Acústica","data":"2026-09-03","local":"Café Central","codigo":"A1B2C3","perfilArtistico":{"id":"11111111-1111-1111-1111-111111111111","nomeArtistico":"Duo Aurora","bio":null},"pedidosAbertos":true,"status":"EmAndamento"}',
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
    await tester.tap(find.text('Fila').last);
    await tester.pumpAndSettle();

    expect(find.text('Tocando agora'), findsWidgets);
    expect(find.text('Próximas músicas'), findsOneWidget);
    expect(find.text('Já tocadas'), findsOneWidget);
    expect(find.text('Agora'), findsOneWidget);
    expect(find.text('Depois'), findsOneWidget);
    expect(find.text('Anterior'), findsOneWidget);
  });

  testWidgets('público avalia pedido finalizado com estrelas', (tester) async {
    SharedPreferences.setMockInitialValues({
      'pedidos_publico_A1B2C3': ['33333333-3333-3333-3333-333333333333'],
    });
    final cliente = MockClient((requisicao) async {
      if (requisicao.url.path.endsWith('/fila')) {
        return http.Response(
          '[{"id":"33333333-3333-3333-3333-333333333333","apresentacaoId":"22222222-2222-2222-2222-222222222222","musica":"Evidências","artista":null,"nomeSolicitante":"Ana","status":"Finalizado","posicao":null,"criadoEm":"2026-09-03T20:00:00Z","quantidadeAvaliacoes":0,"solicitantes":["Ana"]}]',
          200,
        );
      }
      if (requisicao.url.path.contains('/pedidos/')) {
        final avaliacao = requisicao.method == 'PUT'
            ? ',"quantidadeAvaliacoes":1,"mediaAvaliacoes":5,"minhaAvaliacao":5'
            : '';
        if (requisicao.method == 'PUT') {
          expect(requisicao.body, contains('"estrelas":5'));
        }
        return http.Response(
          '{"id":"33333333-3333-3333-3333-333333333333","apresentacaoId":"22222222-2222-2222-2222-222222222222","musica":"Evidências","artista":null,"nomeSolicitante":"Ana","status":"Finalizado","posicao":null,"criadoEm":"2026-09-03T20:00:00Z"$avaliacao}',
          200,
        );
      }
      return http.Response(
        '{"id":"22222222-2222-2222-2222-222222222222","nome":"Noite Acústica","data":"2026-09-03","local":"Café Central","codigo":"A1B2C3","perfilArtistico":{"id":"11111111-1111-1111-1111-111111111111","nomeArtistico":"Duo Aurora","bio":null},"pedidosAbertos":true,"status":"EmAndamento","tipo":"Publica"}',
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

    await tester.tap(find.text('Fila').last);
    await tester.pumpAndSettle();

    final cincoEstrelas = find.byTooltip('5 estrelas');
    await tester.ensureVisible(cincoEstrelas);
    await tester.tap(cincoEstrelas);
    await tester.pumpAndSettle();

    expect(find.text('Obrigado pela avaliação!'), findsOneWidget);
  });

  testWidgets('resenha exige e cria Perfil do Público', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final cliente = MockClient((requisicao) async {
      if (requisicao.url.path.endsWith('/fila') ||
          requisicao.url.path.endsWith('/meus-pedidos')) {
        return http.Response('[]', 200);
      }
      if (requisicao.url.path.endsWith('/contas')) {
        expect(requisicao.body, contains('Ana Souza'));
        return http.Response(
          '{"perfil":{"id":"44444444-4444-4444-4444-444444444444","nome":"Ana Souza","email":"ana@example.com","fotoUrl":null,"criadoEm":"2026-09-03T20:00:00Z"},"token":"TOKEN-DA-ANA"}',
          201,
        );
      }
      if (requisicao.url.path.endsWith('/estatisticas')) {
        return http.Response(
          '{"participacoes":2,"pedidos":5,"pedidosTocados":3,"avaliacoesRealizadas":2,"mediaAvaliacoes":4.5,"musicasMaisPedidas":[{"musica":"Evidências","quantidade":2}]}',
          200,
        );
      }
      if (requisicao.url.path.endsWith('/participantes')) {
        expect(requisicao.headers['authorization'], 'Bearer TOKEN-DA-ANA');
        return http.Response(
          '[{"publicoId":"44444444-4444-4444-4444-444444444444","nome":"Ana Souza","fotoUrl":null,"pedidos":5,"pedidosTocados":3,"mediaAvaliacoes":4.5,"musicasMaisPedidas":[{"musica":"Evidências","quantidade":2}]}]',
          200,
        );
      }
      if (requisicao.url.path.endsWith('/participacoes')) {
        expect(requisicao.method, 'POST');
        expect(requisicao.headers['authorization'], 'Bearer TOKEN-DA-ANA');
        return http.Response('', 204);
      }
      return http.Response(
        '{"id":"22222222-2222-2222-2222-222222222222","nome":"Resenha de sexta","data":"2026-09-03","local":"Casa da Ana","codigo":"A1B2C3","perfilArtistico":{"id":"11111111-1111-1111-1111-111111111111","nomeArtistico":"Duo Aurora","bio":null},"pedidosAbertos":true,"status":"EmAndamento","tipo":"ResenhaEntreAmigos"}',
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

    expect(find.text('Entre na resenha'), findsOneWidget);
    final alternarCadastro = find.text('Criar meu Perfil do Público');
    await tester.ensureVisible(alternarCadastro);
    await tester.tap(alternarCadastro);
    await tester.pumpAndSettle();
    await tester.enterText(
        find.widgetWithText(TextField, 'Seu nome'), 'Ana Souza');
    await tester.enterText(
        find.widgetWithText(TextField, 'E-mail'), 'ana@example.com');
    await tester.enterText(find.widgetWithText(TextField, 'Senha'), 'senha123');
    final criar = find.text('Criar perfil e entrar');
    await tester.ensureVisible(criar);
    await tester.tap(criar);
    await tester.pumpAndSettle();

    expect(find.text('Enviando como Ana Souza'), findsOneWidget);
    await tester.tap(find.text('Galera').last);
    await tester.pumpAndSettle();
    expect(find.text('Galera da resenha'), findsOneWidget);
    expect(find.text('Ana Souza'), findsOneWidget);
    expect(find.text('Você'), findsOneWidget);
    await tester.tap(find.text('Perfil').last);
    await tester.pumpAndSettle();
    expect(find.text('Músicas favoritas'), findsOneWidget);
    expect(find.text('Evidências'), findsWidgets);
    expect(find.text('Minha retrospectiva'), findsNothing);
    expect(find.text('Conquistas'), findsOneWidget);
    expect(find.text('Primeiro pedido'), findsOneWidget);
    expect(find.text('Copiar meu resumo'), findsOneWidget);
    await tester.tap(find.text('Nesta resenha'));
    await tester.pumpAndSettle();
    expect(find.text('Minha retrospectiva'), findsOneWidget);
    expect(find.text('Colocar minha foto'), findsOneWidget);
    expect(find.text('Conquistas'), findsNothing);
    expect(find.text('Copiar meu resumo'), findsNothing);
    await tester.tap(find.text('Perfil geral'));
    await tester.pumpAndSettle();
    expect(find.text('Conquistas'), findsOneWidget);
    expect(find.text('Minha retrospectiva'), findsNothing);
    final preferencias = await SharedPreferences.getInstance();
    expect(preferencias.getString('token_do_publico'), 'TOKEN-DA-ANA');
  });

  testWidgets('apresentação pública oferece perfil sem obrigar cadastro',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    var tentouCriarConta = false;
    final cliente = MockClient((requisicao) async {
      if (requisicao.url.path.endsWith('/fila')) {
        return http.Response('[]', 200);
      }
      if (requisicao.url.path.endsWith('/contas')) {
        tentouCriarConta = true;
        return http.Response('{}', 400);
      }
      return http.Response(
        '{"id":"22222222-2222-2222-2222-222222222222","nome":"Noite Acústica","data":"2026-09-03","local":"Café Central","codigo":"A1B2C3","perfilArtistico":{"id":"11111111-1111-1111-1111-111111111111","nomeArtistico":"Duo Aurora","bio":null},"pedidosAbertos":true,"status":"EmAndamento","tipo":"Publica"}',
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

    expect(find.text('Seu nome (opcional)'), findsOneWidget);
    expect(find.text('Perfil do Público'), findsNothing);
    await tester.tap(find.text('Perfil').last);
    await tester.pumpAndSettle();
    expect(find.text('Perfil do Público'), findsOneWidget);
    expect(find.text('Use seu Perfil do Público'), findsOneWidget);
    expect(find.text('Continuar como convidado'), findsOneWidget);

    final criarPerfil = find.text('Criar meu Perfil do Público');
    await tester.ensureVisible(criarPerfil);
    await tester.tap(criarPerfil);
    await tester.pumpAndSettle();
    await tester.enterText(
        find.widgetWithText(TextField, 'Seu nome'), 'Deborah');
    await tester.enterText(
        find.widgetWithText(TextField, 'E-mail'), 'deborah@gmail.com');
    await tester.enterText(find.widgetWithText(TextField, 'Senha'), '123');
    final criarEEntrar = find.text('Criar perfil e entrar');
    await tester.ensureVisible(criarEEntrar);
    await tester.tap(criarEEntrar);
    await tester.pump();

    expect(
        find.text('A senha deve ter pelo menos 6 caracteres.'), findsOneWidget);
    expect(tentouCriarConta, isFalse);
  });

  testWidgets('atualização automática preserva campo e posição da tela',
      (tester) async {
    final cliente = MockClient((requisicao) async {
      if (requisicao.url.path.endsWith('/fila')) {
        return http.Response('[]', 200);
      }
      return http.Response(
        '{"id":"22222222-2222-2222-2222-222222222222","nome":"Noite Acústica","data":"2026-09-03","local":"Café Central","codigo":"A1B2C3","perfilArtistico":{"id":"11111111-1111-1111-1111-111111111111","nomeArtistico":"Duo Aurora","bio":null},"pedidosAbertos":true,"status":"EmAndamento","tipo":"Publica"}',
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

    final campoMusica = find.widgetWithText(TextField, 'Música');
    await tester.ensureVisible(campoMusica);
    await tester.tap(campoMusica);
    await tester.enterText(campoMusica, 'Minha música favorita');
    final editavel = find.descendant(
      of: campoMusica,
      matching: find.byType(EditableText),
    );
    final focoAntes =
        tester.state<EditableTextState>(editavel).widget.focusNode;
    final pagina = find
        .descendant(
          of: find.byType(SingleChildScrollView).first,
          matching: find.byType(Scrollable),
        )
        .first;
    final rolagemAntes = tester.state<ScrollableState>(pagina).position.pixels;

    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    expect(find.text('Minha música favorita'), findsOneWidget);
    expect(focoAntes.hasFocus, isTrue);
    expect(tester.state<ScrollableState>(pagina).position.pixels, rolagemAntes);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
}
