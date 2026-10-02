import 'package:shared_preferences/shared_preferences.dart';

/// Remove do aparelho o nome, os pedidos e o identificador de avaliação
/// deixados por quem o usou antes, para que uma conta nunca herde o
/// histórico de outra pessoa ao entrar ou sair.
Future<void> limparRastrosLocaisDoPublico(
    SharedPreferences preferencias) async {
  for (final chave in preferencias.getKeys().toList()) {
    if (chave == 'nome_do_publico' ||
        chave == 'identificador_avaliador' ||
        chave.startsWith('pedidos_publico_')) {
      await preferencias.remove(chave);
    }
  }
}
