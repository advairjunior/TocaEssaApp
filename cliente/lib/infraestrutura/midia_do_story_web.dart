import 'dart:async';
import 'dart:js_interop';

import 'package:image_picker/image_picker.dart';
import 'package:web/web.dart';

/// Lê só os metadados do vídeo para saber a duração; nulo se o navegador
/// não conseguir em alguns segundos.
Future<Duration?> duracaoDoVideo(XFile arquivo) async {
  final video = HTMLVideoElement()
    ..preload = 'metadata'
    ..muted = true;
  final pronto = Completer<Duration?>();
  video.onloadedmetadata = ((Event _) {
    final segundos = video.duration;
    if (!pronto.isCompleted) {
      pronto.complete(segundos.isFinite
          ? Duration(milliseconds: (segundos * 1000).round())
          : null);
    }
  }).toJS;
  video.onerror = ((Event _) {
    if (!pronto.isCompleted) pronto.complete(null);
  }).toJS;
  video.src = arquivo.path;
  try {
    return await pronto.future
        .timeout(const Duration(seconds: 5), onTimeout: () => null);
  } finally {
    video.removeAttribute('src');
  }
}

/// PUT direto do blob escolhido (sem copiar o vídeo para a memória do app),
/// com o progresso do envio.
Future<void> enviarArquivo(Uri url, Map<String, String> cabecalhos,
    XFile arquivo, void Function(double fracao) progresso) async {
  final resposta = await window.fetch(arquivo.path.toJS).toDart;
  final conteudo = await resposta.blob().toDart;
  final pedido = XMLHttpRequest()..open('PUT', url.toString());
  cabecalhos.forEach(pedido.setRequestHeader);
  final terminou = Completer<void>();
  pedido.upload.onprogress = ((ProgressEvent evento) {
    if (evento.lengthComputable && evento.total > 0) {
      progresso(evento.loaded / evento.total);
    }
  }).toJS;
  pedido.onload = ((Event _) {
    if (pedido.status >= 200 && pedido.status < 300) {
      progresso(1);
      terminou.complete();
    } else {
      terminou.completeError(Exception('Envio recusado (${pedido.status}).'));
    }
  }).toJS;
  pedido.onerror = ((Event _) {
    if (!terminou.isCompleted) {
      terminou.completeError(Exception('Sem conexão para enviar.'));
    }
  }).toJS;
  pedido.send(conteudo);
  await terminou.future;
}
