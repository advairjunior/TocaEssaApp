import 'dart:js_interop';

import 'package:web/web.dart' as web;

typedef LiberarTelaAcesa = void Function();

/// Impede a tela de apagar enquanto o modo palco está aberto. O navegador
/// solta o pedido quando a aba fica escondida (ao abrir a cifra), então ele é
/// refeito sempre que o app volta a aparecer. Navegador sem suporte segue
/// normalmente.
LiberarTelaAcesa manterTelaAcesaNoAparelho() {
  var ativa = true;
  web.WakeLockSentinel? sentinela;

  Future<void> pedir() async {
    if (!ativa || web.document.visibilityState != 'visible') return;
    try {
      sentinela = await web.window.navigator.wakeLock.request('screen').toDart;
      if (!ativa) await sentinela?.release().toDart;
    } catch (_) {
      // Sem suporte ou sem permissão: a tela apaga como de costume.
    }
  }

  final aoMudarVisibilidade = ((web.Event _) {
    pedir();
  }).toJS;
  web.document.addEventListener('visibilitychange', aoMudarVisibilidade);
  pedir();

  return () {
    ativa = false;
    web.document.removeEventListener('visibilitychange', aoMudarVisibilidade);
    sentinela?.release();
  };
}
