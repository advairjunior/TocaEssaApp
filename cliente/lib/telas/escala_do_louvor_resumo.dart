part of 'escala_do_louvor.dart';

/// Topo da aba Hinos: o que falta ("1 sem letra", "2 partes sem escala") e
/// os pontos ("de 3 a 36"); um toque abre uma barra por cantor, para ver se
/// ficou equilibrado. Começa fechado, para os hinos aparecerem logo.
class _ResumoDaEscala extends StatefulWidget {
  const _ResumoDaEscala({
    required this.louvor,
    this.temOQueEscalar = false,
    this.escalarTodos,
    this.temEscala = false,
    this.limparEscala,
  });

  final LouvorDoArtista louvor;
  final bool temOQueEscalar;
  // "Escalar todos", discreto no cartão: depois de escalado, um botão cheio
  // no meio da tela só ocupava espaço.
  final VoidCallback? escalarTodos;
  // "Limpar escala" aparece quando alguma parte já tem alguém.
  final bool temEscala;
  final VoidCallback? limparEscala;

  @override
  State<_ResumoDaEscala> createState() => _ResumoDaEscalaState();
}

class _ResumoDaEscalaState extends State<_ResumoDaEscala> {
  bool _aberto = false;

  @override
  Widget build(BuildContext context) {
    final louvor = widget.louvor;
    final texto = Theme.of(context).textTheme;
    final hinos = louvor.hinos.length;
    final semLetra = louvor.hinos.where((hino) => !hino.temLetra).length;
    final semEscala = louvor.hinos
        .expand((hino) => hino.partes)
        .where((parte) => !parte.definida)
        .length;
    final situacao = [
      '$hinos ${hinos == 1 ? 'hino' : 'hinos'}',
      if (semLetra > 0) '$semLetra sem letra',
      if (semEscala > 0)
        '$semEscala ${semEscala == 1 ? 'parte' : 'partes'} sem escala',
      if (semLetra == 0 && semEscala == 0) 'tudo escalado',
    ].join(' · ');
    final pontos = {
      for (final item in louvor.placar) item.nome: item.pontos,
    };
    final valores = [
      for (final nome in louvor.cantores) pontos[nome] ?? 0,
    ];
    final menor = valores.fold<int?>(
        null, (menor, p) => menor == null || p < menor ? p : menor);
    final maximo = valores.fold<int>(0, (maior, p) => p > maior ? p : maior);
    final solos = [
      for (final item in louvor.placarDosSolos) '${item.nome} ${item.solos}',
    ];
    return Container(
      key: const ValueKey('resumo-da-escala'),
      padding: const EdgeInsets.all(EspacoTocaEssa.base),
      decoration: BoxDecoration(
        color: CoresTocaEssa.superficie,
        borderRadius: BorderRadius.circular(RaioTocaEssa.cartao),
        border: Border.all(color: CoresTocaEssa.borda),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(situacao,
              style: texto.bodyMedium?.copyWith(
                  color: semLetra + semEscala > 0
                      ? CoresTocaEssa.atencao
                      : CoresTocaEssa.sucesso)),
          if (widget.temOQueEscalar || widget.temEscala)
            Wrap(
              spacing: EspacoTocaEssa.pequeno,
              children: [
                if (widget.temOQueEscalar)
                  TextButton.icon(
                    onPressed: widget.escalarTodos,
                    icon: const Icon(Icons.auto_awesome_rounded, size: 18),
                    label: const Text('Escalar todos'),
                  ),
                if (widget.temEscala)
                  TextButton.icon(
                    onPressed: widget.limparEscala,
                    style: TextButton.styleFrom(
                        foregroundColor: CoresTocaEssa.rosa),
                    icon: const Icon(Icons.layers_clear_outlined, size: 18),
                    label: const Text('Limpar escala'),
                  ),
              ],
            ),
          if (menor != null)
            InkWell(
              onTap: () => setState(() => _aberto = !_aberto),
              borderRadius: BorderRadius.circular(RaioTocaEssa.campo),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: EspacoTocaEssa.mini),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        menor == maximo
                            ? 'Pontos: $menor cada'
                            : 'Pontos: de $menor a $maximo',
                        style: texto.bodySmall
                            ?.copyWith(color: CoresTocaEssa.textoSecundario),
                      ),
                    ),
                    Icon(
                      _aberto
                          ? Icons.expand_less_rounded
                          : Icons.expand_more_rounded,
                      color: CoresTocaEssa.textoSecundario,
                    ),
                  ],
                ),
              ),
            ),
          if (_aberto)
            for (final nome in louvor.cantores) ...[
              const SizedBox(height: EspacoTocaEssa.pequeno),
              Row(
                children: [
                  SizedBox(
                    width: 88,
                    child: Text(nome,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: texto.labelLarge?.copyWith(
                            color: corDoCantor(louvor.cantores, nome))),
                  ),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(RaioTocaEssa.pilula),
                      child: LinearProgressIndicator(
                        minHeight: 8,
                        value: maximo == 0 ? 0 : (pontos[nome] ?? 0) / maximo,
                        color: corDoCantor(louvor.cantores, nome),
                        backgroundColor: CoresTocaEssa.borda,
                      ),
                    ),
                  ),
                  const SizedBox(width: EspacoTocaEssa.medio),
                  SizedBox(
                    width: 44,
                    child: Text(
                      '${pontos[nome] ?? 0} ${pontos[nome] == 1 ? 'pt' : 'pts'}',
                      textAlign: TextAlign.right,
                      style: texto.labelMedium
                          ?.copyWith(color: CoresTocaEssa.textoSecundario),
                    ),
                  ),
                ],
              ),
            ],
          if (_aberto && solos.isNotEmpty) ...[
            const SizedBox(height: EspacoTocaEssa.pequeno),
            Text('Solos: ${solos.join(' · ')}',
                style: texto.labelMedium?.copyWith(color: corInstrumental)),
          ],
        ],
      ),
    );
  }
}

/// Legenda da cor de uma pessoa nos filtros e na aba Pessoas.
class _Bolinha extends StatelessWidget {
  const _Bolinha(this.cor);

  final Color cor;

  @override
  Widget build(BuildContext context) => Center(
        widthFactor: 1,
        child: Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: cor, shape: BoxShape.circle),
        ),
      );
}
