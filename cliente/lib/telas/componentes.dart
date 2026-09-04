import 'package:flutter/material.dart';

class ConteudoMobile extends StatelessWidget {
  const ConteudoMobile({super.key, required this.filho});
  final Widget filho;

  @override
  Widget build(BuildContext context) => SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: filho,
            ),
          ),
        ),
      );
}

class FotoPerfilArtistico extends StatelessWidget {
  const FotoPerfilArtistico({
    super.key,
    required this.enderecoFoto,
    this.tamanho = 84,
    this.iconeFallback = Icons.mic_rounded,
  });

  final String? enderecoFoto;
  final double tamanho;
  final IconData iconeFallback;

  @override
  Widget build(BuildContext context) {
    final fallback = ColoredBox(
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Center(
        child: Icon(iconeFallback, size: tamanho * 0.5),
      ),
    );
    return Align(
      alignment: Alignment.center,
      child: SizedBox.square(
        dimension: tamanho,
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: Theme.of(context).colorScheme.primary,
              width: 2,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(3),
            child: ClipOval(
              child: enderecoFoto == null
                  ? fallback
                  : Image.network(
                      enderecoFoto!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => fallback,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

String formatarData(DateTime data) =>
    '${data.day.toString().padLeft(2, '0')}/${data.month.toString().padLeft(2, '0')}/${data.year}';

void mostrarErro(BuildContext context, Object erro) {
  ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(erro.toString())));
}
