part of 'modelos.dart';

enum TipoDaParte {
  estrofe,
  refrao;

  factory TipoDaParte.deJson(String valor) =>
      valor == 'Refrao' ? refrao : estrofe;

  String get rotulo => switch (this) {
        estrofe => 'Estrofe',
        refrao => 'Refrão',
      };
}

/// Parte da letra de um hino e quem a canta; sem cantores é de Todos.
class ParteDoHino {
  const ParteDoHino({
    required this.tipo,
    required this.texto,
    required this.cantores,
    required this.escolhidaAMao,
  });

  final TipoDaParte tipo;
  final String texto;
  final List<String> cantores;
  final bool escolhidaAMao;

  bool get deTodos => cantores.isEmpty;

  String get quemCanta => deTodos ? 'Todos' : cantores.join(' e ');

  factory ParteDoHino.deJson(Map<String, dynamic> json) => ParteDoHino(
        tipo: TipoDaParte.deJson(json['tipo'] as String? ?? ''),
        texto: json['texto'] as String? ?? '',
        cantores: _textos(json['cantores']),
        escolhidaAMao: json['escolhidaAMao'] as bool? ?? false,
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
  const PlacarDoCantor({required this.nome, required this.estrofes});

  final String nome;
  final int estrofes;

  factory PlacarDoCantor.deJson(Map<String, dynamic> json) => PlacarDoCantor(
        nome: json['nome'] as String? ?? '',
        estrofes: (json['estrofes'] as num?)?.toInt() ?? 0,
      );
}

/// O louvor visto pelo artista: cantores, placar e a escala de cada hino.
class LouvorDoArtista {
  const LouvorDoArtista({
    required this.cantores,
    required this.placar,
    required this.hinos,
  });

  final List<String> cantores;
  final List<PlacarDoCantor> placar;
  final List<HinoDoLouvor> hinos;

  factory LouvorDoArtista.deJson(Map<String, dynamic> json) => LouvorDoArtista(
        cantores: _textos(json['cantores']),
        placar: [
          for (final item in json['placar'] as List<dynamic>? ?? const [])
            PlacarDoCantor.deJson(item as Map<String, dynamic>),
        ],
        hinos: _hinos(json['hinos']),
      );
}

/// O que cada participante vê pelo código.
class RoteiroDoLouvor {
  const RoteiroDoLouvor({
    required this.nome,
    required this.cantores,
    required this.hinoAtualId,
    required this.hinos,
  });

  final String nome;
  final List<String> cantores;
  final String? hinoAtualId;
  final List<HinoDoLouvor> hinos;

  factory RoteiroDoLouvor.deJson(Map<String, dynamic> json) => RoteiroDoLouvor(
        nome: json['nome'] as String? ?? '',
        cantores: _textos(json['cantores']),
        hinoAtualId: json['hinoAtualId'] as String?,
        hinos: _hinos(json['hinos']),
      );
}

List<String> _textos(Object? valor) => [
      for (final item in valor as List<dynamic>? ?? const []) item as String,
    ];

List<HinoDoLouvor> _hinos(Object? valor) => [
      for (final hino in valor as List<dynamic>? ?? const [])
        HinoDoLouvor.deJson(hino as Map<String, dynamic>),
    ];
