part of 'escala_do_louvor.dart';

/// "João · Ana · solo José · 1 sem escala": quem participa do hino.
String _resumoDoHino(HinoDoLouvor hino) {
  final nomes = <String>[];
  for (final parte in hino.partes) {
    for (final nome in parte.cantores) {
      final rotulo =
          parte.tipo == TipoDaParte.instrumental ? 'solo $nome' : nome;
      if (!nomes.contains(rotulo)) nomes.add(rotulo);
    }
  }
  final semEscala = hino.partes.where((parte) => !parte.definida).length;
  return [
    ...nomes,
    if (semEscala > 0) '$semEscala sem escala',
    if (nomes.isEmpty && semEscala == 0) 'Todos',
  ].join(' · ');
}

class _CartaoDoHino extends StatelessWidget {
  const _CartaoDoHino({
    required this.ordem,
    required this.hino,
    required this.cantores,
    required this.filtro,
    required this.aberto,
    required this.ehAgora,
    required this.alternar,
    required this.escolherParte,
    required this.colarLetra,
    required this.escalar,
  });

  final int ordem;
  final HinoDoLouvor hino;
  // Para a cor de cada cantor, a mesma do roteiro.
  final List<String> cantores;
  final String? filtro;
  final bool aberto;
  final bool ehAgora;
  final VoidCallback alternar;
  final void Function(int indice, String rotulo)? escolherParte;
  final VoidCallback? colarLetra;
  final VoidCallback? escalar;

  Color _corDa(ParteDoHino parte) => switch (parte) {
        ParteDoHino(tipo: TipoDaParte.instrumental) => corInstrumental,
        ParteDoHino(definida: false) => CoresTocaEssa.borda,
        ParteDoHino(deTodos: true) => CoresTocaEssa.textoSecundario,
        _ => corDoCantor(cantores, parte.cantores.first),
      };

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    final rotulos = rotulosDasPartes(hino);
    final daPessoa = filtro == null
        ? const <String>[]
        : [
            for (final (indice, parte) in hino.partes.indexed)
              if (parte.cantores.contains(filtro)) rotulos[indice],
          ];
    return Opacity(
      // Hino já cantado fica apagado.
      opacity: hino.tocado && !ehAgora ? .55 : 1,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: CoresTocaEssa.superficie,
          borderRadius: BorderRadius.circular(RaioTocaEssa.cartao),
          border: Border.all(
              color: ehAgora ? CoresTocaEssa.sucesso : CoresTocaEssa.borda,
              width: ehAgora ? 2 : 1),
        ),
        child: Material(
          color: Colors.transparent,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              InkWell(
                onTap: alternar,
                child: Padding(
                  padding: const EdgeInsets.all(EspacoTocaEssa.base),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            alignment: Alignment.center,
                            decoration: const BoxDecoration(
                              color: CoresTocaEssa.destaqueFundo,
                              shape: BoxShape.circle,
                            ),
                            child: Text('$ordem',
                                style: texto.titleSmall
                                    ?.copyWith(color: CoresTocaEssa.roxoClaro)),
                          ),
                          const SizedBox(width: EspacoTocaEssa.medio),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(hino.titulo, style: texto.titleMedium),
                                if (hino.partes.isNotEmpty)
                                  Text(
                                    _resumoDoHino(hino),
                                    style: texto.bodySmall?.copyWith(
                                        color: CoresTocaEssa.textoSecundario),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(width: EspacoTocaEssa.pequeno),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              if (hino.tom case final tom?)
                                Text('Tom $tom',
                                    style: texto.labelLarge?.copyWith(
                                        color: CoresTocaEssa.roxoClaro)),
                              if (ehAgora)
                                Text('Agora',
                                    style: texto.labelMedium?.copyWith(
                                        color: CoresTocaEssa.sucesso)),
                            ],
                          ),
                          Icon(
                            aberto
                                ? Icons.expand_less_rounded
                                : Icons.expand_more_rounded,
                            color: CoresTocaEssa.textoSecundario,
                          ),
                        ],
                      ),
                      if (hino.partes.isNotEmpty) ...[
                        const SizedBox(height: EspacoTocaEssa.pequeno),
                        // Faixa com um pedaço por parte, na cor de quem
                        // canta: a ordem das vozes do hino de relance.
                        Padding(
                          padding: const EdgeInsets.only(left: 44),
                          child: Row(
                            key: ValueKey('faixa-${hino.itemId}'),
                            children: [
                              for (final (indice, parte) in hino.partes.indexed)
                                Expanded(
                                  child: Container(
                                    height: 6,
                                    margin: EdgeInsets.only(
                                        left: indice == 0 ? 0 : 2),
                                    decoration: BoxDecoration(
                                      color: _corDa(parte),
                                      borderRadius: BorderRadius.circular(
                                          RaioTocaEssa.pilula),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                      if (daPessoa.isNotEmpty) ...[
                        const SizedBox(height: EspacoTocaEssa.pequeno),
                        Padding(
                          padding: const EdgeInsets.only(left: 44),
                          child: Text('$filtro: ${daPessoa.join(', ')}',
                              style: texto.bodySmall
                                  ?.copyWith(color: CoresTocaEssa.ouro)),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              if (!hino.temLetra)
                ListTile(
                  leading: const Icon(Icons.warning_amber_rounded,
                      color: CoresTocaEssa.atencao),
                  title: const Text('Sem letra'),
                  trailing: TextButton(
                    onPressed: colarLetra,
                    child: const Text('Colar letra'),
                  ),
                ),
              if (aberto && hino.partes.isNotEmpty) ...[
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.fromLTRB(EspacoTocaEssa.base,
                      EspacoTocaEssa.medio, EspacoTocaEssa.base, 0),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: FilledButton.tonalIcon(
                      onPressed: escalar,
                      icon: const Icon(Icons.auto_awesome_rounded, size: 18),
                      label: const Text('Escalar automático'),
                    ),
                  ),
                ),
                for (final (indice, parte) in hino.partes.indexed)
                  ListTile(
                    dense: true,
                    tileColor: filtro != null && parte.cantores.contains(filtro)
                        ? CoresTocaEssa.destaqueFundo
                        : null,
                    onTap: escolherParte == null
                        ? null
                        : () => escolherParte!(indice, rotulos[indice]),
                    leading: Container(
                      width: 4,
                      height: 32,
                      decoration: BoxDecoration(
                        color: _corDa(parte),
                        borderRadius:
                            BorderRadius.circular(RaioTocaEssa.pilula),
                      ),
                    ),
                    minLeadingWidth: 4,
                    title: Text(rotulos[indice]),
                    subtitle: Text(
                      // A primeira linha da letra, não a dos acordes.
                      parte.texto
                              .split('\n')
                              .where((linha) =>
                                  linha.trim().isNotEmpty &&
                                  !linhaDeAcordes(linha))
                              .firstOrNull ??
                          '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          switch (parte) {
                            ParteDoHino(definida: false) => '—',
                            ParteDoHino(
                              tipo: TipoDaParte.instrumental,
                              deTodos: true
                            ) =>
                              'Banda',
                            _ => parte.quemCanta,
                          },
                          // Na cor de quem canta, a mesma da faixa do roteiro.
                          style: texto.labelLarge?.copyWith(
                            color: parte.definida && !parte.deTodos
                                ? _corDa(parte)
                                : CoresTocaEssa.textoSecundario,
                          ),
                        ),
                        const Icon(Icons.chevron_right_rounded,
                            color: CoresTocaEssa.textoSecundario),
                      ],
                    ),
                  ),
                const SizedBox(height: EspacoTocaEssa.pequeno),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Topo da aba Hinos: o que falta ("1 sem letra", "2 partes sem escala") e
/// os pontos ("de 3 a 36"); um toque abre uma barra por cantor, para ver se
/// ficou equilibrado. Começa fechado, para os hinos aparecerem logo.
class _ResumoDaEscala extends StatefulWidget {
  const _ResumoDaEscala({required this.louvor});

  final LouvorDoArtista louvor;

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
