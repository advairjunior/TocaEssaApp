part of 'modelos.dart';

class Repertorio {
  const Repertorio({
    required this.id,
    required this.artistaId,
    required this.nome,
    required this.musicas,
  });

  final String id;
  final String artistaId;
  final String nome;
  final List<MusicaDoRepertorio> musicas;

  factory Repertorio.deJson(Map<String, dynamic> json) => Repertorio(
        id: json['id'] as String,
        artistaId: json['artistaId'] as String,
        nome: json['nome'] as String,
        musicas: (json['musicas'] as List<dynamic>)
            .map((m) => MusicaDoRepertorio.deJson(m as Map<String, dynamic>))
            .toList(),
      );
}

class MusicaDoRepertorio {
  const MusicaDoRepertorio({
    required this.id,
    required this.repertorioId,
    required this.titulo,
    this.artista,
    this.tom,
    required this.ordem,
  });

  final String id;
  final String repertorioId;
  final String titulo;
  final String? artista;
  final String? tom;
  final int ordem;

  factory MusicaDoRepertorio.deJson(Map<String, dynamic> json) =>
      MusicaDoRepertorio(
        id: json['id'] as String,
        repertorioId: json['repertorioId'] as String,
        titulo: json['titulo'] as String,
        artista: json['artista'] as String?,
        tom: json['tom'] as String?,
        ordem: json['ordem'] as int,
      );
}

/// Música da setlist, hino ou pedido a caminho de um repertório.
typedef MusicaParaRepertorio = ({String titulo, String? artista, String? tom});

class MusicasAdicionadas {
  const MusicasAdicionadas({
    required this.repertorio,
    required this.adicionadas,
    required this.jaEstavam,
  });

  final Repertorio repertorio;
  final int adicionadas;
  final int jaEstavam;

  factory MusicasAdicionadas.deJson(Map<String, dynamic> json) =>
      MusicasAdicionadas(
        repertorio:
            Repertorio.deJson(json['repertorio'] as Map<String, dynamic>),
        adicionadas: json['adicionadas'] as int,
        jaEstavam: json['jaEstavam'] as int,
      );
}

/// Música pedida pelo público nos shows e ainda fora dos repertórios.
class PedidaForaDoRepertorio {
  const PedidaForaDoRepertorio({
    required this.musica,
    this.artista,
    required this.vezes,
    required this.shows,
  });

  final String musica;
  final String? artista;
  final int vezes;
  final int shows;

  /// "pedida 7x em 3 shows", ou só "pedida 2x" quando foi num show.
  String get resumo =>
      shows > 1 ? 'pedida ${vezes}x em $shows shows' : 'pedida ${vezes}x';

  factory PedidaForaDoRepertorio.deJson(Map<String, dynamic> json) =>
      PedidaForaDoRepertorio(
        musica: json['musica'] as String,
        artista: json['artista'] as String?,
        vezes: json['vezes'] as int,
        shows: json['shows'] as int,
      );
}

class ItemDoSetlist {
  const ItemDoSetlist({
    required this.id,
    required this.apresentacaoId,
    required this.titulo,
    this.artista,
    this.tom,
    required this.tocada,
    required this.ordem,
  });

  final String id;
  final String apresentacaoId;
  final String titulo;
  final String? artista;
  final String? tom;
  final bool tocada;
  final int ordem;

  factory ItemDoSetlist.deJson(Map<String, dynamic> json) => ItemDoSetlist(
        id: json['id'] as String,
        apresentacaoId: json['apresentacaoId'] as String,
        titulo: json['titulo'] as String,
        artista: json['artista'] as String?,
        tom: json['tom'] as String?,
        tocada: json['tocada'] as bool,
        ordem: json['ordem'] as int,
      );
}

const _semAcento = {
  'á': 'a', 'à': 'a', 'â': 'a', 'ã': 'a', 'ä': 'a', //
  'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e', //
  'í': 'i', 'ì': 'i', 'î': 'i', 'ï': 'i', //
  'ó': 'o', 'ò': 'o', 'ô': 'o', 'õ': 'o', 'ö': 'o', //
  'ú': 'u', 'ù': 'u', 'û': 'u', 'ü': 'u', 'ç': 'c', 'ñ': 'n',
};

/// Mesma regra do servidor: sem acento, maiúscula nem espaço repetido.
String normalizarMusica(String? valor) => (valor ?? '')
    .toLowerCase()
    .split('')
    .map((letra) => _semAcento[letra] ?? letra)
    .join()
    .split(RegExp(r'\s+'))
    .where((parte) => parte.isNotEmpty)
    .join(' ');

/// A busca de todas as listas: sem acento nem maiúscula, em qualquer um dos
/// [campos] (título, cantor...); busca vazia combina com tudo.
bool combinaComBusca(String termo, List<String?> campos) {
  final procurado = normalizarMusica(termo);
  return procurado.isEmpty ||
      normalizarMusica(campos.whereType<String>().join(' '))
          .contains(procurado);
}

/// Mesmo título e mesmo cantor; sem cantor num dos lados, vale o título.
bool mesmaMusica(
    String titulo, String? artista, String outroTitulo, String? outroArtista) {
  if (normalizarMusica(titulo) != normalizarMusica(outroTitulo)) return false;
  final um = normalizarMusica(artista);
  final outro = normalizarMusica(outroArtista);
  return um.isEmpty || outro.isEmpty || um == outro;
}
