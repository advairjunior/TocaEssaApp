/// Leitura e troca de tom de cifras no formato do Cifra Club: acordes numa
/// linha, a letra na linha de baixo.
library;

final _acorde = RegExp(
    r'^[A-G][#b]?(m|maj7?|M7?|dim|aug|sus[24]?|add9|º|°|\+)?\d{0,2}'
    r'(\([^)]*\))?([#b]\d{1,2})*(/[A-G][#b]?)?$');
final _rotuloDaParte = RegExp(r'^\s*\[[^\]]*\]');
final _separador = RegExp(r'^[|\-/()]+$');

/// Linha só de acordes ("G   D/F#   Em"). Aceita o rótulo da parte no
/// começo ("[Intro] E9 C#m") e acordes entre parênteses ("( E C#m )").
bool linhaDeAcordes(String linha) {
  final partes = linha
      .replaceFirst(_rotuloDaParte, '')
      .replaceAll(RegExp(r'[()]'), ' ')
      .split(RegExp(r'\s+'))
      .where((parte) => parte.isNotEmpty && !_separador.hasMatch(parte))
      .toList();
  return partes.isNotEmpty && partes.every(_acorde.hasMatch);
}

const _notas = {
  'C': 0, 'B#': 0, 'C#': 1, 'Db': 1, 'D': 2, 'D#': 3, 'Eb': 3, 'E': 4, //
  'Fb': 4, 'F': 5, 'E#': 5, 'F#': 6, 'Gb': 6, 'G': 7, 'G#': 8, 'Ab': 8,
  'A': 9, 'A#': 10, 'Bb': 10, 'B': 11, 'Cb': 11,
};
// Sustenido por padrão, mas Bb no lugar de A#, como se escreve no Brasil.
const _comSustenido = [
  'C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'Bb', 'B', //
];
const _comBemol = [
  'C', 'Db', 'D', 'Eb', 'E', 'F', 'Gb', 'G', 'Ab', 'A', 'Bb', 'B', //
];
final _partesDoAcorde = RegExp(r'^([A-G][#b]?)(.*?)(?:/([A-G][#b]?))?$');
final _tomDoCabecalho = RegExp(r'^(\s*Tom:\s*)(\S+)(.*)$');

String _transporNota(String nota, int semitons) {
  final indice = (_notas[nota]! + semitons) % 12;
  return (nota.endsWith('b') ? _comBemol : _comSustenido)[indice];
}

String _transporAcorde(String acorde, int semitons) {
  final partes = _partesDoAcorde.firstMatch(acorde)!;
  final baixo = partes[3];
  return '${_transporNota(partes[1]!, semitons)}${partes[2]}'
      '${baixo == null ? '' : '/${_transporNota(baixo, semitons)}'}';
}

/// Nome de um tom ("G", "Bb", "Em") meio tom acima ou abaixo por [semitons].
String transporTom(String tom, int semitons) =>
    _acorde.hasMatch(tom) ? _transporAcorde(tom, semitons) : tom;

/// Troca o tom da cifra. Só as linhas de acordes e o "Tom:" mudam; quando
/// um acorde muda de tamanho, os espaços se ajustam para os acordes
/// seguintes continuarem em cima da mesma sílaba.
String transporCifra(String texto, int semitons) {
  if (semitons % 12 == 0) return texto;
  return texto.split('\n').map((linha) {
    final cabecalho = _tomDoCabecalho.firstMatch(linha);
    if (cabecalho != null) {
      return '${cabecalho[1]}${transporTom(cabecalho[2]!, semitons)}'
          '${cabecalho[3]}';
    }
    return linhaDeAcordes(linha) ? _transporLinha(linha, semitons) : linha;
  }).join('\n');
}

String _transporLinha(String linha, int semitons) {
  final rotulo = _rotuloDaParte.firstMatch(linha)?.group(0) ?? '';
  final resto = linha.substring(rotulo.length);
  final pedacos = RegExp(r'(\s*)(\S+)').allMatches(resto).toList();
  final saida = StringBuffer(rotulo);
  var ajuste = 0; // espaços a tirar (positivo) ou pôr (negativo) antes do próximo
  for (final (indice, pedaco) in pedacos.indexed) {
    var espacos = pedaco[1]!.length;
    final original = pedaco[2]!;
    final eAcorde = _acorde.hasMatch(original);
    if (eAcorde && indice > 0) {
      // Compensa o acorde anterior, deixando pelo menos um espaço.
      espacos = (espacos - ajuste).clamp(1, 1 << 20);
    }
    ajuste = 0;
    final novo = eAcorde ? _transporAcorde(original, semitons) : original;
    if (eAcorde) ajuste = novo.length - original.length;
    saida
      ..write(' ' * espacos)
      ..write(novo);
  }
  return saida.toString();
}
