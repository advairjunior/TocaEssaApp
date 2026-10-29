/// O "A seguir" da TV: a próxima música e, se for pedido, quem pediu
/// ("Lua · pedida por Carla e mais 2"), para quem pediu se sentir chamado.
String aSeguirDaTv(String titulo, List<String> solicitantes) {
  final nomes = [
    for (final nome in solicitantes)
      if (nome.trim().isNotEmpty) nome.trim()
  ];
  return switch (nomes) {
    [] => titulo,
    [final unico] => '$titulo · pedida por $unico',
    [final primeiro, final segundo] =>
      '$titulo · pedida por $primeiro e $segundo',
    [final primeiro, ...final outros] =>
      '$titulo · pedida por $primeiro e mais ${outros.length}',
  };
}
