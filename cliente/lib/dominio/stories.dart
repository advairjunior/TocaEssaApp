/// Stories do show: vídeos e fotos que o público manda durante a
/// apresentação. Todos do show veem por 24 h depois do fim; o artista
/// guarda por 7 dias.
enum TipoDeStory {
  video('Video'),
  foto('Foto');

  const TipoDeStory(this.valorApi);
  final String valorApi;

  static TipoDeStory daApi(String valor) =>
      values.firstWhere((tipo) => tipo.valorApi == valor);
}

/// Envio aberto no servidor: o arquivo vai direto para [urlDeEnvio] com os
/// [cabecalhos] pedidos.
class EnvioAberto {
  const EnvioAberto({
    required this.id,
    required this.urlDeEnvio,
    required this.cabecalhos,
  });

  final String id;
  final Uri urlDeEnvio;
  final Map<String, String> cabecalhos;
}

class StoryDoShow {
  const StoryDoShow({
    required this.id,
    required this.tipo,
    required this.nome,
    required this.criadoEm,
    required this.tipoDeConteudo,
    required this.url,
    this.doArtista = false,
  });

  factory StoryDoShow.deJson(Map<String, dynamic> json, Uri base) =>
      StoryDoShow(
        id: json['id'] as String,
        tipo: TipoDeStory.daApi(json['tipo'] as String),
        nome: json['nome'] as String?,
        criadoEm: DateTime.parse(json['criadoEm'] as String),
        tipoDeConteudo: json['tipoDeConteudo'] as String,
        url: base.resolve(json['url'] as String),
        doArtista: json['doArtista'] as bool? ?? false,
      );

  final String id;
  final TipoDeStory tipo;
  final String? nome;
  final DateTime criadoEm;
  final String tipoDeConteudo;
  final Uri url;

  /// Postado pelo artista: aparece com destaque.
  final bool doArtista;
}
