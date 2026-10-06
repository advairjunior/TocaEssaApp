import 'modelos.dart';

/// Um número de destaque do cartão: "80" + "pessoas no app".
class DestaqueDaRetrospectiva {
  const DestaqueDaRetrospectiva({required this.valor, required this.rotulo});
  final String valor;
  final String rotulo;
}

/// Um prêmio de zoeira da resenha: quem (ou qual música) levou e por quê.
class PremioDaResenha {
  const PremioDaResenha({
    required this.emoji,
    required this.titulo,
    required this.vencedor,
    required this.detalhe,
  });
  final String emoji;
  final String titulo;
  final String vencedor;
  final String detalhe;
}

// Regras da vitrine do show público: o cartão serve para o artista se
// divulgar, então um número só aparece quando valoriza a noite.
const _publicoMinimo = 10;
const _tocadosMinimos = 3;
const _tocadosPorPessoa = .15;
const _avaliacoesMinimas = 3;
const _notaMinima = 4.0;
const _pedidosMinimosParaAtendimento = 5;
const _atendimentoMinimo = .7;
const _maximoDeDestaques = 3;

/// Números que entram no cartão do show público, do mais forte ao mais
/// fraco, sem nunca mostrar público pequeno, poucas músicas ou nota baixa.
List<DestaqueDaRetrospectiva> destaquesDoShow(EstatisticasDaApresentacao e) {
  final destaques = <DestaqueDaRetrospectiva>[];
  if (e.pessoasNoEvento >= _publicoMinimo) {
    destaques.add(DestaqueDaRetrospectiva(
        valor: '${e.pessoasNoEvento}', rotulo: 'pessoas no app'));
  }
  if (e.tocados >= _tocadosMinimos &&
      e.tocados >= e.pessoasNoEvento * _tocadosPorPessoa) {
    destaques.add(DestaqueDaRetrospectiva(
        valor: '${e.tocados}', rotulo: 'músicas a pedido'));
  }
  final media = e.mediaAvaliacoes;
  if (media != null &&
      e.avaliados >= _avaliacoesMinimas &&
      media >= _notaMinima) {
    destaques.add(DestaqueDaRetrospectiva(
        valor: media.toStringAsFixed(1), rotulo: 'de nota'));
  }
  if (e.totalPedidos >= _pedidosMinimosParaAtendimento &&
      e.tocados / e.totalPedidos >= _atendimentoMinimo) {
    destaques.add(DestaqueDaRetrospectiva(
        valor: '${(e.tocados * 100 / e.totalPedidos).round()}%',
        rotulo: 'pedidos atendidos'));
  }
  return destaques.take(_maximoDeDestaques).toList();
}

/// Música mais pedida do show, só quando foi pedida mais de uma vez.
String? favoritaDoShow(EstatisticasDaApresentacao e) {
  final primeira = e.musicasMaisPedidas.firstOrNull;
  return primeira != null && primeira.quantidade >= 2 ? primeira.musica : null;
}

/// Na resenha vale tudo: números completos, inclusive recusas e nota baixa.
List<DestaqueDaRetrospectiva> numerosDaResenha(EstatisticasDaApresentacao e) {
  String plural(int valor, String um, String varios) =>
      valor == 1 ? um : varios;
  return [
    DestaqueDaRetrospectiva(
        valor: '${e.pessoasNoEvento}', rotulo: 'na resenha'),
    DestaqueDaRetrospectiva(
        valor: '${e.totalPedidos}',
        rotulo: plural(e.totalPedidos, 'pedido', 'pedidos')),
    DestaqueDaRetrospectiva(
        valor: '${e.tocados}', rotulo: plural(e.tocados, 'tocado', 'tocados')),
    DestaqueDaRetrospectiva(
        valor: '${e.recusados}',
        rotulo: plural(e.recusados, 'recusado', 'recusados')),
    if (e.mediaAvaliacoes != null)
      DestaqueDaRetrospectiva(
          valor: e.mediaAvaliacoes!.toStringAsFixed(1), rotulo: 'de nota'),
  ];
}

/// Prêmios de zoeira da resenha, calculados só com quem é do público.
List<PremioDaResenha> premiosDaResenha(
  List<ParticipanteDaResenha> participantes,
  EstatisticasDaApresentacao e,
) {
  final galera = participantes.where((p) => !p.ehArtista).toList();
  int pediu(ParticipanteDaResenha p) => p.pedidos + p.pedidosRecusados;
  ParticipanteDaResenha? maior(
    Iterable<ParticipanteDaResenha> candidatos,
    num Function(ParticipanteDaResenha) medida,
  ) =>
      candidatos.fold<ParticipanteDaResenha?>(
          null,
          (atual, p) =>
              atual == null || medida(p) > medida(atual) ? p : atual);
  double mediaDada(ParticipanteDaResenha p) =>
      p.avaliacoes.map((a) => a.estrelas).reduce((a, b) => a + b) /
      p.avaliacoes.length;
  String plural(int valor, String um, String varios) =>
      '$valor ${valor == 1 ? um : varios}';

  final hino = e.musicasMaisPedidas.firstOrNull;
  final pidao = maior(galera.where((p) => pediu(p) > 0), pediu);
  final certeiro = maior(
      galera.where((p) => p.pedidosTocados > 0 && p.pedidosTocados == pediu(p)),
      (p) => p.pedidosTocados);
  final ignorado = maior(galera.where((p) => p.pedidosRecusados > 0),
          (p) => p.pedidosRecusados) ??
      maior(galera.where((p) => pediu(p) > 0 && p.pedidosTocados == 0), pediu);
  final polemica = e.musicasRecusadas.firstOrNull;
  final avaliadores = galera.where((p) => p.avaliacoes.isNotEmpty);
  final critico = maior(
      avaliadores.where((p) => mediaDada(p) < _notaMinima),
      (p) => -mediaDada(p));
  final puxaSaco = maior(
      avaliadores.where((p) =>
          p.avaliacoes.length >= 2 && p.avaliacoes.every((a) => a.estrelas == 5)),
      (p) => p.avaliacoes.length);
  final (climao, piorNota) = _piorNota(avaliadores);
  final calados = galera.where((p) => pediu(p) == 0).map((p) => p.nome).toList();

  return [
    if (hino != null)
      PremioDaResenha(
          emoji: '🔥',
          titulo: 'Hino da resenha',
          vencedor: hino.musica,
          detalhe: 'pedida ${plural(hino.quantidade, 'vez', 'vezes')}'),
    if (pidao != null)
      PremioDaResenha(
          emoji: '🎤',
          titulo: 'Pidão da noite',
          vencedor: pidao.nome,
          detalhe: plural(pediu(pidao), 'pedido', 'pedidos')),
    if (certeiro != null)
      PremioDaResenha(
          emoji: '🎯',
          titulo: 'Pontaria certeira',
          vencedor: certeiro.nome,
          detalhe: 'tudo o que pediu foi tocado'),
    if (ignorado != null)
      PremioDaResenha(
          emoji: '🙈',
          titulo: 'Ignorado da noite',
          vencedor: ignorado.nome,
          detalhe: ignorado.pedidosRecusados > 0
              ? plural(ignorado.pedidosRecusados, 'pedido recusado',
                  'pedidos recusados')
              : 'pediu e não ouviu nenhuma'),
    if (polemica != null)
      PremioDaResenha(
          emoji: '🚫',
          titulo: 'Polêmica da noite',
          vencedor: polemica.musica,
          detalhe:
              'recusada ${plural(polemica.quantidade, 'vez', 'vezes')}'),
    if (critico != null)
      PremioDaResenha(
          emoji: '🧐',
          titulo: 'Crítico da noite',
          vencedor: critico.nome,
          detalhe: 'média de ${mediaDada(critico).toStringAsFixed(1)} ★'),
    if (puxaSaco != null)
      PremioDaResenha(
          emoji: '⭐',
          titulo: 'Puxa-saco oficial',
          vencedor: puxaSaco.nome,
          detalhe: 'só deu 5 estrelas'),
    if (climao != null && piorNota != null)
      PremioDaResenha(
          emoji: '🥶',
          titulo: 'Climão da noite',
          vencedor: climao.nome,
          detalhe: '${piorNota.estrelas} ★ para "${piorNota.musica}"'),
    if (calados.isNotEmpty)
      PremioDaResenha(
          emoji: '🍻',
          titulo: 'Só veio pela resenha',
          vencedor: _listarNomes(calados),
          detalhe: 'não pediu nenhuma música'),
  ];
}

/// Quem deu a nota mais baixa da noite, quando ela foi de 2 estrelas ou menos.
(ParticipanteDaResenha?, AvaliacaoNaResenha?) _piorNota(
    Iterable<ParticipanteDaResenha> avaliadores) {
  ParticipanteDaResenha? quem;
  AvaliacaoNaResenha? pior;
  for (final pessoa in avaliadores) {
    for (final avaliacao in pessoa.avaliacoes) {
      if (avaliacao.estrelas <= 2 &&
          (pior == null || avaliacao.estrelas < pior.estrelas)) {
        quem = pessoa;
        pior = avaliacao;
      }
    }
  }
  return (quem, pior);
}

String _listarNomes(List<String> nomes) => switch (nomes.length) {
      1 => nomes[0],
      2 => '${nomes[0]} e ${nomes[1]}',
      3 => '${nomes[0]}, ${nomes[1]} e ${nomes[2]}',
      _ => '${nomes.take(3).join(', ')} e mais ${nomes.length - 3}',
    };
