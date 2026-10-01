import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:toca_essa_app/dominio/modelos.dart';
import 'package:toca_essa_app/telas/escolher_cifra.dart';
import 'package:toca_essa_app/tema/tema_toca_essa.dart';

final _cifraSalva = CifraDoArtista(
  id: 'c1',
  artistaId: 'a1',
  musica: 'Evidências',
  url: 'https://www.cifraclub.com.br/evidencias/',
  fonte: 'CifraClub',
  criadaEm: DateTime(2026, 9, 10),
  atualizadaEm: DateTime(2026, 9, 10),
);

Future<List<DecisaoCifra?>> _abrir(
  WidgetTester tester, {
  CifraDoArtista? cifra,
}) async {
  final decisoes = <DecisaoCifra?>[];
  await tester.pumpWidget(MaterialApp(
    theme: TemaTocaEssa.escuro,
    home: Builder(
      builder: (context) => TextButton(
        onPressed: () async => decisoes.add(await mostrarEscolhaDeCifra(
          context,
          musica: 'Evidências',
          artista: 'Chitãozinho & Xororó',
          resultado: ResultadoCifraDoArtista(
            cifra: cifra,
            urlPesquisa: 'https://www.google.com/search?q=evidencias',
            urlSugerida: 'https://www.cifraclub.com.br/evidencias/',
          ),
          abrirUrl: (_) async {},
        )),
        child: const Text('Abrir'),
      ),
    ),
  ));
  await tester.tap(find.text('Abrir'));
  await tester.pumpAndSettle();
  return decisoes;
}

void main() {
  testWidgets('link da cifra vem antes das opções de busca', (tester) async {
    await _abrir(tester);

    final campo =
        tester.getRect(find.widgetWithText(TextField, 'Link da cifra'));
    expect(
        campo.top, lessThan(tester.getRect(find.text('Abrir sugestão')).top));
    expect(
        campo.top, lessThan(tester.getRect(find.text('Pesquisar na web')).top));
  });

  testWidgets('fechar sai sem decidir nada', (tester) async {
    final decisoes = await _abrir(tester);

    await tester.tap(find.byTooltip('Fechar'));
    await tester.pumpAndSettle();

    expect(find.text('Escolher cifra'), findsNothing);
    expect(decisoes, [null]);
  });

  testWidgets('remover link aparece somente quando já existe cifra',
      (tester) async {
    await _abrir(tester);
    expect(find.text('Remover link'), findsNothing);
    await tester.tap(find.byTooltip('Fechar'));
    await tester.pumpAndSettle();

    final decisoes = await _abrir(tester, cifra: _cifraSalva);
    await tester.ensureVisible(find.text('Remover link'));
    await tester.tap(find.text('Remover link'));
    await tester.pumpAndSettle();

    expect(decisoes.single?.tipo, TipoDecisaoCifra.remover);
  });
}
