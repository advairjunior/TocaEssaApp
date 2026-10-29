/// TV recém-aberta: o token fica guardado nela e o código aparece na tela.
class NovaTv {
  const NovaTv({required this.id, required this.token, required this.codigo});

  factory NovaTv.deJson(Map<String, dynamic> json) => NovaTv(
        id: json['id'] as String,
        token: json['token'] as String,
        codigo: json['codigo'] as String,
      );

  final String id;
  final String token;
  final String codigo;
}

/// TV presa à conta, na lista do celular.
class TvDaConta {
  const TvDaConta({required this.id, required this.criadaEm});

  factory TvDaConta.deJson(Map<String, dynamic> json) => TvDaConta(
        id: json['id'] as String,
        criadaEm: DateTime.parse(json['criadaEm'] as String),
      );

  final String id;
  final DateTime criadaEm;
}

/// O que o celular do dono manda para as TVs da conta. Quem monta é a fonte
/// de cada tipo de evento (resenha agora, louvor depois); a TV só desenha.
class ConteudoParaTv {
  const ConteudoParaTv({
    required this.titulo,
    required this.texto,
    required this.linha,
    this.subtitulo,
    this.aSeguir,
    this.codigo,
  });

  final String titulo;
  final String? subtitulo;
  // A cifra colada: a TV separa a letra do mesmo jeito que o celular.
  final String texto;
  final String? aSeguir;
  // Código do evento, para a galera entrar e pedir.
  final String? codigo;
  final int linha;

  ConteudoParaTv naLinha(int linha) => ConteudoParaTv(
        titulo: titulo,
        subtitulo: subtitulo,
        texto: texto,
        aSeguir: aSeguir,
        codigo: codigo,
        linha: linha,
      );

  Map<String, dynamic> paraJson() => {
        'titulo': titulo,
        'subtitulo': subtitulo,
        'texto': texto,
        'aSeguir': aSeguir,
        'codigo': codigo,
        'linha': linha,
      };
}

/// O que a TV está mostrando. A versão muda a cada música nova.
class ConteudoDaTv {
  const ConteudoDaTv({
    required this.titulo,
    required this.texto,
    required this.linha,
    required this.versao,
    this.subtitulo,
    this.aSeguir,
    this.codigo,
  });

  factory ConteudoDaTv.deJson(Map<String, dynamic> json) => ConteudoDaTv(
        titulo: json['titulo'] as String,
        subtitulo: json['subtitulo'] as String?,
        texto: json['texto'] as String,
        aSeguir: json['aSeguir'] as String?,
        codigo: json['codigo'] as String?,
        linha: json['linha'] as int,
        versao: json['versao'] as int,
      );

  final String titulo;
  final String? subtitulo;
  final String texto;
  final String? aSeguir;
  final String? codigo;
  final int linha;
  final int versao;

  ConteudoDaTv naLinha(int linha) => ConteudoDaTv(
        titulo: titulo,
        subtitulo: subtitulo,
        texto: texto,
        aSeguir: aSeguir,
        codigo: codigo,
        linha: linha,
        versao: versao,
      );
}

/// O código, enquanto ninguém conectou a TV, ou o que mostrar.
class EstadoDaTv {
  const EstadoDaTv({required this.pareada, this.codigo, this.conteudo});

  factory EstadoDaTv.deJson(Map<String, dynamic> json) => EstadoDaTv(
        pareada: json['pareada'] as bool,
        codigo: json['codigo'] as String?,
        conteudo: switch (json['conteudo']) {
          final Map<String, dynamic> conteudo => ConteudoDaTv.deJson(conteudo),
          _ => null,
        },
      );

  final bool pareada;
  final String? codigo;
  final ConteudoDaTv? conteudo;
}

/// Evento do tempo real da TV: "linha:3:6" é a linha 6 da versão 3.
class EventoDaTv {
  const EventoDaTv({required this.versao, required this.linha});

  static EventoDaTv? ler(String dado) {
    final partes = dado.split(':');
    if (partes.length != 3 || partes.first != 'linha') return null;
    final versao = int.tryParse(partes[1]);
    final linha = int.tryParse(partes[2]);
    return versao == null || linha == null
        ? null
        : EventoDaTv(versao: versao, linha: linha);
  }

  final int versao;
  final int linha;

  @override
  bool operator ==(Object other) =>
      other is EventoDaTv && other.versao == versao && other.linha == linha;

  @override
  int get hashCode => Object.hash(versao, linha);
}

/// O servidor não conhece mais o token desta TV: ela pede um código novo.
class TvDesconhecida implements Exception {
  const TvDesconhecida();
}

/// A linha chegou antes da música (o servidor dormiu): mandar tudo de novo.
class TvAindaSemMusica implements Exception {
  const TvAindaSemMusica();
}

/// Link do comando da TV para o ajudante; o token vai no endereço.
class NovoComando {
  const NovoComando({required this.id, required this.token});

  final String id;
  final String token;

  factory NovoComando.deJson(Map<String, dynamic> json) =>
      NovoComando(id: json['id'] as String, token: json['token'] as String);
}

/// O que o celular do ajudante recebe: a letra da TV e o canal do tempo real.
class ComandoDoAjudante {
  const ComandoDoAjudante({required this.canal, this.conteudo});

  final String canal;
  final ConteudoDaTv? conteudo;

  factory ComandoDoAjudante.deJson(Map<String, dynamic> json) =>
      ComandoDoAjudante(
        canal: json['canal'] as String,
        conteudo: switch (json['conteudo']) {
          final Map<String, dynamic> conteudo => ConteudoDaTv.deJson(conteudo),
          _ => null,
        },
      );
}

/// O dono retomou o comando (ou gerou outro link).
class ComandoEncerrado implements Exception {
  const ComandoEncerrado();
}
