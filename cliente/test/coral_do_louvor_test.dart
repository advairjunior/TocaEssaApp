import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:toca_essa_app/dominio/modelos.dart';
import 'package:toca_essa_app/infraestrutura/api_toca_essa.dart';
import 'package:toca_essa_app/telas/cifra_do_palco.dart';
import 'package:toca_essa_app/telas/roteiro_do_louvor.dart';
import 'package:toca_essa_app/telas/trechos_do_louvor.dart';
import 'package:toca_essa_app/tema/tema_toca_essa.dart';

Map<String, Object?> _parte(String tipo, String texto, List<String> cantores,
        {bool definida = true, bool coral = false}) =>
    {
      'tipo': tipo,
      'texto': texto,
      'cantores': cantores,
      'definida': definida,
      'coral': coral,
    };

// O coral canta o primeiro refrão (de Todos) e a estrofe da Ana, junto
// dela; o segundo refrão ainda não foi escalado.
final _hinoJson = {
  'itemId': 'h1',
  'titulo': '80 · Por Cristo, resgatado',
  'tom': 'G',
  'tocado': false,
  'temLetra': true,
  'partes': [
    _parte('Estrofe', 'Cristo Jesus, o santo Cordeiro', ['João']),
    _parte('Refrao', 'Por Cristo, resgatado', []),
    _parte('Estrofe', 'Preso estava na iniquidade', ['Ana'], coral: true),
    _parte('Refrao', 'Sirvo ao grande Deus', [], definida: false),
    _parte('Estrofe', 'Tem minha alma grande alegria', ['João']),
  ],
};

final _hino = HinoDoLouvor.deJson(_hinoJson);

// Bia está só no coral: não tem parte no microfone.
const _cantores = ['João', 'Ana', 'Bia'];

List<TrechoDaCifra> _trechosDe(String nome) =>
    trechosDoHino(_hino, cantores: _cantores, quemSou: nome);

Future<void> _abrirRoteiro(WidgetTester tester) async {
  final api = ApiTocaEssa(
    enderecoBase: 'http://teste',
    cliente: MockClient((requisicao) async => http.Response(
        jsonEncode({
          'nome': 'Louvor de sábado',
          'cantores': _cantores,
          'solistas': [
            {'nome': 'José', 'instrumento': 'sax'},
          ],
          'hinoAtualId': null,
          'hinos': [_hinoJson],
        }),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'})),
  );
  tester.view.physicalSize = const Size(430, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    theme: TemaTocaEssa.escuro,
    home: RoteiroDoLouvorTela(api: api, codigo: 'ABC123'),
  ));
  await tester.pumpAndSettle();
}

Future<void> _escolher(WidgetTester tester, String nome) async {
  await tester.tap(find.widgetWithText(OutlinedButton, nome));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('modelo', () {
    test('a parte diz se o coral canta junto de quem tem a parte', () {
      expect(_hino.partes[2].coral, isTrue);
      expect(_hino.partes[2].quemCanta, 'Ana + coral');
      expect(_hino.partes[0].quemCanta, 'João');
      expect(_hino.partes[1].quemCanta, 'Todos');
      expect(ParteDoHino.deJson({'tipo': 'Estrofe'}).coral, isFalse);
    });

    test('o coral canta as partes marcadas e as de Todos já escaladas', () {
      expect([for (final parte in _hino.partes) parte.doCoral],
          [false, true, true, false, false]);
      const solo = ParteDoHino(
          tipo: TipoDaParte.instrumental,
          texto: '',
          cantores: [],
          definida: true);
      expect(solo.doCoral, isFalse);
    });

    test('a configuração leva e traz o coral nos refrões', () {
      final configuracao =
          ConfiguracaoDaEscala.deJson({'coralNosRefroes': true});
      expect(configuracao.coralNosRefroes, isTrue);
      expect(configuracao.copiarCom(coralNosRefroes: false).paraJson(),
          containsPair('coralNosRefroes', false));
      expect(ConfiguracaoDaEscala.deJson(null).coralNosRefroes, isFalse);
    });

    test('marcar o coral numa parte vai para a rota do coral', () async {
      late http.Request enviada;
      final api = ApiTocaEssa(
        enderecoBase: 'http://teste',
        cliente: MockClient((requisicao) async {
          enviada = requisicao;
          return http.Response(
              jsonEncode({
                'cantores': <Object?>[],
                'placar': <Object?>[],
                'hinos': [_hinoJson],
              }),
              200,
              headers: {'content-type': 'application/json; charset=utf-8'});
        }),
      )..definirTokenArtista('token');

      final louvor = await api.marcarCoralDoLouvor('a1', 'h1', 2, true);

      expect(enviada.method, 'PUT');
      expect(enviada.url.path, '/api/apresentacoes/a1/louvor/coral');
      expect(enviada.headers['Authorization'], 'Bearer token');
      expect(jsonDecode(enviada.body),
          {'itemId': 'h1', 'indice': 2, 'coral': true});
      expect(louvor.hinos.single.partes[2].coral, isTrue);
    });
  });

  group('quem não está no microfone canta no coral', () {
    test('quem só está no coral vê a vez dele e o resto apagado', () {
      final daBia = _trechosDe('Bia');

      expect([for (final trecho in daBia) trecho.destaque],
          [false, true, true, false, false]);
      expect([for (final trecho in daBia) trecho.apagado],
          [true, false, false, true, true]);
      expect([for (final trecho in daBia) trecho.rotulo], [
        'JOÃO',
        'TODOS · SUA VEZ',
        'ANA + CORAL · SUA VEZ',
        'TODOS',
        'JOÃO',
      ]);
      expect([for (final trecho in daBia) trecho.aviso],
          ['coral entra', null, 'depois, para', null, null]);
    });

    test('quem tem a parte no microfone canta no microfone, não no coral', () {
      final daAna = _trechosDe('Ana');

      expect(daAna[2].rotulo, 'ANA + CORAL · SUA VEZ');
      expect(daAna[1].rotulo, 'TODOS · SUA VEZ');
      expect([for (final trecho in daAna) trecho.apagado],
          [true, false, false, true, true]);
      expect([for (final trecho in daAna) trecho.aviso],
          ['coral entra', null, null, null, null]);
    });

    test('quem sai do coral e volta ao microfone é avisado', () {
      final doJoao = _trechosDe('João');

      expect(doJoao[2].rotulo, 'ANA + CORAL · SUA VEZ');
      expect([for (final trecho in doJoao) trecho.aviso],
          [null, null, 'depois, para', 'você é o próximo', null]);
    });

    test('quem só toca e quem só acompanha não entram no coral', () {
      final doJose = _trechosDe('José');
      final deNinguem = _trechosDe('');

      expect(doJose.any((trecho) => trecho.destaque), isFalse);
      expect(doJose.any((trecho) => trecho.apagado), isFalse);
      expect(deNinguem.any((trecho) => trecho.apagado), isFalse);
      expect(partesNoCoral(_hino, 'José', cantores: _cantores), isNull);
    });

    test('as partes no coral saem pelo nome, sem as do microfone', () {
      expect(partesNoCoral(_hino, 'Bia', cantores: _cantores),
          'Refrão e Estrofe 2');
      expect(partesNoCoral(_hino, 'Ana', cantores: _cantores), 'Refrão');
      expect(partesDaPessoa(_hino, 'Ana'), 'Estrofe 2');
    });

    test('vários refrões no coral saem juntos, sem repetir "Refrão"', () {
      ParteDoHino parte(TipoDaParte tipo, List<String> cantores,
              {bool coral = false}) =>
          ParteDoHino(
              tipo: tipo,
              texto: 'x',
              cantores: cantores,
              definida: true,
              coral: coral);
      HinoDoLouvor hino(List<ParteDoHino> partes) => HinoDoLouvor(
          itemId: 'h9',
          titulo: 'Hino',
          tom: null,
          tocado: false,
          temLetra: true,
          partes: partes);
      final tresRefroes = hino([
        parte(TipoDaParte.estrofe, ['João']),
        parte(TipoDaParte.refrao, ['Ana'], coral: true),
        parte(TipoDaParte.estrofe, ['Ana'], coral: true),
        parte(TipoDaParte.refrao, ['João'], coral: true),
        parte(TipoDaParte.refrao, []),
      ]);

      expect(partesNoCoral(tresRefroes, 'Bia', cantores: _cantores),
          'todos os refrões e Estrofe 2');
      expect(partesNoCoral(tresRefroes, 'Ana', cantores: _cantores),
          '2 refrões');
    });
  });

  group('roteiro', () {
    testWidgets('quem é do coral vê onde entra e onde para', (tester) async {
      await _abrirRoteiro(tester);
      await _escolher(tester, 'Bia');

      expect(find.textContaining('Suas partes'), findsNothing);
      expect(find.text('No coral: Refrão e Estrofe 2'), findsOneWidget);
      expect(find.text('ANA + CORAL · SUA VEZ'), findsOneWidget);
      expect(find.text('coral entra'), findsOneWidget);
      expect(find.text('depois, para'), findsOneWidget);
    });

    testWidgets('quem canta no microfone vê também o coral', (tester) async {
      await _abrirRoteiro(tester);
      await _escolher(tester, 'Ana');

      expect(find.text('Suas partes: Estrofe 2'), findsOneWidget);
      expect(find.text('No coral: Refrão'), findsOneWidget);
    });

    testWidgets('Meus hinos traz os hinos com coral da pessoa', (tester) async {
      await _abrirRoteiro(tester);
      await _escolher(tester, 'Bia');

      await tester.tap(find.byTooltip('Meus hinos'));
      await tester.pumpAndSettle();

      expect(find.text('Hinos de Bia'), findsOneWidget);
      expect(find.text('2 partes em 1 hino'), findsOneWidget);
      expect(find.text('coral: Refrão e Estrofe 2 · Tom G'), findsOneWidget);
    });

    testWidgets('a lista de hinos diz onde a pessoa canta no coral',
        (tester) async {
      await _abrirRoteiro(tester);
      await _escolher(tester, 'Ana');

      await tester.tap(find.byTooltip('Lista de hinos'));
      await tester.pumpAndSettle();

      expect(find.text('Tom G · você canta Estrofe 2 · coral: Refrão'),
          findsOneWidget);
    });
  });
}
