import 'dart:async';

import 'package:flutter/material.dart';

import '../tema/tema_toca_essa.dart';

class EtiquetaDetalhePedido extends StatelessWidget {
  const EtiquetaDetalhePedido({
    super.key,
    required this.icone,
    required this.texto,
    this.destaque = false,
  });

  final IconData icone;
  final String texto;
  final bool destaque;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: destaque
              ? CoresTocaEssa.roxo.withValues(alpha: .2)
              : CoresTocaEssa.superficie,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: CoresTocaEssa.borda),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icone, size: 16, color: CoresTocaEssa.roxoClaro),
            const SizedBox(width: 6),
            Text(texto, style: const TextStyle(fontSize: 12)),
          ],
        ),
      );
}

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

/// Esconde [child] enquanto o teclado virtual estiver aberto, para que barras
/// e botões fixos no rodapé não subam junto com o teclado e cubram os campos.
class OcultoComTecladoAberto extends StatefulWidget {
  const OcultoComTecladoAberto({super.key, required this.child});
  final Widget child;

  @override
  State<OcultoComTecladoAberto> createState() => _OcultoComTecladoAbertoState();
}

// Lê os recuos direto da View: o Scaffold zera viewInsets no MediaQuery do body.
class _OcultoComTecladoAbertoState extends State<OcultoComTecladoAberto>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeMetrics() => setState(() {});

  @override
  Widget build(BuildContext context) => View.of(context).viewInsets.bottom > 0
      ? const SizedBox.shrink()
      : widget.child;
}

/// Rola o campo focado até a área visível depois que o teclado termina de abrir.
///
/// O Flutter só rola o campo no primeiro quadro após o teclado aparecer; em
/// janelas e folhas que encolhem com animação, o cálculo usa o tamanho antigo
/// e o campo termina escondido atrás do teclado ou dos botões.
class ManterCampoFocadoVisivel extends StatefulWidget {
  const ManterCampoFocadoVisivel({super.key, required this.child});
  final Widget child;

  static const espera = Duration(milliseconds: 300);

  @override
  State<ManterCampoFocadoVisivel> createState() =>
      _ManterCampoFocadoVisivelState();
}

class _ManterCampoFocadoVisivelState extends State<ManterCampoFocadoVisivel>
    with WidgetsBindingObserver {
  Timer? _espera;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    _espera?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    _espera?.cancel();
    _espera = Timer(ManterCampoFocadoVisivel.espera, _mostrarCampoFocado);
  }

  void _mostrarCampoFocado() {
    if (!mounted || View.of(context).viewInsets.bottom <= 0) return;
    final campo = FocusManager.instance.primaryFocus?.context;
    if (campo == null ||
        campo.findAncestorWidgetOfExactType<EditableText>() == null) {
      return;
    }
    final caixa = campo.findRenderObject();
    if (caixa is! RenderBox || !caixa.attached) return;
    caixa.showOnScreen(
      rect: (Offset.zero & caixa.size).inflate(20),
      duration: const Duration(milliseconds: 150),
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
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
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: enderecoFoto == null || enderecoFoto!.isEmpty
              ? null
              : () => Navigator.of(context).push<void>(MaterialPageRoute(
                    builder: (_) =>
                        _FotoPerfilAmpliada(endereco: enderecoFoto!),
                    fullscreenDialog: true,
                  )),
          child: Tooltip(
            message: enderecoFoto == null ? '' : 'Ver foto de perfil',
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
        ),
      ),
    );
  }
}

class _FotoPerfilAmpliada extends StatelessWidget {
  const _FotoPerfilAmpliada({required this.endereco});
  final String endereco;

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          title: const Text('Foto de perfil'),
          leading: IconButton(
            tooltip: 'Fechar foto',
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: SafeArea(
          child: SizedBox.expand(
            child: InteractiveViewer(
              minScale: 1,
              maxScale: 5,
              child: Center(
                child: Image.network(
                  endereco,
                  fit: BoxFit.contain,
                  semanticLabel: 'Foto de perfil ampliada',
                  loadingBuilder: (_, imagem, progresso) => progresso == null
                      ? imagem
                      : const Center(child: CircularProgressIndicator()),
                  errorBuilder: (_, __, ___) => const Center(
                    child: Text('Não foi possível carregar a foto.',
                        style: TextStyle(color: Colors.white)),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
}

String formatarData(DateTime data) =>
    '${data.day.toString().padLeft(2, '0')}/${data.month.toString().padLeft(2, '0')}/${data.year}';

void mostrarErro(BuildContext context, Object erro) {
  ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(erro.toString())));
}
