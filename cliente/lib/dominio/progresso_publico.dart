import 'modelos.dart';

class ProgressoPublico {
  ProgressoPublico(EstatisticasDoPublico dados)
      : xp = dados.pedidos * 10 +
            dados.pedidosTocados * 25 +
            dados.avaliacoesRealizadas * 15 +
            dados.participacoes * 30;

  final int xp;
  static const limites = [0, 100, 300, 600, 1000];
  static const titulos = [
    'Fã iniciante',
    'Frequentador',
    'Fã de carteirinha',
    'Fã VIP',
    'Lenda da pista',
  ];
  int get indice => limites.lastIndexWhere((limite) => xp >= limite);
  int get nivel => indice + 1;
  String get titulo => titulos[indice];
  int? get proximo => indice == limites.length - 1 ? null : limites[indice + 1];
  double get fracao => proximo == null
      ? 1
      : (xp - limites[indice]) / (proximo! - limites[indice]);
}

class ConquistaPublico {
  const ConquistaPublico(this.titulo, this.descricao, this.atual, this.meta);
  final String titulo;
  final String descricao;
  final int atual;
  final int meta;
  bool get desbloqueada => atual >= meta;
  double get fracao => (atual / meta).clamp(0, 1);

  static List<ConquistaPublico> deEstatisticas(EstatisticasDoPublico dados) => [
        ConquistaPublico(
            'Primeiro pedido', 'Peça sua primeira música.', dados.pedidos, 1),
        ConquistaPublico('Primeira tocada', 'Tenha um pedido tocado.',
            dados.pedidosTocados, 1),
        ConquistaPublico('Crítico musical', 'Avalie cinco músicas.',
            dados.avaliacoesRealizadas, 5),
        ConquistaPublico('Frequentador', 'Participe de três apresentações.',
            dados.participacoes, 3),
        ConquistaPublico('Pede mais uma', 'Complete dez pedidos musicais.',
            dados.pedidos, 10),
        ConquistaPublico('Lenda da pista', 'Participe de dez apresentações.',
            dados.participacoes, 10),
      ];
}
