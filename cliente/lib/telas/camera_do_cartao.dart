import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../infraestrutura/camera_do_app.dart';
import '../tema/tema_toca_essa.dart';

part 'camera_do_cartao_barras.dart';

/// O que a câmera devolve: a foto escolhida ou o pedido de usar a câmera do
/// sistema, quando a do app não abre (sem permissão ou sem suporte).
class RespostaDaCamera {
  const RespostaDaCamera.foto(Uint8List this.foto)
      : usarCameraDoSistema = false;
  const RespostaDaCamera.cameraDoSistema()
      : foto = null,
        usarCameraDoSistema = true;

  final Uint8List? foto;
  final bool usarCameraDoSistema;
}

/// Câmera dentro do app, no jeito do WhatsApp: enquadra direto no cartão,
/// vira entre selfie e traseira, tem flash e zoom na pinça. A selfie sai
/// como aparece na tela.
class CameraDoCartao extends StatefulWidget {
  const CameraDoCartao({
    super.key,
    required this.camera,
    required this.lenteInicial,
    required this.cartao,
  });

  final CameraDoApp camera;
  final LenteDaCamera lenteInicial;

  /// Monta o cartão com [fundo] no lugar da foto, para a prévia ser igual
  /// à imagem que vai ser salva.
  final Widget Function(BuildContext context, Widget fundo) cartao;

  @override
  State<CameraDoCartao> createState() => _CameraDoCartaoState();
}

/// Largura em que o cartão é montado dentro da câmera, a de um celular.
const _larguraDoCartao = 328.0;

class _CameraDoCartaoState extends State<CameraDoCartao>
    with TickerProviderStateMixin {
  late final AnimationController _brilho;
  late final AnimationController _espera;
  var _pronta = false;
  var _falhou = false;
  var _flashLigado = false;
  var _flashDeTela = false;
  var _capturando = false;
  var _zoom = 1.0;
  var _zoomInicial = 1.0;
  Uint8List? _foto;

  CameraDoApp get _camera => widget.camera;
  bool get _selfie => _camera.lenteAtual == LenteDaCamera.frontal;

  // Na selfie o flash é a própria tela acesa; na traseira, a lanterna.
  bool get _flashDisponivel => _selfie || _camera.lanternaDisponivel;

  @override
  void initState() {
    super.initState();
    _brilho = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 180));
    _espera = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 300));
    _abrir(widget.lenteInicial);
  }

  @override
  void dispose() {
    _brilho.dispose();
    _espera.dispose();
    _camera.encerrar();
    super.dispose();
  }

  Future<void> _abrir(LenteDaCamera lente) async {
    if (_pronta) setState(() => _pronta = false);
    try {
      await _camera.iniciar(lente);
      if (!mounted) return;
      setState(() {
        _pronta = true;
        _flashLigado = false;
        _zoom = _camera.zoomMinimo;
      });
    } catch (_) {
      if (mounted) setState(() => _falhou = true);
    }
  }

  // No navegador, o vídeo que saiu da tela enquanto a foto aparecia volta
  // parado (preto); reabrir a mesma lente traz a prévia de volta.
  void _tirarOutra() {
    setState(() => _foto = null);
    _abrir(_camera.lenteAtual ?? widget.lenteInicial);
  }

  void _virar() =>
      _abrir(_selfie ? LenteDaCamera.traseira : LenteDaCamera.frontal);

  Future<void> _tirarFoto() async {
    if (_capturando || !_pronta) return;
    setState(() => _capturando = true);
    final flashDeTela = _flashLigado && _selfie;
    final lanterna = _flashLigado && !_selfie;
    try {
      if (flashDeTela) {
        setState(() => _flashDeTela = true);
        await _brilho.forward(from: 0);
      }
      if (lanterna) {
        await _camera.definirLanterna(true);
        await _espera.forward(from: 0);
      }
      final foto = await _camera.capturar();
      if (lanterna) await _camera.definirLanterna(false);
      if (flashDeTela) await _brilho.reverse();
      if (mounted) setState(() => _foto = foto);
    } catch (erro) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível tirar a foto.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _capturando = false;
          _flashDeTela = false;
        });
      }
    }
  }

  void _aproximar(ScaleUpdateDetails detalhes) {
    final zoom = (_zoomInicial * detalhes.scale)
        .clamp(_camera.zoomMinimo, _camera.zoomMaximo)
        .toDouble();
    if (zoom == _zoom) return;
    _zoom = zoom;
    _camera.definirZoom(zoom);
  }

  Widget _previaRecortada() {
    final proporcao = _camera.proporcao;
    // Cobre o cartão como a foto final cobre: o enquadramento é o mesmo.
    return ClipRect(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: 1000 * proporcao,
          height: 1000,
          child: _camera.previa(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final foto = _foto;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          SafeArea(
            child: _falhou
                ? _SemCamera(
                    usarCameraDoSistema: () => Navigator.pop(
                        context, const RespostaDaCamera.cameraDoSistema()),
                  )
                : Column(
                    children: [
                      _BarraDeCima(
                        flashDisponivel:
                            foto == null && _pronta && _flashDisponivel,
                        flashLigado: _flashLigado,
                        alternarFlash: () =>
                            setState(() => _flashLigado = !_flashLigado),
                      ),
                      Expanded(
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: AspectRatio(
                              aspectRatio: 9 / 16,
                              child: GestureDetector(
                                onScaleStart: (_) => _zoomInicial = _zoom,
                                onScaleUpdate: foto == null ? _aproximar : null,
                                // Montado no tamanho de celular e escalado: a
                                // diagramação é a mesma do cartão salvo.
                                child: FittedBox(
                                  child: SizedBox(
                                    width: _larguraDoCartao,
                                    height: _larguraDoCartao * 16 / 9,
                                    child: widget.cartao(
                                      context,
                                      foto != null
                                          ? Image.memory(foto,
                                              fit: BoxFit.cover)
                                          : _pronta
                                              ? _previaRecortada()
                                              : const ColoredBox(
                                                  color: Colors.black,
                                                  child: Center(
                                                    child:
                                                        CircularProgressIndicator(),
                                                  ),
                                                ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (foto == null)
                        _BarraDoDisparo(
                          capturando: _capturando,
                          tirarFoto: _tirarFoto,
                          virar: _camera.lentesDisponiveis.length > 1
                              ? _virar
                              : null,
                        )
                      else
                        _BarraDaConfirmacao(
                          tirarOutra: _tirarOutra,
                          usar: () => Navigator.pop(
                              context, RespostaDaCamera.foto(foto)),
                        ),
                    ],
                  ),
          ),
          if (_flashDeTela)
            IgnorePointer(
              child: FadeTransition(
                key: const ValueKey('flash-de-tela'),
                opacity: _brilho,
                child: const ColoredBox(
                  color: Color(0xFFFFF8E7),
                  child: SizedBox.expand(),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
