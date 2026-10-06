import 'package:flutter_test/flutter_test.dart';
import 'package:toca_essa_app/dominio/modelos.dart';
import 'package:toca_essa_app/dominio/retrospectiva_do_artista.dart';

EstatisticasDaApresentacao _estatisticas({
  int pessoas = 0,
  int pediram = 0,
  int pedidos = 0,
  int tocados = 0,
  int recusados = 0,
  int avaliados = 0,
  double? media,
  List<MusicaMaisPedida> maisPedidas = const [],
  List<MusicaMaisPedida> recusadas = const [],
}) =>
    EstatisticasDaApresentacao(
      totalPedidos: pedidos,
      aguardando: 0,
      aceitos: tocados,
      tocados: tocados,
      recusados: recusados,
      avaliados: avaliados,
      mediaAvaliacoes: media,
      musicasMaisPedidas: maisPedidas,
      pessoasNoEvento: pessoas,
      pessoasQuePediram: pediram,
      musicasRecusadas: recusadas,
    );

ParticipanteDaResenha _pessoa(
  String nome, {
  int pedidos = 0,
  int tocados = 0,
  int recusados = 0,
  List<int> notas = const [],
  bool artista = false,
}) =>
    ParticipanteDaResenha(
      publicoId: nome,
      nome: nome,
      pedidos: pedidos,
      pedidosTocados: tocados,
      pedidosRecusados: recusados,
      musicasMaisPedidas: const [],
      ehArtista: artista,
      avaliacoes: [
        for (final (indice, nota) in notas.indexed)
          AvaliacaoNaResenha(
            musica: 'Música $indice',
            estrelas: nota,
            avaliadoEm: DateTime(2026, 10, 6),
          ),
      ],
    );

List<String> _rotulos(List<DestaqueDaRetrospectiva> destaques) =>
    destaques.map((item) => '${item.valor} ${item.rotulo}').toList();

void main() {
  group('vitrine do show público', () {
    test('noite cheia mostra público, músicas a pedido, nota e atendimento',
        () {
      final destaques = destaquesDoShow(_estatisticas(
        pessoas: 80,
        pediram: 30,
        pedidos: 40,
        tocados: 32,
        avaliados: 12,
        media: 4.8,
      ));

      expect(_rotulos(destaques), [
        '80 pessoas no app',
        '32 músicas a pedido',
        '4.8 de nota',
      ]);
    });

    test('pouca gente não aparece', () {
      final destaques = destaquesDoShow(
          _estatisticas(pessoas: 6, pediram: 4, pedidos: 5, tocados: 5));

      expect(_rotulos(destaques), isNot(contains(startsWith('6 pessoas'))));
    });

    test('poucas músicas tocadas para o tamanho do público não aparecem', () {
      final destaques = destaquesDoShow(
          _estatisticas(pessoas: 100, pediram: 10, pedidos: 10, tocados: 4));

      expect(_rotulos(destaques), ['100 pessoas no app']);
    });

    test('nota baixa ou com poucas avaliações nunca aparece', () {
      expect(
          _rotulos(destaquesDoShow(
              _estatisticas(pessoas: 50, avaliados: 20, media: 3.4))),
          ['50 pessoas no app']);
      expect(
          _rotulos(destaquesDoShow(
              _estatisticas(pessoas: 50, avaliados: 2, media: 5))),
          ['50 pessoas no app']);
    });

    test('atendimento alto aparece quando sobra espaço', () {
      final destaques = destaquesDoShow(
          _estatisticas(pessoas: 12, pediram: 6, pedidos: 10, tocados: 9));

      expect(_rotulos(destaques), [
        '12 pessoas no app',
        '9 músicas a pedido',
        '90% pedidos atendidos',
      ]);
    });

    test('noite fraca não mostra número nenhum', () {
      expect(
          destaquesDoShow(_estatisticas(
              pessoas: 3, pedidos: 2, tocados: 1, avaliados: 1, media: 2)),
          isEmpty);
    });

    test('favorita da galera só com pelo menos dois pedidos', () {
      expect(
          favoritaDoShow(_estatisticas(maisPedidas: const [
            MusicaMaisPedida(musica: 'Evidências', quantidade: 3)
          ])),
          'Evidências');
      expect(
          favoritaDoShow(_estatisticas(maisPedidas: const [
            MusicaMaisPedida(musica: 'Evidências', quantidade: 1)
          ])),
          isNull);
    });
  });

  group('números da resenha', () {
    test('mostra tudo, inclusive recusas e nota baixa', () {
      final numeros = numerosDaResenha(_estatisticas(
          pessoas: 7, pedidos: 9, tocados: 4, recusados: 3, media: 2.5));

      expect(_rotulos(numeros), [
        '7 na resenha',
        '9 pedidos',
        '4 tocados',
        '3 recusados',
        '2.5 de nota',
      ]);
    });
  });

  group('prêmios da resenha', () {
    final participantes = [
      _pessoa('Duo Aurora', artista: true),
      _pessoa('Bia', pedidos: 5, tocados: 2, recusados: 3, notas: [1, 2]),
      _pessoa('Caio', pedidos: 3, tocados: 3, notas: [5, 5, 5]),
      _pessoa('Dani', pedidos: 1, tocados: 0),
      _pessoa('Edu'),
      _pessoa('Fê'),
    ];
    final estatisticas = _estatisticas(
      maisPedidas: const [
        MusicaMaisPedida(musica: 'Evidências', quantidade: 4)
      ],
      recusadas: const [MusicaMaisPedida(musica: 'Macarena', quantidade: 2)],
    );

    Map<String, String> premios() => {
          for (final premio in premiosDaResenha(participantes, estatisticas))
            premio.titulo: premio.vencedor,
        };

    test('distribui os prêmios da noite', () {
      expect(premios(), {
        'Hino da resenha': 'Evidências',
        'Pidão da noite': 'Bia',
        'Pontaria certeira': 'Caio',
        'Ignorado da noite': 'Bia',
        'Polêmica da noite': 'Macarena',
        'Crítico da noite': 'Bia',
        'Puxa-saco oficial': 'Caio',
        'Climão da noite': 'Bia',
        'Só veio pela resenha': 'Edu e Fê',
      });
    });

    test('artista nunca concorre', () {
      final apenasArtista = premiosDaResenha(
          [_pessoa('Duo Aurora', artista: true)], _estatisticas());

      expect(apenasArtista, isEmpty);
    });

    test('quem não pediu nada vira lista curta com o resto contado', () {
      final calados = premiosDaResenha([
        for (final nome in ['Ana', 'Bia', 'Caio', 'Dani', 'Edu']) _pessoa(nome),
      ], _estatisticas());

      expect(calados.single.vencedor, 'Ana, Bia, Caio e mais 2');
    });

    test('ignorado é quem pediu e nunca foi tocado quando ninguém foi recusado',
        () {
      final premios = premiosDaResenha([
        _pessoa('Bia', pedidos: 2, tocados: 0),
        _pessoa('Caio', pedidos: 1, tocados: 1),
      ], _estatisticas());

      expect(
          premios.firstWhere((p) => p.titulo == 'Ignorado da noite').vencedor,
          'Bia');
    });
  });
}
