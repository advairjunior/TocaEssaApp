part of 'modelos.dart';

/// Livre: cada um escolhe a música da playlist. Roleta: o app sorteia.
enum ModoDasMusicas {
  livre,
  roleta;

  factory ModoDasMusicas.deJson(String? valor) =>
      valor == 'Roleta' ? roleta : livre;

  String get paraJson => this == roleta ? 'Roleta' : 'Livre';

  String get rotulo => this == roleta ? 'Roleta' : 'Livre';

  String get descricao => this == roleta
      ? 'O app sorteia a música da playlist; quem não conhece sorteia outra.'
      : 'Cada um escolhe a música da playlist ou adiciona outra.';
}

/// A música de uma vez: da playlist (com vídeo) ou outra, com ou sem link.
class MusicaDoKaraoke {
  const MusicaDoKaraoke({required this.titulo, this.linkDoVideo});

  final String titulo;
  final String? linkDoVideo;

  /// O vídeo guardado; sem ele, a busca do karaokê no YouTube.
  Uri get enderecoNoYouTube => linkDoVideo != null
      ? Uri.parse(linkDoVideo!)
      : Uri.https(
          'www.youtube.com', '/results', {'search_query': '$titulo karaoke'});

  static MusicaDoKaraoke? deJson(Object? json) => json is Map<String, dynamic>
      ? MusicaDoKaraoke(
          titulo: json['titulo'] as String,
          linkDoVideo: json['linkDoVideo'] as String?,
        )
      : null;
}

class PessoaDoKaraoke {
  const PessoaDoKaraoke(
      {required this.publicoId, required this.nome, this.fotoUrl, this.musica});

  final String publicoId;
  final String nome;
  final String? fotoUrl;

  /// A escolhida para a próxima vez da pessoa.
  final MusicaDoKaraoke? musica;

  factory PessoaDoKaraoke.deJson(Map<String, dynamic> json) => PessoaDoKaraoke(
        publicoId: json['publicoId'] as String,
        nome: json['nome'] as String,
        fotoUrl: json['fotoUrl'] as String?,
        musica: MusicaDoKaraoke.deJson(json['musica']),
      );
}

/// "4,6": a nota com uma casa e vírgula.
String notaDoKaraoke(double media) =>
    media.toStringAsFixed(1).replaceAll('.', ',');

/// "★ 4,5 · 2 votos"; sem voto, nulo.
String? mediaComVotos(double? media, int votos) => media == null
    ? null
    : '★ ${notaDoKaraoke(media)} · $votos ${votos == 1 ? 'voto' : 'votos'}';

/// Quem está cantando agora, a média da galera e a nota de quem vê.
class CantandoNoKaraoke {
  const CantandoNoKaraoke({
    required this.publicoId,
    required this.nome,
    required this.musica,
    this.media,
    this.votos = 0,
    this.minhaNota,
  });

  final String publicoId;
  final String nome;
  final MusicaDoKaraoke musica;
  final double? media;
  final int votos;
  final int? minhaNota;

  static CantandoNoKaraoke? deJson(Object? json) => json is Map<String, dynamic>
      ? CantandoNoKaraoke(
          publicoId: json['publicoId'] as String,
          nome: json['nome'] as String,
          musica: MusicaDoKaraoke.deJson(json['musica'])!,
          media: (json['media'] as num?)?.toDouble(),
          votos: json['votos'] as int? ?? 0,
          minhaNota: json['minhaNota'] as int?,
        )
      : null;
}

/// Uma linha do placar: quantas músicas e a média delas.
class LinhaDoPlacar {
  const LinhaDoPlacar({
    required this.publicoId,
    required this.nome,
    required this.musicas,
    this.media,
    this.melhorMusica,
  });

  final String publicoId;
  final String nome;
  final int musicas;
  final double? media;

  /// A música com a maior nota da pessoa na noite.
  final String? melhorMusica;

  /// "2 músicas · ★ 4,6" ou "1 música · sem nota".
  String get resumo => '$musicas ${musicas == 1 ? 'música' : 'músicas'} · '
      '${media == null ? 'sem nota' : '★ ${notaDoKaraoke(media!)}'}';

  factory LinhaDoPlacar.deJson(Map<String, dynamic> json) => LinhaDoPlacar(
        publicoId: json['publicoId'] as String,
        nome: json['nome'] as String,
        musicas: json['musicas'] as int,
        media: (json['media'] as num?)?.toDouble(),
        melhorMusica: json['melhorMusica'] as String?,
      );
}

/// A noite de karaokê na memória de quem cantou.
class KaraokeDoPublico {
  const KaraokeDoPublico(
      {required this.musicas, this.media, this.vozDaNoite = false});

  final int musicas;
  final double? media;
  final bool vozDaNoite;

  static KaraokeDoPublico? deJson(Object? json) => json is Map<String, dynamic>
      ? KaraokeDoPublico(
          musicas: json['musicas'] as int? ?? 0,
          media: (json['media'] as num?)?.toDouble(),
          vozDaNoite: json['vozDaNoite'] as bool? ?? false,
        )
      : null;
}

class MusicaDaPlaylistDoKaraoke {
  const MusicaDaPlaylistDoKaraoke({required this.id, required this.titulo});

  final String id;
  final String titulo;

  factory MusicaDaPlaylistDoKaraoke.deJson(Map<String, dynamic> json) =>
      MusicaDaPlaylistDoKaraoke(
          id: json['id'] as String, titulo: json['titulo'] as String);
}

/// A noite como o dono e a galera veem: antes do sorteio, [ordem] é a ordem
/// de chegada.
class NoiteDeKaraoke {
  const NoiteDeKaraoke({
    required this.repertorioId,
    required this.modo,
    required this.sorteada,
    required this.podeSortearDeNovo,
    required this.ordem,
    required this.foraDaOrdem,
    this.cantando,
    this.proximo,
    this.placar = const [],
    this.vozDaNoite,
  });

  final String? repertorioId;
  final ModoDasMusicas modo;
  final bool sorteada;
  final bool podeSortearDeNovo;
  final List<PessoaDoKaraoke> ordem;
  final List<PessoaDoKaraoke> foraDaOrdem;
  final CantandoNoKaraoke? cantando;

  /// Quem canta depois de quem está cantando (ou o primeiro da noite).
  final String? proximo;

  /// Quem cantou, da maior média para a menor.
  final List<LinhaDoPlacar> placar;

  /// Maior média com votos suficientes; vale como Voz no fim da noite.
  final String? vozDaNoite;

  factory NoiteDeKaraoke.deJson(Map<String, dynamic> json) => NoiteDeKaraoke(
        repertorioId: json['repertorioId'] as String?,
        modo: ModoDasMusicas.deJson(json['modo'] as String?),
        sorteada: json['sorteada'] as bool,
        podeSortearDeNovo: json['podeSortearDeNovo'] as bool,
        ordem: _pessoas(json['ordem']),
        foraDaOrdem: _pessoas(json['foraDaOrdem']),
        cantando: CantandoNoKaraoke.deJson(json['cantando']),
        proximo: json['proximo'] as String?,
        placar: [
          for (final linha in json['placar'] as List<dynamic>? ?? const [])
            LinhaDoPlacar.deJson(linha as Map<String, dynamic>),
        ],
        vozDaNoite: json['vozDaNoite'] as String?,
      );

  static List<PessoaDoKaraoke> _pessoas(Object? lista) => [
        for (final pessoa in lista as List<dynamic>? ?? const [])
          PessoaDoKaraoke.deJson(pessoa as Map<String, dynamic>),
      ];

  /// Posição de [publicoId] na ordem, a partir de 1; nulo se não está nela.
  int? posicaoDe(String? publicoId) {
    final indice = ordem.indexWhere((pessoa) => pessoa.publicoId == publicoId);
    return indice < 0 ? null : indice + 1;
  }
}

extension VezNaNoite on NoiteDeKaraoke {
  PessoaDoKaraoke? pessoa(String? publicoId) {
    for (final pessoa in ordem) {
      if (pessoa.publicoId == publicoId) return pessoa;
    }
    return null;
  }
}
