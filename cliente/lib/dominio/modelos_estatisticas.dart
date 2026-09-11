part of 'modelos.dart';

class PerfilPublico {
  const PerfilPublico({
    required this.id,
    required this.nome,
    required this.email,
    required this.criadoEm,
    this.fotoUrl,
  });

  final String id;
  final String nome;
  final String email;
  final String? fotoUrl;
  final DateTime criadoEm;

  factory PerfilPublico.deJson(Map<String, dynamic> json) => PerfilPublico(
        id: json['id'] as String,
        nome: json['nome'] as String,
        email: json['email'] as String,
        fotoUrl: json['fotoUrl'] as String?,
        criadoEm: DateTime.parse(json['criadoEm'] as String),
      );
}

class SessaoDoPublico {
  const SessaoDoPublico({required this.perfil, required this.token});

  final PerfilPublico perfil;
  final String token;

  factory SessaoDoPublico.deJson(Map<String, dynamic> json) => SessaoDoPublico(
        perfil: PerfilPublico.deJson(json['perfil'] as Map<String, dynamic>),
        token: json['token'] as String,
      );
}

class MusicaMaisPedida {
  const MusicaMaisPedida({required this.musica, required this.quantidade});

  final String musica;
  final int quantidade;

  factory MusicaMaisPedida.deJson(Map<String, dynamic> json) =>
      MusicaMaisPedida(
        musica: json['musica'] as String,
        quantidade: json['quantidade'] as int,
      );
}

class EstatisticasDaApresentacao {
  const EstatisticasDaApresentacao({
    required this.totalPedidos,
    required this.aguardando,
    required this.aceitos,
    required this.tocados,
    required this.recusados,
    required this.avaliados,
    required this.musicasMaisPedidas,
    this.mediaAvaliacoes,
  });

  final int totalPedidos;
  final int aguardando;
  final int aceitos;
  final int tocados;
  final int recusados;
  final int avaliados;
  final double? mediaAvaliacoes;
  final List<MusicaMaisPedida> musicasMaisPedidas;

  factory EstatisticasDaApresentacao.deJson(Map<String, dynamic> json) =>
      EstatisticasDaApresentacao(
        totalPedidos: json['totalPedidos'] as int,
        aguardando: json['aguardando'] as int,
        aceitos: json['aceitos'] as int,
        tocados: json['tocados'] as int,
        recusados: json['recusados'] as int,
        avaliados: json['avaliados'] as int,
        mediaAvaliacoes: (json['mediaAvaliacoes'] as num?)?.toDouble(),
        musicasMaisPedidas: (json['musicasMaisPedidas'] as List<dynamic>)
            .map(
                (item) => MusicaMaisPedida.deJson(item as Map<String, dynamic>))
            .toList(),
      );
}

class EstatisticasDoPublico {
  const EstatisticasDoPublico({
    required this.participacoes,
    required this.pedidos,
    required this.pedidosTocados,
    required this.avaliacoesRealizadas,
    required this.musicasMaisPedidas,
    this.mediaAvaliacoes,
  });

  final int participacoes;
  final int pedidos;
  final int pedidosTocados;
  final int avaliacoesRealizadas;
  final double? mediaAvaliacoes;
  final List<MusicaMaisPedida> musicasMaisPedidas;

  factory EstatisticasDoPublico.deJson(Map<String, dynamic> json) =>
      EstatisticasDoPublico(
        participacoes: json['participacoes'] as int,
        pedidos: json['pedidos'] as int,
        pedidosTocados: json['pedidosTocados'] as int,
        avaliacoesRealizadas: json['avaliacoesRealizadas'] as int,
        mediaAvaliacoes: (json['mediaAvaliacoes'] as num?)?.toDouble(),
        musicasMaisPedidas: (json['musicasMaisPedidas'] as List<dynamic>)
            .map(
                (item) => MusicaMaisPedida.deJson(item as Map<String, dynamic>))
            .toList(),
      );
}
