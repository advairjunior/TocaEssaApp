part of 'camera_do_cartao.dart';

class _BarraDeCima extends StatelessWidget {
  const _BarraDeCima({
    required this.flashDisponivel,
    required this.flashLigado,
    required this.alternarFlash,
  });

  final bool flashDisponivel;
  final bool flashLigado;
  final VoidCallback alternarFlash;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
        child: Row(
          children: [
            IconButton(
              tooltip: 'Fechar câmera',
              color: Colors.white,
              icon: const Icon(Icons.close_rounded),
              onPressed: () => Navigator.pop(context),
            ),
            const Spacer(),
            if (flashDisponivel)
              IconButton(
                tooltip: flashLigado ? 'Flash ligado' : 'Flash desligado',
                color: flashLigado ? CoresTocaEssa.ouro : Colors.white,
                icon: Icon(flashLigado
                    ? Icons.flash_on_rounded
                    : Icons.flash_off_rounded),
                onPressed: alternarFlash,
              ),
          ],
        ),
      );
}

class _BarraDoDisparo extends StatelessWidget {
  const _BarraDoDisparo({
    required this.capturando,
    required this.tirarFoto,
    required this.virar,
  });

  final bool capturando;
  final VoidCallback tirarFoto;
  final VoidCallback? virar;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const SizedBox.square(dimension: 48),
            Tooltip(
              message: 'Tirar foto',
              child: Semantics(
                button: true,
                child: GestureDetector(
                  onTap: capturando ? null : tirarFoto,
                  child: Container(
                    width: 74,
                    height: 74,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 4),
                    ),
                    padding: const EdgeInsets.all(5),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: capturando ? Colors.white54 : Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (virar != null)
              IconButton(
                tooltip: 'Virar câmera',
                iconSize: 30,
                color: Colors.white,
                icon: const Icon(Icons.flip_camera_android_rounded),
                onPressed: capturando ? null : virar,
              )
            else
              const SizedBox.square(dimension: 48),
          ],
        ),
      );
}

class _BarraDaConfirmacao extends StatelessWidget {
  const _BarraDaConfirmacao({required this.tirarOutra, required this.usar});
  final VoidCallback tirarOutra;
  final VoidCallback usar;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: tirarOutra,
                icon: const Icon(Icons.replay_rounded),
                label: const Text('Tirar outra'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                onPressed: usar,
                icon: const Icon(Icons.check_rounded),
                label: const Text('Usar foto'),
              ),
            ),
          ],
        ),
      );
}

class _SemCamera extends StatelessWidget {
  const _SemCamera({required this.usarCameraDoSistema});
  final VoidCallback usarCameraDoSistema;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.no_photography_outlined,
                  color: Colors.white70, size: 48),
              const SizedBox(height: 16),
              const Text(
                'Não foi possível abrir a câmera.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              const Text(
                'Confira se o navegador tem permissão para usar a câmera.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: usarCameraDoSistema,
                icon: const Icon(Icons.photo_camera_outlined),
                label: const Text('Usar a câmera do celular'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Fechar'),
              ),
            ],
          ),
        ),
      );
}
