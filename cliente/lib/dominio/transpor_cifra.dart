/// Leitura e troca de tom de cifras no formato do Cifra Club: acordes numa
/// linha, a letra na linha de baixo.
library;

// Nota, o resto do acorde ("7M(9)", "sus4", "m7(b5)") e o baixo ("/F#").
final _raizESufixo = RegExp(r'^[A-G][#b]?(\S*)$');
final _palavrasDoAcorde = RegExp(r'maj|min|dim|aug|sus|add|alt|omit|no|[ºøΔ∆]');
final _baixo = RegExp(r'/[A-G][#b]?');
// Depois de tirar as palavras e o baixo, letra que sobra só pode ser m, M
// (7M) ou b (bemol). Assim "Amor", "Deus" e "Bom" continuam sendo letra.
final _letraForaDoAcorde = RegExp(r'[^\P{L}mMb]', unicode: true);
final _rotuloDaParte = RegExp(r'^\s*\[[^\]]*\]');
final _separador = RegExp(r'^[|\-/()]+$');
final _repeticao = RegExp(r'^\(?(\d+x|x\d+)\)?$', caseSensitive: false);

/// Uma palavra de acorde, aceitando o que a cifra brasileira usa: "C7M",
/// "G7M(9)/B", "D7sus4", "C6/9", "A7+", "Bm7-5", "Bº". Símbolo estranho
/// no resto ("C7M*") não atrapalha: a nota da frente ainda muda de tom.
bool _ehAcorde(String palavra) {
  final achado = _raizESufixo.firstMatch(palavra);
  if (achado == null || palavra.length > 16) return false;
  final sufixo = achado[1]!;
  if (sufixo.contains('|') || sufixo.contains(':')) return false;
  return !_letraForaDoAcorde.hasMatch(
      sufixo.replaceAll(_baixo, '').replaceAll(_palavrasDoAcorde, ''));
}

/// Tira o parêntese que abre ou fecha a linha ("(E", "C#9)") e deixa o do
/// acorde ("G7(9)").
({String antes, String acorde, String depois}) _separarParenteses(
    String palavra) {
  var inicio = 0;
  var fim = palavra.length;
  int conta(String letra) =>
      palavra.substring(inicio, fim).split(letra).length - 1;
  while (inicio < fim && palavra[inicio] == '(' && conta('(') > conta(')')) {
    inicio++;
  }
  while (fim > inicio && palavra[fim - 1] == ')' && conta(')') > conta('(')) {
    fim--;
  }
  return (
    antes: palavra.substring(0, inicio),
    acorde: palavra.substring(inicio, fim),
    depois: palavra.substring(fim),
  );
}

/// O acorde de uma palavra da linha, sem os parênteses de fora, ou nulo.
String? acordeDaPalavra(String palavra) {
  final acorde = _separarParenteses(palavra).acorde;
  return _ehAcorde(acorde) ? acorde : null;
}

/// Palavras da linha que contam: sem o rótulo da parte, separadores como
/// "|" e "-" e marcas de repetição como "(2x)".
List<String> _palavrasDaLinha(String linha) => linha
    .replaceFirst(_rotuloDaParte, '')
    .split(RegExp(r'\s+'))
    .where((parte) =>
        parte.isNotEmpty &&
        !_separador.hasMatch(parte) &&
        !_repeticao.hasMatch(parte))
    .toList();

/// Linha só de acordes ("G   D/F#   Em"). Aceita o rótulo da parte no
/// começo ("[Intro] E9 C#m") e acordes entre parênteses ("( E C#m )").
bool linhaDeAcordes(String linha) {
  final partes = _palavrasDaLinha(linha);
  return partes.isNotEmpty &&
      partes.every((parte) => acordeDaPalavra(parte) != null);
}

/// Palavras que o app não entendeu numa linha que parece de acordes (dois
/// terços ou mais são acordes). Letra e linha já reconhecida dão vazio.
List<String> acordesNaoReconhecidos(String linha) {
  final partes = _palavrasDaLinha(linha);
  final estranhas =
      partes.where((parte) => acordeDaPalavra(parte) == null).toList();
  final acordes = partes.length - estranhas.length;
  if (estranhas.isEmpty || acordes < 2 || acordes * 3 < partes.length * 2) {
    return const [];
  }
  return estranhas;
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
    _ehAcorde(tom) ? _transporAcorde(tom, semitons) : tom;

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
    final partes = _separarParenteses(original);
    final eAcorde = _ehAcorde(partes.acorde);
    if (eAcorde && indice > 0) {
      // Compensa o acorde anterior, deixando pelo menos um espaço.
      espacos = (espacos - ajuste).clamp(1, 1 << 20);
    }
    ajuste = 0;
    final novo = eAcorde
        ? '${partes.antes}${_transporAcorde(partes.acorde, semitons)}'
            '${partes.depois}'
        : original;
    if (eAcorde) ajuste = novo.length - original.length;
    saida
      ..write(' ' * espacos)
      ..write(novo);
  }
  return saida.toString();
}
