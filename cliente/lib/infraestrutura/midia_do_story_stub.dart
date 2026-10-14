import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

/// Fora da Web não há como ler a duração sem tocar o vídeo.
Future<Duration?> duracaoDoVideo(XFile arquivo) async => null;

/// Fora da Web: envio de uma vez, sem progresso parcial.
Future<void> enviarArquivo(Uri url, Map<String, String> cabecalhos,
    XFile arquivo, void Function(double fracao) progresso) async {
  final resposta =
      await http.put(url, headers: cabecalhos, body: await arquivo.readAsBytes());
  if (resposta.statusCode >= 300) {
    throw Exception('Envio recusado (${resposta.statusCode}).');
  }
  progresso(1);
}
