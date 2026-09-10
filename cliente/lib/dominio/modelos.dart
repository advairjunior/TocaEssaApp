class PerfilArtistico {
  const PerfilArtistico(
      {required this.id, required this.nomeArtistico, this.bio, this.fotoUrl});

  final String id;
  final String nomeArtistico;
  final String? bio;
  final String? fotoUrl;

  factory PerfilArtistico.deJson(Map<String, dynamic> json) => PerfilArtistico(
        id: json['id'] as String,
        nomeArtistico: json['nomeArtistico'] as String,
        bio: json['bio'] as String?,
        fotoUrl: json['fotoUrl'] as String?,
      );
}

class ContaArtista {
  const ContaArtista({
    required this.id,
    required this.nome,
    required this.email,
    required this.criadoEm,
  });

  final String id;
  final String nome;
  final String email;
  final DateTime criadoEm;

  factory ContaArtista.deJson(Map<String, dynamic> json) => ContaArtista(
        id: json['id'] as String,
        nome: json['nome'] as String,
        email: json['email'] as String,
        criadoEm: DateTime.parse(json['criadoEm'] as String),
      );
}

class SessaoDoArtista {
  const SessaoDoArtista({required this.conta, required this.token});

  final ContaArtista conta;
  final String token;

  factory SessaoDoArtista.deJson(Map<String, dynamic> json) => SessaoDoArtista(
        conta: ContaArtista.deJson(json['conta'] as Map<String, dynamic>),
        token: json['token'] as String,
      );
}

enum StatusApresentacao {
  agendada,
  emAndamento,
  encerrada;

  factory StatusApresentacao.deJson(String valor) => switch (valor) {
        'EmAndamento' => emAndamento,
        'Encerrada' => encerrada,
        _ => agendada,
      };

  String get paraJson => switch (this) {
        agendada => 'Agendada',
        emAndamento => 'EmAndamento',
        encerrada => 'Encerrada',
      };

  String get rotulo => switch (this) {
        agendada => 'Agendada',
        emAndamento => 'Em andamento',
        encerrada => 'Encerrada',
      };
}

enum TipoApresentacao {
  publica,
  resenhaEntreAmigos;

  factory TipoApresentacao.deJson(String valor) =>
      valor == 'ResenhaEntreAmigos' ? resenhaEntreAmigos : publica;

  String get paraJson => switch (this) {
        publica => 'Publica',
        resenhaEntreAmigos => 'ResenhaEntreAmigos',
      };

  String get rotulo => switch (this) {
        publica => 'Apresentação Pública',
        resenhaEntreAmigos => 'Resenha entre Amigos',
      };

  String get descricao => switch (this) {
        publica => 'Entrada rápida pelo código, sem cadastro.',
        resenhaEntreAmigos =>
          'Encontro identificado, preparado para perfis e histórico entre amigos.',
      };
}

class Apresentacao {
  const Apresentacao({
    required this.id,
    required this.nome,
    required this.data,
    required this.local,
    required this.codigo,
    required this.perfilArtistico,
    required this.pedidosAbertos,
    required this.status,
    required this.tipo,
    this.fotoRetrospectivaUrl,
  });

  final String id;
  final String nome;
  final DateTime data;
  final String local;
  final String codigo;
  final PerfilArtistico perfilArtistico;
  final bool pedidosAbertos;
  final StatusApresentacao status;
  final TipoApresentacao tipo;
  final String? fotoRetrospectivaUrl;

  factory Apresentacao.deJson(Map<String, dynamic> json) => Apresentacao(
        id: json['id'] as String,
        nome: json['nome'] as String,
        data: DateTime.parse(json['data'] as String),
        local: json['local'] as String,
        codigo: json['codigo'] as String,
        perfilArtistico: PerfilArtistico.deJson(
            json['perfilArtistico'] as Map<String, dynamic>),
        pedidosAbertos: json['pedidosAbertos'] as bool? ?? true,
        status: StatusApresentacao.deJson(
          json['status'] as String? ?? 'Agendada',
        ),
        tipo: TipoApresentacao.deJson(
          json['tipo'] as String? ?? 'Publica',
        ),
        fotoRetrospectivaUrl: json['fotoRetrospectivaUrl'] as String?,
      );
}

class ApresentacaoCriada {
  const ApresentacaoCriada(
      {required this.apresentacao, required this.linkPublico});

  final Apresentacao apresentacao;
  final String linkPublico;

  factory ApresentacaoCriada.deJson(Map<String, dynamic> json) =>
      ApresentacaoCriada(
        apresentacao:
            Apresentacao.deJson(json['apresentacao'] as Map<String, dynamic>),
        linkPublico: json['linkPublico'] as String,
      );
}

enum StatusPedidoMusical {
  aguardando,
  aceito,
  tocandoAgora,
  finalizado,
  naoConhecemos,
  aindaNaoSabemosTocar,
  canceladoPeloPublico;

  factory StatusPedidoMusical.deJson(String valor) => switch (valor) {
        'Aceito' => aceito,
        'TocandoAgora' => tocandoAgora,
        'Finalizado' => finalizado,
        'NaoConhecemos' => naoConhecemos,
        'AindaNaoSabemosTocar' => aindaNaoSabemosTocar,
        'CanceladoPeloPublico' => canceladoPeloPublico,
        _ => aguardando,
      };

  String get paraJson => switch (this) {
        aguardando => 'Aguardando',
        aceito => 'Aceito',
        tocandoAgora => 'TocandoAgora',
        finalizado => 'Finalizado',
        naoConhecemos => 'NaoConhecemos',
        aindaNaoSabemosTocar => 'AindaNaoSabemosTocar',
        canceladoPeloPublico => 'CanceladoPeloPublico',
      };

  String get rotulo => switch (this) {
        aguardando => 'Aguardando análise',
        aceito => 'Aceito',
        tocandoAgora => 'Tocando agora',
        finalizado => 'Finalizado',
        naoConhecemos => 'Não conhecemos',
        aindaNaoSabemosTocar => 'Ainda não sabemos tocar',
        canceladoPeloPublico => 'Cancelado por você',
      };
}

enum FormaParticipacaoPedido {
  pedidoNormal,
  euCanto;

  factory FormaParticipacaoPedido.deJson(String? valor) => switch (valor) {
        'EuCanto' => euCanto,
        _ => pedidoNormal,
      };

  String get paraJson => switch (this) {
        pedidoNormal => 'PedidoNormal',
        euCanto => 'EuCanto',
      };

  String get rotulo => switch (this) {
        pedidoNormal => 'Pedido normal',
        euCanto => 'Eu canto',
      };
}

enum TipoPedido {
  musica,
  alo;

  factory TipoPedido.deJson(String? valor) => valor == 'Alo' ? alo : musica;

  String get paraJson => this == alo ? 'Alo' : 'Musica';
}

class PedidoMusical {
  const PedidoMusical({
    required this.id,
    required this.apresentacaoId,
    required this.musica,
    required this.status,
    required this.criadoEm,
    this.artista,
    this.nomeSolicitante,
    this.posicao,
    this.avaliacao,
    this.formaParticipacao = FormaParticipacaoPedido.pedidoNormal,
    this.tomPreferido,
    this.recado,
    this.tipo = TipoPedido.musica,
    this.destinatarioAlo,
    this.quantidadeAvaliacoes = 0,
    this.mediaAvaliacoes,
    this.minhaAvaliacao,
    this.solicitantes = const [],
  });

  final String id;
  final String apresentacaoId;
  final String musica;
  final String? artista;
  final String? nomeSolicitante;
  final StatusPedidoMusical status;
  final int? posicao;
  final int? avaliacao;
  final FormaParticipacaoPedido formaParticipacao;
  final String? tomPreferido;
  final String? recado;
  final TipoPedido tipo;
  final String? destinatarioAlo;
  final int quantidadeAvaliacoes;
  final double? mediaAvaliacoes;
  final int? minhaAvaliacao;
  final List<String> solicitantes;
  final DateTime criadoEm;

  factory PedidoMusical.deJson(Map<String, dynamic> json) => PedidoMusical(
        id: json['id'] as String,
        apresentacaoId: json['apresentacaoId'] as String,
        musica: json['musica'] as String,
        artista: json['artista'] as String?,
        nomeSolicitante: json['nomeSolicitante'] as String?,
        status: StatusPedidoMusical.deJson(json['status'] as String),
        posicao: json['posicao'] as int?,
        avaliacao: json['avaliacao'] as int?,
        formaParticipacao: FormaParticipacaoPedido.deJson(
            json['formaParticipacao'] as String?),
        tomPreferido: json['tomPreferido'] as String?,
        recado: json['recado'] as String?,
        tipo: TipoPedido.deJson(json['tipo'] as String?),
        destinatarioAlo: json['destinatarioAlo'] as String?,
        quantidadeAvaliacoes: json['quantidadeAvaliacoes'] as int? ?? 0,
        mediaAvaliacoes: (json['mediaAvaliacoes'] as num?)?.toDouble(),
        minhaAvaliacao: json['minhaAvaliacao'] as int?,
        solicitantes: (json['solicitantes'] as List<dynamic>? ?? const [])
            .map((item) => item.toString())
            .toList(),
        criadoEm: DateTime.parse(json['criadoEm'] as String),
      );
}

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

class CifraDoArtista {
  const CifraDoArtista({
    required this.id,
    required this.artistaId,
    required this.musica,
    required this.url,
    required this.fonte,
    required this.criadaEm,
    required this.atualizadaEm,
    this.artista,
  });

  final String id;
  final String artistaId;
  final String musica;
  final String? artista;
  final String url;
  final String fonte;
  final DateTime criadaEm;
  final DateTime atualizadaEm;

  factory CifraDoArtista.deJson(Map<String, dynamic> json) => CifraDoArtista(
        id: json['id'] as String,
        artistaId: json['artistaId'] as String,
        musica: json['musica'] as String,
        artista: json['artista'] as String?,
        url: json['url'] as String,
        fonte: json['fonte'] as String,
        criadaEm: DateTime.parse(json['criadaEm'] as String),
        atualizadaEm: DateTime.parse(json['atualizadaEm'] as String),
      );
}

class ResultadoCifraDoArtista {
  const ResultadoCifraDoArtista({
    required this.urlPesquisa,
    this.cifra,
    this.urlSugerida,
  });

  final CifraDoArtista? cifra;
  final String? urlSugerida;
  final String urlPesquisa;

  factory ResultadoCifraDoArtista.deJson(Map<String, dynamic> json) =>
      ResultadoCifraDoArtista(
        cifra: json['cifra'] == null
            ? null
            : CifraDoArtista.deJson(json['cifra'] as Map<String, dynamic>),
        urlSugerida: json['urlSugerida'] as String?,
        urlPesquisa: json['urlPesquisa'] as String,
      );
}
