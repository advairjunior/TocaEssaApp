import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:toca_essa_app/dominio/modelos.dart';
import 'package:toca_essa_app/infraestrutura/api_toca_essa.dart';

const _louvorJson = {
  'cantores': ['João', 'Ana'],
  'placar': [
    {'nome': 'João', 'estrofes': 1},
    {'nome': 'Ana', 'estrofes': 1},
  ],
  'hinos': [
    {
      'itemId': 'h1',
      'titulo': '80 · Por Cristo, resgatado',
      'tom': 'G',
      'tocado': false,
      'temLetra': true,
      'partes': [
        {
          'tipo': 'Estrofe',
          'texto': 'Cristo Jesus',
          'cantores': ['João'],
          'escolhidaAMao': false,
        },
        {
          'tipo': 'Refrao',
          'texto': 'Por Cristo, resgatado',
          'cantores': <String>[],
          'escolhidaAMao': true,
        },
        {
          'tipo': 'Instrumental',
          'texto': 'G   D',
          'cantores': <String>[],
          'escolhidaAMao': false,
          'nome': 'Solo sax',
          'vezes': 2,
        },
      ],
    },
  ],
};

void main() {
  test('o tipo Louvor vai e volta do servidor', () {
    expect(TipoApresentacao.deJson('Louvor'), TipoApresentacao.louvor);
    expect(TipoApresentacao.louvor.paraJson, 'Louvor');
    expect(TipoApresentacao.louvor.rotuloCurto, 'Louvor');
    expect(TipoApresentacao.deJson('ResenhaEntreAmigos'),
        TipoApresentacao.resenhaEntreAmigos);
    expect(TipoApresentacao.deJson('Publica'), TipoApresentacao.publica);
  });

  test('o louvor do artista traz cantores, placar e partes', () async {
    final requisicoes = <http.Request>[];
    final api = ApiTocaEssa(
      enderecoBase: 'http://teste',
      cliente: MockClient((requisicao) async {
        requisicoes.add(requisicao);
        return http.Response(jsonEncode(_louvorJson), 200,
            headers: {'content-type': 'application/json; charset=utf-8'});
      }),
    )..definirTokenArtista('token');

    final louvor = await api.obterLouvor('a1');
    await api.definirCantoresDoLouvor('a1', ['João', 'Ana']);
    await api.escolherParteDoLouvor('a1', 'h1', 2, ['Ana']);
    await api.escolherParteDoLouvor('a1', 'h1', 0, null);

    expect(louvor.cantores, ['João', 'Ana']);
    expect(louvor.placar.first.nome, 'João');
    expect(louvor.placar.first.estrofes, 1);
    final hino = louvor.hinos.single;
    expect(hino.titulo, '80 · Por Cristo, resgatado');
    expect(hino.tom, 'G');
    expect(hino.temLetra, isTrue);
    expect(hino.partes.first.tipo, TipoDaParte.estrofe);
    expect(hino.partes.first.quemCanta, 'João');
    expect(hino.partes[1].tipo, TipoDaParte.refrao);
    expect(hino.partes[1].quemCanta, 'Todos');
    expect(hino.partes[1].escolhidaAMao, isTrue);
    expect(hino.partes.last.tipo, TipoDaParte.instrumental);
    expect(hino.partes.last.nome, 'Solo sax');
    expect(hino.partes.last.vezes, 2);
    expect(hino.partes.first.vezes, 1);

    expect(requisicoes[0].url.path, '/api/apresentacoes/a1/louvor');
    expect(requisicoes[0].headers['Authorization'], 'Bearer token');
    expect(requisicoes[1].method, 'PUT');
    expect(requisicoes[1].url.path, '/api/apresentacoes/a1/louvor/cantores');
    expect(jsonDecode(requisicoes[1].body), {
      'nomes': ['João', 'Ana'],
    });
    expect(requisicoes[2].url.path, '/api/apresentacoes/a1/louvor/partes');
    expect(jsonDecode(requisicoes[2].body), {
      'itemId': 'h1',
      'indice': 2,
      'cantores': ['Ana'],
    });
    expect(jsonDecode(requisicoes[3].body)['cantores'], isNull);
  });

  test('o roteiro é lido pelo código, sem token', () async {
    late http.Request pedida;
    final api = ApiTocaEssa(
      enderecoBase: 'http://teste',
      cliente: MockClient((requisicao) async {
        pedida = requisicao;
        return http.Response(
            jsonEncode({
              'nome': 'Louvor de sábado',
              'hinoAtualId': 'h1',
              ..._louvorJson,
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'});
      }),
    );

    final roteiro = await api.obterRoteiroDoLouvor(' abc123 ');

    expect(pedida.url.path, '/api/publico/apresentacoes/ABC123/roteiro');
    expect(pedida.headers['Authorization'], isNull);
    expect(roteiro.nome, 'Louvor de sábado');
    expect(roteiro.hinoAtualId, 'h1');
    expect(roteiro.cantores, ['João', 'Ana']);
    expect(roteiro.hinos.single.partes, hasLength(3));
  });
}
