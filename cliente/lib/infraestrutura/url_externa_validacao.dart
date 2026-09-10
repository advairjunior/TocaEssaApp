bool urlExternaPermitida(Uri url) {
  if ((url.scheme != 'http' && url.scheme != 'https') ||
      url.userInfo.isNotEmpty ||
      !url.hasAuthority) {
    return false;
  }
  final host = url.host.toLowerCase();
  if (host.isEmpty ||
      host.length > 253 ||
      host.endsWith('.') ||
      host == 'localhost' ||
      host.endsWith('.localhost') ||
      host.endsWith('.local') ||
      host.contains(':')) {
    return false;
  }
  final rotulos = host.split('.');
  if (rotulos.length < 2 || rotulos.any((rotulo) => !_rotuloValido(rotulo))) {
    return false;
  }
  final ipv4 = rotulos.map(int.tryParse).toList();
  if (ipv4.every((item) => item != null)) {
    final bytes = ipv4.cast<int>();
    if (bytes.any((item) => item < 0 || item > 255)) return false;
    return !_ipv4LocalOuPrivado(bytes);
  }
  return true;
}

bool _rotuloValido(String rotulo) {
  if (rotulo.isEmpty ||
      rotulo.length > 63 ||
      rotulo.startsWith('-') ||
      rotulo.endsWith('-')) {
    return false;
  }
  return RegExp(r'^[a-z0-9-]+$').hasMatch(rotulo);
}

bool _ipv4LocalOuPrivado(List<int> ip) =>
    ip[0] == 0 ||
    ip[0] == 10 ||
    ip[0] == 127 ||
    (ip[0] == 100 && ip[1] >= 64 && ip[1] <= 127) ||
    (ip[0] == 169 && ip[1] == 254) ||
    (ip[0] == 172 && ip[1] >= 16 && ip[1] <= 31) ||
    (ip[0] == 192 && (ip[1] == 0 || ip[1] == 168)) ||
    (ip[0] == 198 && (ip[1] == 18 || ip[1] == 19)) ||
    ip[0] >= 224;
