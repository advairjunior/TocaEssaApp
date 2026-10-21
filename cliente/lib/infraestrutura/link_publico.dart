/// Link público de um show pelo código, o mesmo do QR Code. Com [hino], o
/// roteiro do louvor abre direto nele.
String linkPublicoDoShow(String codigo, {String? hino}) {
  final base = Uri.base;
  final origem = base.scheme == 'http' || base.scheme == 'https'
      ? base.origin
      : 'http://localhost:5173';
  return '$origem/#/publico/$codigo'
      '${hino == null ? '' : '?hino=${Uri.encodeQueryComponent(hino)}'}';
}
