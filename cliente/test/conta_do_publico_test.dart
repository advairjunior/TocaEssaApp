import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:toca_essa_app/infraestrutura/api_toca_essa.dart';
import 'package:toca_essa_app/telas/componentes_formulario.dart';
import 'package:toca_essa_app/telas/componentes_lista.dart';
import 'package:toca_essa_app/telas/conta_do_publico.dart';
import 'package:toca_essa_app/telas/memoria_da_resenha.dart';
import 'package:toca_essa_app/telas/retrospectiva_do_ano.dart';

void main() {
  testWidgets('conta recupera histórico sem código e separa perfil geral',
      (tester) async {
    SharedPreferences.setMockInitialValues({'token_do_publico': 'TOKEN'});
    final api = ApiTocaEssa(
        enderecoBase: 'http://teste',
        cliente: MockClient((request) async {
          expect(request.headers['authorization'], 'Bearer TOKEN');
          final Object resposta;
          switch (request.url.path) {
            case '/api/publico/perfil':
              resposta = {
                'id': 'ana',
                'nome': 'Ana',
                'email': 'ana@teste.com',
                'criadoEm': '2026-09-01T00:00:00Z'
              };
            case '/api/publico/estatisticas':
              resposta = {
                'participacoes': 1,
                'pedidos': 0,
                'pedidosTocados': 0,
                'avaliacoesRealizadas': 0,
                'musicasMaisPedidas': []
              };
            case '/api/publico/historico':
              resposta = [
                {
                  'apresentacao': {
                    'id': 'resenha',
                    'nome': 'Encontro de setembro',
                    'data': '2026-09-01',
                    'local': 'Casa',
                    'codigo': 'ABC123',
                    'status': 'Encerrada',
                    'tipo': 'ResenhaEntreAmigos',
                    'perfilArtistico': {'id': 'artista', 'nomeArtistico': 'Duo'}
                  },
                  'pedidos': 0,
                  'pedidosTocados': 0,
                  'minhasMusicas': [],
                  'companhia': []
                }
              ];
            default:
              throw StateError('Rota inesperada: ${request.url.path}');
          }
          return http.Response(jsonEncode(resposta), 200,
              headers: {'content-type': 'application/json; charset=utf-8'});
        }));
    await tester.pumpWidget(MaterialApp(home: ContaDoPublico(api: api)));
    await tester.pumpAndSettle();
    expect(
      find.image(const AssetImage('assets/fundos/atmosfera.png')),
      findsOneWidget,
    );
    expect(find.text('Minhas resenhas'), findsOneWidget);
    // Cabeçalho editorial no próprio conteúdo, sem barra de app.
    expect(find.byType(AppBar), findsNothing);
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.byType(Card), findsNothing);
    // Linha do tempo única: sem abas, histórico agrupado por ano.
    expect(find.byType(AbaDeTexto), findsNothing);
    expect(find.text('Próximas'), findsNothing);
    expect(find.text('2026'), findsOneWidget);
    expect(find.text('Encontro de setembro'), findsOneWidget);
    expect(find.text('Duo · Casa'), findsOneWidget);
    expect(find.text('01 de setembro · Resenha'), findsOneWidget);
    // Resumo pessoal no topo, no singular quando há uma só resenha.
    expect(find.text('resenha'), findsOneWidget);
    expect(find.text('pedidos'), findsOneWidget);
    expect(find.text('tocadas'), findsOneWidget);

    await tester.tap(find.byTooltip('Meu perfil'));
    await tester.pumpAndSettle();
    expect(find.text('Ana'), findsOneWidget);
    expect(find.text('Encontro de setembro'), findsNothing);
    await tester.tap(find.byTooltip('Voltar às resenhas'));
    await tester.pumpAndSettle();
    expect(find.text('Minhas resenhas'), findsOneWidget);
  });

  testWidgets('sem conta, a tela oferece entrar com campos leves',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final api = ApiTocaEssa(
      enderecoBase: 'http://teste',
      cliente: MockClient((_) async => http.Response('{}', 404)),
    );
    await tester.pumpWidget(MaterialApp(home: ContaDoPublico(api: api)));
    await tester.pumpAndSettle();

    // Mesma linguagem do início: foto do palco ao fundo e sem barra de app.
    expect(find.byType(AppBar), findsNothing);
    expect(
      find.image(const AssetImage('assets/fundos/inicio_palco.png')),
      findsOneWidget,
    );
    expect(find.text('Suas noites, guardadas.'), findsOneWidget);
    expect(find.text('Entre na sua conta'), findsOneWidget);
    expect(find.widgetWithText(CampoTexto, 'E-mail'), findsOneWidget);
    expect(find.widgetWithText(CampoTexto, 'Senha'), findsOneWidget);
    expect(find.text('Entrar com um código'), findsOneWidget);
  });

  ApiTocaEssa apiComApresentacoes(List<Map<String, Object?>> encontros) =>
      ApiTocaEssa(
          enderecoBase: 'http://teste',
          cliente: MockClient((request) async {
            final Object resposta = switch (request.url.path) {
              '/api/publico/perfil' => {
                  'id': 'ana',
                  'nome': 'Ana',
                  'email': 'ana@teste.com',
                  'criadoEm': '2025-01-01T00:00:00Z'
                },
              '/api/publico/estatisticas' => {
                  'participacoes': encontros.length,
                  'pedidos': 7,
                  'pedidosTocados': 3,
                  'avaliacoesRealizadas': 2,
                  'musicasMaisPedidas': []
                },
              '/api/publico/historico' => encontros,
              _ => throw StateError('Rota inesperada: ${request.url.path}'),
            };
            return http.Response(jsonEncode(resposta), 200,
                headers: {'content-type': 'application/json; charset=utf-8'});
          }));

  Map<String, Object?> apresentacao(String nome, String data, String status,
          {String tipo = 'Publica',
          String? foto,
          int pedidos = 0,
          int tocadas = 0,
          List<String> musicas = const [],
          List<String> companhia = const []}) =>
      {
        'apresentacao': {
          'id': nome,
          'nome': nome,
          'data': data,
          'local': 'Bar',
          'codigo': 'C${nome.length}',
          'status': status,
          'tipo': tipo,
          'fotoRetrospectivaUrl': foto,
          'perfilArtistico': {'id': 'artista', 'nomeArtistico': 'Duo'}
        },
        'pedidos': pedidos,
        'pedidosTocados': tocadas,
        'minhasMusicas': [
          for (final (indice, musica) in musicas.indexed)
            {'musica': musica, 'quantidade': musicas.length - indice}
        ],
        'companhia': [
          for (final pessoa in companhia)
            {'publicoId': pessoa, 'nome': pessoa, 'fotoUrl': null}
        ],
      };

  testWidgets('cada memória mostra minha música da noite e quem estava comigo',
      (tester) async {
    SharedPreferences.setMockInitialValues({'token_do_publico': 'TOKEN'});
    final api = apiComApresentacoes([
      apresentacao('Roda de samba', '2026-09-12', 'Encerrada',
          tipo: 'ResenhaEntreAmigos',
          pedidos: 3,
          tocadas: 2,
          musicas: ['Evidências', 'Garota'],
          companhia: ['Bia', 'Caio', 'Davi', 'Eva']),
      apresentacao('Show de agosto', '2026-08-10', 'Encerrada'),
    ]);
    await tester.pumpWidget(MaterialApp(home: ContaDoPublico(api: api)));
    await tester.pumpAndSettle();

    expect(find.text('Evidências'), findsOneWidget);
    expect(find.text('com Bia, Caio e mais 2'), findsOneWidget);
    // Sem pedido nem companhia, a linha fica enxuta.
    expect(find.textContaining(RegExp(r'^com ')), findsOneWidget);
  });

  testWidgets(
      'foto nova do encontro ganha selo até a pessoa abrir aquela memória',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'token_do_publico': 'TOKEN',
      'fotos_vistas_do_publico': ['/fotos/vista.png'],
    });
    final api = apiComApresentacoes([
      apresentacao('Roda nova', '2026-09-12', 'Encerrada',
          foto: '/fotos/nova.png'),
      apresentacao('Roda vista', '2026-08-10', 'Encerrada',
          foto: '/fotos/vista.png'),
      apresentacao('Roda sem foto', '2026-07-10', 'Encerrada'),
    ]);
    await tester.pumpWidget(MaterialApp(home: ContaDoPublico(api: api)));
    await tester.pumpAndSettle();

    expect(find.text('Foto nova'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('memoria-Roda nova')),
        matching: find.text('Foto nova'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('memória encerrada vira cartão com foto e abre a noite inteira',
      (tester) async {
    SharedPreferences.setMockInitialValues({'token_do_publico': 'TOKEN'});
    final api = apiComApresentacoes([
      apresentacao('Roda de samba', '2026-09-12', 'Encerrada',
          tipo: 'ResenhaEntreAmigos',
          pedidos: 3,
          tocadas: 2,
          musicas: ['Evidências'],
          companhia: ['Bia', 'Caio']),
      apresentacao('Show sem foto', '2026-08-10', 'Encerrada'),
    ]);
    await tester.pumpWidget(MaterialApp(home: ContaDoPublico(api: api)));
    await tester.pumpAndSettle();

    // A foto ocupa a largura do cartão, em vez de ser uma miniatura.
    final cartao = find.byKey(const ValueKey('memoria-Roda de samba'));
    final capa = find.descendant(of: cartao, matching: find.byType(Image));
    expect(tester.getSize(capa.first).width,
        closeTo(tester.getSize(cartao).width, 1));
    // Sem foto, a capa usa um fundo de palco, não um ícone solto.
    for (final memoria in ['Roda de samba', 'Show sem foto']) {
      final cartaoSemFoto = find.byKey(ValueKey('memoria-$memoria'));
      expect(
        find.descendant(
            of: cartaoSemFoto, matching: find.byIcon(Icons.mic_rounded)),
        findsNothing,
      );
      expect(
        find.descendant(
            of: cartaoSemFoto,
            matching: find
                .byWidgetPredicate((w) => w is Image && w.image is AssetImage)),
        findsOneWidget,
      );
    }

    await tester.tap(find.text('Roda de samba'));
    await tester.pumpAndSettle();
    expect(find.byType(MemoriaDaResenha), findsOneWidget);
    expect(find.text('SUA MÚSICA DA NOITE'), findsOneWidget);
    expect(find.text('Bia'), findsOneWidget);
  });

  testWidgets(
      'linha do tempo destaca o ao vivo, mostra próximas e agrupa o histórico '
      'por ano, do mais recente ao mais antigo', (tester) async {
    SharedPreferences.setMockInitialValues({'token_do_publico': 'TOKEN'});
    final api = apiComApresentacoes([
      apresentacao('Roda antiga', '2025-12-20', 'Encerrada',
          tipo: 'ResenhaEntreAmigos'),
      apresentacao('Show de agosto', '2026-08-10', 'Encerrada'),
      apresentacao('Agora no bar', '2026-10-02', 'EmAndamento'),
      apresentacao('Festa marcada', '2026-11-15', 'Agendada'),
    ]);
    await tester.pumpWidget(MaterialApp(home: ContaDoPublico(api: api)));
    await tester.pumpAndSettle();

    expect(find.text('Ao vivo agora'), findsOneWidget);
    expect(find.text('Agora no bar'), findsOneWidget);
    expect(find.text('Voltar para a resenha'), findsOneWidget);
    expect(find.text('Próximas'), findsOneWidget);
    expect(find.text('resenhas'), findsOneWidget);
    expect(find.text('7'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);

    double topo(String texto) => tester.getTopLeft(find.text(texto)).dy;
    expect(topo('Ao vivo agora'), lessThan(topo('Próximas')));
    expect(topo('Próximas'), lessThan(topo('Festa marcada')));
    expect(topo('Festa marcada'), lessThan(topo('2026')));
    expect(topo('2026'), lessThan(topo('Show de agosto')));
    expect(topo('Show de agosto'), lessThan(topo('2025')));
    expect(topo('2025'), lessThan(topo('Roda antiga')));
    expect(find.text('10 de agosto · Show'), findsOneWidget);
    expect(find.text('20 de dezembro · Resenha'), findsOneWidget);
  });

  testWidgets('cada ano do histórico abre a retrospectiva daquele ano',
      (tester) async {
    SharedPreferences.setMockInitialValues({'token_do_publico': 'TOKEN'});
    final api = apiComApresentacoes([
      apresentacao('Show de agosto', '2026-08-10', 'Encerrada'),
      apresentacao('Roda antiga', '2025-12-20', 'Encerrada',
          musicas: ['Evidências']),
    ]);
    await tester.pumpWidget(MaterialApp(home: ContaDoPublico(api: api)));
    await tester.pumpAndSettle();

    expect(find.text('Meu 2026'), findsOneWidget);
    await tester.ensureVisible(find.text('Meu 2025'));
    await tester.tap(find.text('Meu 2025'));
    await tester.pumpAndSettle();

    expect(find.byType(RetrospectivaDoAno), findsOneWidget);
    expect(find.text('MÚSICA DO ANO'), findsOneWidget);
    expect(find.text('Evidências'), findsOneWidget);
  });

  testWidgets('sem nenhuma resenha, convida a entrar com um código',
      (tester) async {
    SharedPreferences.setMockInitialValues({'token_do_publico': 'TOKEN'});
    await tester.pumpWidget(
        MaterialApp(home: ContaDoPublico(api: apiComApresentacoes([]))));
    await tester.pumpAndSettle();

    expect(find.text('Sua primeira resenha te espera'), findsOneWidget);
    expect(find.text('Entrar com um código'), findsOneWidget);
    expect(find.text('Histórico vazio'), findsNothing);
  });
}
