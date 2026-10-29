part of 'leitor_de_cifras.dart';

/// Tom escolhido por música no leitor, guardado no aparelho.
mixin _TomNoLeitor on State<LeitorDeCifras> {
  SharedPreferences? _preferencias;

  static String _chaveDoTom(MusicaDoPalco musica) =>
      'leitor_tom|${normalizarMusica(musica.titulo)}|'
      '${normalizarMusica(musica.artista)}';

  int _semitonsDe(MusicaDoPalco musica) =>
      _preferencias?.getInt(_chaveDoTom(musica)) ?? 0;

  Future<void> _mudarTom(MusicaDoPalco musica, int passo) async {
    // Entre -11 e +11: uma oitava inteira volta ao tom original.
    final semitons = (_semitonsDe(musica) + passo).remainder(12);
    final preferencias = _preferencias;
    if (preferencias == null) return;
    try {
      if (semitons == 0) {
        await preferencias.remove(_chaveDoTom(musica));
      } else {
        await preferencias.setInt(_chaveDoTom(musica), semitons);
      }
    } catch (_) {
      // O tom só não fica guardado para a próxima vez.
    }
    if (mounted) setState(() {});
  }

  String? _rotuloDoTom(MusicaDoPalco musica) {
    final semitons = _semitonsDe(musica);
    final tom = musica.tom?.trim();
    final mudanca =
        semitons == 0 ? '' : ' (${semitons > 0 ? '+' : ''}$semitons)';
    if (tom != null && tom.isNotEmpty) {
      return 'Tom ${transporTom(tom, semitons)}$mudanca';
    }
    return semitons == 0 ? null : 'Tom$mudanca';
  }
}
