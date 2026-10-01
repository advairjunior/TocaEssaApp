import 'dart:js_interop';
import 'dart:math';

import 'package:web/web.dart';

import 'correcao_teclado_virtual.dart';

void instalarCorrecaoTecladoVirtual() {
  final correcao = CorrecaoTecladoVirtual(_JanelaWeb());
  correcao.ajustarViewport();

  final aoMudar = ((Event _) => correcao.desfazerDeslocamento()).toJS;
  window.visualViewport?.addEventListener('resize', aoMudar);
  window.visualViewport?.addEventListener('scroll', aoMudar);
  window.addEventListener('scroll', aoMudar);
}

class _JanelaWeb implements JanelaDoNavegador {
  HTMLMetaElement? get _meta =>
      document.querySelector('meta[name="viewport"]') as HTMLMetaElement?;

  @override
  String? get conteudoViewport => _meta?.content;

  @override
  set conteudoViewport(String? valor) {
    if (valor != null) _meta?.content = valor;
  }

  @override
  double get deslocamentoVisivel =>
      max(window.scrollY, window.visualViewport?.offsetTop ?? 0);

  @override
  double get escalaVisivel => window.visualViewport?.scale ?? 1;

  @override
  void rolarParaOTopo() => window.scrollTo(0.toJS, 0);
}
