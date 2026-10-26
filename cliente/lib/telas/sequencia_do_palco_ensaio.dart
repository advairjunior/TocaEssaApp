part of 'sequencia_do_palco.dart';

/// Músicas do acervo tocadas fora de um show, em casa ou no ensaio. Nada
/// vai para o servidor: sem tocada, sem relógio, sem histórico. Só a cifra
/// é buscada, a da página aberta e a da seguinte, porque o acervo inteiro
/// de uma vez demoraria a mostrar a primeira.
class SequenciaDoEnsaio extends SequenciaDoPalco {
  SequenciaDoEnsaio({
    required super.api,
    required List<MusicaDoRepertorio> musicas,
  }) : super(apresentacaoId: '') {
    itens = [
      for (final (indice, musica) in musicas.indexed)
        ItemDoSetlist(
          id: musica.id,
          apresentacaoId: '',
          titulo: musica.titulo,
          artista: musica.artista,
          tom: musica.tom,
          tocada: false,
          ordem: indice + 1,
        ),
    ];
  }

  final _buscando = <String>{};

  @override
  Future<void> carregar() async {}

  @override
  Future<void> recarregar() async {}

  /// Enquanto a cifra da página é buscada pela primeira vez.
  bool buscandoCifra(MusicaDoPalco pagina) => _buscando
      .contains(SequenciaDoPalco._chave(pagina.titulo, pagina.artista));

  /// Busca, uma vez cada, a cifra da página aberta e a da seguinte.
  void prepararPagina(MusicaDoPalco pagina) {
    final paginas = paginasDoLeitor;
    final indice =
        paginas.indexWhere((p) => SequenciaDoPalco.mesmaPagina(p, pagina));
    for (final musica in paginas.skip(indice < 0 ? 0 : indice).take(2)) {
      final chave = SequenciaDoPalco._chave(musica.titulo, musica.artista);
      if (_cifras.containsKey(chave) || !_buscando.add(chave)) continue;
      atualizarCifra(musica).whenComplete(() {
        _buscando.remove(chave);
        _avisar();
      });
    }
  }
}
