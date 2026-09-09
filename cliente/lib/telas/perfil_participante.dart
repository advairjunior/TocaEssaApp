import 'package:flutter/material.dart';
import '../dominio/modelos.dart';
import '../tema/tema_toca_essa.dart';
import 'componentes.dart';
import 'progresso_do_publico.dart';

void abrirPerfilParticipante(BuildContext context,
    ParticipanteDaResenha participante, String? enderecoFoto) {
  Navigator.push<void>(
      context,
      MaterialPageRoute(
          builder: (_) => PerfilParticipante(
              participante: participante, enderecoFoto: enderecoFoto)));
}

class PerfilParticipante extends StatefulWidget {
  const PerfilParticipante(
      {super.key, required this.participante, required this.enderecoFoto});
  final ParticipanteDaResenha participante;
  final String? enderecoFoto;
  @override
  State<PerfilParticipante> createState() => _PerfilParticipanteState();
}

class _PerfilParticipanteState extends State<PerfilParticipante> {
  int _pagina = 0;
  bool _nestaResenha = false;

  Widget _seletorPerfil() => SegmentedButton<bool>(
    segments: const [
      ButtonSegment(value: false, label: Text('Geral')),
      ButtonSegment(value: true, label: Text('Nesta resenha')),
    ],
    selected: {_nestaResenha},
    onSelectionChanged: (valor) => setState(() => _nestaResenha = valor.single),
  );

  @override
  Widget build(BuildContext context) {
    final pessoa = widget.participante;
    final notas = pessoa.avaliacoes;
    final conquistas = [
      ('Na roda', 'Participou desta resenha.', 1, 1, Icons.groups_rounded),
      (
        'Solta o som',
        'Fez um pedido nesta resenha.',
        pessoa.pedidos,
        1,
        Icons.music_note_rounded
      ),
      (
        'Tocou a minha',
        'Teve um pedido tocado nesta resenha.',
        pessoa.pedidosTocados,
        1,
        Icons.check_circle_outline
      ),
      (
        'Ouvido atento',
        'Avaliou três músicas nesta resenha.',
        notas.length,
        3,
        Icons.headphones_rounded
      ),
      (
        'VIP da noite',
        'Teve cinco pedidos tocados nesta resenha.',
        pessoa.pedidosTocados,
        5,
        Icons.emoji_events_rounded
      ),
      (
        'Pede mais uma',
        'Fez cinco pedidos nesta resenha.',
        pessoa.pedidos,
        5,
        Icons.queue_music_rounded
      ),
    ];
    return Scaffold(
        appBar: AppBar(title: const Text('Perfil do participante')),
      body: SafeArea(
          child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Center(
            child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            _SecaoPerfil(
                child: Column(children: [
              FotoPerfilArtistico(
                  enderecoFoto: widget.enderecoFoto,
                  tamanho: 104,
                  iconeFallback: pessoa.ehArtista ? Icons.mic : Icons.person),
              const SizedBox(height: 12),
              Text(pessoa.nome,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              Chip(
                  label: Text(pessoa.ehArtista
                      ? 'Artista · Anfitrião'
                      : 'Galera da resenha')),
              if (widget.enderecoFoto != null)
                const Text('Toque na foto para ampliar',
                    style: TextStyle(
                        fontSize: 12, color: CoresTocaEssa.textoSecundario)),
            ])),
            const SizedBox(height: 16),
            if (pessoa.ehArtista) ...[
              const _SecaoPerfil(
                  child: Text(
                      'Quem faz o som acontecer. As estatísticas da apresentação ficam no Painel do Artista.')),
            ] else if (!_nestaResenha) ...[
              _seletorPerfil(),
              const SizedBox(height: 16),
              const Text('Trajetória em todas as apresentações'),
              if (pessoa.estatisticasGerais != null)
                ProgressoDoPublico(dados: pessoa.estatisticasGerais!)
              else
                const Padding(padding: EdgeInsets.all(20),
                    child: Text('O perfil geral está indisponível no momento. Você pode consultar os dados desta resenha.')),
            ] else ...[
              _seletorPerfil(),
              const SizedBox(height: 16),
              const Text('Participação neste encontro'),
              const SizedBox(height: 12),
              LayoutBuilder(builder: (_, limites) {
                final colunas = limites.maxWidth >= 700 ? 4 : 2;
                return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      (
                        'Pedidos',
                        '${pessoa.pedidos}',
                        Icons.music_note_rounded
                      ),
                      (
                        'Tocados',
                        '${pessoa.pedidosTocados}',
                        Icons.check_circle_outline
                      ),
                      (
                        'Avaliações feitas',
                        '${notas.length}',
                        Icons.rate_review_outlined
                      ),
                      (
                        'Nota média dada',
                        pessoa.mediaAvaliacoes?.toStringAsFixed(1) ?? '—',
                        Icons.star_rounded
                      ),
                    ]
                        .map((item) => SizedBox(
                            width: (limites.maxWidth - 12 * (colunas - 1)) /
                                colunas,
                            child: _SecaoPerfil(
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                  Icon(item.$3, color: CoresTocaEssa.roxoClaro),
                                  const SizedBox(height: 8),
                                  Text(item.$2,
                                      style: Theme.of(context)
                                          .textTheme
                                          .headlineSmall),
                                  Text(item.$1),
                                ]))))
                        .toList());
              }),
              const SizedBox(height: 16),
              _SecaoPerfil(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                    const Text('Do pedido ao palco',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 10),
                    Text(pessoa.pedidos == 0
                        ? 'Ainda não fez pedidos nesta resenha.'
                        : '${(100 * pessoa.pedidosTocados / pessoa.pedidos).round()}% dos pedidos foram tocados'),
                    const SizedBox(height: 10),
                    LinearProgressIndicator(
                        value: pessoa.pedidos == 0
                            ? 0
                            : (pessoa.pedidosTocados / pessoa.pedidos)
                                .clamp(0, 1)),
                  ])),
              const SizedBox(height: 16),
              LayoutBuilder(builder: (context, limites) {
                final medalhas = _SecaoPerfil(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                      Text(
                          'Conquistas da resenha · ${conquistas.where((c) => c.$3 >= c.$4).length}/${conquistas.length}',
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 12),
                      LayoutBuilder(
                          builder: (_, espaco) => Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: conquistas
                                  .map((c) => SizedBox(
                                      width: (espaco.maxWidth - 8) / 2,
                                      child: _MedalhaResenha(
                                          titulo: c.$1,
                                          descricao: c.$2,
                                          atual: c.$3,
                                          meta: c.$4,
                                          icone: c.$5)))
                                  .toList())),
                      const SizedBox(height: 24),
                      Text('Mais pedidas aqui',
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 12),
                      FavoritasDoPerfil(musicas: pessoa.musicasMaisPedidas),
                    ]));
                final historico = _SecaoPerfil(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                      Text('Histórico de avaliações',
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 4),
                      const Text('Notas dadas às músicas desta resenha.'),
                      const SizedBox(height: 16),
                      if (notas.isEmpty)
                        const Text('Nenhuma avaliação por enquanto.'),
                      for (final nota in notas.skip(_pagina * 5).take(5)) ...[
                        ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.music_note_rounded,
                                color: CoresTocaEssa.roxoClaro),
                            title: Text(nota.musica),
                            subtitle:
                                Text(formatarData(nota.avaliadoEm.toLocal())),
                            trailing: Text('${nota.estrelas} ★',
                                style: const TextStyle(
                                    color: Color(0xFFFFC857),
                                    fontWeight: FontWeight.w600))),
                        const Divider(),
                      ],
                      if (notas.length > 5)
                        Row(children: [
                          IconButton(
                              tooltip: 'Página anterior',
                              onPressed: _pagina == 0
                                  ? null
                                  : () => setState(() => _pagina--),
                              icon: const Icon(Icons.chevron_left)),
                          Expanded(
                              child: Text(
                                  '${_pagina + 1} de ${(notas.length / 5).ceil()}',
                                  textAlign: TextAlign.center)),
                          IconButton(
                              tooltip: 'Próxima página',
                              onPressed: (_pagina + 1) * 5 >= notas.length
                                  ? null
                                  : () => setState(() => _pagina++),
                              icon: const Icon(Icons.chevron_right)),
                        ]),
                    ]));
                if (limites.maxWidth < 700) {
                  return Column(children: [
                    medalhas,
                    const SizedBox(height: 16),
                    historico
                  ]);
                }
                return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 2, child: medalhas),
                      const SizedBox(width: 16),
                      Expanded(flex: 3, child: historico),
                    ]);
              }),
            ],
          ]),
        )),
      )),
    );
  }
}

class _SecaoPerfil extends StatelessWidget {
  const _SecaoPerfil({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
            color: CoresTocaEssa.superficie,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: CoresTocaEssa.borda)),
        child: child,
      );
}

class _MedalhaResenha extends StatelessWidget {
  const _MedalhaResenha(
      {required this.titulo,
      required this.descricao,
      required this.atual,
      required this.meta,
      required this.icone});
  final String titulo, descricao;
  final int atual, meta;
  final IconData icone;
  @override
  Widget build(BuildContext context) {
    final liberada = atual >= meta;
    return Material(
      color: liberada ? const Color(0xFF302047) : CoresTocaEssa.fundo,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => showDialog<void>(
            context: context,
            builder: (context) => AlertDialog(
                    title: Text(titulo),
                    content: Text(
                        '$descricao\n\n${liberada ? 'Conquistada nesta resenha!' : '$atual de $meta'}'),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Entendi'))
                    ])),
        child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(children: [
              Icon(liberada ? icone : Icons.lock_outline,
                  color: liberada ? CoresTocaEssa.roxoClaro : Colors.grey),
              const SizedBox(height: 8),
              Text(titulo, textAlign: TextAlign.center),
              const SizedBox(height: 8),
              LinearProgressIndicator(value: (atual / meta).clamp(0, 1)),
            ])),
      ),
    );
  }
}
