import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Tamanho da letra na TV, mudado pelas setas do controle e guardado na
/// própria TV: a distância do sofá muda de casa para casa.
class TamanhoDaLetraNaTv extends ValueNotifier<double> {
  TamanhoDaLetraNaTv() : super(1);

  static const _chave = 'tv_escala';
  static const _passo = .1;
  static const _menor = .6;
  static const _maior = 1.6;

  Future<void> ler() async {
    try {
      final preferencias = await SharedPreferences.getInstance();
      value = (preferencias.getDouble(_chave) ?? 1).clamp(_menor, _maior);
    } catch (_) {
      // Sem o guardado, a letra fica no tamanho normal.
    }
  }

  void aumentar() => _mudar(_passo);

  void diminuir() => _mudar(-_passo);

  /// "Letra 90%", para o aviso que aparece ao mudar.
  String get rotulo => 'Letra ${(value * 100).round()}%';

  Future<void> _mudar(double passo) async {
    // Arredonda para não acumular 0,30000000000000004.
    value = ((value + passo) * 10).round() / 10;
    value = value.clamp(_menor, _maior);
    try {
      final preferencias = await SharedPreferences.getInstance();
      await preferencias.setDouble(_chave, value);
    } catch (_) {
      // Só não fica guardado para a próxima vez.
    }
  }
}
