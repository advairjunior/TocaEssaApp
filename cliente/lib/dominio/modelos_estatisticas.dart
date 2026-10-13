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
    this.pessoasNoEvento = 0,
    this.pessoasQuePediram = 0,
    this.musicasRecusadas = const [],
    this.retrospectiva,
  });

  /// Números validados para o cartão; nulo em servidor antigo.
  final DadosDaRetrospectiva? retrospectiva;

  final int totalPedidos;
  final int aguardando;
  final int aceitos;
  final int tocados;
  final int recusados;
  final int avaliados;
  final double? mediaAvaliacoes;
  final List<MusicaMaisPedida> musicasMaisPedidas;

  /// Quem esteve no evento pelo app: abriu a página, entrou ou pediu.
  final int pessoasNoEvento;
  final int pessoasQuePediram;
  final List<MusicaMaisPedida> musicasRecusadas;

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
        pessoasNoEvento: json['pessoasNoEvento'] as int? ?? 0,
        pessoasQuePediram: json['pessoasQuePediram'] as int? ?? 0,
        musicasRecusadas: (json['musicasRecusadas'] as List<dynamic>? ?? [])
            .map(
                (item) => MusicaMaisPedida.deJson(item as Map<String, dynamic>))
            .toList(),
        retrospectiva: switch (json['retrospectiva']) {
          final Map<String, dynamic> dados =>
            DadosDaRetrospectiva.deJson(dados),
          _ => null,
        },
      );
}

/// Números do cartão de retrospectiva já validados pelo servidor: cada
/// pessoa conta uma vez por música, a favorita foi tocada e a duração é
/// plausível. Em [MusicaMaisPedida] daqui, a quantidade é de pessoas.
class DadosDaRetrospectiva {
  const DadosDaRetrospectiva({
    required this.favorita,
    required this.musicasAPedidoTocadas,
    required this.pedidosConsiderados,
    required this.pedidosAtendidos,
    required this.pessoasQueAvaliaram,
    required this.mediaDasAvaliacoes,
    required this.musicasTocadas,
    required this.alosDados,
    required this.iniciadaEm,
    required this.encerradaEm,
    required this.maisPedidasPorPessoas,
    required this.recusadasPorPessoas,
  });

  final MusicaMaisPedida? favorita;
  final int musicasAPedidoTocadas;
  final int pedidosConsiderados;
  final int pedidosAtendidos;
  final int pessoasQueAvaliaram;
  final double? mediaDasAvaliacoes;
  final int musicasTocadas;
  final int alosDados;
  final DateTime? iniciadaEm;
  final DateTime? encerradaEm;
  final List<MusicaMaisPedida> maisPedidasPorPessoas;
  final List<MusicaMaisPedida> recusadasPorPessoas;

  factory DadosDaRetrospectiva.deJson(Map<String, dynamic> json) {
    List<MusicaMaisPedida> musicas(String chave) =>
        (json[chave] as List<dynamic>? ?? [])
            .map((item) =>
                MusicaMaisPedida.deJson(item as Map<String, dynamic>))
            .toList();
    DateTime? data(String chave) => switch (json[chave]) {
          final String valor => DateTime.parse(valor),
          _ => null,
        };
    return DadosDaRetrospectiva(
      favorita: switch (json['favorita']) {
        final Map<String, dynamic> musica => MusicaMaisPedida.deJson(musica),
        _ => null,
      },
      musicasAPedidoTocadas: json['musicasAPedidoTocadas'] as int? ?? 0,
      pedidosConsiderados: json['pedidosConsiderados'] as int? ?? 0,
      pedidosAtendidos: json['pedidosAtendidos'] as int? ?? 0,
      pessoasQueAvaliaram: json['pessoasQueAvaliaram'] as int? ?? 0,
      mediaDasAvaliacoes: (json['mediaDasAvaliacoes'] as num?)?.toDouble(),
      musicasTocadas: json['musicasTocadas'] as int? ?? 0,
      alosDados: json['alosDados'] as int? ?? 0,
      iniciadaEm: data('iniciadaEm'),
      encerradaEm: data('encerradaEm'),
      maisPedidasPorPessoas: musicas('maisPedidasPorPessoas'),
      recusadasPorPessoas: musicas('recusadasPorPessoas'),
    );
  }
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
