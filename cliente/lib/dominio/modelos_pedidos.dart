part of 'modelos.dart';

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
