import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

void baixarArquivo(Uint8List bytes, String nome) {
  final blob = web.Blob([bytes.toJS].toJS);
  final endereco = web.URL.createObjectURL(blob);
  web.HTMLAnchorElement()
    ..href = endereco
    ..download = nome
    ..click();
  web.URL.revokeObjectURL(endereco);
}
