part of 'cifra_do_palco.dart';

/// Desenho do acorde no violão, com as outras posições ao lado.
Future<void> mostrarDesenhoDoAcorde(BuildContext context, String acorde) =>
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => _DesenhoDoAcorde(acorde: acorde),
    );

class _DesenhoDoAcorde extends StatefulWidget {
  const _DesenhoDoAcorde({required this.acorde});

  final String acorde;

  @override
  State<_DesenhoDoAcorde> createState() => _DesenhoDoAcordeState();
}

class _DesenhoDoAcordeState extends State<_DesenhoDoAcorde> {
  late final _posicoes = posicoesDoAcorde(widget.acorde) ?? const [];
  var _atual = 0;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
            EspacoTocaEssa.base, 0, EspacoTocaEssa.base, EspacoTocaEssa.base),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.acorde, style: textos.headlineSmall),
            const SizedBox(height: EspacoTocaEssa.base),
            if (_posicoes.isEmpty)
              Text('Sem desenho para este acorde.',
                  style: textos.bodyMedium
                      ?.copyWith(color: CoresTocaEssa.textoSecundario))
            else ...[
              FlutterGuitarChord(
                chordName: widget.acorde,
                frets: _posicoes[_atual].frets,
                fingers: _posicoes[_atual].fingers,
                baseFret: _posicoes[_atual].baseFret,
                showLabel: false,
                width: 180,
                height: 200,
                stringColor: CoresTocaEssa.texto,
                barColor: CoresTocaEssa.textoSecundario,
                firstFrameColor: CoresTocaEssa.texto,
                tabBackgroundColor: CoresTocaEssa.roxoClaro,
                tabForegroundColor: Colors.white,
                labelColor: CoresTocaEssa.texto,
                mutedColor: CoresTocaEssa.textoSecundario,
              ),
              if (_posicoes.length > 1)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      tooltip: 'Posição anterior',
                      onPressed:
                          _atual == 0 ? null : () => setState(() => _atual--),
                      icon: const Icon(Icons.chevron_left_rounded),
                    ),
                    Text('${_atual + 1} de ${_posicoes.length}',
                        style: textos.bodyMedium),
                    IconButton(
                      tooltip: 'Próxima posição',
                      onPressed: _atual == _posicoes.length - 1
                          ? null
                          : () => setState(() => _atual++),
                      icon: const Icon(Icons.chevron_right_rounded),
                    ),
                  ],
                ),
            ],
          ],
        ),
      ),
    );
  }
}
