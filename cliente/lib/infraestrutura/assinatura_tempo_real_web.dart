import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart';

class AssinaturaTempoReal {
  /// [aoReceber] recebe o dado do evento, como a linha da TV ("linha:3:6").
  AssinaturaTempoReal(String endereco, void Function() aoAlterar,
      {void Function(String dado)? aoReceber}) {
    _fonte = EventSource(endereco);
    _eventos = _fonte.onMessage.listen((evento) {
      aoAlterar();
      aoReceber?.call((evento.data as JSString?)?.toDart ?? '');
    });
  }

  late final EventSource _fonte;
  late final StreamSubscription<MessageEvent> _eventos;

  void encerrar() {
    _eventos.cancel();
    _fonte.close();
  }
}
