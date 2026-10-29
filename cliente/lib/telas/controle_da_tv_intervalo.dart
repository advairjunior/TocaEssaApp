part of 'controle_da_tv.dart';

/// Entre uma música e outra: um tempo depois de a última linha acender, a
/// TV troca a letra pelo "A seguir", o QR e as fotos dos stories do show.
/// Qualquer linha nova (ou a próxima música) volta para a letra.
mixin _IntervaloDaTv on ChangeNotifier {
  bool intervalo = false;
  List<StoryDoShow> fotos = const [];
  Timer? _paraOIntervalo;

  ApiTocaEssa get api;
  Duration get esperaDoIntervalo;
  ConteudoDaTv? get conteudo;
  void _avisar();

  void _sairDoIntervalo() {
    _paraOIntervalo?.cancel();
    _paraOIntervalo = null;
    intervalo = false;
  }

  /// Na última linha da letra, marca a hora do intervalo.
  void _acompanharOFim() {
    _sairDoIntervalo();
    final atual = conteudo;
    if (atual == null) return;
    final total = LetraDaTela.doTexto(atual.texto).total;
    if (total > 0 && atual.linha >= total - 1) {
      _paraOIntervalo = Timer(esperaDoIntervalo, _entrarNoIntervalo);
    }
  }

  Future<void> _entrarNoIntervalo() async {
    intervalo = true;
    _avisar();
    final codigo = conteudo?.codigo;
    if (codigo == null) return;
    try {
      final stories = await api.listarStoriesDoShow(codigo);
      // Vídeo na TV fica para depois: só as fotos passam.
      fotos = [
        for (final story in stories)
          if (story.tipo == TipoDeStory.foto) story
      ];
      _avisar();
    } catch (_) {
      // Sem os stories, o intervalo fica com o "A seguir" e o QR.
    }
  }
}
