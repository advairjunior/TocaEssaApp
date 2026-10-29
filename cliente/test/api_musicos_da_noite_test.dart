import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:toca_essa_app/dominio/modelos.dart';
import 'package:toca_essa_app/dominio/musicos_da_noite.dart';
import 'package:toca_essa_app/infraestrutura/api_toca_essa.dart';

void main() {
  late List<http.Request> pedidos;

  ApiTocaEssa apiQueResponde(http.Response Function(http.Request) resposta) {
    pedidos = [];
    final api = ApiTocaEssa(
      enderecoBase: 'http://teste',
      cliente: MockClient((pedido) async {
        pedidos.add(pedido);
        return resposta(pedido);
      }),
    );
    api.definirTokenArtista('tk');
    return api;
  }

  http.Response json(Object? corpo, [int status = 200]) =>
      http.Response(jsonEncode(corpo), status,
          headers: {'content-type': 'application/json; charset=utf-8'});

  test('o dono gera o link do convite com o token dele', () async {
    final api = apiQueResponde((_) => json({'codigo': 'ABC123'}));

    final codigo = await api.gerarConvite('ev1');

    expect(codigo, 'ABC123');
    expect(pedidos.single.method, 'POST');
    expect(pedidos.single.url.path, '/api/apresentacoes/ev1/convite');
    expect(pedidos.single.headers['Authorization'], 'Bearer tk');
  });

  test('o dono vê e tira os músicos', () async {
    final api = apiQueResponde((pedido) => pedido.method == 'GET'
        ? json([
            {'artistaId': 'a1', 'nome': 'Advair', 'dono': true},
            {'artistaId': 'a2', 'nome': 'Bia', 'dono': false},
          ])
        : http.Response('', 204));

    final musicos = await api.listarMusicos('ev1');
    await api.tirarMusico('ev1', 'a2');

    expect(musicos.map((m) => (m.nome, m.dono)),
        [('Advair', true), ('Bia', false)]);
    expect(pedidos.last.method, 'DELETE');
    expect(pedidos.last.url.path, '/api/apresentacoes/ev1/musicos/a2');
  });

  test('quem abre o convite vê o evento e entra', () async {
    final api = apiQueResponde((pedido) => pedido.method == 'GET'
        ? json({
            'apresentacaoId': 'ev1',
            'evento': 'Resenha House',
            'dono': 'Advair',
            'data': '2026-10-30',
          })
        : http.Response('', 204));

    final convite = await api.verConvite('ABC123');
    await api.entrarPeloConvite('ABC123');

    expect((convite.evento, convite.dono), ('Resenha House', 'Advair'));
    expect(pedidos.last.method, 'POST');
    expect(pedidos.last.url.path, '/api/convites/ABC123');
  });

  test('convite que não vale avisa', () async {
    final api = apiQueResponde((_) =>
        json({'mensagem': 'Convite não encontrado. Peça um link novo.'}, 404));

    expect(api.verConvite('XYZ'), throwsA(isA<ConviteNaoEncontrado>()));
  });

  test('os eventos em que a conta toca como convidada', () async {
    final api = apiQueResponde((_) => json([
          {
            'apresentacaoId': 'ev1',
            'nome': 'Resenha House',
            'data': '2026-10-30',
            'local': 'Casa',
            'tipo': 'ResenhaEntreAmigos',
            'status': 'EmAndamento',
            'codigo': 'RSN482',
            'dono': 'Advair',
          }
        ]));

    final convites = await api.listarConvites();

    expect(pedidos.single.url.path, '/api/convites');
    final evento = convites.single;
    expect(evento.tipo, TipoApresentacao.resenhaEntreAmigos);
    expect(evento.status, StatusApresentacao.emAndamento);
    expect((evento.nome, evento.codigo, evento.dono),
        ('Resenha House', 'RSN482', 'Advair'));
    expect(evento.data, DateTime(2026, 10, 30));
  });

  test('a cifra da noite vem pela rota do evento', () async {
    final api = apiQueResponde((_) => json({
          'cifra': null,
          'urlSugerida': null,
          'urlPesquisa': 'https://busca',
          'texto': 'A  E\nQuando eu digo',
        }));

    final cifra = await api.consultarCifraDaNoite('ev1', 'Evidências', null);

    expect(pedidos.single.url.path, '/api/apresentacoes/ev1/cifras');
    expect(pedidos.single.url.queryParameters, {'musica': 'Evidências'});
    expect(cifra.texto, 'A  E\nQuando eu digo');
  });
}
