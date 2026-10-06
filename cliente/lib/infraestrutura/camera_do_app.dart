import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/widgets.dart';

enum LenteDaCamera { frontal, traseira }

/// Câmera usada dentro do app para as fotos dos cartões. Isola o plugin
/// para que as telas possam ser testadas com uma câmera falsa.
abstract class CameraDoApp {
  /// Lentes encontradas; só é confiável depois de [iniciar].
  Set<LenteDaCamera> get lentesDisponiveis;
  LenteDaCamera? get lenteAtual;

  /// Lanterna da câmera traseira, quando o navegador permite controlá-la.
  bool get lanternaDisponivel;
  double get zoomMinimo;
  double get zoomMaximo;

  /// Largura sobre altura da imagem da câmera em pé.
  double get proporcao;

  /// Abre a [lente] pedida ou, sem ela, a que existir.
  Future<void> iniciar(LenteDaCamera lente);
  Widget previa();
  Future<void> definirLanterna(bool ligada);
  Future<void> definirZoom(double zoom);

  /// Foto do jeito que aparece na prévia: a selfie sai espelhada como no
  /// espelho, igual à câmera do WhatsApp.
  Future<Uint8List> capturar();
  Future<void> encerrar();
}

/// Câmera real, pelo plugin oficial. No navegador, o plugin já espelha a
/// câmera frontal tanto na prévia quanto na foto capturada.
class CameraDoPlugin implements CameraDoApp {
  List<CameraDescription>? _cameras;
  CameraController? _controle;
  var _lanterna = false;
  var _zoomMinimo = 1.0;
  var _zoomMaximo = 1.0;

  static LenteDaCamera? _lenteDe(CameraDescription camera) =>
      switch (camera.lensDirection) {
        CameraLensDirection.front => LenteDaCamera.frontal,
        CameraLensDirection.back => LenteDaCamera.traseira,
        CameraLensDirection.external => null,
      };

  @override
  Set<LenteDaCamera> get lentesDisponiveis =>
      {...?_cameras?.map(_lenteDe).whereType<LenteDaCamera>()};

  @override
  LenteDaCamera? get lenteAtual {
    final descricao = _controle?.description;
    return descricao == null ? null : _lenteDe(descricao);
  }

  @override
  bool get lanternaDisponivel =>
      _lanterna && lenteAtual == LenteDaCamera.traseira;

  @override
  double get zoomMinimo => _zoomMinimo;

  @override
  double get zoomMaximo => _zoomMaximo;

  @override
  double get proporcao {
    final controle = _controle;
    if (controle == null || !controle.value.isInitialized) return 9 / 16;
    // O plugin informa largura/altura deitada; em pé a proporção inverte.
    final proporcao = controle.value.aspectRatio;
    return proporcao > 1 ? 1 / proporcao : proporcao;
  }

  @override
  Future<void> iniciar(LenteDaCamera lente) async {
    final cameras = _cameras ??= await availableCameras();
    if (cameras.isEmpty) throw StateError('Nenhuma câmera encontrada.');
    final escolhida = cameras.firstWhere(
      (camera) => _lenteDe(camera) == lente,
      orElse: () => cameras.first,
    );
    await _controle?.dispose();
    final controle = CameraController(
      escolhida,
      ResolutionPreset.veryHigh,
      enableAudio: false,
    );
    _controle = controle;
    await controle.initialize();
    try {
      await controle.setFlashMode(FlashMode.off);
      _lanterna = true;
    } catch (_) {
      _lanterna = false;
    }
    try {
      _zoomMinimo = await controle.getMinZoomLevel();
      _zoomMaximo = await controle.getMaxZoomLevel();
    } catch (_) {
      _zoomMinimo = _zoomMaximo = 1;
    }
  }

  @override
  Widget previa() {
    final controle = _controle;
    if (controle == null || !controle.value.isInitialized) {
      return const SizedBox.shrink();
    }
    return CameraPreview(controle);
  }

  @override
  Future<void> definirLanterna(bool ligada) async =>
      _controle?.setFlashMode(ligada ? FlashMode.torch : FlashMode.off);

  @override
  Future<void> definirZoom(double zoom) async {
    if (_zoomMaximo <= _zoomMinimo) return;
    await _controle?.setZoomLevel(zoom.clamp(_zoomMinimo, _zoomMaximo));
  }

  @override
  Future<Uint8List> capturar() async {
    final controle = _controle;
    if (controle == null) throw StateError('Câmera fechada.');
    final arquivo = await controle.takePicture();
    return arquivo.readAsBytes();
  }

  @override
  Future<void> encerrar() async {
    await _controle?.dispose();
    _controle = null;
  }
}

/// Fábrica da câmera usada pelas telas; os testes trocam por uma falsa.
CameraDoApp Function() fabricaDeCamera = CameraDoPlugin.new;
