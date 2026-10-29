import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:toca_essa_app/infraestrutura/api_toca_essa.dart';
import 'package:toca_essa_app/infraestrutura/link_publico.dart';
import 'package:toca_essa_app/main.dart';
import 'package:toca_essa_app/telas/tela_da_tv.dart';
import 'package:toca_essa_app/tema/tema_toca_essa.dart';

const _json = {'content-type': 'application/json; charset=utf-8'};
const _cifra = '[Primeira Parte]\n'
    'G         D\n'
    'O sol desceu devagar\n'
    'Cavaco afinado\n'
    '\n'
    '[Refrão]\n'
    'Canta comigo\n'
    'Ninguém fica de fora';

Map<String, Object?> _estado = {};
void Function(String)? _aoReceber;
var _telaAcesa = 0;

Future<void> _abrir(WidgetTester tester, Map<String, Object?> estado) async {
  SharedPreferences.setMockInitialValues({'tv_token': 't1', 'tv_id': 'tv1'});
  _estado = estado;
  final api = ApiTocaEssa(
    enderecoBase: 'http://teste',
    cliente: MockClient(
        (_) async => http.Response(jsonEncode(_estado), 200, headers: _json)),
  );
  tester.view.physicalSize = const Size(1920, 1080);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    theme: TemaTocaEssa.escuro,
    home: TelaDaTv(
      api: api,
      assinar: (_, aoReceber) {
        _aoReceber = aoReceber;
        return () {};
      },
      manterTelaAcesa: () {
        _telaAcesa++;
        return () {};
      },
    ),
  ));
  await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 50)));
  await tester.pump();
}

Map<String, Object?> _tocando({int linha = 0}) => {
      'pareada': true,
      'conteudo': <String, Object?>{
        'titulo': 'Fim de tarde',
        'subtitulo': 'Turma da Resenha',
        'texto': _cifra,
        'aSeguir': 'Lua de São Jorge',
        'codigo': 'RSN482',
        'linha': linha,
        'versao': 1,
      },
    };

Color? _corDe(WidgetTester tester, String texto) =>
    tester.widget<Text>(find.text(texto)).style?.color ??
    DefaultTextStyle.of(tester.element(find.text(texto))).style.color;

void main() {
  testWidgets('o endereço #/tv abre a tela da TV', (tester) async {
    SharedPreferences.setMockInitialValues({'tv_token': 't1', 'tv_id': 'tv1'});
    final api = ApiTocaEssa(
      enderecoBase: 'http://teste',
      cliente: MockClient((_) async => http.Response(
          jsonEncode({'pareada': false, 'codigo': 'K7Q2'}), 200,
          headers: _json)),
    );
    await tester.pumpWidget(TocaEssaApp(api: api));
    await tester.pump();

    tester.state<NavigatorState>(find.byType(Navigator)).pushNamed('/tv');
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.byType(TelaDaTv), findsOneWidget);
  });

  testWidgets('TV nova mostra o código grande e como conectar', (tester) async {
    await _abrir(tester, {'pareada': false, 'codigo': 'K7Q2'});

    expect(find.text('K7Q2'), findsOneWidget);
    expect(find.textContaining('Conectar TV'), findsOneWidget);
    expect(_telaAcesa, 1);
  });

  testWidgets('conectada sem música, espera a música', (tester) async {
    await _abrir(tester, {'pareada': true, 'conteudo': null});

    expect(find.textContaining('esperando a música'), findsOneWidget);
  });

  testWidgets('mostra a parte da linha, sem acordes, com a linha da vez acesa',
      (tester) async {
    await _abrir(tester, _tocando(linha: 1));

    expect(find.text('Fim de tarde'), findsOneWidget);
    expect(find.text('Turma da Resenha'), findsOneWidget);
    expect(find.text('RSN482'), findsOneWidget);
    expect(find.text('Primeira Parte'), findsOneWidget);
    expect(find.text('Cavaco afinado'), findsOneWidget);
    expect(find.text('G         D'), findsNothing);
    expect(find.text('Canta comigo'), findsNothing);
    expect(find.textContaining('Refrão: Canta comigo'), findsOneWidget);
    expect(find.text('Lua de São Jorge'), findsOneWidget);
    expect(_corDe(tester, 'Cavaco afinado'), CoresTocaEssa.texto);
    expect(_corDe(tester, 'O sol desceu devagar'), isNot(CoresTocaEssa.texto));
  });

  testWidgets('o QR da resenha fica no canto para a galera pedir',
      (tester) async {
    await _abrir(tester, _tocando());

    final qr = tester.widget<QrImageView>(find.byType(QrImageView));
    expect(qr.semanticsLabel, linkPublicoDoShow('RSN482'));
    expect(find.text('Aponte a câmera para pedir'), findsOneWidget);
  });

  testWidgets('sem código, sem QR', (tester) async {
    final estado = _tocando();
    (estado['conteudo'] as Map<String, Object?>)['codigo'] = null;

    await _abrir(tester, estado);

    expect(find.byType(QrImageView), findsNothing);
  });

  testWidgets('a linha que chega pelo tempo real troca a parte',
      (tester) async {
    await _abrir(tester, _tocando());

    _aoReceber!('linha:1:3');
    await tester.pumpAndSettle();

    expect(find.text('Refrão'), findsOneWidget);
    expect(find.text('Ninguém fica de fora'), findsOneWidget);
    expect(_corDe(tester, 'Ninguém fica de fora'), CoresTocaEssa.texto);
    expect(find.textContaining('Fim da música'), findsOneWidget);
  });

  testWidgets('cifra sem letra mostra só o título', (tester) async {
    final estado = _tocando();
    (estado['conteudo'] as Map<String, Object?>)['texto'] = 'G D Em C';

    await _abrir(tester, estado);

    expect(find.text('Fim de tarde'), findsWidgets);
    expect(find.textContaining('Sem letra'), findsOneWidget);
  });
}
