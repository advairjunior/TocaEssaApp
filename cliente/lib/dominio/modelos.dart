part 'modelos_estatisticas.dart';
part 'modelos_resenha.dart';
part 'modelos_cifras.dart';
part 'modelos_repertorio.dart';
part 'modelos_relogio.dart';
part 'modelos_louvor.dart';
part 'vocabulario.dart';
part 'modelos_pedidos.dart';
part 'modelos_karaoke.dart';

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
  resenhaEntreAmigos,
  louvor,
  karaoke;

  factory TipoApresentacao.deJson(String valor) => switch (valor) {
        'ResenhaEntreAmigos' => resenhaEntreAmigos,
        'Louvor' => louvor,
        'Karaoke' => karaoke,
        _ => publica,
      };

  String get paraJson => switch (this) {
        publica => 'Publica',
        resenhaEntreAmigos => 'ResenhaEntreAmigos',
        louvor => 'Louvor',
        karaoke => 'Karaoke',
      };

  String get rotulo => switch (this) {
        publica => 'Apresentação Pública',
        resenhaEntreAmigos => 'Resenha entre Amigos',
        louvor => 'Louvor',
        karaoke => 'Noite de Karaokê',
      };

  String get rotuloCurto => switch (this) {
        publica => 'Pública',
        resenhaEntreAmigos => 'Resenha',
        louvor => 'Louvor',
        karaoke => 'Karaokê',
      };

  /// Como o encontro aparece na memória de quem esteve lá.
  String get naMemoria => switch (this) {
        publica => 'Show',
        resenhaEntreAmigos => 'Resenha',
        louvor => 'Louvor',
        karaoke => 'Karaokê',
      };

  /// "Voltar para o show", "a resenha" ou "o louvor".
  String get voltarPara => switch (this) {
        publica => 'Voltar para o show',
        resenhaEntreAmigos => 'Voltar para a resenha',
        louvor => 'Voltar para o louvor',
        karaoke => 'Voltar para o karaokê',
      };

  String get descricao => switch (this) {
        publica => 'Entrada rápida pelo código, sem cadastro.',
        resenhaEntreAmigos =>
          'Encontro identificado, preparado para perfis e histórico entre amigos.',
        louvor =>
          'Hinos com revezamento: cada um acompanha a letra e a sua vez.',
        karaoke => 'Ordem sorteada, vídeo no YouTube e nota da galera.',
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
