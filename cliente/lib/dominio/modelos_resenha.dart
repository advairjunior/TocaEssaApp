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
    this.pedidosRecusados = 0,
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

  /// Pedidos que o artista não conhecia ou ainda não sabia tocar.
  final int pedidosRecusados;

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
        pedidosRecusados: json['pedidosRecusados'] as int? ?? 0,
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

class PessoaDoEncontro {
  const PessoaDoEncontro(
      {required this.publicoId, required this.nome, this.fotoUrl});
  final String publicoId;
  final String nome;
  final String? fotoUrl;
  factory PessoaDoEncontro.deJson(Map<String, dynamic> json) =>
      PessoaDoEncontro(
          publicoId: json['publicoId'] as String,
          nome: json['nome'] as String,
          fotoUrl: json['fotoUrl'] as String?);
}

/// Um encontro do histórico do público, com os números dele naquela noite.
class EncontroDoPublico {
  const EncontroDoPublico({
    required this.apresentacao,
    this.pedidos = 0,
    this.pedidosTocados = 0,
    this.minhasMusicas = const [],
    this.companhia = const [],
    this.nomeNoLouvor,
    this.hinosNoLouvor = 0,
  });

  final Apresentacao apresentacao;
  final int pedidos;
  final int pedidosTocados;
  final List<MusicaMaisPedida> minhasMusicas;

  /// Quem mais estava na resenha; vazio em apresentação pública.
  final List<PessoaDoEncontro> companhia;

  /// No louvor: quem a pessoa foi no roteiro e em quantos hinos tinha parte.
  final String? nomeNoLouvor;
  final int hinosNoLouvor;

  /// "Como Ana · em 3 hinos"; nulo fora do louvor ou sem nome escolhido.
  String? get resumoDoLouvor => nomeNoLouvor == null
      ? null
      : 'Como $nomeNoLouvor · em $hinosNoLouvor '
          '${hinosNoLouvor == 1 ? 'hino' : 'hinos'}';

  factory EncontroDoPublico.deJson(Map<String, dynamic> json) =>
      EncontroDoPublico(
        apresentacao:
            Apresentacao.deJson(json['apresentacao'] as Map<String, dynamic>),
        pedidos: json['pedidos'] as int? ?? 0,
        pedidosTocados: json['pedidosTocados'] as int? ?? 0,
        minhasMusicas: (json['minhasMusicas'] as List<dynamic>? ?? [])
            .map(
                (item) => MusicaMaisPedida.deJson(item as Map<String, dynamic>))
            .toList(),
        companhia: (json['companhia'] as List<dynamic>? ?? [])
            .map(
                (item) => PessoaDoEncontro.deJson(item as Map<String, dynamic>))
            .toList(),
        nomeNoLouvor: json['nomeNoLouvor'] as String?,
        hinosNoLouvor: json['hinosNoLouvor'] as int? ?? 0,
      );
}
