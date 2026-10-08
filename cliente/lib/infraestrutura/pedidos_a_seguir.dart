import 'package:shared_preferences/shared_preferences.dart';

/// Pedidos que o artista marcou para tocar a seguir, em ordem, por
/// apresentação. Ficam no aparelho: é uma escolha de palco, não muda nada
/// para o público.
abstract final class PedidosASeguir {
  static String _chave(String apresentacaoId) =>
      'pedidosASeguir:$apresentacaoId';

  static Future<List<String>> ler(String apresentacaoId) async {
    final preferencias = await SharedPreferences.getInstance();
    return preferencias.getStringList(_chave(apresentacaoId)) ?? [];
  }

  /// Marca o pedido no fim da sequência ou desmarca se já estava.
  static Future<List<String>> alternar(
      String apresentacaoId, String pedidoId) async {
    final atuais = await ler(apresentacaoId);
    final novos = atuais.contains(pedidoId)
        ? atuais.where((id) => id != pedidoId).toList()
        : [...atuais, pedidoId];
    await _gravar(apresentacaoId, novos);
    return novos;
  }

  static Future<void> adicionarNoInicio(
      String apresentacaoId, String pedidoId) async {
    final atuais = await ler(apresentacaoId);
    await _gravar(
        apresentacaoId, [pedidoId, ...atuais.where((id) => id != pedidoId)]);
  }

  static Future<void> remover(String apresentacaoId, String pedidoId) async {
    final atuais = await ler(apresentacaoId);
    await _gravar(
        apresentacaoId, atuais.where((id) => id != pedidoId).toList());
  }

  static Future<void> _gravar(String apresentacaoId, List<String> ids) async {
    final preferencias = await SharedPreferences.getInstance();
    await preferencias.setStringList(_chave(apresentacaoId), ids);
  }
}
