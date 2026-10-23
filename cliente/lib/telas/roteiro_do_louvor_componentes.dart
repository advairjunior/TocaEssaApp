part of 'roteiro_do_louvor.dart';

/// Cada pessoa num botão grande na cor da sua faixa, para ela já se achar
/// pela cor na letra.
class _EscolhaDeQuemSou extends StatelessWidget {
  const _EscolhaDeQuemSou({
    required this.participantes,
    required this.cantores,
    required this.escolher,
  });

  final List<String> participantes;
  final List<String> cantores;
  final ValueChanged<String> escolher;

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    return ConteudoMobile(
      filho: Column(
        children: [
          const SizedBox(height: EspacoTocaEssa.enorme),
          const Icon(Icons.mic_none_rounded,
              size: 40, color: CoresTocaEssa.roxoClaro),
          const SizedBox(height: EspacoTocaEssa.base),
          Text('Quem é você?', style: texto.headlineSmall),
          const SizedBox(height: EspacoTocaEssa.pequeno),
          Text(
            'Suas partes ficam em destaque na letra, na sua cor.',
            textAlign: TextAlign.center,
            style: texto.bodyMedium
                ?.copyWith(color: CoresTocaEssa.textoSecundario),
          ),
          const SizedBox(height: EspacoTocaEssa.grande),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: EspacoTocaEssa.pequeno,
            runSpacing: EspacoTocaEssa.pequeno,
            children: [
              for (final nome in participantes)
                _BotaoDaPessoa(
                  nome: nome,
                  cor: corDaPessoa(participantes, nome),
                  escolher: () => escolher(nome),
                ),
            ],
          ),
          const SizedBox(height: EspacoTocaEssa.base),
          TextButton(
            onPressed: () => escolher(''),
            child: const Text('Só acompanhar'),
          ),
        ],
      ),
    );
  }
}

class _BotaoDaPessoa extends StatelessWidget {
  const _BotaoDaPessoa({
    required this.nome,
    required this.cor,
    required this.escolher,
  });

  final String nome;
  final Color cor;
  final VoidCallback escolher;

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
        onPressed: escolher,
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(120, 52),
          backgroundColor: cor.withValues(alpha: .12),
          side: BorderSide(color: cor.withValues(alpha: .7), width: 1.5),
        ),
        icon: Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: cor, shape: BoxShape.circle),
        ),
        label: Text(nome,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(color: cor, fontWeight: FontWeight.w700)),
      );
}

/// Topo do hino, que rola junto com a letra: título com o "Agora", o tom
/// (com os acordes ligados no topo, o controle b Tom #) e as partes da pessoa.
class _CabecalhoDoHino extends StatelessWidget {
  const _CabecalhoDoHino({
    required this.hino,
    required this.ehAgora,
    required this.quemSou,
    required this.noCoral,
    required this.acordes,
    required this.tom,
    required this.semitons,
    required this.mudarTom,
  });

  final HinoDoLouvor hino;
  final bool ehAgora;
  final String quemSou;
  // "Refrão e Estrofe 2": onde a pessoa canta no coral.
  final String? noCoral;
  final bool acordes;
  final String? tom;
  final int semitons;
  final ValueChanged<int> mudarTom;

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    final microfone =
        quemSou.isEmpty ? null : partesNoMicrofone(hino, quemSou);
    final toca = quemSou.isEmpty ? null : partesTocadas(hino, quemSou);
    final estilo = texto.bodyMedium?.copyWith(color: CoresTocaEssa.ouro);
    final papeis = [
      if (microfone != null)
        _LinhaDoPapel(
            key: const ValueKey('cabecalho-microfone'),
            icone: iconeDoMicrofone,
            texto: 'Suas partes: $microfone',
            cor: CoresTocaEssa.ouro,
            estilo: estilo),
      if (toca != null)
        _LinhaDoPapel(
            key: const ValueKey('cabecalho-toca'),
            icone: iconeDoSolo,
            texto: 'Você toca: $toca',
            cor: CoresTocaEssa.ouro,
            estilo: estilo),
      if (noCoral != null)
        _LinhaDoPapel(
            key: const ValueKey('cabecalho-coral'),
            icone: iconeDoCoral,
            texto: 'No coral: $noCoral',
            cor: CoresTocaEssa.ouro,
            estilo: estilo),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          key: const ValueKey('titulo-do-hino'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: Text(hino.titulo, style: texto.headlineSmall)),
            if (ehAgora) ...[
              const SizedBox(width: EspacoTocaEssa.pequeno),
              const _Selo(texto: 'Agora', cor: CoresTocaEssa.sucesso),
            ],
          ],
        ),
        const SizedBox(height: EspacoTocaEssa.pequeno),
        // O tom só muda para quem toca, com os acordes ligados.
        if (acordes)
          ControleDoTom(
            tom: tom ?? 'Tom',
            original: hino.tom,
            semitons: semitons,
            mudarTom: mudarTom,
          )
        else if (tom != null)
          _Selo(texto: tom!, cor: CoresTocaEssa.roxoClaro),
        for (final (indice, papel) in papeis.indexed) ...[
          SizedBox(
              height: indice == 0 ? EspacoTocaEssa.medio : EspacoTocaEssa.mini),
          papel,
        ],
        const SizedBox(height: EspacoTocaEssa.pequeno),
        if (!hino.temLetra) ...[
          const SizedBox(height: EspacoTocaEssa.grande),
          Text(
            'A letra deste hino ainda não foi colada.',
            style:
                texto.bodyLarge?.copyWith(color: CoresTocaEssa.textoSecundario),
          ),
        ],
      ],
    );
  }
}

// Os mesmos ícones no topo do hino e em Meus hinos: onde a pessoa fica no
// microfone, no coral e nos solos. Ícones do app, não emoji: o emoji
// depende de baixar uma fonte na hora, e a internet do encontro é fraca.
const iconeDoMicrofone = Icons.mic_rounded;
const iconeDoCoral = Icons.groups_rounded;
const iconeDoSolo = Icons.piano_rounded;

/// Um papel da pessoa no hino: o ícone e as partes dela.
class _LinhaDoPapel extends StatelessWidget {
  const _LinhaDoPapel({
    super.key,
    required this.icone,
    required this.texto,
    required this.cor,
    this.estilo,
  });

  final IconData icone;
  final String texto;
  final Color cor;
  final TextStyle? estilo;

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(icone, size: 18, color: cor),
          ),
          const SizedBox(width: EspacoTocaEssa.pequeno),
          Expanded(child: Text(texto, style: estilo)),
        ],
      );
}

class _Selo extends StatelessWidget {
  const _Selo({required this.texto, required this.cor});

  final String texto;
  final Color cor;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(
            horizontal: EspacoTocaEssa.medio, vertical: EspacoTocaEssa.mini),
        decoration: BoxDecoration(
          color: cor.withValues(alpha: .14),
          borderRadius: BorderRadius.circular(RaioTocaEssa.pilula),
          border: Border.all(color: cor.withValues(alpha: .5)),
        ),
        child: Text(texto,
            style:
                Theme.of(context).textTheme.labelLarge?.copyWith(color: cor)),
      );
}

class _BarraDosHinos extends StatelessWidget {
  const _BarraDosHinos({
    required this.anterior,
    required this.proximo,
    required this.voltarAoAgora,
    required this.depois,
    required this.suaVezDepois,
  });

  final VoidCallback? anterior;
  final VoidCallback? proximo;
  final VoidCallback? voltarAoAgora;
  final String? depois;
  // As partes de quem está com o telefone no próximo hino, para se preparar.
  final String? suaVezDepois;

  @override
  Widget build(BuildContext context) => Container(
        decoration: const BoxDecoration(
          color: CoresTocaEssa.superficie,
          border: Border(top: BorderSide(color: CoresTocaEssa.borda)),
        ),
        padding: const EdgeInsets.symmetric(
            horizontal: EspacoTocaEssa.pequeno, vertical: EspacoTocaEssa.mini),
        child: Row(
          children: [
            IconButton(
              tooltip: 'Hino anterior',
              iconSize: 32,
              icon: const Icon(Icons.chevron_left_rounded),
              onPressed: anterior,
            ),
            Expanded(
              child: voltarAoAgora != null
                  ? TextButton(
                      onPressed: voltarAoAgora,
                      child: const Text('Voltar ao hino de agora'),
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          depois == null ? 'Último hino' : 'Depois: $depois',
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: CoresTocaEssa.textoSecundario),
                        ),
                        if (suaVezDepois case final partes?)
                          Text(
                            'sua vez: $partes',
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .labelMedium
                                ?.copyWith(color: CoresTocaEssa.ouro),
                          ),
                      ],
                    ),
            ),
            IconButton(
              tooltip: 'Próximo hino',
              iconSize: 32,
              icon: const Icon(Icons.chevron_right_rounded),
              onPressed: proximo,
            ),
          ],
        ),
      );
}
