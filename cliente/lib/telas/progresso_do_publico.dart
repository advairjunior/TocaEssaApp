import 'package:flutter/material.dart';
import '../dominio/modelos.dart';
import '../dominio/progresso_publico.dart';
import '../tema/tema_toca_essa.dart';
import 'componentes_lista.dart';

/// Superfície padrão dos blocos do perfil.
BoxDecoration _superficie({Color borda = CoresTocaEssa.borda}) => BoxDecoration(
      color: CoresTocaEssa.superficie,
      borderRadius: BorderRadius.circular(RaioTocaEssa.cartao),
      border: Border.all(color: borda),
    );

class ProgressoDoPublico extends StatelessWidget {
  const ProgressoDoPublico({super.key, required this.dados});
  final EstatisticasDoPublico dados;

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    final secundario =
        texto.bodySmall?.copyWith(color: CoresTocaEssa.textoSecundario);
    final progresso = ProgressoPublico(dados);
    final conquistas = ConquistaPublico.deEstatisticas(dados);
    final desbloqueadas = conquistas.where((c) => c.desbloqueada).length;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const SizedBox(height: 20),
      Container(
        padding: const EdgeInsets.all(EspacoTocaEssa.base),
        decoration: _superficie(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              const Icon(Icons.auto_awesome_rounded,
                  color: CoresTocaEssa.roxoClaro),
              const SizedBox(width: EspacoTocaEssa.medio),
              Expanded(
                child: Text(progresso.titulo,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: texto.titleMedium),
              ),
              const SizedBox(width: EspacoTocaEssa.pequeno),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: EspacoTocaEssa.medio,
                    vertical: EspacoTocaEssa.mini),
                decoration: BoxDecoration(
                  color: CoresTocaEssa.roxoClaro.withValues(alpha: .16),
                  borderRadius: BorderRadius.circular(RaioTocaEssa.pilula),
                ),
                child: Text('Nível ${progresso.nivel}',
                    style: texto.labelMedium
                        ?.copyWith(color: CoresTocaEssa.roxoClaro)),
              ),
            ]),
            const SizedBox(height: EspacoTocaEssa.medio),
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: progresso.fracao),
              duration: const Duration(milliseconds: 450),
              builder: (_, valor, __) => LinearProgressIndicator(
                  value: valor,
                  minHeight: 8,
                  borderRadius: BorderRadius.circular(12)),
            ),
            const SizedBox(height: EspacoTocaEssa.pequeno),
            Text(
                progresso.proximo == null
                    ? '${progresso.xp} XP · Nível máximo alcançado'
                    : '${progresso.xp} XP · Faltam ${progresso.proximo! - progresso.xp} para o próximo nível',
                style: secundario),
          ],
        ),
      ),
      const SizedBox(height: EspacoTocaEssa.medio),
      Container(
        padding: const EdgeInsets.symmetric(vertical: EspacoTocaEssa.base),
        decoration: _superficie(),
        child: IntrinsicHeight(
          child: Row(children: [
            _NumeroDoPerfil(valor: '${dados.pedidos}', rotulo: 'pedidos'),
            const VerticalDivider(width: 1),
            _NumeroDoPerfil(
                valor: '${dados.pedidosTocados}', rotulo: 'tocados'),
            const VerticalDivider(width: 1),
            _NumeroDoPerfil(
                valor: dados.mediaAvaliacoes
                        ?.toStringAsFixed(1)
                        .replaceAll('.', ',') ??
                    '—',
                rotulo: 'nota média'),
            const VerticalDivider(width: 1),
            _NumeroDoPerfil(
                valor: '${dados.participacoes}', rotulo: 'participações'),
          ]),
        ),
      ),
      const SizedBox(height: EspacoTocaEssa.pequeno),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: EspacoTocaEssa.mini),
        child: Text(
            dados.pedidos == 0
                ? 'Seu histórico musical começa com o primeiro pedido.'
                : '${(dados.pedidosTocados / dados.pedidos * 100).round()}% dos seus pedidos foram tocados.',
            style: secundario),
      ),
      const SizedBox(height: EspacoTocaEssa.grande),
      const TituloGrupo('Músicas favoritas'),
      Container(
        padding: const EdgeInsets.fromLTRB(EspacoTocaEssa.base,
            EspacoTocaEssa.base, EspacoTocaEssa.base, EspacoTocaEssa.mini),
        decoration: _superficie(),
        child: FavoritasDoPerfil(musicas: dados.musicasMaisPedidas),
      ),
      const SizedBox(height: EspacoTocaEssa.grande),
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Expanded(child: TituloGrupo('Conquistas')),
        Padding(
          padding: const EdgeInsets.only(right: EspacoTocaEssa.mini),
          child: Text('$desbloqueadas de ${conquistas.length}',
              style: texto.labelMedium
                  ?.copyWith(color: CoresTocaEssa.textoSecundario)),
        ),
      ]),
      LayoutBuilder(
          builder: (context, limites) => Wrap(
                spacing: EspacoTocaEssa.pequeno,
                runSpacing: EspacoTocaEssa.pequeno,
                children: conquistas
                    .map((conquista) => SizedBox(
                          width:
                              (limites.maxWidth - EspacoTocaEssa.pequeno) / 2,
                          child: _Medalha(conquista: conquista),
                        ))
                    .toList(),
              )),
    ]);
  }
}

class _NumeroDoPerfil extends StatelessWidget {
  const _NumeroDoPerfil({required this.valor, required this.rotulo});

  final String valor;
  final String rotulo;

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    return Expanded(
      child: Column(children: [
        FittedBox(
            fit: BoxFit.scaleDown, child: Text(valor, style: texto.titleLarge)),
        const SizedBox(height: 2),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: EspacoTocaEssa.mini),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              rotulo,
              maxLines: 1,
              style: texto.labelMedium
                  ?.copyWith(color: CoresTocaEssa.textoSecundario),
            ),
          ),
        ),
      ]),
    );
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
      return const Padding(
        padding: EdgeInsets.only(bottom: EspacoTocaEssa.medio),
        child: Text('Suas músicas mais pedidas aparecerão aqui.',
            style: TextStyle(color: CoresTocaEssa.textoSecundario)),
      );
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
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    final ganha = conquista.desbloqueada;
    return Material(
      color: CoresTocaEssa.superficie,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(RaioTocaEssa.cartao),
        side: BorderSide(
            color: ganha
                ? CoresTocaEssa.ouro.withValues(alpha: .45)
                : CoresTocaEssa.borda),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(RaioTocaEssa.cartao),
        onTap: () => showDialog<void>(
            context: context,
            builder: (context) => AlertDialog(
                  title: Text(conquista.titulo),
                  content: Text(
                      '${conquista.descricao}\n\n${ganha ? 'Conquistada!' : '${conquista.atual} de ${conquista.meta}'}'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Entendi'))
                  ],
                )),
        child: Padding(
          padding: const EdgeInsets.all(EspacoTocaEssa.medio),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: ganha
                      ? CoresTocaEssa.ouro.withValues(alpha: .14)
                      : CoresTocaEssa.borda.withValues(alpha: .5),
                ),
                child: Icon(
                    ganha ? Icons.emoji_events_rounded : Icons.lock_outline,
                    size: 20,
                    color: ganha
                        ? CoresTocaEssa.ouro
                        : CoresTocaEssa.textoSecundario),
              ),
              const SizedBox(height: EspacoTocaEssa.pequeno),
              Text(conquista.titulo,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: texto.titleSmall?.copyWith(
                      color: ganha ? null : CoresTocaEssa.textoSecundario)),
              const SizedBox(height: EspacoTocaEssa.pequeno),
              if (ganha)
                Text('Conquistada',
                    style:
                        texto.labelMedium?.copyWith(color: CoresTocaEssa.ouro))
              else ...[
                LinearProgressIndicator(
                    value: conquista.fracao,
                    minHeight: 4,
                    borderRadius: BorderRadius.circular(8)),
                const SizedBox(height: EspacoTocaEssa.mini + 1),
                Text('${conquista.atual}/${conquista.meta}',
                    style: texto.labelMedium
                        ?.copyWith(color: CoresTocaEssa.textoSecundario)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
