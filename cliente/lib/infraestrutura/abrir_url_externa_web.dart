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

FinalizarAberturaExterna prepararAberturaExterna() =>
    _finalizarEm(_abrirAbaEmBranco());

// Aba onde a última cifra foi aberta. Cada cifra nova fecha a anterior, para
// sobrar só o app e uma cifra: no iPhone, basta deslizar a barra de endereço
// para ir de uma para a outra.
web.Window? _abaDaCifra;

Future<void> abrirNaAbaDaCifra(Uri url) {
  _validar(url);
  return prepararAberturaNaAbaDaCifra()(url);
}

FinalizarAberturaExterna prepararAberturaNaAbaDaCifra() {
  final janela = _abrirAbaEmBranco();
  final finalizar = _finalizarEm(janela);
  return (url) async {
    await finalizar(url);
    if (url == null) return;
    final anterior = _abaDaCifra;
    _abaDaCifra = janela;
    if (anterior != null && !anterior.closed) anterior.close();
  };
}

web.Window _abrirAbaEmBranco() {
  final janela = web.window.open('about:blank', '_blank');
  if (janela == null) {
    throw StateError(
        'O navegador bloqueou a nova aba. Permita pop-ups para o TocaEssa.');
  }
  janela.opener = null;
  return janela;
}

FinalizarAberturaExterna _finalizarEm(web.Window janela) => (url) async {
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

void _validar(Uri url) {
  if (!urlExternaPermitida(url)) {
    throw ArgumentError('Informe um link público HTTP ou HTTPS válido.');
  }
}
