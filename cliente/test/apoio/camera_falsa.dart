import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:toca_essa_app/infraestrutura/camera_do_app.dart';

/// PNG 1x1 transparente: a "foto" que a câmera falsa devolve.
final pngMinimo = Uint8List.fromList([
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, //
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
  0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
  0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

class CameraFalsa implements CameraDoApp {
  CameraFalsa({
    this.lentes = const {LenteDaCamera.frontal, LenteDaCamera.traseira},
    this.lanterna = false,
    this.zoomMaximo = 4,
    this.falharAoIniciar = false,
  });

  final Set<LenteDaCamera> lentes;
  final bool lanterna;
  final bool falharAoIniciar;
  @override
  final double zoomMaximo;
  @override
  double get zoomMinimo => 1;

  final iniciadas = <LenteDaCamera>[];
  final zooms = <double>[];
  final flashes = <bool>[];
  var capturas = 0;
  var encerrada = false;
  LenteDaCamera? _atual;

  @override
  Set<LenteDaCamera> get lentesDisponiveis => lentes;
  @override
  LenteDaCamera? get lenteAtual => _atual;
  @override
  bool get lanternaDisponivel => lanterna && _atual == LenteDaCamera.traseira;
  @override
  double get proporcao => 9 / 16;

  @override
  Future<void> iniciar(LenteDaCamera lente) async {
    if (falharAoIniciar) throw Exception('sem permissão');
    iniciadas.add(lente);
    _atual = lente;
  }

  @override
  Widget previa() =>
      const ColoredBox(key: ValueKey('previa-falsa'), color: Color(0xFF123456));

  @override
  Future<void> definirLanterna(bool ligada) async => flashes.add(ligada);

  @override
  Future<void> definirZoom(double zoom) async => zooms.add(zoom);

  @override
  Future<Uint8List> capturar() async {
    capturas++;
    return pngMinimo;
  }

  @override
  Future<void> encerrar() async => encerrada = true;
}
