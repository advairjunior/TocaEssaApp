import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../tema/tema_toca_essa.dart';

/// Faixa discreta no topo quando o app mostra dados guardados no aparelho.
class AvisoSemInternet extends StatelessWidget {
  const AvisoSemInternet({super.key, required this.semInternetDesde});

  final ValueListenable<DateTime?> semInternetDesde;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<DateTime?>(
        valueListenable: semInternetDesde,
        builder: (context, salvoEm, _) {
          if (salvoEm == null) return const SizedBox.shrink();
          final hora = '${salvoEm.hour.toString().padLeft(2, '0')}:'
              '${salvoEm.minute.toString().padLeft(2, '0')}';
          return Material(
            color: CoresTocaEssa.superficieElevada,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: EspacoTocaEssa.base,
                  vertical: EspacoTocaEssa.mini,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.cloud_off_rounded,
                        size: 14, color: CoresTocaEssa.textoSecundario),
                    const SizedBox(width: EspacoTocaEssa.pequeno),
                    Flexible(
                      child: Text(
                        'Sem internet · dados salvos às $hora',
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: CoresTocaEssa.textoSecundario),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
}

/// Põe a faixa "Sem internet" acima do app. Com ela visível, as telas de
/// baixo não reservam de novo o espaço da barra de status.
class ComAvisoSemInternet extends StatelessWidget {
  const ComAvisoSemInternet({
    super.key,
    required this.semInternetDesde,
    required this.child,
  });

  final ValueListenable<DateTime?> semInternetDesde;
  final Widget child;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<DateTime?>(
        valueListenable: semInternetDesde,
        builder: (context, salvoEm, conteudo) => Column(
          children: [
            AvisoSemInternet(semInternetDesde: semInternetDesde),
            Expanded(
              child: salvoEm == null
                  ? conteudo!
                  : MediaQuery.removePadding(
                      context: context, removeTop: true, child: conteudo!),
            ),
          ],
        ),
        child: child,
      );
}
