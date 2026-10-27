import 'package:flutter_test/flutter_test.dart';
import 'package:toca_essa_app/dominio/modelos.dart';

EncontroDoPublico _encontro(Map<String, dynamic>? noKaraoke) =>
    EncontroDoPublico.deJson({
      'apresentacao': {
        'id': 'k1',
        'nome': 'Karaokê de sexta',
        'data': '2026-10-30',
        'local': 'Casa',
        'codigo': 'KARA01',
        'perfilArtistico': {'id': 'pa', 'nomeArtistico': 'Advair'},
        'tipo': 'Karaoke',
      },
      'noKaraoke': noKaraoke,
    });

void main() {
  test('o karaokê em Meus encontros diz quanto cantou, a nota e a Voz', () {
    expect(
        _encontro({'musicas': 2, 'media': 4.6, 'vozDaNoite': true})
            .resumoDoKaraoke,
        'Cantei 2 músicas · nota 4,6 · Voz da noite');
    expect(
        _encontro({'musicas': 1, 'media': null, 'vozDaNoite': false})
            .resumoDoKaraoke,
        'Cantei 1 música');
    expect(
        _encontro({'musicas': 0, 'media': null, 'vozDaNoite': false})
            .resumoDoKaraoke,
        isNull);
    expect(_encontro(null).resumoDoKaraoke, isNull);
  });
}
