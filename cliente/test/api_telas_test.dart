import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:toca_essa_app/dominio/tela_da_tv.dart';
import 'package:toca_essa_app/infraestrutura/api_toca_essa.dart';

void main() {
  late List<http.Request> pedidos;

  ApiTocaEssa apiQueResponde(http.Response Function(http.Request) resposta) {
    pedidos = [];
    return ApiTocaEssa(
      enderecoBase: 'http://teste',
      cliente: MockClient((pedido) async {
        pedidos.add(pedido);
        return resposta(pedido);
      }),
    );
  }

  http.Response json(Object corpo, [int status = 200]) =>
      http.Response(jsonEncode(corpo), status,
          headers: {'content-type': 'application/json; charset=utf-8'});

  test('a TV nova recebe id, token e código sem conta', () async {
    final api = apiQueResponde(
        (_) => json({'id': 'tv1', 'token': 'segredo', 'codigo': 'K7Q2'}));

    final tv = await api.criarTv();

    expect(pedidos.single.method, 'POST');
    expect(pedidos.single.url.path, '/api/publico/telas');
    expect(pedidos.single.headers.containsKey('Authorization'), isFalse);
    expect((tv.id, tv.token, tv.codigo), ('tv1', 'segredo', 'K7Q2'));
  });

  test('a TV pergunta o que mostrar com o token dela', () async {
    final api = apiQueResponde((_) => json({
          'pareada': true,
          'codigo': null,
          'conteudo': {
            'titulo': 'Fim de tarde',
            'subtitulo': 'Turma',
            'texto': 'Canta comigo',
            'aSeguir': 'Lua',
            'codigo': 'RSN482',
            'linha': 3,
            'versao': 2,
          },
        }));

    final estado = await api.obterEstadoDaTv('segredo');

    expect(pedidos.single.url.path, '/api/publico/telas/eu');
    expect(pedidos.single.headers['Authorization'], 'Bearer segredo');
    expect(estado.pareada, isTrue);
    final conteudo = estado.conteudo!;
    expect((conteudo.titulo, conteudo.subtitulo, conteudo.aSeguir),
        ('Fim de tarde', 'Turma', 'Lua'));
    expect(
        (conteudo.codigo, conteudo.linha, conteudo.versao), ('RSN482', 3, 2));
  });

  test('TV esquecida pelo servidor vira TvDesconhecida', () async {
    final api =
        apiQueResponde((_) => json({'mensagem': 'TV não encontrada.'}, 404));

    expect(api.obterEstadoDaTv('velho'), throwsA(isA<TvDesconhecida>()));
  });

  test('o celular do dono conecta, manda a letra e a linha', () async {
    final api = apiQueResponde((pedido) =>
        pedido.url.path.endsWith('pareamento')
            ? json({'id': 'tv1', 'criadaEm': '2026-10-29T20:00:00Z'})
            : http.Response('', 204));
    api.definirTokenArtista('artista');

    await api.parearTv('k7q2');
    await api.mostrarNaTv(const ConteudoParaTv(
        titulo: 'Fim de tarde', texto: 'Canta', aSeguir: 'Lua', linha: 0));
    await api.irParaALinhaNaTv(4);
    await api.limparTv();

    expect(pedidos.map((p) => '${p.method} ${p.url.path}'), [
      'POST /api/artista/telas/pareamento',
      'PUT /api/artista/telas/conteudo',
      'PUT /api/artista/telas/conteudo/linha',
      'DELETE /api/artista/telas/conteudo',
    ]);
    expect(pedidos.every((p) => p.headers['Authorization'] == 'Bearer artista'),
        isTrue);
    expect(jsonDecode(pedidos[0].body), {'codigo': 'k7q2'});
    expect(jsonDecode(pedidos[1].body), {
      'titulo': 'Fim de tarde',
      'subtitulo': null,
      'texto': 'Canta',
      'aSeguir': 'Lua',
      'codigo': null,
      'linha': 0,
    });
    expect(jsonDecode(pedidos[2].body), {'linha': 4});
  });

  test('linha antes da música vira TvAindaSemMusica', () async {
    final api = apiQueResponde(
        (_) => json({'mensagem': 'A TV ainda não recebeu a música.'}, 409));
    api.definirTokenArtista('artista');

    expect(api.irParaALinhaNaTv(1), throwsA(isA<TvAindaSemMusica>()));
  });

  test('lista e desconecta as TVs da conta', () async {
    final api = apiQueResponde((pedido) => pedido.method == 'GET'
        ? json([
            {'id': 'tv1', 'criadaEm': '2026-10-29T20:00:00Z'},
          ])
        : http.Response('', 204));
    api.definirTokenArtista('artista');

    final tvs = await api.listarTvs();
    await api.desconectarTv('tv1');

    expect(tvs.single.id, 'tv1');
    expect(tvs.single.criadaEm, DateTime.utc(2026, 10, 29, 20));
    expect(pedidos.last.method, 'DELETE');
    expect(pedidos.last.url.path, '/api/artista/telas/tv1');
  });

  test('o tempo real da TV tem canal próprio', () {
    final api = ApiTocaEssa(enderecoBase: 'http://teste');

    expect(api.enderecoTempoRealDaTv('tv1'),
        'http://teste/api/publico/telas/tv1/tempo-real');
  });

  group('comando da TV', () {
    test('o dono passa, vê e retoma o comando', () async {
      final api = apiQueResponde((pedido) => switch (pedido.method) {
            'POST' => json({'id': 'c1', 'token': 'segredo'}),
            'GET' => json({'ativo': true}),
            _ => http.Response('', 204),
          });
      api.definirTokenArtista('artista');

      final comando = await api.passarComando();
      final ativo = await api.comandoAtivo();
      await api.retomarComando();

      expect((comando.id, comando.token), ('c1', 'segredo'));
      expect(ativo, isTrue);
      expect(pedidos.map((p) => (p.method, p.url.path)), [
        ('POST', '/api/artista/telas/comando'),
        ('GET', '/api/artista/telas/comando'),
        ('DELETE', '/api/artista/telas/comando'),
      ]);
      expect(pedidos.first.headers['Authorization'], 'Bearer artista');
    });

    test('o ajudante lê a letra e manda a linha com o token do link', () async {
      final api = apiQueResponde((pedido) => pedido.method == 'GET'
          ? json({
              'canal': 'c1',
              'conteudo': {
                'titulo': 'Fim de tarde',
                'texto': 'Canta comigo',
                'linha': 0,
                'versao': 2,
              },
            })
          : http.Response('', 204));

      final comando = await api.obterComando('segredo');
      await api.irParaALinhaPeloAjudante('segredo', 3);

      expect(comando.canal, 'c1');
      expect(comando.conteudo?.titulo, 'Fim de tarde');
      expect(pedidos.first.url.path, '/api/publico/comando');
      expect(pedidos.first.headers['Authorization'], 'Bearer segredo');
      expect(pedidos.last.url.path, '/api/publico/comando/linha');
      expect(jsonDecode(pedidos.last.body), {'linha': 3});
      expect(api.enderecoTempoRealDoComando('c1'),
          'http://teste/api/publico/comando/c1/tempo-real');
    });

    test('link retomado avisa que o comando voltou', () async {
      final api = apiQueResponde(
          (_) => json({'mensagem': 'O comando voltou para quem toca.'}, 404));

      expect(api.obterComando('velho'), throwsA(isA<ComandoEncerrado>()));
      expect(api.irParaALinhaPeloAjudante('velho', 1),
          throwsA(isA<ComandoEncerrado>()));
    });
  });

  test('o evento traz a versão e a linha', () {
    expect(EventoDaTv.ler('linha:3:6'), const EventoDaTv(versao: 3, linha: 6));
    expect(EventoDaTv.ler('conectado'), isNull);
    expect(EventoDaTv.ler('linha:x:1'), isNull);
  });
}
