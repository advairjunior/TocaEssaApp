import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:toca_essa_app/infraestrutura/api_toca_essa.dart';
import 'package:toca_essa_app/infraestrutura/midia_do_story.dart';
import 'package:toca_essa_app/telas/stories_do_show.dart';

const _json = {'content-type': 'application/json; charset=utf-8'};

class _SeletorFalso implements SeletorDeMidia {
  _SeletorFalso(this.midia);
  final MidiaEscolhida? midia;
  final pedidos = <String>[];

  @override
  Future<MidiaEscolhida?> gravarVideo() async {
    pedidos.add('video');
    return midia;
  }

  @override
  Future<MidiaEscolhida?> tirarFoto() async {
    pedidos.add('foto');
    return midia;
  }

  @override
  Future<MidiaEscolhida?> escolherDaGaleria() async {
    pedidos.add('galeria');
    return midia;
  }
}

class _EnviadorFalso implements EnviadorDeArquivo {
  _EnviadorFalso({this.falhasAntes = 0});
  int falhasAntes;
  final enviados = <(Uri, Map<String, String>)>[];

  @override
  Future<void> enviar(Uri url, Map<String, String> cabecalhos, XFile arquivo,
      void Function(double fracao) progresso) async {
    progresso(.5);
    if (falhasAntes > 0) {
      falhasAntes--;
      throw const FalhaNaApi('Sem internet.');
    }
    enviados.add((url, cabecalhos));
    progresso(1);
  }
}

MidiaEscolhida _foto({int tamanho = 1000}) => MidiaEscolhida(
      arquivo: XFile.fromData(Uint8List(tamanho), name: 'foto.jpg'),
      tipoDeConteudo: 'image/jpeg',
      tamanho: tamanho,
    );

MidiaEscolhida _video(Duration duracao) => MidiaEscolhida(
      arquivo: XFile.fromData(Uint8List(10), name: 'video.mov'),
      tipoDeConteudo: 'video/quicktime',
      tamanho: 10,
      duracao: duracao,
    );

class _Servidor {
  final requisicoes = <http.Request>[];
  String? erroAoAbrir;

  late final cliente = MockClient((requisicao) async {
    requisicoes.add(requisicao);
    final caminho = requisicao.url.path;
    if (caminho.endsWith('/envios') && erroAoAbrir != null) {
      return http.Response(jsonEncode({'mensagem': erroAoAbrir}), 409,
          headers: _json);
    }
    if (caminho.endsWith('/envios')) {
      return http.Response(
          jsonEncode({
            'id': 'e1',
            'urlDeEnvio': '/api/stories-locais/envios/x/e1.jpg?assinatura=a',
            'cabecalhos': {'Content-Type': 'image/jpeg'},
          }),
          200,
          headers: _json);
    }
    if (caminho.endsWith('/confirmar')) {
      return http.Response(
          jsonEncode({
            'id': 'e1',
            'tipo': 'Foto',
            'nome': 'Ana',
            'criadoEm': '2026-10-17T21:00:00Z',
            'tipoDeConteudo': 'image/jpeg',
            'url': 'http://teste/arquivo',
          }),
          200,
          headers: _json);
    }
    return http.Response('[]', 200, headers: _json);
  });

  Iterable<http.Request> doCaminho(String fim) =>
      requisicoes.where((r) => r.url.path.endsWith(fim));
}

Future<void> _abrir(
  WidgetTester tester, {
  required _Servidor servidor,
  required SeletorDeMidia seletor,
  required EnviadorDeArquivo enviador,
}) async {
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: EnviarStory(
        api: ApiTocaEssa(cliente: servidor.cliente, enderecoBase: 'http://teste'),
        codigo: 'ABC123',
        nome: 'Ana',
        seletor: seletor,
        enviador: enviador,
      ),
    ),
  ));
  await tester.pumpAndSettle();
}

Future<void> _escolher(WidgetTester tester, String opcao) async {
  await tester.tap(find.text('Enviar vídeo ou foto'));
  await tester.pumpAndSettle();
  if (find.text('Entendi').evaluate().isNotEmpty) {
    await tester.tap(find.text('Entendi'));
    await tester.pumpAndSettle();
  }
  await tester.tap(find.text(opcao));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('foto da galeria: abre o envio, manda o arquivo e confirma',
      (tester) async {
    final servidor = _Servidor();
    final enviador = _EnviadorFalso();
    await _abrir(tester,
        servidor: servidor,
        seletor: _SeletorFalso(_foto()),
        enviador: enviador);

    await _escolher(tester, 'Escolher da galeria');

    final abertura = servidor.doCaminho('/envios').single;
    expect(abertura.url.path, '/api/publico/apresentacoes/ABC123/envios');
    final corpo = jsonDecode(abertura.body) as Map<String, dynamic>;
    expect(corpo['tipo'], 'Foto');
    expect(corpo['tipoDeConteudo'], 'image/jpeg');
    expect(corpo['tamanho'], 1000);
    expect(corpo['nome'], 'Ana');
    expect(corpo['aparelho'], isNotEmpty);

    final (url, cabecalhos) = enviador.enviados.single;
    expect(url.toString(),
        'http://teste/api/stories-locais/envios/x/e1.jpg?assinatura=a');
    expect(cabecalhos, {'Content-Type': 'image/jpeg'});
    expect(servidor.doCaminho('/envios/e1/confirmar'), hasLength(1));
    expect(find.text('Enviado! Já aparece nos stories do show.'),
        findsOneWidget);

    // O mesmo aparelho manda sempre o mesmo identificador.
    final preferencias = await SharedPreferences.getInstance();
    expect(preferencias.getString('aparelho_dos_stories'), corpo['aparelho']);
  });

  testWidgets('aviso de que todos veem aparece só no primeiro envio',
      (tester) async {
    final servidor = _Servidor();
    await _abrir(tester,
        servidor: servidor,
        seletor: _SeletorFalso(_foto()),
        enviador: _EnviadorFalso());

    await tester.tap(find.text('Enviar vídeo ou foto'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Todo mundo do show vai ver por 24 h'),
        findsOneWidget);
    await tester.tap(find.text('Entendi'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tirar foto'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Enviar vídeo ou foto'));
    await tester.pumpAndSettle();
    expect(find.text('Entendi'), findsNothing);
    expect(find.text('Gravar vídeo'), findsOneWidget);
  });

  testWidgets('vídeo com mais de 60 s é recusado no próprio aparelho',
      (tester) async {
    final servidor = _Servidor();
    await _abrir(tester,
        servidor: servidor,
        seletor: _SeletorFalso(_video(const Duration(seconds: 75))),
        enviador: _EnviadorFalso());

    await _escolher(tester, 'Gravar vídeo');

    expect(find.text('Envie um vídeo de até 60 segundos.'), findsOneWidget);
    expect(servidor.requisicoes, isEmpty);
  });

  testWidgets('arquivo grande demais é recusado antes de enviar',
      (tester) async {
    final servidor = _Servidor();
    await _abrir(tester,
        servidor: servidor,
        seletor: _SeletorFalso(_foto(tamanho: 16 * 1024 * 1024)),
        enviador: _EnviadorFalso());

    await _escolher(tester, 'Escolher da galeria');

    expect(find.text('Envie um vídeo de até 100 MB ou uma foto de até 15 MB.'),
        findsOneWidget);
    expect(servidor.requisicoes, isEmpty);
  });

  testWidgets('falha no envio oferece tentar de novo sem escolher de novo',
      (tester) async {
    final servidor = _Servidor();
    final seletor = _SeletorFalso(_foto());
    final enviador = _EnviadorFalso(falhasAntes: 1);
    await _abrir(tester,
        servidor: servidor, seletor: seletor, enviador: enviador);

    await _escolher(tester, 'Escolher da galeria');
    expect(find.text('Não foi possível enviar.'), findsOneWidget);

    await tester.tap(find.text('Tentar de novo'));
    await tester.pumpAndSettle();

    expect(seletor.pedidos, ['galeria']);
    expect(servidor.doCaminho('/envios'), hasLength(1));
    expect(enviador.enviados, hasLength(1));
    expect(find.text('Enviado! Já aparece nos stories do show.'),
        findsOneWidget);
  });

  testWidgets('mensagem do servidor aparece quando os stories fecharam',
      (tester) async {
    final servidor = _Servidor()
      ..erroAoAbrir = 'Os stories deste show estão fechados.';
    await _abrir(tester,
        servidor: servidor,
        seletor: _SeletorFalso(_foto()),
        enviador: _EnviadorFalso());

    await _escolher(tester, 'Escolher da galeria');

    expect(find.text('Os stories deste show estão fechados.'), findsOneWidget);
  });

  testWidgets('desistir da câmera não envia nada', (tester) async {
    final servidor = _Servidor();
    await _abrir(tester,
        servidor: servidor,
        seletor: _SeletorFalso(null),
        enviador: _EnviadorFalso());

    await _escolher(tester, 'Gravar vídeo');

    expect(servidor.requisicoes, isEmpty);
  });
}
