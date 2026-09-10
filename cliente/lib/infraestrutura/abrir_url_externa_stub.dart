import 'url_externa_validacao.dart';

Future<void> abrirUrlExterna(Uri url) => urlExternaPermitida(url)
    ? throw UnsupportedError('Abertura de links disponível somente na Web.')
    : throw ArgumentError('Informe um link público HTTP ou HTTPS válido.');

typedef FinalizarAberturaExterna = Future<void> Function(Uri? url);

FinalizarAberturaExterna prepararAberturaExterna() => (url) async {
      if (url != null) await abrirUrlExterna(url);
    };
