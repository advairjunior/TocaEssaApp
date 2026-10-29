part of 'sequencia_do_palco.dart';

/// A noite de outro artista, para o músico que entrou pelo convite: a mesma
/// setlist e os mesmos pedidos do dono, com as cifras que o dono preparou
/// (lidas pela rota do evento). Ele marca o que tocou, mas não cola nem
/// corrige cifra: a cifra é do dono.
class SequenciaDoConvidado extends SequenciaDoPalco {
  SequenciaDoConvidado({
    required super.api,
    required super.apresentacaoId,
    super.codigo,
    super.vocabulario,
  });

  @override
  Future<ResultadoCifraDoArtista> consultarCifra(MusicaDoPalco musica) =>
      api.consultarCifraDaNoite(apresentacaoId, musica.titulo, musica.artista);

  @override
  bool get colaCifra => false;
}
