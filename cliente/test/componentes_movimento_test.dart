import 'dart:async';

import 'package:animations/animations.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:toca_essa_app/dominio/modelos.dart';
import 'package:toca_essa_app/infraestrutura/api_toca_essa.dart';
import 'package:toca_essa_app/telas/componentes_lista.dart';
import 'package:toca_essa_app/telas/componentes_movimento.dart';
import 'package:toca_essa_app/telas/setlist_do_artista.dart';
import 'package:toca_essa_app/tema/tema_toca_essa.dart';

Future<void> _mostrar(WidgetTester tester, Widget filho,
        {bool semAnimacoes = false}) =>
    tester.pumpWidget(MaterialApp(
      theme: TemaTocaEssa.escuro,
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: semAnimacoes),
        child: Scaffold(body: filho),
      ),
    ));

double _opacidade(WidgetTester tester, String texto) {
  final camadas = tester
      .widgetList<FadeTransition>(find.ancestor(
          of: find.text(texto), matching: find.byType(FadeTransition)))
      .map((camada) => camada.opacity.value);
  return camadas.fold(1, (total, valor) => total * valor);
}

void main() {
  group('esqueleto no carregamento', () {
    testWidgets('mostra linhas de mentira com brilho, sem a rodinha',
        (tester) async {
      await _mostrar(tester, const EsqueletoDeLista(linhas: 4));

      final esqueleto = tester.widget<Skeletonizer>(
          find.byWidgetPredicate((w) => w is Skeletonizer).first);
      expect(esqueleto.enabled, isTrue);
      expect(find.byType(ListTile), findsNWidgets(4));
      expect(find.byType(CircularProgressIndicator), findsNothing);
      // A entrada das linhas começa depois de um instante.
      await tester.pump(const Duration(milliseconds: 1));
    });

    testWidgets('a setlist carregando já mostra o formato da lista',
        (tester) async {
      final resposta = Completer<http.Response>();
      final cliente = MockClient((_) => resposta.future);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SetlistDoArtista(
            api: ApiTocaEssa(cliente: cliente, enderecoBase: 'http://teste')
              ..definirTokenArtista('TOKEN'),
            apresentacao: Apresentacao(
              id: '33333333-3333-3333-3333-333333333333',
              nome: 'Show',
              data: DateTime(2026, 9, 10),
              local: 'Bar',
              codigo: 'ABC123',
              perfilArtistico: const PerfilArtistico(
                  id: '22222222-2222-2222-2222-222222222222',
                  nomeArtistico: 'Duo Aurora'),
              pedidosAbertos: true,
              status: StatusApresentacao.emAndamento,
              tipo: TipoApresentacao.publica,
            ),
            incorporada: true,
          ),
        ),
      ));
      await tester.pump();

      expect(find.byType(EsqueletoDeLista), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      await tester.pump(const Duration(milliseconds: 1));
    });
  });

  group('entrada suave', () {
    testWidgets('aparece subindo e termina no lugar, inteira', (tester) async {
      await _mostrar(tester, const EntradaSuave(child: Text('Olá')));

      expect(_opacidade(tester, 'Olá'), lessThan(1));
      await tester.pumpAndSettle();
      expect(_opacidade(tester, 'Olá'), 1);
    });

    testWidgets('quem pediu menos movimento no aparelho vê tudo parado',
        (tester) async {
      await _mostrar(tester, const EntradaSuave(child: Text('Olá')),
          semAnimacoes: true);

      expect(_opacidade(tester, 'Olá'), 1);
    });

    testWidgets('linhas de um grupo entram uma depois da outra',
        (tester) async {
      await _mostrar(
        tester,
        const GrupoDeLinhas(linhas: [
          ListTile(title: Text('Primeira')),
          ListTile(title: Text('Segunda')),
          ListTile(title: Text('Terceira')),
        ]),
      );
      // A entrada só começa depois de um instante.
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump(const Duration(milliseconds: 120));

      expect(_opacidade(tester, 'Primeira'),
          greaterThan(_opacidade(tester, 'Segunda')));
      expect(_opacidade(tester, 'Segunda'),
          greaterThan(_opacidade(tester, 'Terceira')));
      await tester.pumpAndSettle();
      expect(_opacidade(tester, 'Terceira'), 1);
    });
  });

  group('trocas de tela', () {
    testWidgets('trocar de aba esmaece a antiga e traz a nova', (tester) async {
      Widget aba(String nome) =>
          TrocaDeAba(chave: nome, child: Text('Aba $nome'));
      await _mostrar(tester, aba('Pedir'));
      await _mostrar(tester, aba('Fila'));
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.byType(FadeThroughTransition), findsWidgets);
      expect(find.text('Aba Pedir'), findsOneWidget);
      await tester.pumpAndSettle();
      expect(find.text('Aba Pedir'), findsNothing);
      expect(find.text('Aba Fila'), findsOneWidget);
    });

    testWidgets('entrar numa tela desliza para o lado', (tester) async {
      Widget tela(String nome, {bool voltando = false}) => TrocaDeTela(
          chave: nome, voltando: voltando, child: Text('Tela $nome'));
      await _mostrar(tester, tela('Início'));
      await _mostrar(tester, tela('Show'));
      await tester.pump(const Duration(milliseconds: 50));

      final transicao = tester
          .widget<SharedAxisTransition>(find.byType(SharedAxisTransition).last);
      expect(transicao.transitionType, SharedAxisTransitionType.horizontal);
      await tester.pumpAndSettle();
      expect(find.text('Tela Início'), findsNothing);
    });

    test(
        'telas novas deslizam no lado, mas o iPhone mantém o voltar com o dedo',
        () {
      final transicoes = TemaTocaEssa.escuro.pageTransitionsTheme.builders;

      expect(transicoes[TargetPlatform.android],
          isA<SharedAxisPageTransitionsBuilder>());
      expect(transicoes[TargetPlatform.windows],
          isA<SharedAxisPageTransitionsBuilder>());
      expect(transicoes[TargetPlatform.iOS],
          isA<CupertinoPageTransitionsBuilder>());
    });
  });
}
