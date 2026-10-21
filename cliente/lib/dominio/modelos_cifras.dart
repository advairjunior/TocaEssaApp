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
    this.texto,
  });

  final CifraDoArtista? cifra;
  final String? urlSugerida;
  final String urlPesquisa;

  /// Letra e cifra coladas no app, independentes do link.
  final String? texto;

  factory ResultadoCifraDoArtista.deJson(Map<String, dynamic> json) =>
      ResultadoCifraDoArtista(
        cifra: json['cifra'] == null
            ? null
            : CifraDoArtista.deJson(json['cifra'] as Map<String, dynamic>),
        urlSugerida: json['urlSugerida'] as String?,
        urlPesquisa: json['urlPesquisa'] as String,
        texto: json['texto'] as String?,
      );
}

/// Situação da cifra de uma música do repertório: se já tem cifra colada,
/// o link salvo e a pesquisa pronta para achar a cifra.
class CifraDaMusicaDoRepertorio {
  const CifraDaMusicaDoRepertorio({
    required this.musicaId,
    required this.temTexto,
    required this.urlPesquisa,
    this.url,
  });

  final String musicaId;
  final bool temTexto;
  final String? url;
  final String urlPesquisa;

  factory CifraDaMusicaDoRepertorio.deJson(Map<String, dynamic> json) =>
      CifraDaMusicaDoRepertorio(
        musicaId: json['musicaId'] as String,
        temTexto: json['temTexto'] as bool,
        url: json['url'] as String?,
        urlPesquisa: json['urlPesquisa'] as String,
      );
}

/// O que quem abre o link de uma cifra vê, sem conta.
class CifraCompartilhada {
  const CifraCompartilhada({
    required this.musica,
    this.artista,
    this.tom,
    required this.texto,
    this.nomeArtistico,
  });

  final String musica;
  final String? artista;
  final String? tom;
  final String texto;
  final String? nomeArtistico;

  factory CifraCompartilhada.deJson(Map<String, dynamic> json) =>
      CifraCompartilhada(
        musica: json['musica'] as String,
        artista: json['artista'] as String?,
        tom: json['tom'] as String?,
        texto: json['texto'] as String,
        nomeArtistico: json['nomeArtistico'] as String?,
      );
}
