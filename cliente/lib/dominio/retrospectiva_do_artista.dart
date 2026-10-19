import 'modelos.dart';

/// Um número de destaque do cartão, no jeito do Strava: "Tempo" + "3h12".
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
// divulgar, então um número só aparece quando valoriza a noite. Público no
// app, atendimento e alôs interessam só ao artista e ficam fora.
const _duracaoMinima = Duration(minutes: 30);
const _tocadosMinimos = 3;
const _tocadosPorPessoa = .15;
const _notaMinima = 4.0;
const _musicasTocadasMinimas = 10;
const _maximoDeDestaques = 3;

String _nota(double media) => media.toStringAsFixed(1).replaceAll('.', ',');

// O cartão usa só os números validados pelo servidor (cada pessoa conta uma
// vez por música); sem eles, nenhum número de pedido aparece.
const _semDadosValidados = DadosDaRetrospectiva(
  favorita: null,
  musicasAPedidoTocadas: 0,
  pedidosConsiderados: 0,
  pedidosAtendidos: 0,
  pessoasQueAvaliaram: 0,
  mediaDasAvaliacoes: null,
  musicasTocadas: 0,
  alosDados: 0,
  iniciadaEm: null,
  encerradaEm: null,
  maisPedidasPorPessoas: [],
  recusadasPorPessoas: [],
);

DadosDaRetrospectiva _validados(EstatisticasDaApresentacao e) =>
    e.retrospectiva ?? _semDadosValidados;

/// Números que entram no cartão do show público, do mais forte ao mais
/// fraco, sem nunca mostrar show curto, poucas músicas nem a nota.
List<DestaqueDaRetrospectiva> destaquesDoShow(EstatisticasDaApresentacao e) {
  final r = _validados(e);
  final destaques = <DestaqueDaRetrospectiva>[];
  if (r.iniciadaEm case final inicio?) {
    if (r.encerradaEm?.difference(inicio) case final tempo?
        when tempo >= _duracaoMinima) {
      destaques.add(DestaqueDaRetrospectiva(
          valor: formatarTempoDoShow(tempo), rotulo: 'Tempo'));
    }
  }
  if (r.musicasTocadas >= _musicasTocadasMinimas) {
    destaques.add(DestaqueDaRetrospectiva(
        valor: '${r.musicasTocadas}', rotulo: 'Músicas'));
  }
  // A nota fica fora: quem vê "4,7" não sabe que é de 5 e lê como nota baixa.
  final aPedido = r.musicasAPedidoTocadas;
  if (aPedido >= _tocadosMinimos &&
      aPedido >= e.pessoasNoEvento * _tocadosPorPessoa) {
    destaques
        .add(DestaqueDaRetrospectiva(valor: '$aPedido', rotulo: 'A pedido'));
  }
  return destaques.take(_maximoDeDestaques).toList();
}

/// Música tocada que mais pessoas diferentes pediram (pelo menos duas).
String? favoritaDoShow(EstatisticasDaApresentacao e) =>
    _validados(e).favorita?.musica;

/// "21h00 às 00h12 · 3h12 de show", só com início e fim plausíveis.
String? duracaoDoShow(EstatisticasDaApresentacao e) {
  final r = _validados(e);
  final inicio = r.iniciadaEm?.toLocal();
  final fim = r.encerradaEm?.toLocal();
  if (inicio == null || fim == null) return null;
  String hora(DateTime data) => '${data.hour.toString().padLeft(2, '0')}h'
      '${data.minute.toString().padLeft(2, '0')}';
  return '${hora(inicio)} às ${hora(fim)} · '
      '${formatarTempoDoShow(fim.difference(inicio))} de show';
}

/// Na resenha vale tudo: números completos, inclusive recusas e nota baixa,
/// mas sem contar a mesma pessoa duas vezes na mesma música.
List<DestaqueDaRetrospectiva> numerosDaResenha(EstatisticasDaApresentacao e) {
  final r = _validados(e);
  return [
    DestaqueDaRetrospectiva(
        valor: '${r.pedidosConsiderados}', rotulo: 'Pedidos'),
    DestaqueDaRetrospectiva(
        valor: '${r.musicasAPedidoTocadas}', rotulo: 'Tocadas'),
    DestaqueDaRetrospectiva(
        valor: '${r.recusadasPorPessoas.length}', rotulo: 'Recusadas'),
    if (r.mediaDasAvaliacoes case final media?)
      DestaqueDaRetrospectiva(valor: _nota(media), rotulo: 'Nota'),
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
      candidatos.fold<ParticipanteDaResenha?>(null,
          (atual, p) => atual == null || medida(p) > medida(atual) ? p : atual);
  double mediaDada(ParticipanteDaResenha p) =>
      p.avaliacoes.map((a) => a.estrelas).reduce((a, b) => a + b) /
      p.avaliacoes.length;
  String plural(int valor, String um, String varios) =>
      '$valor ${valor == 1 ? um : varios}';

  final hino = _validados(e).maisPedidasPorPessoas.firstOrNull;
  final pidao = maior(galera.where((p) => pediu(p) > 0), pediu);
  final certeiro = maior(
      galera.where((p) => p.pedidosTocados > 0 && p.pedidosTocados == pediu(p)),
      (p) => p.pedidosTocados);
  final ignorado = maior(galera.where((p) => p.pedidosRecusados > 0),
          (p) => p.pedidosRecusados) ??
      maior(galera.where((p) => pediu(p) > 0 && p.pedidosTocados == 0), pediu);
  final polemica = _validados(e).recusadasPorPessoas.firstOrNull;
  final avaliadores = galera.where((p) => p.avaliacoes.isNotEmpty);
  final critico = maior(avaliadores.where((p) => mediaDada(p) < _notaMinima),
      (p) => -mediaDada(p));
  final puxaSaco = maior(
      avaliadores.where((p) =>
          p.avaliacoes.length >= 2 &&
          p.avaliacoes.every((a) => a.estrelas == 5)),
      (p) => p.avaliacoes.length);
  final (climao, piorNota) = _piorNota(avaliadores);
  final calados =
      galera.where((p) => pediu(p) == 0).map((p) => p.nome).toList();

  return [
    if (hino != null)
      PremioDaResenha(
          emoji: '🔥',
          titulo: 'Hino da resenha',
          vencedor: hino.musica,
          detalhe:
              'pedida por ${plural(hino.quantidade, 'pessoa', 'pessoas')}'),
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
              'recusada para ${plural(polemica.quantidade, 'pessoa', 'pessoas')}'),
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
