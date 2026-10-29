import 'transpor_cifra.dart';

/// Linha de letra com o número dela na música: o celular manda o número e
/// a TV acende a mesma linha, com qualquer tamanho de tela.
class LinhaDaLetra {
  const LinhaDaLetra(this.numero, this.texto);

  final int numero;
  final String texto;
}

/// Pedaço da letra que a TV mostra de uma vez: estrofe, refrão, ponte.
class ParteDaLetra {
  const ParteDaLetra({required this.rotulo, required this.linhas});

  // Nome da marca na cifra ("Refrão"); sem marca, nulo.
  final String? rotulo;
  final List<LinhaDaLetra> linhas;
}

// "[Primeira Parte]": colchete é sempre marca, como no Cifra Club.
final _marcaEntreColchetes = RegExp(r'^\s*\[([^\]]+)\]\s*$');
// "(Estrofe 2)" e "Refrão:" só com o nome de uma parte, porque a letra
// também usa parênteses para o backing vocal.
final _marcaEntreParenteses = RegExp(r'^\s*\(([^)]+)\)\s*$');
final _marcaComDoisPontos = RegExp(r'^\s*([^:]{1,30}):\s*$');
final _nomeDeParte = RegExp(
    r'estrofe|refr[aã]o|coro|ponte|parte|intro|solo|final|verso|coral|interl[uú]dio',
    caseSensitive: false);
// "Tom: G", "Capotraste: 2ª casa" e "Afinação: ..." do topo da cifra.
final _informacao =
    RegExp(r'^\s*(tom|capo\w*|afina\w*)\s*:', caseSensitive: false);
final _tablatura = RegExp(r'^\s*[A-Ga-g]?\|.*[-|]');
final _repeticao =
    RegExp(r'^\s*\(?\s*(\d+x|x\d+)\s*\)?\s*$', caseSensitive: false);

/// A letra da cifra colada, separada em partes e com as linhas numeradas.
/// A mesma conta roda no celular de quem puxa e na TV.
class LetraDaTela {
  LetraDaTela._(this.partes, this._numeros);

  factory LetraDaTela.doTexto(String texto) {
    final montagem = _Montagem();
    for (final linha in texto.split('\n')) {
      montagem.ler(linha);
    }
    return LetraDaTela._(montagem.terminar(), montagem.numeros);
  }

  final List<ParteDaLetra> partes;
  // Número na letra de cada linha do texto; nulo se a linha não é letra.
  final List<int?> _numeros;

  int get total => partes.fold(0, (soma, parte) => soma + parte.linhas.length);

  int? numeroDaLinhaDoTexto(int indice) =>
      indice >= 0 && indice < _numeros.length ? _numeros[indice] : null;

  /// A parte da linha; depois do fim, a última.
  ParteDaLetra? parteDaLinha(int numero) {
    for (final parte in partes) {
      if (parte.linhas.last.numero >= numero) return parte;
    }
    return partes.isEmpty ? null : partes.last;
  }

  ParteDaLetra? parteDepois(ParteDaLetra parte) {
    final indice = partes.indexOf(parte);
    return indice >= 0 && indice + 1 < partes.length
        ? partes[indice + 1]
        : null;
  }
}

class _Montagem {
  final numeros = <int?>[];
  final _partes = <ParteDaLetra>[];
  String? _rotulo;
  var _linhas = <LinhaDaLetra>[];
  var _proximoNumero = 0;

  void ler(String linha) {
    final marca = _marca(linha);
    if (marca != null || linha.trim().isEmpty) {
      _fecharParte(proximoRotulo: marca);
    } else if (_ehLetra(linha)) {
      _linhas.add(LinhaDaLetra(_proximoNumero, linha.trim()));
      numeros.add(_proximoNumero++);
      return;
    }
    numeros.add(null);
  }

  List<ParteDaLetra> terminar() {
    _fecharParte(proximoRotulo: null);
    return _partes;
  }

  /// Linha em branco só fecha a parte que já tem letra: a marca logo acima
  /// continua valendo.
  void _fecharParte({required String? proximoRotulo}) {
    if (_linhas.isEmpty) {
      _rotulo = proximoRotulo ?? _rotulo;
      return;
    }
    _partes.add(ParteDaLetra(rotulo: _rotulo, linhas: _linhas));
    _linhas = [];
    _rotulo = proximoRotulo;
  }
}

String? _marca(String linha) {
  final colchetes = _marcaEntreColchetes.firstMatch(linha);
  if (colchetes != null) return colchetes.group(1)!.trim();
  final nome = (_marcaEntreParenteses.firstMatch(linha) ??
          _marcaComDoisPontos.firstMatch(linha))
      ?.group(1)
      ?.trim();
  return nome != null && _nomeDeParte.hasMatch(nome) ? nome : null;
}

bool _ehLetra(String linha) =>
    !linhaDeAcordes(linha) &&
    !_informacao.hasMatch(linha) &&
    !_tablatura.hasMatch(linha) &&
    !_repeticao.hasMatch(linha);
