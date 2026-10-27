part of 'cartao_do_karaoke.dart';

/// O que vai impresso no cartão do karaokê: de quem cantou ou da noite.
class ConteudoDoCartaoDoKaraoke {
  const ConteudoDoCartaoDoKaraoke({
    required this.titulo,
    required this.subtitulo,
    required this.numeros,
    this.selo,
    this.destaque,
  });

  final String titulo;
  final String subtitulo;

  /// "Voz da noite", acima do nome.
  final String? selo;

  /// Rótulo e valor em destaque: a melhor música, ou quem foi a voz.
  final (String, String)? destaque;

  /// Valor e rótulo de cada número, da esquerda para a direita.
  final List<(String, String)> numeros;
}

bool _encerrada(Apresentacao apresentacao) =>
    apresentacao.status == StatusApresentacao.encerrada;

String _nota(double? media) => media == null ? '—' : notaDoKaraoke(media);

/// O cartão de quem já cantou na noite; quem não cantou ainda não tem.
ConteudoDoCartaoDoKaraoke? cartaoDeQuemCantou(
    Apresentacao apresentacao, NoiteDeKaraoke noite, String? eu) {
  final indice = noite.placar.indexWhere((linha) => linha.publicoId == eu);
  if (indice < 0) return null;
  final linha = noite.placar[indice];
  final voz = _encerrada(apresentacao) && noite.vozDaNoite == eu;
  return ConteudoDoCartaoDoKaraoke(
    titulo: linha.nome,
    subtitulo: '${apresentacao.nome} · ${formatarData(apresentacao.data)}',
    selo: voz ? 'Voz da noite' : null,
    destaque: linha.melhorMusica == null
        ? null
        : ('Minha melhor música', linha.melhorMusica!),
    numeros: [
      ('${linha.musicas}', linha.musicas == 1 ? 'música' : 'músicas'),
      (_nota(linha.media), 'nota da galera'),
      ('${indice + 1}º', 'de ${noite.placar.length} no placar'),
    ],
  );
}

/// O cartão da noite para o dono: quantos cantaram e quem foi a voz.
ConteudoDoCartaoDoKaraoke? cartaoDaNoiteDoKaraoke(
    Apresentacao apresentacao, NoiteDeKaraoke noite) {
  if (noite.placar.isEmpty) return null;
  final musicas =
      noite.placar.fold<int>(0, (total, linha) => total + linha.musicas);
  final voz = noite.placar
      .where((linha) => linha.publicoId == noite.vozDaNoite)
      .firstOrNull;
  return ConteudoDoCartaoDoKaraoke(
    titulo: apresentacao.nome,
    subtitulo: 'Noite de Karaokê · ${formatarData(apresentacao.data)}',
    destaque: voz == null
        ? null
        : (
            _encerrada(apresentacao) ? 'Voz da noite' : 'Liderando',
            '${voz.nome} · ★ ${_nota(voz.media)}'
          ),
    numeros: [
      (
        '${noite.placar.length}',
        noite.placar.length == 1 ? 'cantou' : 'cantaram'
      ),
      ('$musicas', musicas == 1 ? 'música' : 'músicas'),
    ],
  );
}
