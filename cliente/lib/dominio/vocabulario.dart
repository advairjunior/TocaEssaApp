part of 'modelos.dart';

/// Palavras das telas do show. No louvor, música vira hino e cifra vira
/// letra; as frases que mudam de gênero ficam inteiras.
class Vocabulario {
  const Vocabulario._({
    required this.musica,
    required this.musicas,
    required this.cifra,
    required this.setlist,
    required this.tocadas,
    required this.todasSaemDaSetlist,
    required this.setlistVazia,
    required this.convitePraMontar,
    required this.avulsa,
    required this.anterior,
    required this.proxima,
  });

  static const musical = Vocabulario._(
    musica: 'música',
    musicas: 'músicas',
    cifra: 'cifra',
    setlist: 'setlist',
    tocadas: 'tocadas',
    todasSaemDaSetlist:
        'Todas as músicas saem da setlist, inclusive as já tocadas.',
    setlistVazia: 'Setlist vazia',
    convitePraMontar:
        'Monte a setlist com músicas dos seus repertórios ou avulsas.',
    avulsa: 'Música avulsa',
    anterior: 'Música anterior',
    proxima: 'Próxima música',
  );

  static const louvor = Vocabulario._(
    musica: 'hino',
    musicas: 'hinos',
    cifra: 'letra',
    setlist: 'lista de hinos',
    tocadas: 'cantados',
    todasSaemDaSetlist:
        'Todos os hinos saem da lista, inclusive os já cantados.',
    setlistVazia: 'Nenhum hino na lista',
    convitePraMontar:
        'Monte a lista com hinos dos seus repertórios ou avulsos.',
    avulsa: 'Hino avulso',
    anterior: 'Hino anterior',
    proxima: 'Próximo hino',
  );

  final String musica;
  final String musicas;
  final String cifra;
  final String setlist;
  final String tocadas;
  final String todasSaemDaSetlist;
  final String setlistVazia;
  final String convitePraMontar;
  final String avulsa;
  final String anterior;
  final String proxima;

  /// "Cifra" ou "Letra", para começo de frase.
  String get cifraMaiuscula => cifra[0].toUpperCase() + cifra.substring(1);

  String semCifra(int quantidade) => quantidade == 1
      ? '1 $musica sem $cifra'
      : '$quantidade $musicas sem $cifra';
}

extension VocabularioDoTipo on TipoApresentacao {
  Vocabulario get vocabulario => this == TipoApresentacao.louvor
      ? Vocabulario.louvor
      : Vocabulario.musical;
}
