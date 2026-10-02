import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:toca_essa_app/dominio/modelos.dart';
import 'package:toca_essa_app/telas/retrospectiva_do_ano.dart';

EncontroDoPublico _encontro(
  String artista, {
  int pedidos = 0,
  int tocadas = 0,
  Map<String, int> musicas = const {},
  List<String> companhia = const [],
}) =>
    EncontroDoPublico(
      apresentacao: Apresentacao(
        id: artista,
        nome: 'Noite com $artista',
        data: DateTime(2026, 5, 1),
        local: 'Bar',
        codigo: 'ABC',
        perfilArtistico: PerfilArtistico(id: artista, nomeArtistico: artista),
        pedidosAbertos: false,
        status: StatusApresentacao.encerrada,
        tipo: TipoApresentacao.resenhaEntreAmigos,
      ),
      pedidos: pedidos,
      pedidosTocados: tocadas,
      minhasMusicas: [
        for (final MapEntry(:key, :value) in musicas.entries)
          MusicaMaisPedida(musica: key, quantidade: value)
      ],
      companhia: [
        for (final nome in companhia)
          PessoaDoEncontro(publicoId: nome, nome: nome)
      ],
    );

final _encontros = [
  _encontro('Duo',
      pedidos: 3,
      tocadas: 2,
      musicas: {'Evidências': 2, 'Garota': 1},
      companhia: ['Bia', 'Caio']),
  _encontro('Léo',
      pedidos: 2,
      tocadas: 1,
      musicas: {'evidências': 1, 'Trem-bala': 1},
      companhia: ['Bia']),
  _encontro('Duo'),
];

void main() {
  test('resumo do ano soma noites e elege música, parceria e artistas', () {
    final resumo = ResumoDoAno.de(_encontros);

    expect(resumo.encontros, 3);
    expect(resumo.pedidos, 5);
    expect(resumo.tocadas, 3);
    expect(resumo.musicaDoAno?.toLowerCase(), 'evidências');
    expect(resumo.parceriaDoAno, 'Bia');
    expect(resumo.artistas, ['Duo', 'Léo']);
  });

  test('ano sem pedidos nem companhia não inventa destaques', () {
    final resumo = ResumoDoAno.de([_encontro('Duo')]);

    expect(resumo.musicaDoAno, isNull);
    expect(resumo.parceriaDoAno, isNull);
  });

  testWidgets('cartão do ano mostra os destaques e oferece salvar a imagem',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(
      home: RetrospectivaDoAno(ano: 2026, nome: 'Ana', encontros: _encontros),
    ));

    expect(find.text('Meu 2026'), findsWidgets);
    expect(find.text('Ana'), findsOneWidget);
    expect(find.text('MÚSICA DO ANO'), findsOneWidget);
    expect(find.text('PARCERIA DO ANO'), findsOneWidget);
    expect(find.text('Bia'), findsOneWidget);
    expect(find.text('Duo · Léo'), findsOneWidget);
    expect(find.text('Salvar imagem para compartilhar'), findsOneWidget);
  });
}
