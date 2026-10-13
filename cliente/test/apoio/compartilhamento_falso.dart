import 'package:share_plus_platform_interface/share_plus_platform_interface.dart';

/// Janela de compartilhar do sistema falsa: guarda o que o app pediu para
/// compartilhar.
class CompartilhamentoFalso extends SharePlatform {
  final pedidos = <ShareParams>[];

  @override
  Future<ShareResult> share(ShareParams params) async {
    pedidos.add(params);
    return const ShareResult('', ShareResultStatus.success);
  }
}

/// Liga o compartilhamento falso até o fim do teste.
CompartilhamentoFalso usarCompartilhamentoFalso() {
  final falso = CompartilhamentoFalso();
  SharePlatform.instance = falso;
  return falso;
}
