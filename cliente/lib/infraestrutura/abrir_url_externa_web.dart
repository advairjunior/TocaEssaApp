import 'package:web/web.dart' as web;

Future<void> abrirUrlExterna(Uri url) async {
  final janela = web.window.open(url.toString(), '_blank');
  if (janela == null) {
    throw StateError(
        'O navegador bloqueou a nova aba. Permita pop-ups para o TocaEssa.');
  }
  janela.opener = null;
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
      janela.location.href = url.toString();
    }
  };
}
