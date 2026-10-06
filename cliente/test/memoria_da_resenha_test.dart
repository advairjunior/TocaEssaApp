import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:toca_essa_app/dominio/modelos.dart';
import 'package:toca_essa_app/infraestrutura/camera_do_app.dart';
import 'package:toca_essa_app/telas/camera_do_cartao.dart';
import 'package:toca_essa_app/telas/memoria_da_resenha.dart';

import 'apoio/camera_falsa.dart';

EncontroDoPublico _encontro({
  TipoApresentacao tipo = TipoApresentacao.resenhaEntreAmigos,
  String? foto,
  List<String> musicas = const [],
  List<String> companhia = const [],
}) =>
    EncontroDoPublico(
      apresentacao: Apresentacao(
        id: 'roda',
        nome: 'Roda de samba',
        data: DateTime(2026, 9, 12),
        local: 'Quintal',
        codigo: 'RODA12',
        perfilArtistico:
            const PerfilArtistico(id: 'leo', nomeArtistico: 'Léo Violão'),
        pedidosAbertos: false,
        status: StatusApresentacao.encerrada,
        tipo: tipo,
        fotoRetrospectivaUrl: foto,
      ),
      pedidos: 4,
      pedidosTocados: 3,
      minhasMusicas: [
        for (final (indice, musica) in musicas.indexed)
          MusicaMaisPedida(musica: musica, quantidade: musicas.length - indice)
      ],
      companhia: [
        for (final nome in companhia)
          PessoaDoEncontro(publicoId: nome, nome: nome)
      ],
    );

Future<void> _montar(WidgetTester tester, EncontroDoPublico encontro,
    {VoidCallback? abrirResenha}) async {
  await tester.binding.setSurfaceSize(const Size(420, 2400));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  // A memória sempre é aberta por cima da lista de resenhas.
  final navegador = GlobalKey<NavigatorState>();
  await tester.pumpWidget(MaterialApp(
    navigatorKey: navegador,
    home: const Scaffold(),
  ));
  navegador.currentState!.push(MaterialPageRoute<void>(
    builder: (_) => MemoriaDaResenha(
      encontro: encontro,
      nome: 'Ana Souza',
      enderecoArquivo: (caminho) =>
          caminho == null ? null : 'http://teste$caminho',
      abrirResenha: abrirResenha ?? () {},
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('memória abre com a capa da noite, sem barra de app',
      (tester) async {
    await _montar(tester, _encontro());

    expect(find.byType(AppBar), findsNothing);
    expect(find.byTooltip('Voltar'), findsOneWidget);
    expect(find.text('Roda de samba'), findsWidgets);
    expect(find.text('Léo Violão · Quintal'), findsOneWidget);
    expect(find.text('12 DE SETEMBRO · RESENHA'), findsOneWidget);
    // Sem foto do encontro, a capa usa o palco da marca.
    expect(
      find.image(const AssetImage('assets/fundos/inicio_palco.png')),
      findsWidgets,
    );
  });

  testWidgets('sua noite mostra música, números uma vez só e a companhia',
      (tester) async {
    await _montar(
      tester,
      _encontro(
        musicas: ['Evidências', 'Garota de Ipanema'],
        companhia: ['Bia', 'Caio', 'Davi'],
      ),
    );

    expect(find.text('SUA MÚSICA DA NOITE'), findsOneWidget);
    expect(find.text('também pediu Garota de Ipanema'), findsOneWidget);
    expect(find.text('QUEM ESTAVA COM VOCÊ'), findsOneWidget);
    for (final nome in ['Bia', 'Caio', 'Davi']) {
      expect(find.text(nome), findsOneWidget);
    }
    // Os números aparecem só uma vez fora do cartão compartilhável.
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('sua-noite')),
        matching: find.text('4'),
      ),
      findsOneWidget,
    );
    expect(find.text('pedidos'), findsWidgets);
  });

  testWidgets('cartão para compartilhar diz com quem a pessoa estava',
      (tester) async {
    await _montar(tester, _encontro(companhia: ['Bia', 'Caio', 'Davi']));

    expect(find.text('com Bia, Caio e mais 1'), findsOneWidget);
  });

  testWidgets('selfie do público é tirada já dentro do cartão', (tester) async {
    final camera = CameraFalsa();
    fabricaDeCamera = () => camera;
    addTearDown(() => fabricaDeCamera = CameraDoPlugin.new);
    await _montar(tester, _encontro(musicas: ['Evidências']));

    await tester.ensureVisible(find.text('Colocar minha foto'));
    await tester.tap(find.text('Colocar minha foto'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tirar uma selfie'));
    await tester.pumpAndSettle();

    expect(camera.iniciadas, [LenteDaCamera.frontal]);
    expect(
      find.descendant(
          of: find.byType(CameraDoCartao), matching: find.text('Ana Souza')),
      findsOneWidget,
    );
    await tester.tap(find.byTooltip('Tirar foto'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Usar foto'));
    await tester.pumpAndSettle();

    expect(find.byType(CameraDoCartao), findsNothing);
    expect(find.text('Trocar minha foto'), findsOneWidget);
  });

  testWidgets('show sem pedidos nem companhia não inventa seções',
      (tester) async {
    await _montar(tester,
        _encontro(tipo: TipoApresentacao.publica, foto: '/fotos/x.png'));

    expect(find.text('12 DE SETEMBRO · SHOW'), findsOneWidget);
    expect(find.text('SUA MÚSICA DA NOITE'), findsNothing);
    expect(find.text('QUEM ESTAVA COM VOCÊ'), findsNothing);
  });

  testWidgets('cartão para compartilhar já pode ser salvo e aceita foto',
      (tester) async {
    var abriu = false;
    await _montar(tester, _encontro(musicas: ['Evidências']),
        abrirResenha: () => abriu = true);

    expect(find.text('Ana Souza'), findsOneWidget);
    final salvar = find.ancestor(
      of: find.text('Salvar imagem para compartilhar'),
      matching: find.byWidgetPredicate((w) => w is FilledButton),
    );
    expect(tester.widget<FilledButton>(salvar).onPressed, isNotNull);
    expect(find.text('Colocar minha foto'), findsOneWidget);

    await tester.ensureVisible(find.text('Abrir a resenha completa'));
    await tester.tap(find.text('Abrir a resenha completa'));
    expect(abriu, isTrue);
  });
}
