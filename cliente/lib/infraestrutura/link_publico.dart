/// Link público de um show pelo código, o mesmo do QR Code. Com [hino], o
/// roteiro do louvor abre direto nele.
String linkPublicoDoShow(String codigo, {String? hino}) =>
    '${_origem()}/#/publico/$codigo'
    '${hino == null ? '' : '?hino=${Uri.encodeQueryComponent(hino)}'}';

/// Link de uma cifra fora do louvor: abre direto nela, sem conta.
String linkDaCifra(String codigo) => '${_origem()}/#/cifra/$codigo';

/// Endereço para abrir no navegador da TV da Letra na TV, sem o "https://"
/// que ninguém precisa digitar no controle.
String enderecoDaTv() =>
    '${_origem().replaceFirst(RegExp(r'^https?://'), '')}/#/tv';

// Endereço do app no navegador; fora dele (testes), o local.
String _origem() {
  final base = Uri.base;
  return base.scheme == 'http' || base.scheme == 'https'
      ? base.origin
      : 'http://localhost:5173';
}
