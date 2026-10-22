import 'dart:math' as math;

import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart' hide ShimmerEffect;
import 'package:skeletonizer/skeletonizer.dart';

import '../tema/tema_toca_essa.dart';
import 'componentes.dart';
import 'componentes_lista.dart';

const _duracaoDaTroca = Duration(milliseconds: 300);

// Quem pediu menos movimento nas configurações do aparelho vê tudo parado.
bool _semMovimento(BuildContext context) =>
    MediaQuery.maybeDisableAnimationsOf(context) ?? false;

/// Enquanto a lista carrega: linhas de mentira no formato da lista, com um
/// brilho passando, no lugar da rodinha girando.
class EsqueletoDeLista extends StatelessWidget {
  const EsqueletoDeLista({
    super.key,
    this.linhas = 5,
    this.telaInteira = true,
  });

  final int linhas;

  /// Ocupa o lugar do conteúdo da tela, com as mesmas margens; fora disso,
  /// fica no meio de outra lista, sem margem própria.
  final bool telaInteira;

  @override
  Widget build(BuildContext context) {
    final esqueleto = Skeletonizer(
      effect: const ShimmerEffect(
        baseColor: CoresTocaEssa.superficieElevada,
        highlightColor: CoresTocaEssa.borda,
      ),
      child: GrupoDeLinhas(
        linhas: [
          for (var i = 0; i < linhas; i++)
            const ListTile(
              leading: Bone.circle(size: 36),
              title: Text('Nome da música aqui'),
              subtitle: Text('Artista da música'),
            ),
        ],
      ),
    );
    return telaInteira ? ConteudoMobile(filho: esqueleto) : esqueleto;
  }
}

/// Aparece subindo de leve; com [ordem], entra depois dos anteriores.
class EntradaSuave extends StatelessWidget {
  const EntradaSuave({super.key, this.ordem = 0, required this.child});

  final int ordem;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (_semMovimento(context)) return child;
    // A espera fica no próprio efeito: na lista comprida, só as primeiras
    // linhas esperam a vez.
    final espera = Duration(milliseconds: 45 * math.min(ordem, 8));
    const duracao = Duration(milliseconds: 260);
    return child
        .animate()
        .fadeIn(delay: espera, duration: duracao, curve: Curves.easeOut)
        .slideY(
            delay: espera,
            duration: duracao,
            begin: .12,
            end: 0,
            curve: Curves.easeOutCubic);
  }
}

// Mantém o tamanho que a tela dá às abas, sem centralizar o conteúdo.
Widget _empilhar(List<Widget> filhos) => Stack(
      alignment: Alignment.topCenter,
      fit: StackFit.passthrough,
      children: filhos,
    );

/// Troca de aba: a antiga esmaece e a nova surge no lugar.
class TrocaDeAba extends StatelessWidget {
  const TrocaDeAba({super.key, required this.chave, required this.child});

  final Object chave;
  final Widget child;

  @override
  Widget build(BuildContext context) => PageTransitionSwitcher(
        duration: _semMovimento(context) ? Duration.zero : _duracaoDaTroca,
        layoutBuilder: _empilhar,
        transitionBuilder: (filho, entrada, saida) => FadeThroughTransition(
          animation: entrada,
          secondaryAnimation: saida,
          fillColor: Colors.transparent,
          child: filho,
        ),
        child: KeyedSubtree(key: ValueKey(chave), child: child),
      );
}

/// Troca de tela no mesmo lugar: a nova chega pela direita, ou pela esquerda
/// quando [voltando].
class TrocaDeTela extends StatelessWidget {
  const TrocaDeTela({
    super.key,
    required this.chave,
    required this.child,
    this.voltando = false,
  });

  final Object chave;
  final Widget child;
  final bool voltando;

  @override
  Widget build(BuildContext context) => PageTransitionSwitcher(
        duration: _semMovimento(context) ? Duration.zero : _duracaoDaTroca,
        reverse: voltando,
        layoutBuilder: _empilhar,
        transitionBuilder: (filho, entrada, saida) => SharedAxisTransition(
          animation: entrada,
          secondaryAnimation: saida,
          transitionType: SharedAxisTransitionType.horizontal,
          fillColor: Colors.transparent,
          child: filho,
        ),
        child: KeyedSubtree(key: ValueKey(chave), child: child),
      );
}
