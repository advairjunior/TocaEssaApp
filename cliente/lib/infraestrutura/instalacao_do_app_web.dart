import 'dart:js_interop';

import 'package:web/web.dart';

import 'instalacao_do_app.dart';

InstalacaoDoApp criarInstalacaoDoNavegador() => _InstalacaoWeb();

/// Pedido de instalação guardado pelo index.html (`beforeinstallprompt`),
/// que costuma chegar antes de o Flutter carregar.
@JS('pedidoDeInstalacaoDoTocaEssa')
external _PedidoDeInstalacao? get _pedidoGuardado;

@JS('pedidoDeInstalacaoDoTocaEssa')
external set _pedidoGuardado(_PedidoDeInstalacao? pedido);

extension type _PedidoDeInstalacao._(JSObject _) implements JSObject {
  external JSPromise<JSAny?> prompt();
  external JSPromise<_EscolhaDoUsuario> get userChoice;
}

extension type _EscolhaDoUsuario._(JSObject _) implements JSObject {
  external String get outcome;
}

@JS('navigator.standalone')
external bool? get _abertoPelaTelaDeInicioNoIphone;

class _InstalacaoWeb implements InstalacaoDoApp {
  @override
  bool get instalado =>
      window.matchMedia('(display-mode: standalone)').matches ||
      _abertoPelaTelaDeInicioNoIphone == true;

  @override
  bool get podePedirAoNavegador => _pedidoGuardado != null;

  @override
  bool get iPhone {
    final agente = window.navigator.userAgent;
    // iPad novo se apresenta como Mac, mas com toque.
    return RegExp('iPhone|iPad|iPod').hasMatch(agente) ||
        (agente.contains('Macintosh') && window.navigator.maxTouchPoints > 1);
  }

  @override
  Future<bool> pedir() async {
    final pedido = _pedidoGuardado;
    if (pedido == null) return false;
    // O navegador só aceita usar o mesmo pedido uma vez.
    _pedidoGuardado = null;
    await pedido.prompt().toDart;
    final escolha = await pedido.userChoice.toDart;
    return escolha.outcome == 'accepted';
  }
}
