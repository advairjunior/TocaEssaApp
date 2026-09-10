Future<void> abrirUrlExterna(Uri url) =>
    throw UnsupportedError('Abertura de links disponível somente na Web.');

typedef FinalizarAberturaExterna = Future<void> Function(Uri? url);

FinalizarAberturaExterna prepararAberturaExterna() => (url) async {
      if (url != null) await abrirUrlExterna(url);
    };
