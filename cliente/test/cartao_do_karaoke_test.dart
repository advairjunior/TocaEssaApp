import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:toca_essa_app/dominio/modelos.dart';
import 'package:toca_essa_app/telas/cartao_do_karaoke.dart';

Apresentacao _karaoke({String status = 'Agendada'}) => Apresentacao.deJson({
      'id': 'k1',
      'nome': 'Karaokê de sexta',
      'data': '2026-10-30',
      'local': 'Casa',
      'codigo': 'KARA01',
      'perfilArtistico': {'id': 'pa', 'nomeArtistico': 'Advair'},
      'tipo': 'Karaoke',
      'status': status,
    });

final _noite = NoiteDeKaraoke.deJson({
  'repertorioId': 'r1',
  'modo': 'Livre',
  'sorteada': true,
  'podeSortearDeNovo': false,
  'ordem': [],
  'foraDaOrdem': [],
  'vozDaNoite': 'p2',
  'placar': [
    {
      'publicoId': 'p2',
      'nome': 'Bia',
      'musicas': 2,
      'media': 4.6,
      'votos': 9,
      'melhorMusica': 'Trem-Bala'
    },
    {
      'publicoId': 'p1',
      'nome': 'Ana',
      'musicas': 1,
      'media': null,
      'votos': 0,
      'melhorMusica': null
    },
  ],
});

void main() {
  test('quem cantou leva as músicas, a nota e o lugar no placar', () {
    final conteudo = cartaoDeQuemCantou(_karaoke(), _noite, 'p1')!;

    expect(conteudo.titulo, 'Ana');
    expect(conteudo.subtitulo, 'Karaokê de sexta · 30/10/2026');
    expect(conteudo.selo, isNull);
    expect(conteudo.destaque, isNull);
    expect(conteudo.numeros, [
      ('1', 'música'),
      ('—', 'nota da galera'),
      ('2º', 'de 2 no placar'),
    ]);
  });

  test('a Voz da noite só entra no cartão com a noite encerrada', () {
    final durante = cartaoDeQuemCantou(_karaoke(), _noite, 'p2')!;
    final encerrada =
        cartaoDeQuemCantou(_karaoke(status: 'Encerrada'), _noite, 'p2')!;

    expect(durante.selo, isNull);
    expect(encerrada.selo, 'Voz da noite');
    expect(encerrada.destaque, ('Minha melhor música', 'Trem-Bala'));
    expect(encerrada.numeros, [
      ('2', 'músicas'),
      ('4,6', 'nota da galera'),
      ('1º', 'de 2 no placar'),
    ]);
  });

  test('quem ainda não cantou não tem cartão', () {
    expect(cartaoDeQuemCantou(_karaoke(), _noite, 'p9'), isNull);
    expect(cartaoDeQuemCantou(_karaoke(), _noite, null), isNull);
  });

  test('o cartão do dono conta a noite e mostra a Voz da noite', () {
    final durante = cartaoDaNoiteDoKaraoke(_karaoke(), _noite)!;
    final encerrada =
        cartaoDaNoiteDoKaraoke(_karaoke(status: 'Encerrada'), _noite)!;

    expect(durante.titulo, 'Karaokê de sexta');
    expect(durante.subtitulo, 'Noite de Karaokê · 30/10/2026');
    expect(durante.destaque, ('Liderando', 'Bia · ★ 4,6'));
    expect(encerrada.destaque, ('Voz da noite', 'Bia · ★ 4,6'));
    expect(durante.numeros, [('2', 'cantaram'), ('3', 'músicas')]);
  });

  test('sem ninguém no placar a noite ainda não tem cartão', () {
    final vazia = NoiteDeKaraoke.deJson({
      'modo': 'Livre',
      'sorteada': true,
      'podeSortearDeNovo': true,
      'ordem': [],
      'foraDaOrdem': [],
    });

    expect(cartaoDaNoiteDoKaraoke(_karaoke(), vazia), isNull);
  });

  testWidgets('o cartão mostra o nome, a Voz da noite e os números',
      (tester) async {
    final conteudo =
        cartaoDeQuemCantou(_karaoke(status: 'Encerrada'), _noite, 'p2')!;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 360,
          child: CartaoDoKaraoke(conteudo: conteudo, enderecoFoto: null),
        ),
      ),
    ));

    expect(find.text('Bia'), findsOneWidget);
    expect(find.text('VOZ DA NOITE'), findsOneWidget);
    expect(find.text('MINHA MELHOR MÚSICA'), findsOneWidget);
    expect(find.text('Trem-Bala'), findsOneWidget);
    expect(find.text('4,6'), findsOneWidget);
    expect(find.text('de 2 no placar'), findsOneWidget);
  });
}
