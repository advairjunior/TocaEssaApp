import 'transpor_cifra.dart';

/// Quebra as linhas da cifra que passam de [colunas] letras, para a pinça
/// aumentar a cifra sem esconder o fim das linhas. A linha de acordes e a
/// letra logo abaixo quebram no mesmo ponto, e cada acorde continua em cima
/// da mesma sílaba.
List<String> quebrarCifra(String texto, int colunas) =>
    [for (final pedaco in quebrarCifraComOrigem(texto, colunas)) pedaco.texto];

/// O mesmo que [quebrarCifra], com a linha do texto de onde cada pedaço
/// veio: a seta da Letra na TV acha o número da linha de letra por ela.
List<({String texto, int origem})> quebrarCifraComOrigem(
    String texto, int colunas) {
  final linhas = texto.split('\n');
  if (colunas <= 0) {
    return [
      for (var i = 0; i < linhas.length; i++) (texto: linhas[i], origem: i)
    ];
  }
  final saida = <({String texto, int origem})>[];
  for (var i = 0; i < linhas.length; i++) {
    final linha = linhas[i];
    final proxima = i + 1 < linhas.length ? linhas[i + 1] : null;
    if (linhaDeAcordes(linha) &&
        proxima != null &&
        proxima.trim().isNotEmpty &&
        !linhaDeAcordes(proxima)) {
      final origemDosAcordes = i++;
      saida.addAll(_quebrarPar(linha, proxima, colunas).map((pedaco) => (
            texto: pedaco,
            origem: linhaDeAcordes(pedaco) ? origemDosAcordes : i,
          )));
    } else {
      saida.addAll(_quebrarSozinha(linha, colunas)
          .map((pedaco) => (texto: pedaco, origem: i)));
    }
  }
  return saida;
}

/// Letra ou acordes sem par: quebra no último espaço que cabe.
List<String> _quebrarSozinha(String linha, int colunas) {
  final saida = <String>[];
  var resto = linha;
  while (resto.length > colunas) {
    final espaco = resto.lastIndexOf(' ', colunas);
    final corte = espaco > 0 ? espaco : colunas;
    saida.add(resto.substring(0, corte).trimRight());
    resto = resto.substring(corte).trimLeft();
  }
  saida.add(resto);
  return saida;
}

List<String> _quebrarPar(String acordes, String letra, int colunas) {
  final saida = <String>[];
  var cima = acordes;
  var baixo = letra;
  while (cima.length > colunas || baixo.length > colunas) {
    var corte = baixo.length > colunas ? baixo.lastIndexOf(' ', colunas) : -1;
    if (corte <= 0) corte = colunas;
    // Não corta um acorde ao meio: o acorde inteiro desce.
    while (corte > 0 &&
        corte < cima.length &&
        cima[corte] != ' ' &&
        cima[corte - 1] != ' ') {
      corte--;
    }
    if (corte == 0) corte = colunas;
    final acordesDaLinha = _ate(cima, corte).trimRight();
    if (acordesDaLinha.isNotEmpty) saida.add(acordesDaLinha);
    final letraDaLinha = _ate(baixo, corte).trimRight();
    if (letraDaLinha.isNotEmpty) saida.add(letraDaLinha);
    cima = _desde(cima, corte);
    baixo = _desde(baixo, corte);
    // Espaços no começo da continuação saem das duas linhas juntos, para o
    // acorde seguir alinhado; espaço com acorde em cima fica.
    var inicio = 0;
    while (inicio < baixo.length &&
        baixo[inicio] == ' ' &&
        (inicio >= cima.length || cima[inicio] == ' ')) {
      inicio++;
    }
    cima = _desde(cima, inicio);
    baixo = _desde(baixo, inicio);
  }
  final acordesDaLinha = cima.trimRight();
  if (acordesDaLinha.isNotEmpty) saida.add(acordesDaLinha);
  if (baixo.isNotEmpty) saida.add(baixo);
  return saida;
}

String _ate(String texto, int coluna) =>
    texto.length <= coluna ? texto : texto.substring(0, coluna);

String _desde(String texto, int coluna) =>
    texto.length <= coluna ? '' : texto.substring(coluna);
