/// Pedaço da letra de uma parte, cantado ou não pelo coral.
class PedacoDaLetra {
  const PedacoDaLetra(this.texto, {required this.coral});

  final String texto;
  final bool coral;
}

// "(Coral)", "[Coral]" ou "Coral:" numa linha sozinha começam o coral.
final _inicio = RegExp(r'^[\(\[]?\s*coral\s*[\)\]]?\s*:?$');
// "(Fim do coral)", "(Fim coral)" ou "(Coral fim)" terminam.
final _fim =
    RegExp(r'^[\(\[]?\s*(fim\s+(do\s+)?coral|coral\s+fim)\s*[\)\]]?\s*:?$');

String _marca(String linha) => linha
    .trim()
    .toLowerCase()
    .replaceAll(RegExp('[áàâã]'), 'a')
    .replaceAll(RegExp('[éê]'), 'e');

bool temCoralNaLetra(String texto) =>
    texto.split('\n').any((linha) => _inicio.hasMatch(_marca(linha)));

/// Separa a parte nos pedaços dentro e fora das marcas do coral; sem fim,
/// o coral vai até o fim da parte. As linhas de marca não ficam no texto.
List<PedacoDaLetra> pedacosDoCoral(String texto) {
  final pedacos = <PedacoDaLetra>[];
  var linhas = <String>[];
  var coral = false;
  void fechar() {
    while (linhas.isNotEmpty && linhas.first.trim().isEmpty) {
      linhas.removeAt(0);
    }
    while (linhas.isNotEmpty && linhas.last.trim().isEmpty) {
      linhas.removeLast();
    }
    if (linhas.isNotEmpty) {
      pedacos.add(PedacoDaLetra(linhas.join('\n'), coral: coral));
    }
    linhas = [];
  }

  for (final linha in texto.split('\n')) {
    final marca = _marca(linha);
    if (_inicio.hasMatch(marca)) {
      fechar();
      coral = true;
    } else if (_fim.hasMatch(marca)) {
      fechar();
      coral = false;
    } else {
      linhas.add(linha);
    }
  }
  fechar();
  return pedacos.isEmpty ? [PedacoDaLetra(texto, coral: false)] : pedacos;
}
