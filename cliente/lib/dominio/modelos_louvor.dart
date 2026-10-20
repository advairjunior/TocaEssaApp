part of 'modelos.dart';

enum TipoDaParte {
  estrofe,
  refrao,
  instrumental;

  factory TipoDaParte.deJson(String valor) => switch (valor) {
        'Refrao' => refrao,
        'Instrumental' => instrumental,
        _ => estrofe,
      };

  String get rotulo => switch (this) {
        estrofe => 'Estrofe',
        refrao => 'Refrão',
        instrumental => 'Instrumental',
      };
}

/// Parte da letra de um hino e quem a canta; sem cantores é de Todos (ou de
/// ninguém, numa parte instrumental como um solo).
class ParteDoHino {
  const ParteDoHino({
    required this.tipo,
    required this.texto,
    required this.cantores,
    required this.definida,
    this.nome,
    this.vezes = 1,
  });

  final TipoDaParte tipo;
  final String texto;
  final List<String> cantores;
  // Falso: a parte ainda não foi escalada.
  final bool definida;
  // Da parte instrumental, como "Solo sax tenor".
  final String? nome;
  // De marcações como "(Coro 2x)".
  final int vezes;

  bool get deTodos => cantores.isEmpty;

  String get quemCanta => deTodos ? 'Todos' : cantores.join(' e ');

  factory ParteDoHino.deJson(Map<String, dynamic> json) => ParteDoHino(
        tipo: TipoDaParte.deJson(json['tipo'] as String? ?? ''),
        texto: json['texto'] as String? ?? '',
        cantores: _textos(json['cantores']),
        definida: json['definida'] as bool? ?? false,
        nome: json['nome'] as String?,
        vezes: (json['vezes'] as num?)?.toInt() ?? 1,
      );
}

class HinoDoLouvor {
  const HinoDoLouvor({
    required this.itemId,
    required this.titulo,
    this.artista,
    required this.tom,
    required this.tocado,
    required this.temLetra,
    required this.partes,
  });

  final String itemId;
  final String titulo;
  final String? artista;
  final String? tom;
  final bool tocado;
  final bool temLetra;
  final List<ParteDoHino> partes;

  /// Quantas partes do hino a pessoa canta no microfone.
  int partesDe(String nome) =>
      partes.where((parte) => parte.cantores.contains(nome)).length;

  factory HinoDoLouvor.deJson(Map<String, dynamic> json) => HinoDoLouvor(
        itemId: json['itemId'] as String,
        titulo: json['titulo'] as String? ?? '',
        artista: json['artista'] as String?,
        tom: json['tom'] as String?,
        tocado: json['tocado'] as bool? ?? false,
        temLetra: json['temLetra'] as bool? ?? false,
        partes: [
          for (final parte in json['partes'] as List<dynamic>? ?? const [])
            ParteDoHino.deJson(parte as Map<String, dynamic>),
        ],
      );
}

class PlacarDoCantor {
  const PlacarDoCantor({required this.nome, required this.pontos});

  final String nome;
  // Cada estrofe ou coro cantado vale um ponto.
  final int pontos;

  factory PlacarDoCantor.deJson(Map<String, dynamic> json) => PlacarDoCantor(
        nome: json['nome'] as String? ?? '',
        pontos: (json['pontos'] as num?)?.toInt() ?? 0,
      );
}

/// Quem toca os solos e o instrumento, como "José" e "sax tenor".
class Solista {
  const Solista({required this.nome, required this.instrumento});

  final String nome;
  final String instrumento;

  Map<String, Object?> paraJson() => {'nome': nome, 'instrumento': instrumento};

  factory Solista.deJson(Map<String, dynamic> json) => Solista(
        nome: json['nome'] as String? ?? '',
        instrumento: json['instrumento'] as String? ?? '',
      );
}

class PlacarDoSolista {
  const PlacarDoSolista({required this.nome, required this.solos});

  final String nome;
  final int solos;

  factory PlacarDoSolista.deJson(Map<String, dynamic> json) => PlacarDoSolista(
        nome: json['nome'] as String? ?? '',
        solos: (json['solos'] as num?)?.toInt() ?? 0,
      );
}

/// Como o louvor escala: [maximoDeCantoresPorHino] nulo reveza entre todos
/// os cantores; [corosComTodos] deixa todo coro para Todos, não só o final.
class ConfiguracaoDaEscala {
  const ConfiguracaoDaEscala({
    this.maximoDeCantoresPorHino,
    this.corosComTodos = false,
  });

  final int? maximoDeCantoresPorHino;
  final bool corosComTodos;

  Map<String, Object?> paraJson() => {
        'maximoDeCantoresPorHino': maximoDeCantoresPorHino,
        'corosComTodos': corosComTodos,
      };

  factory ConfiguracaoDaEscala.deJson(Map<String, dynamic>? json) =>
      ConfiguracaoDaEscala(
        maximoDeCantoresPorHino:
            (json?['maximoDeCantoresPorHino'] as num?)?.toInt(),
        corosComTodos: json?['corosComTodos'] as bool? ?? false,
      );
}

/// O louvor visto pelo artista: cantores, solistas, placares, a escala de
/// cada hino e como ela é feita.
class LouvorDoArtista {
  const LouvorDoArtista({
    required this.cantores,
    required this.placar,
    required this.hinos,
    this.solistas = const [],
    this.placarDosSolos = const [],
    this.configuracao = const ConfiguracaoDaEscala(),
  });

  final List<String> cantores;
  final List<PlacarDoCantor> placar;
  final List<HinoDoLouvor> hinos;
  final List<Solista> solistas;
  final List<PlacarDoSolista> placarDosSolos;
  final ConfiguracaoDaEscala configuracao;

  /// Cantores e solistas, sem repetir: quem pode escolher "Quem é você?".
  List<String> get participantes => _participantes(cantores, solistas);

  factory LouvorDoArtista.deJson(Map<String, dynamic> json) => LouvorDoArtista(
        cantores: _textos(json['cantores']),
        placar: [
          for (final item in json['placar'] as List<dynamic>? ?? const [])
            PlacarDoCantor.deJson(item as Map<String, dynamic>),
        ],
        hinos: _hinos(json['hinos']),
        solistas: _solistas(json['solistas']),
        placarDosSolos: [
          for (final item
              in json['placarDosSolos'] as List<dynamic>? ?? const [])
            PlacarDoSolista.deJson(item as Map<String, dynamic>),
        ],
        configuracao: ConfiguracaoDaEscala.deJson(
            json['configuracao'] as Map<String, dynamic>?),
      );
}

/// O que cada participante vê pelo código.
class RoteiroDoLouvor {
  const RoteiroDoLouvor({
    required this.nome,
    required this.cantores,
    required this.hinoAtualId,
    required this.hinos,
    this.solistas = const [],
  });

  final String nome;
  final List<String> cantores;
  final String? hinoAtualId;
  final List<HinoDoLouvor> hinos;
  final List<Solista> solistas;

  /// Cantores e solistas, sem repetir: quem pode escolher "Quem é você?".
  List<String> get participantes => _participantes(cantores, solistas);

  factory RoteiroDoLouvor.deJson(Map<String, dynamic> json) => RoteiroDoLouvor(
        nome: json['nome'] as String? ?? '',
        cantores: _textos(json['cantores']),
        hinoAtualId: json['hinoAtualId'] as String?,
        hinos: _hinos(json['hinos']),
        solistas: _solistas(json['solistas']),
      );
}

List<String> _participantes(List<String> cantores, List<Solista> solistas) => [
      ...cantores,
      for (final solista in solistas)
        if (!cantores.contains(solista.nome)) solista.nome,
    ];

List<Solista> _solistas(Object? valor) => [
      for (final item in valor as List<dynamic>? ?? const [])
        Solista.deJson(item as Map<String, dynamic>),
    ];

List<String> _textos(Object? valor) => [
      for (final item in valor as List<dynamic>? ?? const []) item as String,
    ];

List<HinoDoLouvor> _hinos(Object? valor) => [
      for (final hino in valor as List<dynamic>? ?? const [])
        HinoDoLouvor.deJson(hino as Map<String, dynamic>),
    ];
