import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:toca_essa_app/infraestrutura/api_toca_essa.dart';
import 'package:toca_essa_app/telas/controle_da_tv.dart';

const _json = {'content-type': 'application/json; charset=utf-8'};

Map<String, Object?> _conteudo({int linha = 0, int versao = 1}) => {
      'titulo': 'Fim de tarde',
      'subtitulo': 'Turma',
      'texto': 'Canta comigo\nNinguém fica de fora',
      'aSeguir': 'Lua',
      'codigo': 'RSN482',
      'linha': linha,
      'versao': versao,
    };

Map<String, Object?> _story(String id, String tipo, String conteudo) => {
      'id': id,
      'tipo': tipo,
      'nome': 'Carla',
      'criadoEm': '2026-10-29T20:00:00Z',
      'tipoDeConteudo': conteudo,
      'url': '/api/publico/stories/$id',
    };

class _Servidor {
  var tvsCriadas = 0;
  var consultas = 0;
  Map<String, Object?> estado = {'pareada': false, 'codigo': 'K7Q2'};
  var esquecida = false;

  late final api = ApiTocaEssa(
    enderecoBase: 'http://teste',
    cliente: MockClient((pedido) async {
      if (pedido.method == 'POST') {
        tvsCriadas++;
        esquecida = false;
        return http.Response(
            jsonEncode({
              'id': 'tv$tvsCriadas',
              'token': 't$tvsCriadas',
              'codigo': 'K7Q2'
            }),
            200,
            headers: _json);
      }
      if (pedido.url.path == '/api/publico/apresentacoes/RSN482/stories') {
        return http.Response(
            jsonEncode([
              _story('f1', 'Foto', 'image/jpeg'),
              _story('v1', 'Video', 'video/mp4'),
            ]),
            200,
            headers: _json);
      }
      consultas++;
      if (esquecida) return http.Response('{}', 404, headers: _json);
      return http.Response(jsonEncode(estado), 200, headers: _json);
    }),
  );
}

class _TempoRealFalso {
  String? endereco;
  void Function(String dado)? aoReceber;
  var encerrada = false;

  AssinaturaDaTv assinar(String endereco, void Function(String) aoReceber) {
    this.endereco = endereco;
    this.aoReceber = aoReceber;
    return () => encerrada = true;
  }
}

void main() {
  late _Servidor servidor;
  late _TempoRealFalso tempoReal;
  late ControleDaTv controle;

  Future<void> comecar(WidgetTester tester) async {
    controle = ControleDaTv(
        api: servidor.api,
        assinar: tempoReal.assinar,
        espera: const Duration(seconds: 3));
    await tester.runAsync(controle.comecar);
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    servidor = _Servidor();
    tempoReal = _TempoRealFalso();
  });

  tearDown(() => controle.dispose());

  testWidgets('TV nova mostra o código e guarda o token', (tester) async {
    await comecar(tester);

    expect(controle.codigo, 'K7Q2');
    expect(controle.pareada, isFalse);
    final guardadas = await SharedPreferences.getInstance();
    expect(guardadas.getString('tv_token'), 't1');
    expect(guardadas.getString('tv_id'), 'tv1');
  });

  testWidgets('TV que já tinha token não pede outra', (tester) async {
    SharedPreferences.setMockInitialValues({'tv_token': 't9', 'tv_id': 'tv9'});

    await comecar(tester);

    expect(servidor.tvsCriadas, 0);
    expect(controle.codigo, 'K7Q2');
  });

  testWidgets('enquanto espera o código, pergunta de novo até ser conectada',
      (tester) async {
    await comecar(tester);
    servidor.estado = {'pareada': true, 'conteudo': null};

    await tester
        .runAsync(() => Future.delayed(const Duration(milliseconds: 10)));
    await tester.runAsync(controle.consultar);

    expect(controle.pareada, isTrue);
    expect(controle.conteudo, isNull);
    expect(tempoReal.endereco, 'http://teste/api/publico/telas/tv1/tempo-real');
  });

  testWidgets('conectada, mostra a música e acompanha a linha pelo tempo real',
      (tester) async {
    servidor.estado = {'pareada': true, 'conteudo': _conteudo()};
    await comecar(tester);
    expect(controle.conteudo?.titulo, 'Fim de tarde');
    final consultasAntes = servidor.consultas;

    tempoReal.aoReceber!('linha:1:1');

    expect(controle.conteudo?.linha, 1);
    expect(servidor.consultas, consultasAntes);
    // A linha 1 é a última: o intervalo chega depois.
    await tester.pump(const Duration(seconds: 21));
    await tester.pump();
  });

  testWidgets('música nova (outra versão) busca o conteúdo de novo',
      (tester) async {
    servidor.estado = {'pareada': true, 'conteudo': _conteudo()};
    await comecar(tester);
    servidor.estado = {
      'pareada': true,
      'conteudo': {..._conteudo(versao: 2), 'titulo': 'Lua'},
    };

    await tester.runAsync(() async {
      tempoReal.aoReceber!('linha:2:0');
      await Future.delayed(const Duration(milliseconds: 50));
    });

    expect(controle.conteudo?.titulo, 'Lua');
    expect(controle.conteudo?.versao, 2);
  });

  testWidgets('TV desconectada ou esquecida pede um código novo',
      (tester) async {
    servidor.estado = {'pareada': true, 'conteudo': _conteudo()};
    await comecar(tester);
    servidor.esquecida = true;
    servidor.estado = {'pareada': false, 'codigo': 'K7Q2'};

    await tester.runAsync(controle.consultar);

    expect(servidor.tvsCriadas, 2);
    expect(controle.pareada, isFalse);
    expect(controle.codigo, 'K7Q2');
    expect(tempoReal.encerrada, isTrue);
    expect((await SharedPreferences.getInstance()).getString('tv_token'), 't2');
  });

  group('entre uma música e outra', () {
    testWidgets(
        'vinte segundos na última linha, a TV vai para o intervalo '
        'com as fotos dos stories', (tester) async {
      servidor.estado = {'pareada': true, 'conteudo': _conteudo()};
      await comecar(tester);

      tempoReal.aoReceber!('linha:1:1');
      await tester.pump(const Duration(seconds: 19));
      expect(controle.intervalo, isFalse);
      await tester.pump(const Duration(seconds: 2));
      await tester.pump();

      expect(controle.intervalo, isTrue);
      expect(controle.fotos.map((foto) => foto.id), ['f1']);
    });

    testWidgets('linha antes da última não leva ao intervalo', (tester) async {
      servidor.estado = {'pareada': true, 'conteudo': _conteudo()};
      await comecar(tester);

      tempoReal.aoReceber!('linha:1:0');
      await tester.pump(const Duration(seconds: 30));

      expect(controle.intervalo, isFalse);
    });

    testWidgets('a próxima música tira a TV do intervalo', (tester) async {
      servidor.estado = {'pareada': true, 'conteudo': _conteudo()};
      await comecar(tester);
      tempoReal.aoReceber!('linha:1:1');
      await tester.pump(const Duration(seconds: 21));
      await tester.pump();
      expect(controle.intervalo, isTrue);

      tempoReal.aoReceber!('linha:2:0');

      expect(controle.intervalo, isFalse);
    });

    testWidgets('voltar uma linha também sai do intervalo', (tester) async {
      servidor.estado = {'pareada': true, 'conteudo': _conteudo()};
      await comecar(tester);
      tempoReal.aoReceber!('linha:1:1');
      await tester.pump(const Duration(seconds: 21));
      await tester.pump();

      tempoReal.aoReceber!('linha:1:0');

      expect(controle.intervalo, isFalse);
    });
  });
}
