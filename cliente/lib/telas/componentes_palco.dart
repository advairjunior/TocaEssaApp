import 'package:flutter/material.dart';

import '../tema/tema_toca_essa.dart';

/// Barra fixa no rodapé: um toque abre a cifra da próxima música, para não
/// haver silêncio entre uma música e outra no palco. Depois do Tocar, mostra
/// em cima a música que começou, com Desfazer, sem cobrir a próxima.
class BarraProximaMusica extends StatelessWidget {
  const BarraProximaMusica({
    super.key,
    required this.titulo,
    required this.detalhe,
    required this.salvando,
    required this.tocar,
    this.comecou,
    this.desfazer,
  });

  /// Próxima música; nula quando não sobrou nada para tocar.
  final String? titulo;
  final String? detalhe;
  final bool salvando;
  final VoidCallback tocar;
  final String? comecou;
  final VoidCallback? desfazer;

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    return Material(
      color: CoresTocaEssa.superficie,
      child: SafeArea(
        top: false,
        child: Align(
          alignment: Alignment.topCenter,
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                20,
                EspacoTocaEssa.pequeno,
                20,
                EspacoTocaEssa.medio,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (comecou != null) _comecou(texto),
                  if (titulo != null) _proxima(texto),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _comecou(TextTheme texto) => Row(
        children: [
          const Icon(Icons.check_circle_rounded,
              size: 18, color: CoresTocaEssa.sucesso),
          const SizedBox(width: EspacoTocaEssa.pequeno),
          Expanded(
            child: Text(
              'Começou: $comecou',
              style: texto.bodyMedium
                  ?.copyWith(color: CoresTocaEssa.textoSecundario),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (desfazer != null)
            TextButton(
              onPressed: salvando ? null : desfazer,
              child: const Text('Desfazer'),
            ),
        ],
      );

  Widget _proxima(TextTheme texto) => Padding(
        padding: const EdgeInsets.only(top: EspacoTocaEssa.mini),
        child: Row(
          children: [
            const Icon(Icons.skip_next_rounded, color: CoresTocaEssa.roxoClaro),
            const SizedBox(width: EspacoTocaEssa.pequeno),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Próxima: $titulo',
                    style: texto.titleMedium,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (detalhe != null)
                    Text(
                      detalhe!,
                      style: texto.bodyMedium
                          ?.copyWith(color: CoresTocaEssa.textoSecundario),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            const SizedBox(width: EspacoTocaEssa.pequeno),
            FilledButton.icon(
              onPressed: salvando ? null : tocar,
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('Tocar'),
            ),
          ],
        ),
      );
}
