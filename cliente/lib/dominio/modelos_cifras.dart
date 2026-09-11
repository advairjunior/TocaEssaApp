part of 'modelos.dart';

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
