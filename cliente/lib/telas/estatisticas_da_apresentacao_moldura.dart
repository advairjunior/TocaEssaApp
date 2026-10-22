part of 'estatisticas_da_apresentacao.dart';

/// Lembrete no lugar da foto: o melhor cartão é a selfie com a galera.
class _ConviteDaSelfie extends StatelessWidget {
  const _ConviteDaSelfie({required this.enviando, required this.tirarSelfie});

  final bool enviando;
  final VoidCallback tirarSelfie;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        child: GestureDetector(
          onTap: enviando ? null : tirarSelfie,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 32),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            decoration: BoxDecoration(
              color: const Color(0x8C000000),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white24),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                enviando
                    ? const SizedBox.square(
                        dimension: 30,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.photo_camera_front_outlined,
                        color: Colors.white, size: 32),
                const SizedBox(height: 10),
                const Text(
                  'Tire uma selfie com o seu público',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Toque para abrir a câmera',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      );
}

/// Cartão 9:16: a foto ocupa tudo, com a marca no topo e os números embaixo
/// sobre um escurecido suave.
class _MolduraDoCartao extends StatelessWidget {
  const _MolduraDoCartao({
    super.key,
    required this.enderecoFoto,
    required this.child,
    this.fundo,
  });

  final String? enderecoFoto;
  final Widget child;

  /// Substitui a foto, como a prévia da câmera do app.
  final Widget? fundo;

  @override
  Widget build(BuildContext context) => AspectRatio(
        aspectRatio: 9 / 16,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: ColoredBox(
            color: const Color(0xFF111111),
            child: Stack(
              fit: StackFit.expand,
              children: [
                fundo ?? CapaDaNoite(endereco: enderecoFoto),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0x66000000),
                        Color(0x00000000),
                        Color(0x00000000),
                        Color(0xD9000000),
                        Color(0xF2000000),
                      ],
                      stops: [0, .14, .42, .72, 1],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: Image.asset(
                              'assets/marca/toca_essa_icone.png',
                              width: 22,
                              height: 22,
                              errorBuilder: (_, __, ___) =>
                                  const SizedBox.square(dimension: 22),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'TocaEssa',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      DefaultTextStyle.merge(
                        style: const TextStyle(color: Colors.white),
                        child: child,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}

/// Número do cartão no jeito do Strava: rótulo pequeno em cima, valor grande.
class _NumeroDoCartao extends StatelessWidget {
  const _NumeroDoCartao(this.destaque);
  final DestaqueDaRetrospectiva destaque;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              destaque.rotulo,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white70, fontSize: 11),
            ),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                destaque.valor,
                maxLines: 1,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  height: 1.15,
                ),
              ),
            ),
          ],
        ),
      );
}

class _NumerosDoCartao extends StatelessWidget {
  const _NumerosDoCartao(this.numeros);
  final List<DestaqueDaRetrospectiva> numeros;

  @override
  // Alinhados por baixo: os valores ficam na mesma linha mesmo quando um
  // rótulo quebra em duas.
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [for (final numero in numeros) _NumeroDoCartao(numero)],
      );
}

/// Linha discreta acima do nome: "Retrospectiva do show".
class _RotuloDoCartao extends StatelessWidget {
  const _RotuloDoCartao(this.texto);
  final String texto;

  @override
  Widget build(BuildContext context) => Text(
        texto,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: Colors.white70, fontSize: 12),
      );
}
