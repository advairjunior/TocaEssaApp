import 'package:flutter/material.dart';

import '../dominio/modelos.dart';
import '../tema/tema_toca_essa.dart';
import 'componentes_lista.dart';

/// Quem cantou, da maior média para a menor. Durante a noite, o primeiro
/// está "Liderando"; encerrada, é a "Voz da noite" (com votos suficientes).
class PlacarDaNoite extends StatelessWidget {
  const PlacarDaNoite(
      {super.key, required this.noite, required this.encerrada});

  final NoiteDeKaraoke noite;
  final bool encerrada;

  @override
  Widget build(BuildContext context) {
    if (noite.placar.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: EspacoTocaEssa.grande),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const TituloGrupo('Placar da noite'),
          GrupoDeLinhas(linhas: [
            for (final (indice, linha) in noite.placar.indexed)
              ListTile(
                key: ValueKey(linha.publicoId),
                leading: SizedBox(
                  width: 28,
                  child: Center(
                    child: Text('${indice + 1}º',
                        style: const TextStyle(color: CoresTocaEssa.roxoClaro)),
                  ),
                ),
                title: Text(linha.nome),
                subtitle: Text(linha.resumo),
                trailing: linha.publicoId == noite.vozDaNoite
                    ? _Selo(encerrada ? 'Voz da noite' : 'Liderando')
                    : null,
              ),
          ]),
        ],
      ),
    );
  }
}

class _Selo extends StatelessWidget {
  const _Selo(this.texto);
  final String texto;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.emoji_events_rounded,
              size: 18, color: CoresTocaEssa.ouro),
          const SizedBox(width: EspacoTocaEssa.mini),
          Text(texto,
              style: Theme.of(context)
                  .textTheme
                  .labelLarge
                  ?.copyWith(color: CoresTocaEssa.ouro)),
        ],
      );
}
