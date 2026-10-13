import 'package:flutter_test/flutter_test.dart';
import 'package:toca_essa_app/dominio/modelos.dart';
import 'package:toca_essa_app/dominio/retrospectiva_do_artista.dart';

/// Números já validados pelo servidor: cada pessoa conta uma vez por música.
DadosDaRetrospectiva _dados({
  MusicaMaisPedida? favorita,
  int aPedido = 0,
  int considerados = 0,
  int atendidos = 0,
  int avaliaram = 0,
  double? media,
  int tocadas = 0,
  int alos = 0,
  DateTime? inicio,
  DateTime? fim,
  List<MusicaMaisPedida> maisPedidas = const [],
  List<MusicaMaisPedida> recusadas = const [],
}) =>
    DadosDaRetrospectiva(
      favorita: favorita,
      musicasAPedidoTocadas: aPedido,
      pedidosConsiderados: considerados,
      pedidosAtendidos: atendidos,
      pessoasQueAvaliaram: avaliaram,
      mediaDasAvaliacoes: media,
      musicasTocadas: tocadas,
      alosDados: alos,
      iniciadaEm: inicio,
      encerradaEm: fim,
      maisPedidasPorPessoas: maisPedidas,
      recusadasPorPessoas: recusadas,
    );

/// Os números brutos (pedidos) ficam altos de propósito: o cartão não pode
/// usá-los, só o bloco validado.
EstatisticasDaApresentacao _estatisticas({
  int pessoas = 0,
  DadosDaRetrospectiva? retrospectiva,
}) =>
    EstatisticasDaApresentacao(
      totalPedidos: 99,
      aguardando: 0,
      aceitos: 99,
      tocados: 99,
      recusados: 99,
      avaliados: 99,
      mediaAvaliacoes: 5,
      musicasMaisPedidas: const [
        MusicaMaisPedida(musica: 'Pedida pela mesma pessoa', quantidade: 9)
      ],
      pessoasNoEvento: pessoas,
      retrospectiva: retrospectiva ?? _dados(),
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
    test('noite cheia mostra público, músicas a pedido e nota', () {
      final destaques = destaquesDoShow(_estatisticas(
        pessoas: 80,
        retrospectiva: _dados(
          aPedido: 32,
          considerados: 40,
          atendidos: 36,
          avaliaram: 12,
          media: 4.8,
          tocadas: 50,
        ),
      ));

      expect(_rotulos(destaques), [
        '80 pessoas no app',
        '32 músicas a pedido',
        '4.8 de nota',
      ]);
    });

    test('nunca usa os pedidos brutos, só o que foi validado', () {
      final destaques = destaquesDoShow(_estatisticas(pessoas: 3));

      expect(destaques, isEmpty);
      expect(favoritaDoShow(_estatisticas()), isNull);
    });

    test('pouca gente não aparece', () {
      final destaques = destaquesDoShow(
          _estatisticas(pessoas: 6, retrospectiva: _dados(aPedido: 5)));

      expect(_rotulos(destaques), isNot(contains(startsWith('6 pessoas'))));
    });

    test('poucas músicas a pedido para o tamanho do público não aparecem', () {
      final destaques = destaquesDoShow(
          _estatisticas(pessoas: 100, retrospectiva: _dados(aPedido: 4)));

      expect(_rotulos(destaques), ['100 pessoas no app']);
    });

    test('nota baixa ou de poucas pessoas nunca aparece', () {
      expect(
          _rotulos(destaquesDoShow(_estatisticas(
              pessoas: 50,
              retrospectiva: _dados(avaliaram: 20, media: 3.4)))),
          ['50 pessoas no app']);
      expect(
          _rotulos(destaquesDoShow(_estatisticas(
              pessoas: 50, retrospectiva: _dados(avaliaram: 2, media: 5)))),
          ['50 pessoas no app']);
    });

    test('atendimento alto conta pedidos sem repetição', () {
      final destaques = destaquesDoShow(_estatisticas(
          pessoas: 12,
          retrospectiva: _dados(aPedido: 6, considerados: 10, atendidos: 9)));

      expect(_rotulos(destaques), [
        '12 pessoas no app',
        '6 músicas a pedido',
        '90% pedidos atendidos',
      ]);
    });

    test('total de músicas tocadas e alôs entram quando sobra espaço', () {
      final destaques = destaquesDoShow(
          _estatisticas(retrospectiva: _dados(tocadas: 42, alos: 7)));

      expect(_rotulos(destaques), ['42 músicas tocadas', '7 alôs']);
      expect(
          destaquesDoShow(
              _estatisticas(retrospectiva: _dados(tocadas: 8, alos: 2))),
          isEmpty);
    });

    test('favorita é a que o servidor validou', () {
      expect(
          favoritaDoShow(_estatisticas(
              retrospectiva: _dados(
                  favorita: const MusicaMaisPedida(
                      musica: 'Evidências', quantidade: 3)))),
          'Evidências');
    });

    test('duração com horário de início e fim', () {
      expect(
          duracaoDoShow(_estatisticas(
              retrospectiva: _dados(
                  inicio: DateTime(2026, 10, 17, 21),
                  fim: DateTime(2026, 10, 18, 0, 12)))),
          '21h00 às 00h12 · 3h12 de show');
      expect(duracaoDoShow(_estatisticas()), isNull);
    });
  });

  group('números da resenha', () {
    test('mostra tudo, sem contar a mesma pessoa duas vezes', () {
      final numeros = numerosDaResenha(_estatisticas(
        pessoas: 7,
        retrospectiva: _dados(
          considerados: 9,
          aPedido: 4,
          media: 2.5,
          recusadas: const [
            MusicaMaisPedida(musica: 'Macarena', quantidade: 2),
            MusicaMaisPedida(musica: 'Ragatanga', quantidade: 1),
          ],
        ),
      ));

      expect(_rotulos(numeros), [
        '7 na resenha',
        '9 pedidos',
        '4 tocadas',
        '2 recusadas',
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
      retrospectiva: _dados(
        maisPedidas: const [
          MusicaMaisPedida(musica: 'Evidências', quantidade: 4)
        ],
        recusadas: const [MusicaMaisPedida(musica: 'Macarena', quantidade: 2)],
      ),
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

    test('hino e polêmica contam pessoas, não pedidos repetidos', () {
      final detalhes = {
        for (final premio in premiosDaResenha(participantes, estatisticas))
          premio.titulo: premio.detalhe,
      };

      expect(detalhes['Hino da resenha'], 'pedida por 4 pessoas');
      expect(detalhes['Polêmica da noite'], 'recusada para 2 pessoas');
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
