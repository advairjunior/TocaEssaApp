import 'dart:async';

import 'package:web/web.dart';

class AssinaturaTempoReal {
  AssinaturaTempoReal(String endereco, void Function() aoAlterar) {
    _fonte = EventSource(endereco);
    _eventos = _fonte.onMessage.listen((_) => aoAlterar());
  }

  late final EventSource _fonte;
  late final StreamSubscription<MessageEvent> _eventos;

  void encerrar() {
    _eventos.cancel();
    _fonte.close();
  }
}
