import 'package:web/web.dart' as web;

import 'url_externa_validacao.dart';

Future<void> abrirUrlExterna(Uri url) async {
  _validar(url);
  web.HTMLAnchorElement()
    ..href = url.toString()
    ..target = '_blank'
    ..rel = 'noopener noreferrer'
    ..click();
}

typedef FinalizarAberturaExterna = Future<void> Function(Uri? url);

FinalizarAberturaExterna prepararAberturaExterna() {
  final janela = web.window.open('about:blank', '_blank');
  if (janela == null) {
    throw StateError(
        'O navegador bloqueou a nova aba. Permita pop-ups para o TocaEssa.');
  }
  janela.opener = null;
  return (url) async {
    if (url == null) {
      janela.close();
    } else {
      _validar(url);
      final link = janela.document.createElement('a') as web.HTMLAnchorElement
        ..href = url.toString()
        ..target = '_self'
        ..rel = 'noreferrer';
      janela.document.body?.append(link);
      link.click();
    }
  };
}

void _validar(Uri url) {
  if (!urlExternaPermitida(url)) {
    throw ArgumentError('Informe um link público HTTP ou HTTPS válido.');
  }
}
