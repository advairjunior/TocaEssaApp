import 'package:shared_preferences/shared_preferences.dart';

/// "Letra na TV" ligada neste aparelho: a seta aparece na cifra e a letra
/// vai para a TV. Fica no aparelho de quem puxa, como a velocidade da rolagem.
abstract final class PreferenciaDaLetraNaTv {
  static const chave = 'letra_na_tv';

  static Future<bool> ler() async {
    try {
      final preferencias = await SharedPreferences.getInstance();
      return preferencias.getBool(chave) ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> guardar(bool ligada) async {
    try {
      final preferencias = await SharedPreferences.getInstance();
      await preferencias.setBool(chave, ligada);
    } catch (_) {
      // Só não fica guardado para a próxima vez.
    }
  }
}
