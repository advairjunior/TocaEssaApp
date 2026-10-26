import 'dart:convert';

import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:toca_essa_app/infraestrutura/api_toca_essa.dart';
import 'package:toca_essa_app/infraestrutura/camera_do_app.dart';
import 'package:toca_essa_app/main.dart';
import 'package:toca_essa_app/telas/componentes_formulario.dart';
import 'package:toca_essa_app/telas/fundo_toca_essa.dart';
import 'package:toca_essa_app/telas/gerenciar_repertorios.dart';
import 'package:toca_essa_app/telas/instalar_app.dart';
import 'package:toca_essa_app/telas/tocar_musicas.dart';

import 'apoio/camera_falsa.dart';

const _contaArtistaJson =
    '{"id":"aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa","nome":"Ana","email":"ana@artista.com","criadoEm":"2026-09-03T20:00:00Z"}';
const _perfilJson =
    '{"id":"11111111-1111-1111-1111-111111111111","nomeArtistico":"Duo Aurora","bio":null}';

String _apresentacao({
  required String id,
  required String nome,
  required String data,
  String status = 'Agendada',
  String tipo = 'Publica',
  bool pedidosAbertos = true,
}) =>
    '{"id":"20000000-0000-0000-0000-00000000000$id","nome":"$nome","data":"$data","local":"Bar do Zé","codigo":"COD00$id","perfilArtistico":{"id":"11111111-1111-1111-1111-111111111111","nomeArtistico":"Duo Aurora"},"pedidosAbertos":$pedidosAbertos,"status":"$status","tipo":"$tipo"}';

Finder campo(String rotulo) => find.descendant(
      of: find.widgetWithText(CampoTexto, rotulo),
      matching: find.byType(TextField),
    );

Future<void> _abrirPainel(
  WidgetTester tester, {
  String? perfil = _perfilJson,
  String apresentacoes = '[]',
  Future<http.Response?> Function(http.Request)? outras,
  bool recarregando = false,
}) async {
  // Recarregar a página mantém o que o aparelho guardou.
  if (!recarregando) {
    SharedPreferences.setMockInitialValues({'token_do_artista': 'TOKEN'});
  }
  final cliente = MockClient((requisicao) async {
    final resposta = await outras?.call(requisicao);
    if (resposta != null) return resposta;
    if (requisicao.url.path == '/api/artista/conta') {
      return http.Response(_contaArtistaJson, 200);
    }
    if (requisicao.url.path == '/api/perfil-artistico') {
      return perfil == null
          ? http.Response('{"mensagem":"Perfil não encontrado."}', 404)
          : http.Response(perfil, 200);
    }
    if (requisicao.url.path == '/api/apresentacoes') {
      return http.Response(apresentacoes, 200);
    }
    return http.Response('[]', 200);
  });
  await tester.pumpWidget(TocaEssaApp(
    api: ApiTocaEssa(cliente: cliente, enderecoBase: 'http://teste'),
  ));
  final acessarPainel = find.textContaining('meu painel');
  await tester.ensureVisible(acessarPainel);
  await tester.tap(acessarPainel);
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('início do painel não tem barra de abas e cumprimenta o artista',
      (tester) async {
    await _abrirPainel(tester);

    expect(find.byType(NavigationBar), findsNothing);
    expect(find.text('Olá, Duo Aurora'), findsOneWidget);
    expect(find.byTooltip('Minha conta'), findsOneWidget);
    expect(find.text('Nova apresentação'), findsOneWidget);
    expect(find.text('Nenhuma apresentação ainda'), findsOneWidget);
  });

  group('início do artista', () {
    String dia(int deslocamento) {
      final data = DateTime.now().add(Duration(days: deslocamento));
      return '${data.year}-${data.month.toString().padLeft(2, '0')}-'
          '${data.day.toString().padLeft(2, '0')}';
    }

    String repertorio(String id, String nome, int musicas) => jsonEncode({
          'id': id,
          'artistaId': 'a1',
          'nome': nome,
          'musicas': [
            for (var i = 0; i < musicas; i++)
              {
                'id': '$id-$i',
                'repertorioId': id,
                'titulo': 'Música $i',
                'ordem': i + 1,
              },
          ],
        });

    testWidgets('sem seta de voltar; a tela inicial fica no menu da conta',
        (tester) async {
      await _abrirPainel(tester);

      expect(find.byType(BackButton), findsNothing);
      await tester.tap(find.byTooltip('Minha conta'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tela inicial'));
      await tester.pumpAndSettle();

      expect(find.textContaining('meu painel'), findsOneWidget);
    });

    testWidgets('show agendado que já passou vai para o fim e avisa',
        (tester) async {
      await _abrirPainel(
        tester,
        apresentacoes: '[${_apresentacao(
          id: '1',
          nome: 'Segunda braba',
          data: dia(-37),
        )},${_apresentacao(
          id: '2',
          nome: 'Cantata de sábado',
          data: dia(3),
        )}]',
      );

      expect(tester.getTopLeft(find.text('Cantata de sábado')).dy,
          lessThan(tester.getTopLeft(find.text('Segunda braba')).dy));
      expect(find.text('Já passou · Bar do Zé · Pública'), findsOneWidget);
      expect(find.text('Bar do Zé · Pública'), findsOneWidget);
    });

    testWidgets('mostra o acervo e abre os repertórios', (tester) async {
      await _abrirPainel(
        tester,
        outras: (requisicao) async => requisicao.url.path ==
                '/api/artista/repertorios'
            ? http.Response(
                '[${repertorio('r1', 'Barzinho', 2)},'
                '${repertorio('r2', 'Louvor', 1)}]',
                200,
                headers: {'content-type': 'application/json; charset=utf-8'})
            : null,
      );

      expect(find.text('Acervo'), findsOneWidget);
      expect(find.text('2 repertórios · 3 músicas'), findsOneWidget);
      await tester.tap(find.text('Meus repertórios'));
      await tester.pumpAndSettle();

      expect(find.byType(GerenciarRepertorios), findsOneWidget);
    });

    testWidgets('Tocar e ensaiar abre o acervo sem criar show', (tester) async {
      await _abrirPainel(
        tester,
        outras: (requisicao) async => requisicao.url.path ==
                '/api/artista/repertorios'
            ? http.Response('[${repertorio('r1', 'Barzinho', 2)}]', 200,
                headers: {'content-type': 'application/json; charset=utf-8'})
            : null,
      );

      await tester.tap(find.text('Tocar e ensaiar'));
      await tester.pumpAndSettle();

      expect(find.byType(TocarMusicas), findsOneWidget);
    });

    testWidgets('sem repertórios, não oferece tocar', (tester) async {
      await _abrirPainel(tester);

      expect(find.text('Tocar e ensaiar'), findsNothing);
    });

    testWidgets('sem repertórios, convida a montar o acervo', (tester) async {
      await _abrirPainel(tester);

      expect(find.text('Monte seu acervo de músicas'), findsOneWidget);
    });
  });

  testWidgets('sem perfil artístico o painel orienta a criar o perfil',
      (tester) async {
    await _abrirPainel(tester, perfil: null);

    expect(find.text('Nova apresentação'), findsNothing);
    await tester.tap(find.text('Criar perfil artístico'));
    await tester.pumpAndSettle();
    expect(find.text('Identidade artística'), findsOneWidget);
  });

  testWidgets('menu da conta abre perfil artístico e volta ao início',
      (tester) async {
    await _abrirPainel(tester);

    await tester.tap(find.byTooltip('Minha conta'));
    await tester.pumpAndSettle();
    expect(find.text('Repertórios'), findsOneWidget);
    expect(find.text('Sair'), findsOneWidget);
    await tester.tap(find.text('Perfil artístico'));
    await tester.pumpAndSettle();
    expect(find.byType(LinhaInstalarApp, skipOffstage: false), findsOneWidget);

    expect(find.text('Identidade artística'), findsOneWidget);
    expect(find.text('Conquistas'), findsOneWidget);
    await tester.tap(find.byTooltip('Voltar ao início'));
    await tester.pumpAndSettle();
    expect(find.text('Olá, Duo Aurora'), findsOneWidget);
  });

  testWidgets('show ao vivo aparece em destaque e abre direto na fila',
      (tester) async {
    await _abrirPainel(
      tester,
      apresentacoes: '[${_apresentacao(
        id: '1',
        nome: 'Show de hoje',
        data: '2026-09-04',
        status: 'EmAndamento',
      )}]',
    );

    expect(find.text('Ao vivo agora'), findsOneWidget);
    expect(find.text('Show de hoje'), findsOneWidget);
    await tester.tap(find.text('Abrir fila'));
    await tester.pumpAndSettle();

    final barra = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(barra.destinations, hasLength(4));
    expect(find.text('Setlist'), findsOneWidget);
    expect(find.text('Mais'), findsOneWidget);
    expect(barra.selectedIndex, 0);
  });

  testWidgets('abrir o show desliza para o lado e trocar de aba esmaece',
      (tester) async {
    await _abrirPainel(
      tester,
      apresentacoes: '[${_apresentacao(
        id: '1',
        nome: 'Show de hoje',
        data: '2026-09-04',
        status: 'EmAndamento',
      )}]',
    );

    await tester.tap(find.text('Abrir fila'));
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byType(SharedAxisTransition), findsWidgets);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Setlist'));
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byType(FadeThroughTransition), findsWidgets);
    await tester.pumpAndSettle();
  });

  testWidgets('lista mostra data em bloco e tipo resumido', (tester) async {
    await _abrirPainel(
      tester,
      apresentacoes: '[${_apresentacao(
        id: '1',
        nome: 'Show de sábado',
        data: '2030-09-05',
        tipo: 'ResenhaEntreAmigos',
      )}]',
    );

    expect(find.text('SET'), findsOneWidget);
    expect(find.text('05'), findsOneWidget);
    expect(find.text('Bar do Zé · Resenha'), findsOneWidget);
  });

  testWidgets('próximas mostram primeiro a apresentação mais próxima',
      (tester) async {
    await _abrirPainel(
      tester,
      apresentacoes: '[${_apresentacao(
        id: '1',
        nome: 'Show de outubro',
        data: '2030-10-10',
      )},${_apresentacao(
        id: '2',
        nome: 'Show de dezembro',
        data: '2030-12-20',
      )},${_apresentacao(
        id: '3',
        nome: 'Show de setembro',
        data: '2030-09-05',
      )}]',
    );

    final setembro = tester.getTopLeft(find.text('Show de setembro')).dy;
    final outubro = tester.getTopLeft(find.text('Show de outubro')).dy;
    final dezembro = tester.getTopLeft(find.text('Show de dezembro')).dy;
    expect(setembro, lessThan(outubro));
    expect(outubro, lessThan(dezembro));
  });

  testWidgets('histórico mostra primeiro a apresentação mais recente',
      (tester) async {
    await _abrirPainel(
      tester,
      apresentacoes: '[${_apresentacao(
        id: '1',
        nome: 'Show de julho',
        data: '2026-07-10',
        status: 'Encerrada',
      )},${_apresentacao(
        id: '2',
        nome: 'Show de setembro',
        data: '2026-09-05',
        status: 'Encerrada',
      )},${_apresentacao(
        id: '3',
        nome: 'Show de agosto',
        data: '2026-08-15',
        status: 'Encerrada',
      )}]',
    );

    final setembro = tester.getTopLeft(find.text('Show de setembro')).dy;
    final agosto = tester.getTopLeft(find.text('Show de agosto')).dy;
    final julho = tester.getTopLeft(find.text('Show de julho')).dy;
    expect(setembro, lessThan(agosto));
    expect(agosto, lessThan(julho));
  });

  testWidgets('leitores de tela anunciam itens e menu da conta como botões',
      (tester) async {
    final semantica = tester.ensureSemantics();
    await _abrirPainel(
      tester,
      apresentacoes: '[${_apresentacao(
        id: '1',
        nome: 'Show de sábado',
        data: '2026-09-05',
      )}]',
    );

    expect(
      tester.getSemantics(find.text('Show de sábado')),
      isSemantics(isButton: true, hasTapAction: true),
    );
    expect(
      tester.getSemantics(find.byTooltip('Minha conta')),
      isSemantics(isButton: true),
    );
    semantica.dispose();
  });

  testWidgets('nova apresentação usa cartões de tipo e campos sem menu',
      (tester) async {
    await _abrirPainel(tester);

    await tester.tap(find.text('Nova apresentação'));
    await tester.pumpAndSettle();

    expect(find.byType(DropdownButtonFormField<Object>), findsNothing);
    expect(find.text('Pública'), findsOneWidget);
    expect(find.text('Resenha'), findsOneWidget);
    expect(campo('Nome da apresentação'), findsOneWidget);
    expect(campo('Local'), findsOneWidget);
    expect(find.text('Criar apresentação'), findsOneWidget);
  });

  testWidgets('barra de status mostra controles da apresentação ao vivo',
      (tester) async {
    var pedidosAlterados = false;
    await _abrirPainel(
      tester,
      apresentacoes: '[${_apresentacao(
        id: '1',
        nome: 'Show de hoje',
        data: '2026-09-04',
        status: 'EmAndamento',
      )}]',
      outras: (requisicao) async {
        if (requisicao.url.path.endsWith('/pedidos') &&
            requisicao.method == 'PATCH') {
          pedidosAlterados = true;
          expect(requisicao.body, contains('"abertos":false'));
          return http.Response(
            _apresentacao(
              id: '1',
              nome: 'Show de hoje',
              data: '2026-09-04',
              status: 'EmAndamento',
              pedidosAbertos: false,
            ),
            200,
          );
        }
        return null;
      },
    );
    await tester.tap(find.text('Show de hoje'));
    await tester.pumpAndSettle();

    expect(find.text('Ao vivo'), findsOneWidget);
    expect(find.text('Encerrar'), findsOneWidget);
    expect(tester.getSize(find.byTooltip('Receber pedidos')).height,
        greaterThanOrEqualTo(44),
        reason: 'área de toque');
    await tester.tap(find.byTooltip('Receber pedidos'));
    await tester.pumpAndSettle();
    expect(pedidosAlterados, isTrue);
  });

  group('encerrar lembra da selfie com o público', () {
    Future<List<String>> abrirShowAoVivo(WidgetTester tester) async {
      final chamadas = <String>[];
      final aoVivo = _apresentacao(
          id: '1',
          nome: 'Show de hoje',
          data: '2026-09-04',
          status: 'EmAndamento');
      await _abrirPainel(
        tester,
        apresentacoes: '[$aoVivo]',
        outras: (requisicao) async {
          final caminho = requisicao.url.path;
          if (caminho.endsWith('/foto-retrospectiva')) {
            chamadas.add('foto');
            return http.Response(
                aoVivo.replaceFirst(
                    '"tipo"', '"fotoRetrospectivaUrl":"/fotos/s.jpg","tipo"'),
                200);
          }
          if (caminho.endsWith('/status')) {
            chamadas.add('encerrar');
            return http.Response(
                aoVivo.replaceFirst('EmAndamento', 'Encerrada'), 200);
          }
          return null;
        },
      );
      await tester.tap(find.text('Show de hoje'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Encerrar'));
      await tester.pumpAndSettle();
      return chamadas;
    }

    testWidgets('tirar a selfie guarda a foto e depois encerra',
        (tester) async {
      final camera = CameraFalsa();
      fabricaDeCamera = () => camera;
      addTearDown(() => fabricaDeCamera = CameraDoPlugin.new);
      final chamadas = await abrirShowAoVivo(tester);

      expect(find.textContaining('selfie com o público'), findsOneWidget);
      await tester.tap(find.text('Tirar selfie'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tirar uma selfie'));
      await tester.pumpAndSettle();
      expect(camera.iniciadas, [LenteDaCamera.frontal]);
      await tester.tap(find.byTooltip('Tirar foto'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Usar foto'));
      await tester.pumpAndSettle();

      expect(chamadas, ['foto', 'encerrar']);
    });

    testWidgets('encerrar sem selfie continua possível', (tester) async {
      final chamadas = await abrirShowAoVivo(tester);

      await tester.tap(find.widgetWithText(TextButton, 'Encerrar sem foto'));
      await tester.pumpAndSettle();

      expect(chamadas, ['encerrar']);
    });

    testWidgets('desistir da câmera não encerra o show', (tester) async {
      final chamadas = await abrirShowAoVivo(tester);

      await tester.tap(find.text('Tirar selfie'));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      expect(chamadas, isEmpty);
    });
  });

  testWidgets('início e barra de status cabem em celular de 360px',
      (tester) async {
    addTearDown(tester.view.reset);
    tester.view.devicePixelRatio = 3;
    tester.view.physicalSize = const Size(360, 740) * 3;
    await _abrirPainel(
      tester,
      apresentacoes: '[${_apresentacao(
        id: '1',
        nome: 'Show de hoje com nome bem comprido',
        data: '2026-09-04',
        status: 'EmAndamento',
      )},${_apresentacao(
        id: '2',
        nome: 'Show de sábado',
        data: '2026-09-05',
        tipo: 'ResenhaEntreAmigos',
      )}]',
    );
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Show de sábado'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Iniciar'), findsOneWidget);
  });

  testWidgets('aba Mais reúne detalhes, código e exclusão', (tester) async {
    await _abrirPainel(
      tester,
      apresentacoes: '[${_apresentacao(
        id: '1',
        nome: 'Show de sábado',
        data: '2026-09-05',
      )}]',
    );
    await tester.tap(find.text('Show de sábado'));
    await tester.pumpAndSettle();

    expect(find.text('COD001'), findsOneWidget);
    expect(find.text('Bar do Zé'), findsOneWidget);
    expect(find.text('05/09/2026'), findsOneWidget);
    expect(find.text('Editar apresentação'), findsOneWidget);
    expect(find.text('Excluir apresentação'), findsOneWidget);
    expect(find.text('Iniciar'), findsOneWidget);
    // A foto só no topo, como nas outras abas: inteira, a borda do tapete
    // parecia um corte no meio da tela.
    expect(tester.widget<FundoTocaEssa>(find.byType(FundoTocaEssa)).intensidade,
        IntensidadeFundoTocaEssa.cabecalho);
  });

  group('horas contratadas', () {
    String relogio({int? duracao, bool pausa = false}) => jsonEncode({
          'duracaoContratadaMinutos': duracao,
          'intervaloPausaRelogio': pausa,
          'iniciadaEm': null,
          'emIntervaloDesde': null,
          'segundosEmIntervalo': 0,
          'musicasComecadas': 0,
          'musicasRestantes': 0,
          'agora': '2026-09-04T21:00:00Z',
        });

    testWidgets('nova apresentação guarda as horas e se o intervalo pausa',
        (tester) async {
      final configuracoes = <Map<String, dynamic>>[];
      await _abrirPainel(tester, outras: (requisicao) async {
        if (requisicao.method == 'POST' &&
            requisicao.url.path == '/api/apresentacoes') {
          return http.Response(
            '{"apresentacao":${_apresentacao(id: '1', nome: 'Casamento', data: '2026-09-05')},"linkPublico":"http://teste/#/publico/COD001"}',
            201,
          );
        }
        if (requisicao.url.path.endsWith('/relogio')) {
          configuracoes
              .add(jsonDecode(requisicao.body) as Map<String, dynamic>);
          return http.Response(relogio(duracao: 240, pausa: true), 200);
        }
        return null;
      });
      await tester.tap(find.text('Nova apresentação'));
      await tester.pumpAndSettle();
      await tester.enterText(campo('Nome da apresentação'), 'Casamento');
      await tester.enterText(campo('Local'), 'Salão');
      expect(find.text('Intervalo pausa o relógio'), findsNothing);
      await tester.enterText(campo('Horas contratadas'), '4');
      await tester.pumpAndSettle();
      final pausa = find.text('Intervalo pausa o relógio');
      await tester.ensureVisible(pausa);
      await tester.tap(pausa);
      final criar = find.text('Criar apresentação');
      await tester.ensureVisible(criar);
      await tester.tap(criar);
      await tester.pumpAndSettle();

      expect(configuracoes, [
        {'duracaoContratadaMinutos': 240, 'intervaloPausaRelogio': true}
      ]);
      expect(find.text('Apresentação criada!'), findsOneWidget);
    });

    testWidgets('horas que o app não entende não salvam', (tester) async {
      var criou = false;
      await _abrirPainel(tester, outras: (requisicao) async {
        if (requisicao.method == 'POST') criou = true;
        return null;
      });
      await tester.tap(find.text('Nova apresentação'));
      await tester.pumpAndSettle();
      await tester.enterText(campo('Nome da apresentação'), 'Casamento');
      await tester.enterText(campo('Local'), 'Salão');
      await tester.enterText(campo('Horas contratadas'), 'quatro');
      final criar = find.text('Criar apresentação');
      await tester.ensureVisible(criar);
      await tester.tap(criar);
      await tester.pumpAndSettle();

      expect(criou, isFalse);
      expect(find.textContaining('ex.: 4 ou 3h30'), findsOneWidget);
    });

    testWidgets('show ao vivo mostra o cronômetro em todas as abas',
        (tester) async {
      final agora = DateTime.now().toUtc();
      await _abrirPainel(
        tester,
        apresentacoes: '[${_apresentacao(
          id: '1',
          nome: 'Show de hoje',
          data: '2026-09-04',
          status: 'EmAndamento',
        )}]',
        outras: (requisicao) async => requisicao.url.path.endsWith('/relogio')
            ? http.Response(
                jsonEncode({
                  ...jsonDecode(relogio(duracao: 240)) as Map<String, dynamic>,
                  'iniciadaEm': agora
                      .subtract(const Duration(hours: 1))
                      .toIso8601String(),
                  'agora': agora.toIso8601String(),
                }),
                200)
            : null,
      );
      await tester.tap(find.text('Abrir fila'));
      await tester.pumpAndSettle();
      expect(find.text('Restam 3h00'), findsOneWidget);

      for (final aba in ['Setlist', 'Estatísticas', 'Mais']) {
        await tester.tap(find.text(aba));
        await tester.pumpAndSettle();
        expect(find.text('Restam 3h00'), findsOneWidget, reason: aba);
      }
    });

    testWidgets('show agendado não mostra o cronômetro', (tester) async {
      await _abrirPainel(
        tester,
        apresentacoes: '[${_apresentacao(
          id: '1',
          nome: 'Show de sábado',
          data: '2026-09-05',
        )}]',
        outras: (requisicao) async => requisicao.url.path.endsWith('/relogio')
            ? http.Response(relogio(duracao: 240), 200)
            : null,
      );
      await tester.tap(find.text('Show de sábado'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Restam'), findsNothing);
      expect(find.text('Intervalo'), findsNothing);
    });

    testWidgets('editar mostra as horas guardadas e salva a mudança',
        (tester) async {
      final configuracoes = <Map<String, dynamic>>[];
      final show =
          _apresentacao(id: '1', nome: 'Show de sábado', data: '2026-09-05');
      await _abrirPainel(tester, apresentacoes: '[$show]',
          outras: (requisicao) async {
        if (requisicao.url.path.endsWith('/relogio')) {
          if (requisicao.method == 'PUT') {
            configuracoes
                .add(jsonDecode(requisicao.body) as Map<String, dynamic>);
          }
          return http.Response(relogio(duracao: 240), 200);
        }
        if (requisicao.method == 'PUT') return http.Response(show, 200);
        return null;
      });
      await tester.tap(find.text('Show de sábado'));
      await tester.pumpAndSettle();
      final editar = find.text('Editar apresentação');
      await tester.ensureVisible(editar);
      await tester.tap(editar);
      await tester.pumpAndSettle();

      expect(find.text('4h'), findsOneWidget);
      await tester.enterText(campo('Horas contratadas'), '3h30');
      final salvar = find.text('Salvar');
      await tester.ensureVisible(salvar);
      await tester.tap(salvar);
      await tester.pumpAndSettle();

      expect(configuracoes, [
        {'duracaoContratadaMinutos': 210, 'intervaloPausaRelogio': false}
      ]);
    });
  });

  group('ao recarregar a página', () {
    String showDeHoje({String status = 'EmAndamento'}) => '[${_apresentacao(
          id: '1',
          nome: 'Show de hoje',
          data: '2026-09-04',
          status: status,
        )}]';

    Future<void> abrirSetlistDoShow(WidgetTester tester) async {
      await _abrirPainel(tester, apresentacoes: showDeHoje());
      await tester.tap(find.text('Abrir fila'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Setlist'));
      await tester.pumpAndSettle();
    }

    Future<void> recarregar(WidgetTester tester, String apresentacoes) async {
      await tester.pumpWidget(const SizedBox());
      await _abrirPainel(tester,
          apresentacoes: apresentacoes, recarregando: true);
    }

    testWidgets('volta para a aba do show em andamento onde parou',
        (tester) async {
      await abrirSetlistDoShow(tester);

      await recarregar(tester, showDeHoje());

      final barra = tester.widget<NavigationBar>(find.byType(NavigationBar));
      expect(barra.selectedIndex, 1);
      expect(find.text('Show de hoje'), findsWidgets);
    });

    testWidgets('show já encerrado abre o início do painel', (tester) async {
      await abrirSetlistDoShow(tester);

      await recarregar(tester, showDeHoje(status: 'Encerrada'));

      expect(find.byType(NavigationBar), findsNothing);
      expect(find.text('Olá, Duo Aurora'), findsOneWidget);
    });

    testWidgets('depois de voltar ao início, abre o início', (tester) async {
      await abrirSetlistDoShow(tester);
      await tester.tap(find.byTooltip('Voltar ao início'));
      await tester.pumpAndSettle();

      await recarregar(tester, showDeHoje());

      expect(find.byType(NavigationBar), findsNothing);
      expect(find.text('Olá, Duo Aurora'), findsOneWidget);
    });
  });

  group('louvor', () {
    final louvorJson = jsonEncode({
      'cantores': ['João', 'Ana'],
      'placar': [
        {'nome': 'João', 'pontos': 0},
        {'nome': 'Ana', 'pontos': 0},
      ],
      'hinos': <Object?>[],
    });

    Future<http.Response?> servirLouvor(http.Request requisicao) async =>
        requisicao.url.path.endsWith('/louvor')
            ? http.Response(louvorJson, 200, headers: {
                'content-type': 'application/json; charset=utf-8',
              })
            : null;

    testWidgets('nova apresentação oferece o tipo Louvor', (tester) async {
      await _abrirPainel(tester);

      await tester.tap(find.text('Nova apresentação'));
      await tester.pumpAndSettle();

      expect(find.text('Louvor'), findsOneWidget);
    });

    testWidgets('louvor tem as abas Escala, Hinos e Mais, sem pedidos',
        (tester) async {
      await _abrirPainel(
        tester,
        apresentacoes: '[${_apresentacao(
          id: '1',
          nome: 'Louvor de sábado',
          data: '2026-10-24',
          tipo: 'Louvor',
        )}]',
        outras: servirLouvor,
      );
      await tester.tap(find.text('Louvor de sábado'));
      await tester.pumpAndSettle();

      final barra = tester.widget<NavigationBar>(find.byType(NavigationBar));
      expect(barra.destinations, hasLength(3));
      expect(find.text('Escala'), findsOneWidget);
      expect(find.text('Hinos'), findsOneWidget);
      expect(find.text('Mais'), findsOneWidget);
      expect(find.text('Fila'), findsNothing);
      expect(find.text('Estatísticas'), findsNothing);
      expect(find.text('Recebendo pedidos'), findsNothing);
      // Sem pedidos, não sobra faixa só para o Iniciar: ele fica no topo.
      expect(
          find.descendant(
              of: find.byType(AppBar), matching: find.text('Iniciar')),
          findsOneWidget);
      expect(tester.widget<AppBar>(find.byType(AppBar)).bottom, isNull);
      expect(barra.selectedIndex, 0);
      expect(find.text('Por hino'), findsOneWidget);
      expect(find.text('Pessoas'), findsOneWidget);
    });

    testWidgets('karaokê abre na aba Noite, com a galera e o Mais',
        (tester) async {
      await _abrirPainel(
        tester,
        apresentacoes: '[${_apresentacao(
          id: '1',
          nome: 'Karaokê de sexta',
          data: '2026-10-30',
          tipo: 'Karaoke',
        )}]',
        outras: (requisicao) async => requisicao.url.path.endsWith('/karaoke')
            ? http.Response(
                '{"repertorioId":null,"modo":"Livre","sorteada":false,'
                '"podeSortearDeNovo":true,"ordem":[],"foraDaOrdem":[]}',
                200,
                headers: {'content-type': 'application/json; charset=utf-8'})
            : null,
      );
      await tester.tap(find.text('Karaokê de sexta'));
      await tester.pumpAndSettle();

      final barra = tester.widget<NavigationBar>(find.byType(NavigationBar));
      expect(barra.destinations, hasLength(2));
      expect(barra.selectedIndex, 0);
      expect(find.text('Noite'), findsOneWidget);
      expect(find.text('Ninguém na galera ainda'), findsOneWidget);

      await tester.tap(find.text('Mais'));
      await tester.pumpAndSettle();
      expect(find.byType(NavigationBar), findsOneWidget);
    });

    testWidgets('louvor ao vivo abre direto nos hinos', (tester) async {
      await _abrirPainel(
        tester,
        apresentacoes: '[${_apresentacao(
          id: '1',
          nome: 'Louvor de hoje',
          data: '2026-10-24',
          status: 'EmAndamento',
          tipo: 'Louvor',
        )}]',
        outras: servirLouvor,
      );

      expect(find.text('Abrir fila'), findsNothing);
      expect(find.text('Pedidos abertos'), findsNothing);
      await tester.tap(find.text('Abrir hinos'));
      await tester.pumpAndSettle();

      final barra = tester.widget<NavigationBar>(find.byType(NavigationBar));
      expect(barra.selectedIndex, 1);
      expect(
          find.descendant(
              of: find.byType(AppBar), matching: find.text('Encerrar')),
          findsOneWidget);
      expect(tester.widget<AppBar>(find.byType(AppBar)).bottom, isNull);
    });
  });
}
