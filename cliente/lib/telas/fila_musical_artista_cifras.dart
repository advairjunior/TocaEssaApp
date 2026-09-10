part of 'fila_musical_artista.dart';

extension _CifrasDaFila on _FilaMusicalArtistaState {
  Future<void> _abrirCifra(PedidoMusical pedido) async {
    FinalizarAberturaExterna? finalizarAbertura;
    try {
      finalizarAbertura = widget.prepararAbertura();
      final resultado =
          await widget.api.consultarCifra(pedido.musica, pedido.artista);
      if (!mounted) {
        await finalizarAbertura(null);
        return;
      }
      final salva = resultado.cifra;
      if (salva != null) {
        await finalizarAbertura(Uri.parse(salva.url));
        return;
      }
      await finalizarAbertura(null);
      await _mostrarEscolhaDaCifra(pedido, resultado);
    } catch (erro) {
      await finalizarAbertura?.call(null);
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
      abrirUrl: widget.abrirUrl,
    );
    if (decisao == null || !mounted) return;
    try {
      switch (decisao.tipo) {
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
          await widget.api.salvarCifra(
            pedido.musica,
            pedido.artista,
            decisao.url!,
          );
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Cifra salva para os próximos pedidos.'),
              ),
            );
          }
      }
    } catch (erro) {
      if (mounted) mostrarErro(context, erro);
    }
  }
}
