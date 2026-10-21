import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

/// Abre a janela de compartilhar do aparelho (WhatsApp, Mensagens) com o
/// link. Responde falso onde ela não existe, como no computador, para quem
/// chama copiar o link. Desistir da janela também conta como resolvido.
/// Chamar direto no toque: o Safari só abre a janela em resposta a ele.
Future<bool> compartilharNoAparelho(String titulo, String url) async {
  final navegador = web.window.navigator;
  if (!(navegador as JSObject).has('share')) return false;
  try {
    await navegador.share(web.ShareData(title: titulo, url: url)).toDart;
  } catch (_) {
    // A pessoa fechou a janela sem escolher: nada a fazer.
  }
  return true;
}
