part of 'fila_musical_artista.dart';

extension _CifrasDaFila on _FilaMusicalArtistaState {
  Future<void> _abrirCifra(PedidoMusical pedido) async {
    try {
      final resultado =
          await widget.api.consultarCifra(pedido.musica, pedido.artista);
      if (!mounted) return;
      final salva = resultado.cifra;
      if (salva != null) {
        await widget.abrirUrl(Uri.parse(salva.url));
        return;
      }
      await _mostrarEscolhaDaCifra(pedido, resultado);
    } catch (erro) {
      if (mounted) mostrarErro(context, erro);
    }
  }

  Future<void> _escolherCifra(PedidoMusical pedido) async {
    try {
      final resultado =
          await widget.api.consultarCifra(pedido.musica, pedido.artista);
      if (mounted) await _mostrarEscolhaDaCifra(pedido, resultado);
    } catch (erro) {
      if (mounted) mostrarErro(context, erro);
    }
  }

  Future<void> _mostrarEscolhaDaCifra(
      PedidoMusical pedido, ResultadoCifraDoArtista resultado) async {
    final decisao = await mostrarEscolhaDeCifra(
      context,
      musica: pedido.musica,
      artista: pedido.artista,
      resultado: resultado,
    );
    if (decisao == null || !mounted) return;
    try {
      switch (decisao.tipo) {
        case TipoDecisaoCifra.pesquisar:
          await widget.abrirUrl(Uri.parse(resultado.urlPesquisa));
        case TipoDecisaoCifra.remover:
          final cifra = resultado.cifra;
          if (cifra == null) return;
          await widget.api.removerCifra(cifra.id);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Link da cifra removido.')),
            );
          }
        case TipoDecisaoCifra.salvar:
          final cifra = await widget.api.salvarCifra(
            pedido.musica,
            pedido.artista,
            decisao.url!,
          );
          await widget.abrirUrl(Uri.parse(cifra.url));
      }
    } catch (erro) {
      if (mounted) mostrarErro(context, erro);
    }
  }
}
