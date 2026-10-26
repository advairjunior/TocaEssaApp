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

class PessoaDoKaraoke {
  const PessoaDoKaraoke(
      {required this.publicoId, required this.nome, this.fotoUrl});

  final String publicoId;
  final String nome;
  final String? fotoUrl;

  factory PessoaDoKaraoke.deJson(Map<String, dynamic> json) => PessoaDoKaraoke(
        publicoId: json['publicoId'] as String,
        nome: json['nome'] as String,
        fotoUrl: json['fotoUrl'] as String?,
      );
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
  });

  final String? repertorioId;
  final ModoDasMusicas modo;
  final bool sorteada;
  final bool podeSortearDeNovo;
  final List<PessoaDoKaraoke> ordem;
  final List<PessoaDoKaraoke> foraDaOrdem;

  factory NoiteDeKaraoke.deJson(Map<String, dynamic> json) => NoiteDeKaraoke(
        repertorioId: json['repertorioId'] as String?,
        modo: ModoDasMusicas.deJson(json['modo'] as String?),
        sorteada: json['sorteada'] as bool,
        podeSortearDeNovo: json['podeSortearDeNovo'] as bool,
        ordem: _pessoas(json['ordem']),
        foraDaOrdem: _pessoas(json['foraDaOrdem']),
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
