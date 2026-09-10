import 'package:web/web.dart' as web;

Future<void> abrirUrlExterna(Uri url) async {
  web.window.open(url.toString(), '_blank', 'noopener,noreferrer');
}
