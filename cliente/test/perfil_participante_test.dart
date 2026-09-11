import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:toca_essa_app/dominio/modelos.dart';
import 'package:toca_essa_app/telas/perfil_participante.dart';
import 'package:toca_essa_app/telas/componentes.dart';

void main() {
  testWidgets('perfil detalhado cabe no celular e abre a foto', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
        home: PerfilParticipante(
      participante: ParticipanteDaResenha(
          publicoId: '1',
          nome: 'Ana',
          pedidos: 1,
          pedidosTocados: 1,
          mediaAvaliacoes: 5,
          estatisticasGerais: const EstatisticasDoPublico(
            participacoes: 4, pedidos: 10, pedidosTocados: 5,
            avaliacoesRealizadas: 5, musicasMaisPedidas: [],
          ),
          musicasMaisPedidas: const [
            MusicaMaisPedida(musica: 'Evidências', quantidade: 1)
          ],
          avaliacoes: [
            AvaliacaoNaResenha(
                musica: 'Evidências',
                estrelas: 5,
                avaliadoEm: DateTime(2026, 9, 9))
          ]),
      enderecoFoto: 'https://example.com/foto.png',
    )));
    await tester.pumpAndSettle();
    expect(
      find.image(const AssetImage('assets/fundos/atmosfera.png')),
      findsOneWidget,
    );
    expect(find.text('Perfil do participante'), findsOneWidget);
    expect(find.text('Ana'), findsOneWidget);
    expect(tester.takeException(), isNull);
    expect(find.text('Fã de carteirinha'), findsOneWidget);
    expect(find.text('Conquistas'), findsOneWidget);
    expect(find.text('Histórico de avaliações'), findsNothing);
    await tester.tap(find.byType(FotoPerfilArtistico));
    await tester.pumpAndSettle();
    expect(find.byType(InteractiveViewer), findsOneWidget);
    await tester.tap(find.byTooltip('Fechar foto'));
    await tester.pumpAndSettle();
    expect(find.text('Perfil do participante'), findsOneWidget);
    await tester.tap(find.text('Nesta resenha'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Histórico de avaliações'), 300);
    expect(find.text('Fã de carteirinha'), findsNothing);
    expect(find.text('Histórico de avaliações'), findsOneWidget);
    // A rede simulada do Flutter Test responde 400 à imagem.
    expect(tester.takeException(),
        anyOf(isNull, isA<NetworkImageLoadException>()));
  });
}
