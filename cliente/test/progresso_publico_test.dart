import 'package:flutter_test/flutter_test.dart';
import 'package:toca_essa_app/dominio/modelos.dart';
import 'package:toca_essa_app/dominio/progresso_publico.dart';

EstatisticasDoPublico dados(
        {int pedidos = 0,
        int tocados = 0,
        int avaliacoes = 0,
        int participacoes = 0}) =>
    EstatisticasDoPublico(
      participacoes: participacoes,
      pedidos: pedidos,
      pedidosTocados: tocados,
      avaliacoesRealizadas: avaliacoes,
      musicasMaisPedidas: [],
    );

void main() {
  test('níveis respeitam limites e reiniciam progresso em cada nível', () {
    for (final xp in [0, 100, 300, 600, 1000]) {
      final progresso = ProgressoPublico(dados(pedidos: xp ~/ 10));
      expect(progresso.xp, xp);
      expect(progresso.nivel, ProgressoPublico.limites.indexOf(xp) + 1);
      expect(progresso.fracao, xp == 1000 ? 1 : 0);
    }
    final maximo = ProgressoPublico(dados(pedidos: 120));
    expect(maximo.proximo, isNull);
    expect(maximo.fracao, 1);
  });
  test('XP usa participações, pedidos, tocados e avaliações', () {
    expect(
        ProgressoPublico(
                dados(pedidos: 2, tocados: 1, avaliacoes: 3, participacoes: 1))
            .xp,
        120);
  });
  test('conquistas ficam bloqueadas sem ações e liberam na meta', () {
    expect(
        ConquistaPublico.deEstatisticas(dados())
            .every((c) => !c.desbloqueada && c.fracao == 0),
        isTrue);
    expect(
        ConquistaPublico.deEstatisticas(dados(
                pedidos: 10, tocados: 1, avaliacoes: 5, participacoes: 10))
            .every((c) => c.desbloqueada && c.fracao == 1),
        isTrue);
  });
}
