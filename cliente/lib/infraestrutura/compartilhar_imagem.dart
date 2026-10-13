import 'dart:typed_data';

import 'package:share_plus/share_plus.dart';

/// Abre a janela de compartilhar do sistema com a imagem (WhatsApp,
/// Instagram, salvar nas fotos). Onde o navegador não tem essa janela, como
/// no computador, o arquivo é baixado.
Future<void> compartilharImagem(Uint8List bytes, String nome) =>
    SharePlus.instance.share(ShareParams(
      files: [XFile.fromData(bytes, mimeType: 'image/png', name: nome)],
      fileNameOverrides: [nome],
    ));
