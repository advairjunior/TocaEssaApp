import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:toca_essa_app/infraestrutura/api_toca_essa.dart';

void main() {
  test('consulta cifra codifica a busca e autentica a conta artistica', () async {
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
    expect(requisicoes.every((item) =>
        item.headers['Authorization'] == 'Bearer token-artista'), isTrue);
    expect(jsonDecode(requisicoes.first.body), {
      'musica': 'Evidências',
      'artista': 'Chitãozinho & Xororó',
      'url':
          'https://www.cifraclub.com.br/chitaozinho-e-xororo/evidencias/',
    });
  });
}

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
