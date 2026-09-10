import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:toca_essa_app/dominio/modelos.dart';
import 'package:toca_essa_app/infraestrutura/api_toca_essa.dart';
import 'package:toca_essa_app/telas/cartao_pedido_artista.dart';
import 'package:toca_essa_app/telas/fila_musical_artista.dart';

void main() {
  test('consulta cifra codifica a busca e autentica a conta artistica',
      () async {
    late http.Request recebida;
    final api = ApiTocaEssa(
      enderecoBase: 'https://tocaessa.test',
      cliente: MockClient((requisicao) async {
        recebida = requisicao;
        return http.Response(
          jsonEncode({
            'cifra': null,
            'urlSugerida':
                'https://www.cifraclub.com.br/chitaozinho-e-xororo/evidencias/',
            'urlPesquisa':
                'https://www.google.com/search?q=site%3Acifraclub.com.br+Evidencias',
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    )..definirTokenArtista('token-artista');

    final resultado =
        await api.consultarCifra('Evidências', 'Chitãozinho & Xororó');

    expect(recebida.method, 'GET');
    expect(recebida.headers['Authorization'], 'Bearer token-artista');
    expect(recebida.url.path, '/api/artista/cifras/consulta');
    expect(recebida.url.queryParameters, {
      'musica': 'Evidências',
      'artista': 'Chitãozinho & Xororó',
    });
    expect(resultado.cifra, isNull);
    expect(resultado.urlSugerida,
        'https://www.cifraclub.com.br/chitaozinho-e-xororo/evidencias/');
  });

  test('salva lista e remove cifra usando o contrato da API', () async {
    final requisicoes = <http.Request>[];
    final api = ApiTocaEssa(
      enderecoBase: 'https://tocaessa.test',
      cliente: MockClient((requisicao) async {
        requisicoes.add(requisicao);
        if (requisicao.method == 'PUT') {
          return http.Response(_cifraJson, 200,
              headers: {'content-type': 'application/json'});
        }
        if (requisicao.method == 'GET') {
          return http.Response('[$_cifraJson]', 200,
              headers: {'content-type': 'application/json'});
        }
        return http.Response('', 204);
      }),
    )..definirTokenArtista('token-artista');

    final salva = await api.salvarCifra(
      'Evidências',
      'Chitãozinho & Xororó',
      'https://www.cifraclub.com.br/chitaozinho-e-xororo/evidencias/',
    );
    final lista = await api.listarCifras();
    await api.removerCifra(salva.id);

    expect(salva.fonte, 'www.cifraclub.com.br');
    expect(lista.single.id, '11111111-1111-1111-1111-111111111111');
    expect(requisicoes.map((item) => item.method), ['PUT', 'GET', 'DELETE']);
    expect(requisicoes.last.url.path,
        '/api/artista/cifras/11111111-1111-1111-1111-111111111111');
    expect(
        requisicoes.every(
            (item) => item.headers['Authorization'] == 'Bearer token-artista'),
        isTrue);
    expect(jsonDecode(requisicoes.first.body), {
      'musica': 'Evidências',
      'artista': 'Chitãozinho & Xororó',
      'url': 'https://www.cifraclub.com.br/chitaozinho-e-xororo/evidencias/',
    });
  });

  testWidgets('cartao oferece cifra apenas para pedido musical',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Column(children: [
          CartaoPedidoArtista(
            pedido: _pedido(),
            alterar: (_) {},
            abrirCifra: () {},
            escolherCifra: () {},
          ),
          CartaoPedidoArtista(
            pedido: _pedido(tipo: TipoPedido.alo),
            alterar: (_) {},
            abrirCifra: () {},
            escolherCifra: () {},
          ),
        ]),
      ),
    ));

    expect(find.text('Abrir cifra'), findsOneWidget);
    expect(find.byTooltip('Escolher ou trocar cifra'), findsOneWidget);
  });

  testWidgets('fila abre cifra salva diretamente sem recarregar pedidos',
      (tester) async {
    var consultasDaFila = 0;
    Uri? aberta;
    final api = ApiTocaEssa(
      enderecoBase: 'https://tocaessa.test',
      cliente: MockClient((requisicao) async {
        if (requisicao.url.path.endsWith('/pedidos')) {
          consultasDaFila++;
          return http.Response('[$_pedidoJson]', 200);
        }
        return http.Response(
          '{"cifra":$_cifraJson,"urlSugerida":null,'
          '"urlPesquisa":"https://www.google.com/search?q=Evidencias"}',
          200,
        );
      }),
    )..definirTokenArtista('token-artista');

    await tester.pumpWidget(MaterialApp(
      home: FilaMusicalArtista(
        api: api,
        apresentacao: _apresentacao(),
        prepararAbertura: () => (url) async => aberta = url,
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Abrir cifra'));
    await tester.pumpAndSettle();

    expect(aberta.toString(),
        'https://www.cifraclub.com.br/chitaozinho-e-xororo/evidencias/');
    expect(consultasDaFila, 1);
  });

  testWidgets('fila confirma sugestao quando ainda nao existe cifra',
      (tester) async {
    var salvamentos = 0;
    Uri? aberta;
    final api = ApiTocaEssa(
      enderecoBase: 'https://tocaessa.test',
      cliente: MockClient((requisicao) async {
        if (requisicao.url.path.endsWith('/pedidos')) {
          return http.Response('[$_pedidoJson]', 200);
        }
        if (requisicao.method == 'PUT') {
          salvamentos++;
          return http.Response(_cifraJson, 200);
        }
        return http.Response(
          '{"cifra":null,'
          '"urlSugerida":"https://www.cifraclub.com.br/chitaozinho-e-xororo/evidencias/",'
          '"urlPesquisa":"https://www.google.com/search?q=Evidencias"}',
          200,
        );
      }),
    )..definirTokenArtista('token-artista');

    await tester.pumpWidget(MaterialApp(
      home: FilaMusicalArtista(
        api: api,
        apresentacao: _apresentacao(),
        abrirUrl: (url) async => aberta = url,
        prepararAbertura: () => (url) async {},
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Abrir cifra'));
    await tester.pumpAndSettle();
    expect(find.text('Escolher cifra'), findsOneWidget);
    await tester.tap(find.text('Abrir sugestão'));
    await tester.pumpAndSettle();

    expect(salvamentos, 0);
    expect(aberta, isNotNull);
    expect(find.text('Escolher cifra'), findsOneWidget);

    await tester.tap(find.text('Confirmar cifra'));
    await tester.pumpAndSettle();

    expect(salvamentos, 1);
    expect(find.text('Escolher cifra'), findsNothing);
  });
}

Apresentacao _apresentacao() => Apresentacao(
      id: '33333333-3333-3333-3333-333333333333',
      nome: 'Resenha',
      data: DateTime(2026, 9, 10),
      local: 'Casa',
      codigo: 'ABC123',
      perfilArtistico: const PerfilArtistico(
        id: '22222222-2222-2222-2222-222222222222',
        nomeArtistico: 'Duo Aurora',
      ),
      pedidosAbertos: true,
      status: StatusApresentacao.emAndamento,
      tipo: TipoApresentacao.resenhaEntreAmigos,
    );

PedidoMusical _pedido({TipoPedido tipo = TipoPedido.musica}) => PedidoMusical(
      id: '44444444-4444-4444-4444-444444444444',
      apresentacaoId: '33333333-3333-3333-3333-333333333333',
      musica: tipo == TipoPedido.alo ? 'Alô' : 'Evidências',
      artista: tipo == TipoPedido.alo ? null : 'Chitãozinho & Xororó',
      nomeSolicitante: 'Ana',
      status: StatusPedidoMusical.aguardando,
      criadoEm: DateTime.utc(2026, 9, 10, 12),
      tipo: tipo,
      destinatarioAlo: tipo == TipoPedido.alo ? 'João' : null,
    );

const _cifraJson = '''
{
  "id":"11111111-1111-1111-1111-111111111111",
  "artistaId":"22222222-2222-2222-2222-222222222222",
  "musica":"Evidências",
  "artista":"Chitãozinho & Xororó",
  "url":"https://www.cifraclub.com.br/chitaozinho-e-xororo/evidencias/",
  "fonte":"www.cifraclub.com.br",
  "criadaEm":"2026-09-10T12:00:00Z",
  "atualizadaEm":"2026-09-10T12:00:00Z"
}
''';

const _pedidoJson = '''
{
  "id":"44444444-4444-4444-4444-444444444444",
  "apresentacaoId":"33333333-3333-3333-3333-333333333333",
  "musica":"Evidências",
  "artista":"Chitãozinho & Xororó",
  "nomeSolicitante":"Ana",
  "status":"Aguardando",
  "posicao":null,
  "criadoEm":"2026-09-10T12:00:00Z",
  "tipo":"Musica"
}
''';
