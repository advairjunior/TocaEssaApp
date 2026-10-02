part 'modelos_estatisticas.dart';
part 'modelos_resenha.dart';
part 'modelos_cifras.dart';
part 'modelos_repertorio.dart';

class PerfilArtistico {
  const PerfilArtistico(
      {required this.id,
      required this.nomeArtistico,
      this.bio,
      this.fotoUrl,
      this.instagram,
      this.whatsapp,
      this.apoioPixDisponivel = false});

  final String id;
  final String nomeArtistico;
  final String? bio;
  final String? fotoUrl;
  final String? instagram;
  final String? whatsapp;
  final bool apoioPixDisponivel;

  factory PerfilArtistico.deJson(Map<String, dynamic> json) => PerfilArtistico(
        id: json['id'] as String,
        nomeArtistico: json['nomeArtistico'] as String,
        bio: json['bio'] as String?,
        fotoUrl: json['fotoUrl'] as String?,
        instagram: json['instagram'] as String?,
        whatsapp: json['whatsapp'] as String?,
        apoioPixDisponivel: json['apoioPixDisponivel'] as bool? ?? false,
      );
}

class ConfiguracaoPerfilArtistico {
  const ConfiguracaoPerfilArtistico({
    required this.perfil,
    this.instagram,
    this.exibirInstagram = false,
    this.whatsapp,
    this.exibirWhatsapp = false,
    this.pixAtivo = false,
    this.pixChave,
    this.pixNomeBeneficiario,
    this.pixCidadeBeneficiario,
    this.pixMensagem,
  });

  final PerfilArtistico perfil;
  final String? instagram;
  final bool exibirInstagram;
  final String? whatsapp;
  final bool exibirWhatsapp;
  final bool pixAtivo;
  final String? pixChave;
  final String? pixNomeBeneficiario;
  final String? pixCidadeBeneficiario;
  final String? pixMensagem;

  factory ConfiguracaoPerfilArtistico.deJson(Map<String, dynamic> json) {
    final perfilJson = json['perfil'] as Map<String, dynamic>? ?? json;
    return ConfiguracaoPerfilArtistico(
      perfil: PerfilArtistico.deJson(perfilJson),
      instagram:
          json['instagram'] as String? ?? perfilJson['instagram'] as String?,
      exibirInstagram:
          json['exibirInstagram'] as bool? ?? perfilJson['instagram'] != null,
      whatsapp:
          json['whatsapp'] as String? ?? perfilJson['whatsapp'] as String?,
      exibirWhatsapp:
          json['exibirWhatsapp'] as bool? ?? perfilJson['whatsapp'] != null,
      pixAtivo: json['pixAtivo'] as bool? ??
          perfilJson['apoioPixDisponivel'] as bool? ??
          false,
      pixChave: json['pixChave'] as String?,
      pixNomeBeneficiario: json['pixNomeBeneficiario'] as String?,
      pixCidadeBeneficiario: json['pixCidadeBeneficiario'] as String?,
      pixMensagem: json['pixMensagem'] as String?,
    );
  }

  ConfiguracaoPerfilArtistico comPerfil(PerfilArtistico novoPerfil) =>
      ConfiguracaoPerfilArtistico(
        perfil: novoPerfil,
        instagram: instagram,
        exibirInstagram: exibirInstagram,
        whatsapp: whatsapp,
        exibirWhatsapp: exibirWhatsapp,
        pixAtivo: pixAtivo,
        pixChave: pixChave,
        pixNomeBeneficiario: pixNomeBeneficiario,
        pixCidadeBeneficiario: pixCidadeBeneficiario,
        pixMensagem: pixMensagem,
      );
}

class ApoioPix {
  const ApoioPix({
    required this.valor,
    required this.pixCopiaECola,
    required this.mensagem,
  });

  final double valor;
  final String pixCopiaECola;
  final String mensagem;

  /// Chave do recebedor lida do próprio payload (campo 26, subcampo 01),
  /// para quem prefere colar a chave no banco e digitar o valor.
  String? get chavePix {
    final contaPix = _campoPix(pixCopiaECola, '26');
    return contaPix == null ? null : _campoPix(contaPix, '01');
  }

  static String? _campoPix(String texto, String id) {
    var posicao = 0;
    while (posicao + 4 <= texto.length) {
      final tamanho = int.tryParse(texto.substring(posicao + 2, posicao + 4));
      final fim = posicao + 4 + (tamanho ?? 0);
      if (tamanho == null || fim > texto.length) return null;
      if (texto.substring(posicao, posicao + 2) == id) {
        return texto.substring(posicao + 4, fim);
      }
      posicao = fim;
    }
    return null;
  }

  factory ApoioPix.deJson(Map<String, dynamic> json) => ApoioPix(
        valor: (json['valor'] as num).toDouble(),
        pixCopiaECola: json['pixCopiaECola'] as String,
        mensagem: json['mensagem'] as String,
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

  String get rotuloCurto => switch (this) {
        publica => 'Pública',
        resenhaEntreAmigos => 'Resenha',
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
    this.quantidadePedidos = 1,
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
  final int quantidadePedidos;
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
        quantidadePedidos: json['quantidadePedidos'] as int? ?? 1,
        criadoEm: DateTime.parse(json['criadoEm'] as String),
      );
}

class GrupoPedidoMusical {
  const GrupoPedidoMusical({
    required this.pedidoRepresentativoId,
    required this.pedidoIds,
    required this.apresentacaoId,
    required this.musica,
    required this.status,
    required this.criadoEm,
    required this.quantidadePedidos,
    required this.solicitantes,
    this.artista,
    this.posicao,
    this.formaParticipacao = FormaParticipacaoPedido.pedidoNormal,
    this.tomPreferido,
    this.recado,
    this.tipo = TipoPedido.musica,
    this.destinatarioAlo,
    this.quantidadeAvaliacoes = 0,
    this.mediaAvaliacoes,
  });

  final String pedidoRepresentativoId;
  final List<String> pedidoIds;
  final String apresentacaoId;
  final String musica;
  final String? artista;
  final StatusPedidoMusical status;
  final int? posicao;
  final DateTime criadoEm;
  final FormaParticipacaoPedido formaParticipacao;
  final String? tomPreferido;
  final String? recado;
  final TipoPedido tipo;
  final String? destinatarioAlo;
  final int quantidadePedidos;
  final List<String> solicitantes;
  final int quantidadeAvaliacoes;
  final double? mediaAvaliacoes;

  factory GrupoPedidoMusical.deJson(Map<String, dynamic> json) =>
      GrupoPedidoMusical(
        pedidoRepresentativoId: json['pedidoRepresentativoId'] as String,
        pedidoIds: (json['pedidoIds'] as List<dynamic>)
            .map((item) => item.toString())
            .toList(),
        apresentacaoId: json['apresentacaoId'] as String,
        musica: json['musica'] as String,
        artista: json['artista'] as String?,
        status: StatusPedidoMusical.deJson(json['status'] as String),
        posicao: json['posicao'] as int?,
        criadoEm: DateTime.parse(json['criadoEm'] as String),
        formaParticipacao: FormaParticipacaoPedido.deJson(
            json['formaParticipacao'] as String?),
        tomPreferido: json['tomPreferido'] as String?,
        recado: json['recado'] as String?,
        tipo: TipoPedido.deJson(json['tipo'] as String?),
        destinatarioAlo: json['destinatarioAlo'] as String?,
        quantidadePedidos: json['quantidadePedidos'] as int? ?? 1,
        solicitantes: (json['solicitantes'] as List<dynamic>? ?? const [])
            .map((item) => item.toString())
            .toList(),
        quantidadeAvaliacoes: json['quantidadeAvaliacoes'] as int? ?? 0,
        mediaAvaliacoes: (json['mediaAvaliacoes'] as num?)?.toDouble(),
      );

  PedidoMusical comoPedidoMusical() => PedidoMusical(
        id: pedidoRepresentativoId,
        apresentacaoId: apresentacaoId,
        musica: musica,
        artista: artista,
        status: status,
        posicao: posicao,
        criadoEm: criadoEm,
        formaParticipacao: formaParticipacao,
        tomPreferido: tomPreferido,
        recado: recado,
        tipo: tipo,
        destinatarioAlo: destinatarioAlo,
        quantidadeAvaliacoes: quantidadeAvaliacoes,
        mediaAvaliacoes: mediaAvaliacoes,
        solicitantes: solicitantes,
        nomeSolicitante: solicitantes.length == 1 ? solicitantes.first : null,
        quantidadePedidos: quantidadePedidos,
      );
}
