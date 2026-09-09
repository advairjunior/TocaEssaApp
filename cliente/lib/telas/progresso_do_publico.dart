import 'package:flutter/material.dart';
import '../dominio/modelos.dart';
import '../dominio/progresso_publico.dart';
import '../tema/tema_toca_essa.dart';

class ProgressoDoPublico extends StatelessWidget {
  const ProgressoDoPublico({super.key, required this.dados});
  final EstatisticasDoPublico dados;

  @override
  Widget build(BuildContext context) {
    final progresso = ProgressoPublico(dados);
    final conquistas = ConquistaPublico.deEstatisticas(dados);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const SizedBox(height: 20),
      Row(children: [
        const Icon(Icons.auto_awesome_rounded, color: CoresTocaEssa.roxoClaro),
        const SizedBox(width: 10),
        Expanded(
            child: Text(progresso.titulo,
                style: Theme.of(context).textTheme.titleMedium)),
        Text('Nível ${progresso.nivel}'),
      ]),
      const SizedBox(height: 12),
      TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: progresso.fracao),
        duration: const Duration(milliseconds: 450),
        builder: (_, valor, __) => LinearProgressIndicator(
            value: valor,
            minHeight: 8,
            borderRadius: BorderRadius.circular(12)),
      ),
      const SizedBox(height: 8),
      Text(
          progresso.proximo == null
              ? '${progresso.xp} XP · Nível máximo alcançado'
              : '${progresso.xp} XP · Faltam ${progresso.proximo! - progresso.xp} para o próximo nível',
          style: Theme.of(context).textTheme.bodySmall),
      const SizedBox(height: 20),
      LayoutBuilder(
          builder: (context, limites) => Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  (
                    'Pedidos feitos',
                    '${dados.pedidos}',
                    Icons.music_note_rounded
                  ),
                  (
                    'Músicas tocadas',
                    '${dados.pedidosTocados}',
                    Icons.check_circle_outline
                  ),
                  (
                    'Nota média dada',
                    dados.mediaAvaliacoes?.toStringAsFixed(1) ?? '—',
                    Icons.star_outline_rounded
                  ),
                  (
                    'Participações',
                    '${dados.participacoes}',
                    Icons.celebration_outlined
                  ),
                ]
                    .map((item) => SizedBox(
                          width: (limites.maxWidth - 10) / 2,
                          child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                  color: CoresTocaEssa.fundo,
                                  borderRadius: BorderRadius.circular(16)),
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(item.$3,
                                        color: CoresTocaEssa.roxoClaro,
                                        size: 22),
                                    const SizedBox(height: 8),
                                    Text(item.$2,
                                        style: Theme.of(context)
                                            .textTheme
                                            .headlineSmall),
                                    Text(item.$1,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall),
                                  ])),
                        ))
                    .toList(),
              )),
      const SizedBox(height: 12),
      Text(
          dados.pedidos == 0
              ? 'Seu histórico musical começa com o primeiro pedido.'
              : '${(dados.pedidosTocados / dados.pedidos * 100).round()}% dos seus pedidos foram tocados.',
          style: Theme.of(context).textTheme.bodySmall),
      const SizedBox(height: 24),
      Text('Músicas favoritas', style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 12),
      FavoritasDoPerfil(musicas: dados.musicasMaisPedidas),
      const SizedBox(height: 24),
      Text('Conquistas', style: Theme.of(context).textTheme.titleMedium),
      Text(
          '${conquistas.where((c) => c.desbloqueada).length} de ${conquistas.length} desbloqueadas',
          style: Theme.of(context).textTheme.bodySmall),
      const SizedBox(height: 12),
      LayoutBuilder(
          builder: (context, limites) => Wrap(
                spacing: 10,
                runSpacing: 10,
                children: conquistas
                    .map((conquista) => SizedBox(
                          width: (limites.maxWidth - 10) / 2,
                          child: _Medalha(conquista: conquista),
                        ))
                    .toList(),
              )),
    ]);
  }
}

class FavoritasDoPerfil extends StatelessWidget {
  const FavoritasDoPerfil({super.key, required this.musicas});
  final List<MusicaMaisPedida> musicas;
  @override
  Widget build(BuildContext context) {
    final ordenadas = [...musicas]
      ..sort((a, b) => b.quantidade.compareTo(a.quantidade));
    if (ordenadas.isEmpty) {
      return const Text('Suas músicas mais pedidas aparecerão aqui.');
    }
    final maior = ordenadas.first.quantidade;
    return Column(
        children: ordenadas
            .take(5)
            .map((musica) => Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Column(children: [
                    Row(children: [
                      Expanded(
                          child: Text(musica.musica,
                              maxLines: 2, overflow: TextOverflow.ellipsis)),
                      const SizedBox(width: 10),
                      Text('${musica.quantidade}×'),
                    ]),
                    const SizedBox(height: 7),
                    LinearProgressIndicator(
                        value: maior == 0 ? 0 : musica.quantidade / maior,
                        minHeight: 4,
                        borderRadius: BorderRadius.circular(8)),
                  ]),
                ))
            .toList());
  }
}

class _Medalha extends StatelessWidget {
  const _Medalha({required this.conquista});
  final ConquistaPublico conquista;
  @override
  Widget build(BuildContext context) => Card(
        margin: EdgeInsets.zero,
        color: conquista.desbloqueada
            ? const Color(0xFF2C1B45)
            : CoresTocaEssa.fundo,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
                color: conquista.desbloqueada
                    ? CoresTocaEssa.roxoClaro
                    : CoresTocaEssa.borda)),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => showDialog<void>(
              context: context,
              builder: (context) => AlertDialog(
                    title: Text(conquista.titulo),
                    content: Text(
                        '${conquista.descricao}\n\n${conquista.desbloqueada ? 'Conquistada!' : '${conquista.atual} de ${conquista.meta}'}'),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Entendi'))
                    ],
                  )),
          child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                        conquista.desbloqueada
                            ? Icons.emoji_events_rounded
                            : Icons.lock_outline,
                        color: conquista.desbloqueada
                            ? const Color(0xFFFFC857)
                            : CoresTocaEssa.textoSecundario),
                    const SizedBox(height: 8),
                    Text(conquista.titulo,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(value: conquista.fracao),
                    const SizedBox(height: 5),
                    Text(
                        conquista.desbloqueada
                            ? 'Conquistada'
                            : '${conquista.atual}/${conquista.meta}',
                        style: Theme.of(context).textTheme.bodySmall),
                  ])),
        ),
      );
}
