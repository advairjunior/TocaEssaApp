part of 'modelos.dart';

class Repertorio {
  const Repertorio({
    required this.id,
    required this.artistaId,
    required this.nome,
    required this.musicas,
  });

  final String id;
  final String artistaId;
  final String nome;
  final List<MusicaDoRepertorio> musicas;

  factory Repertorio.deJson(Map<String, dynamic> json) => Repertorio(
        id: json['id'] as String,
        artistaId: json['artistaId'] as String,
        nome: json['nome'] as String,
        musicas: (json['musicas'] as List<dynamic>)
            .map((m) => MusicaDoRepertorio.deJson(m as Map<String, dynamic>))
            .toList(),
      );
}

class MusicaDoRepertorio {
  const MusicaDoRepertorio({
    required this.id,
    required this.repertorioId,
    required this.titulo,
    this.artista,
    this.tom,
    required this.ordem,
  });

  final String id;
  final String repertorioId;
  final String titulo;
  final String? artista;
  final String? tom;
  final int ordem;

  factory MusicaDoRepertorio.deJson(Map<String, dynamic> json) =>
      MusicaDoRepertorio(
        id: json['id'] as String,
        repertorioId: json['repertorioId'] as String,
        titulo: json['titulo'] as String,
        artista: json['artista'] as String?,
        tom: json['tom'] as String?,
        ordem: json['ordem'] as int,
      );
}

class ItemDoSetlist {
  const ItemDoSetlist({
    required this.id,
    required this.apresentacaoId,
    required this.titulo,
    this.artista,
    this.tom,
    required this.tocada,
    required this.ordem,
  });

  final String id;
  final String apresentacaoId;
  final String titulo;
  final String? artista;
  final String? tom;
  final bool tocada;
  final int ordem;

  factory ItemDoSetlist.deJson(Map<String, dynamic> json) => ItemDoSetlist(
        id: json['id'] as String,
        apresentacaoId: json['apresentacaoId'] as String,
        titulo: json['titulo'] as String,
        artista: json['artista'] as String?,
        tom: json['tom'] as String?,
        tocada: json['tocada'] as bool,
        ordem: json['ordem'] as int,
      );
}
