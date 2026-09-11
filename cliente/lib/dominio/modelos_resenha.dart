part of 'modelos.dart';

class ParticipanteDaResenha {
  const ParticipanteDaResenha({
    required this.publicoId,
    required this.nome,
    required this.pedidos,
    required this.pedidosTocados,
    required this.musicasMaisPedidas,
    this.fotoUrl,
    this.mediaAvaliacoes,
    this.ehArtista = false,
    this.estatisticasGerais,
    this.avaliacoes = const [],
  });

  final String publicoId;
  final String nome;
  final String? fotoUrl;
  final int pedidos;
  final int pedidosTocados;
  final double? mediaAvaliacoes;
  final List<MusicaMaisPedida> musicasMaisPedidas;
  final bool ehArtista;
  final EstatisticasDoPublico? estatisticasGerais;
  final List<AvaliacaoNaResenha> avaliacoes;

  factory ParticipanteDaResenha.deJson(Map<String, dynamic> json) =>
      ParticipanteDaResenha(
        publicoId: json['publicoId'] as String,
        nome: json['nome'] as String,
        fotoUrl: json['fotoUrl'] as String?,
        pedidos: json['pedidos'] as int,
        pedidosTocados: json['pedidosTocados'] as int,
        mediaAvaliacoes: (json['mediaAvaliacoes'] as num?)?.toDouble(),
        musicasMaisPedidas: (json['musicasMaisPedidas'] as List<dynamic>)
            .map(
                (item) => MusicaMaisPedida.deJson(item as Map<String, dynamic>))
            .toList(),
        ehArtista: json['ehArtista'] as bool? ?? false,
        estatisticasGerais: json['estatisticasGerais'] == null
            ? null
            : EstatisticasDoPublico.deJson(
                json['estatisticasGerais'] as Map<String, dynamic>),
        avaliacoes: (json['avaliacoes'] as List<dynamic>? ?? [])
            .map((item) =>
                AvaliacaoNaResenha.deJson(item as Map<String, dynamic>))
            .toList(),
      );
}

class AvaliacaoNaResenha {
  const AvaliacaoNaResenha(
      {required this.musica, required this.estrelas, required this.avaliadoEm});
  final String musica;
  final int estrelas;
  final DateTime avaliadoEm;
  factory AvaliacaoNaResenha.deJson(Map<String, dynamic> json) =>
      AvaliacaoNaResenha(
          musica: json['musica'] as String,
          estrelas: json['estrelas'] as int,
          avaliadoEm: DateTime.parse(json['avaliadoEm'] as String));
}
