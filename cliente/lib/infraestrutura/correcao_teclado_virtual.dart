/// Acesso mínimo à janela do navegador usado pela [CorrecaoTecladoVirtual].
abstract interface class JanelaDoNavegador {
  String? get conteudoViewport;
  set conteudoViewport(String? valor);

  /// Quanto a área visível foi empurrada para baixo da origem da página.
  double get deslocamentoVisivel;

  /// Zoom aplicado pelo usuário com gesto de pinça (1 = sem zoom).
  double get escalaVisivel;

  void rolarParaOTopo();
}

/// Evita que o navegador desloque a página quando o teclado virtual abre.
///
/// O Flutter Web já encolhe o layout e rola o campo focado para a área
/// visível. Se o navegador também empurra a página, os dois ajustes se somam:
/// o campo some por cima e barras e botões do rodapé sobem junto do teclado.
class CorrecaoTecladoVirtual {
  const CorrecaoTecladoVirtual(this._janela);

  final JanelaDoNavegador _janela;

  /// Chrome/Android: encolhe a página em vez de deslocá-la. O Flutter troca a
  /// tag viewport do index.html pela dele, por isso o ajuste é feito depois.
  void ajustarViewport() {
    final atual = _janela.conteudoViewport;
    if (atual == null || atual.contains('interactive-widget')) return;
    _janela.conteudoViewport = '$atual, interactive-widget=resizes-content';
  }

  /// Safari/iOS ignora a tag viewport e sempre desloca a página; aqui ela é
  /// devolvida ao topo, exceto quando o usuário deu zoom de propósito.
  void desfazerDeslocamento() {
    if (_janela.escalaVisivel > 1.01) return;
    if (_janela.deslocamentoVisivel <= 0) return;
    _janela.rolarParaOTopo();
  }
}
