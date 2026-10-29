import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:toca_essa_app/infraestrutura/api_toca_essa.dart';
import 'package:toca_essa_app/main.dart';
import 'package:toca_essa_app/telas/comando_do_ajudante.dart';
import 'package:toca_essa_app/tema/tema_toca_essa.dart';

const _json = {'content-type': 'application/json; charset=utf-8'};
const _cifra = '[Primeira Parte]\n'
    'G         D\n'
    'O sol desceu devagar\n'
    'Cavaco afinado\n'
    '\n'
    '[Refrão]\n'
    'Canta comigo';

late List<http.Request> _pedidos;
void Function(String)? _aoReceber;
String? _enderecoAssinado;
int _status = 200;
Map<String, Object?> _conteudo = {};

ApiTocaEssa _api() {
  _pedidos = [];
  return ApiTocaEssa(
    enderecoBase: 'http://teste',
    cliente: MockClient((pedido) async {
      _pedidos.add(pedido);
      if (_status == 404) {
        return http.Response(
            jsonEncode({'mensagem': 'O comando voltou para quem toca.'}), 404,
            headers: _json);
      }
      if (pedido.method == 'PUT') return http.Response('', 204);
      return http.Response(
          jsonEncode({'canal': 'c1', 'conteudo': _conteudo}), 200,
          headers: _json);
    }),
  );
}

Map<String, Object?> _musica(String titulo,
        {int linha = 0, int versao = 1, String texto = _cifra}) =>
    {
      'titulo': titulo,
      'texto': texto,
      'linha': linha,
      'versao': versao,
    };

Future<void> _abrir(WidgetTester tester) async {
  await tester.pumpWidget(MaterialApp(
    theme: TemaTocaEssa.escuro,
    home: ComandoDoAjudante(
      api: _api(),
      token: 'segredo',
      assinar: (endereco, aoReceber) {
        _enderecoAssinado = endereco;
        _aoReceber = aoReceber;
        return () {};
      },
      manterTelaAcesa: () => () {},
    ),
  ));
  await tester.pumpAndSettle();
}

Color? _corDe(WidgetTester tester, String texto) =>
    tester.widget<Text>(find.text(texto)).style?.color;

void main() {
  setUp(() {
    _status = 200;
    _conteudo = _musica('Fim de tarde');
  });

  testWidgets('mostra a letra da TV, sem acordes, com a linha da vez acesa',
      (tester) async {
    _conteudo = _musica('Fim de tarde', linha: 1);
    await _abrir(tester);

    expect(find.text('Fim de tarde'), findsOneWidget);
    expect(find.text('Refrão'), findsOneWidget);
    expect(find.text('G         D'), findsNothing);
    expect(_corDe(tester, 'Cavaco afinado'), CoresTocaEssa.texto);
    expect(_corDe(tester, 'O sol desceu devagar'), isNot(CoresTocaEssa.texto));
    expect(_pedidos.first.headers['Authorization'], 'Bearer segredo');
    expect(_enderecoAssinado, 'http://teste/api/publico/comando/c1/tempo-real');
  });

  testWidgets('tocar numa linha manda para a TV e acende na hora',
      (tester) async {
    await _abrir(tester);

    await tester.tap(find.text('Canta comigo'));
    await tester.pumpAndSettle();

    final enviada = _pedidos.singleWhere((p) => p.method == 'PUT');
    expect(enviada.url.path, '/api/publico/comando/linha');
    expect(jsonDecode(enviada.body), {'linha': 2});
    expect(_corDe(tester, 'Canta comigo'), CoresTocaEssa.texto);
  });

  testWidgets('música nova no celular do dono chega sozinha', (tester) async {
    await _abrir(tester);

    _conteudo = _musica('Lua de São Jorge',
        versao: 2, texto: 'Lua de São Jorge\nlua deslumbrante');
    _aoReceber!('linha:2:0');
    await tester.pumpAndSettle();

    expect(find.text('Lua de São Jorge'), findsWidgets);
    expect(find.text('lua deslumbrante'), findsOneWidget);
  });

  testWidgets('quando o dono retoma, avisa que o comando voltou',
      (tester) async {
    await _abrir(tester);

    _status = 404;
    await tester.tap(find.text('Canta comigo'));
    await tester.pumpAndSettle();

    expect(
        find.textContaining('O comando voltou para quem toca'), findsOneWidget);
  });

  testWidgets('sem música na TV, espera o dono abrir uma', (tester) async {
    _conteudo = {};
    await tester.pumpWidget(const SizedBox());
    _pedidos = [];
    await tester.pumpWidget(MaterialApp(
      home: ComandoDoAjudante(
        api: ApiTocaEssa(
          enderecoBase: 'http://teste',
          cliente: MockClient((_) async => http.Response(
              jsonEncode({'canal': 'c1', 'conteudo': null}), 200,
              headers: _json)),
        ),
        token: 'segredo',
        assinar: (_, __) => () {},
        manterTelaAcesa: () => () {},
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.textContaining('esperando a música'), findsOneWidget);
  });

  testWidgets('o link #/comando/ abre a tela do ajudante sem o início embaixo',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.binding.platformDispatcher.defaultRouteNameTestValue =
        '/comando/segredo';
    addTearDown(
        tester.binding.platformDispatcher.clearDefaultRouteNameTestValue);

    await tester.pumpWidget(TocaEssaApp(api: _api()));
    await tester.pump();

    expect(find.byType(ComandoDoAjudante), findsOneWidget);
    expect(
        tester.state<NavigatorState>(find.byType(Navigator)).canPop(), isFalse);
  });
}
