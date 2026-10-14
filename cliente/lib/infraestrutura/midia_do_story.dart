import 'package:image_picker/image_picker.dart';

import '../dominio/stories.dart';
import 'midia_do_story_stub.dart'
    if (dart.library.js_interop) 'midia_do_story_web.dart' as plataforma;

export 'package:image_picker/image_picker.dart' show XFile;

/// Vídeo ou foto escolhido no aparelho para virar story.
class MidiaEscolhida {
  const MidiaEscolhida({
    required this.arquivo,
    required this.tipoDeConteudo,
    required this.tamanho,
    this.duracao,
  });

  final XFile arquivo;
  final String tipoDeConteudo;
  final int tamanho;

  /// Só de vídeo, quando o navegador consegue ler.
  final Duration? duracao;

  TipoDeStory get tipo =>
      tipoDeConteudo.startsWith('video/') ? TipoDeStory.video : TipoDeStory.foto;
}

/// Câmera e galeria do aparelho. Isolado para as telas serem testadas com
/// um seletor falso.
abstract interface class SeletorDeMidia {
  Future<MidiaEscolhida?> gravarVideo();
  Future<MidiaEscolhida?> tirarFoto();
  Future<MidiaEscolhida?> escolherDaGaleria();
}

/// Manda o arquivo direto para a URL assinada, contando o progresso.
abstract interface class EnviadorDeArquivo {
  Future<void> enviar(Uri url, Map<String, String> cabecalhos, XFile arquivo,
      void Function(double fracao) progresso);
}

class SeletorDoAparelho implements SeletorDeMidia {
  final _seletor = ImagePicker();

  @override
  Future<MidiaEscolhida?> gravarVideo() async => _descrever(await _seletor
      .pickVideo(
          source: ImageSource.camera,
          maxDuration: const Duration(seconds: 60)));

  @override
  Future<MidiaEscolhida?> tirarFoto() async =>
      _descrever(await _seletor.pickImage(source: ImageSource.camera));

  @override
  Future<MidiaEscolhida?> escolherDaGaleria() async =>
      _descrever(await _seletor.pickMedia());

  static Future<MidiaEscolhida?> _descrever(XFile? arquivo) async {
    if (arquivo == null) return null;
    final tipo = arquivo.mimeType ?? _tipoPeloNome(arquivo.name);
    return MidiaEscolhida(
      arquivo: arquivo,
      tipoDeConteudo: tipo,
      tamanho: await arquivo.length(),
      duracao: tipo.startsWith('video/')
          ? await plataforma.duracaoDoVideo(arquivo)
          : null,
    );
  }

  static String _tipoPeloNome(String nome) =>
      switch (nome.split('.').last.toLowerCase()) {
        'mp4' => 'video/mp4',
        'mov' => 'video/quicktime',
        'png' => 'image/png',
        'heic' => 'image/heic',
        'jpg' || 'jpeg' => 'image/jpeg',
        _ => 'application/octet-stream',
      };
}

class EnviadorDoAparelho implements EnviadorDeArquivo {
  @override
  Future<void> enviar(Uri url, Map<String, String> cabecalhos, XFile arquivo,
          void Function(double fracao) progresso) =>
      plataforma.enviarArquivo(url, cabecalhos, arquivo, progresso);
}
