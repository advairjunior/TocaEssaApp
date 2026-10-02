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
            case '/api/publico/apresentacoes':
              resposta = [
                {
                  'id': 'resenha',
                  'nome': 'Encontro de setembro',
                  'data': '2026-09-01',
                  'local': 'Casa',
                  'codigo': 'ABC123',
                  'status': 'Encerrada',
                  'tipo': 'ResenhaEntreAmigos',
                  'perfilArtistico': {'id': 'artista', 'nomeArtistico': 'Duo'}
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

    expect(find.text('Entre na sua conta'), findsOneWidget);
    expect(find.widgetWithText(CampoTexto, 'E-mail'), findsOneWidget);
    expect(find.widgetWithText(CampoTexto, 'Senha'), findsOneWidget);
    expect(find.text('Entrar com um código'), findsOneWidget);
  });

  ApiTocaEssa apiComApresentacoes(List<Map<String, Object?>> apresentacoes) =>
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
                  'participacoes': apresentacoes.length,
                  'pedidos': 7,
                  'pedidosTocados': 3,
                  'avaliacoesRealizadas': 2,
                  'musicasMaisPedidas': []
                },
              '/api/publico/apresentacoes' => apresentacoes,
              _ => throw StateError('Rota inesperada: ${request.url.path}'),
            };
            return http.Response(jsonEncode(resposta), 200,
                headers: {'content-type': 'application/json; charset=utf-8'});
          }));

  Map<String, Object?> apresentacao(String nome, String data, String status,
          {String tipo = 'Publica'}) =>
      {
        'id': nome,
        'nome': nome,
        'data': data,
        'local': 'Bar',
        'codigo': 'C${nome.length}',
        'status': status,
        'tipo': tipo,
        'perfilArtistico': {'id': 'artista', 'nomeArtistico': 'Duo'}
      };

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
