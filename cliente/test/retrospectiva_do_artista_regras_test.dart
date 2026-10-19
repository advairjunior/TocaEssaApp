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
    destaques.map((item) => '${item.rotulo} ${item.valor}').toList();

void main() {
  group('vitrine do show público', () {
    final noiteCheia = _dados(
      inicio: DateTime(2026, 10, 17, 21),
      fim: DateTime(2026, 10, 18, 0, 12),
      tocadas: 42,
      avaliaram: 12,
      media: 4.8,
      aPedido: 32,
      considerados: 40,
      atendidos: 36,
      alos: 9,
    );

    test('noite cheia mostra tempo, músicas e pedidas pelo público, como no Strava', () {
      final destaques =
          destaquesDoShow(_estatisticas(pessoas: 80, retrospectiva: noiteCheia));

      expect(_rotulos(destaques), ['Tempo 3h12', 'Músicas 42', 'Pedidas pelo público 32']);
    });

    test('público no app, atendimento e alôs nunca vão para as redes', () {
      final destaques = destaquesDoShow(_estatisticas(
          pessoas: 80,
          retrospectiva: _dados(
              aPedido: 32, considerados: 40, atendidos: 36, alos: 9)));

      expect(_rotulos(destaques), ['Pedidas pelo público 32']);
    });

    test('nunca usa os pedidos brutos, só o que foi validado', () {
      final destaques = destaquesDoShow(_estatisticas(pessoas: 3));

      expect(destaques, isEmpty);
      expect(favoritaDoShow(_estatisticas()), isNull);
    });

    test('show curto, poucas músicas ou poucas a pedido não aparecem', () {
      expect(
          destaquesDoShow(_estatisticas(
              pessoas: 100,
              retrospectiva: _dados(
                  inicio: DateTime(2026, 10, 17, 21),
                  fim: DateTime(2026, 10, 17, 21, 20),
                  tocadas: 8,
                  aPedido: 4))),
          isEmpty);
    });

    // Quem vê "4,7" no cartão não sabe que é de 5 e lê como nota baixa.
    test('nota nunca aparece no cartão do show, nem a alta', () {
      expect(
          destaquesDoShow(_estatisticas(
              retrospectiva: _dados(avaliaram: 20, media: 4.9))),
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
    test('mostra tudo, sem contar gente no app', () {
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

      // A nota fica fora também aqui: "2,5" sem dizer que é de 5 confunde.
      expect(_rotulos(numeros), ['Pedidos 9', 'Tocadas 4', 'Recusadas 2']);
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
