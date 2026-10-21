import 'package:flutter/material.dart';

import '../dominio/modelos.dart';
import '../dominio/transpor_cifra.dart';
import '../infraestrutura/api_toca_essa.dart';
import '../tema/tema_toca_essa.dart';
import 'como_marcar_hinos.dart';
import 'componentes.dart';
import 'componentes_lista.dart';
import 'editor_de_cifra.dart';
import 'trechos_do_louvor.dart';

enum _AbaDaEscala { hinos, pessoas }

/// Escala do louvor, vista pelo artista. Na aba Hinos, cada hino é um cartão
/// fechado com a ordem, o tom e o resumo de quem participa; tocar abre as
/// partes, o botão "Escalar automático" e a troca à mão. "Ver por pessoa"
/// destaca as partes de alguém. Na aba Pessoas ficam cantores, solistas e o
/// sumário das marcações.
class EscalaDoLouvor extends StatefulWidget {
  const EscalaDoLouvor({
    super.key,
    required this.api,
    required this.apresentacao,
    this.pedirLetra,
  });

  final ApiTocaEssa api;
  final Apresentacao apresentacao;

  /// Tela de colar a letra; responde o texto ou nulo se cancelar.
  final Future<String?> Function(String titulo)? pedirLetra;

  @override
  State<EscalaDoLouvor> createState() => _EscalaDoLouvorState();
}

class _EscalaDoLouvorState extends State<EscalaDoLouvor> {
  LouvorDoArtista? _louvor;
  Object? _erro;
  bool _salvando = false;
  // Sem ninguém cadastrado, começa em Pessoas.
  _AbaDaEscala? _aba;
  final _abertos = <String>{};
  String? _filtro;

  String get _id => widget.apresentacao.id;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    try {
      final louvor = await widget.api.obterLouvor(_id);
      if (mounted) {
        setState(() {
          _louvor = louvor;
          _aba ??= louvor.participantes.isEmpty
              ? _AbaDaEscala.pessoas
              : _AbaDaEscala.hinos;
        });
      }
    } catch (erro) {
      if (mounted) setState(() => _erro = erro);
    }
  }

  Future<void> _salvar(Future<LouvorDoArtista> Function() acao) async {
    setState(() => _salvando = true);
    try {
      final louvor = await acao();
      if (mounted) setState(() => _louvor = louvor);
    } catch (erro) {
      if (mounted) mostrarErro(context, erro);
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  Future<void> _definirCantores(List<String> nomes) =>
      _salvar(() => widget.api.definirCantoresDoLouvor(_id, nomes));

  Future<void> _adicionarCantor() async {
    final nome = await showDialog<String>(
      context: context,
      builder: (_) => const _NovoCantor(),
    );
    final limpo = nome?.trim() ?? '';
    if (limpo.isEmpty) return;
    await _definirCantores([..._louvor!.cantores, limpo]);
  }

  Future<void> _definirSolistas(List<Solista> solistas) =>
      _salvar(() => widget.api.definirSolistasDoLouvor(_id, solistas));

  Future<void> _adicionarSolista() async {
    final solista = await showDialog<Solista>(
      context: context,
      builder: (_) => const _NovoSolista(),
    );
    if (solista == null || solista.nome.trim().isEmpty) return;
    await _definirSolistas([..._louvor!.solistas, solista]);
  }

  Future<void> _definirConfiguracao(ConfiguracaoDaEscala configuracao) =>
      _salvar(() => widget.api.definirConfiguracaoDoLouvor(_id, configuracao));

  Future<void> _escolherParte(
      HinoDoLouvor hino, int indice, String rotulo) async {
    final parte = hino.partes[indice];
    // No solo, quem toca; sem solistas cadastrados, todo mundo.
    final nomes = parte.tipo == TipoDaParte.instrumental
        ? (_louvor!.solistas.isEmpty
            ? _louvor!.participantes
            : [for (final solista in _louvor!.solistas) solista.nome])
        : _louvor!.cantores;
    final escolha = await showModalBottomSheet<_Escolha>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => _EscolhaDaParte(
        titulo: '$rotulo · ${hino.titulo}',
        cantores: nomes,
        atuais: parte.cantores,
      ),
    );
    if (escolha == null) return;
    await _salvar(() => widget.api
        .escolherParteDoLouvor(_id, hino.itemId, indice, escolha.cantores));
  }

  /// Refaz a escala dos hinos marcados na confirmação (todos, de início);
  /// confirma porque apaga as trocas feitas à mão neles.
  Future<void> _escalarTodos() async {
    final itens = await showDialog<List<String>>(
      context: context,
      builder: (_) => _HinosAEscalar(
        hinos: [
          for (final hino in _louvor!.hinos)
            if (hino.partes.isNotEmpty) hino,
        ],
      ),
    );
    if (itens == null || itens.isEmpty) return;
    await _salvar(
        () => widget.api.escalarTodosOsHinosDoLouvor(_id, itens: itens));
  }

  Future<void> _colarLetra(HinoDoLouvor hino) async {
    final texto = await (widget.pedirLetra?.call(hino.titulo) ??
        pedirCifraEmTexto(context, titulo: hino.titulo, oQue: 'Letra'));
    if (texto == null || texto.trim().isEmpty) return;
    await _salvar(() async {
      await widget.api.salvarCifraEmTexto(hino.titulo, hino.artista, texto);
      return widget.api.obterLouvor(_id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final louvor = _louvor;
    if (louvor == null) {
      return _erro == null
          ? const Center(child: CircularProgressIndicator())
          : EstadoVazio(
              icone: Icons.wifi_off_rounded,
              titulo: 'Não foi possível abrir a escala',
              descricao: '$_erro',
            );
    }
    final aba = _aba ?? _AbaDaEscala.hinos;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
              EspacoTocaEssa.base, EspacoTocaEssa.base, EspacoTocaEssa.base, 0),
          child: SizedBox(
            width: double.infinity,
            child: SegmentedButton<_AbaDaEscala>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(
                  value: _AbaDaEscala.hinos,
                  icon: Icon(Icons.library_music_outlined),
                  label: Text('Por hino'),
                ),
                ButtonSegment(
                  value: _AbaDaEscala.pessoas,
                  icon: Icon(Icons.groups_outlined),
                  label: Text('Pessoas'),
                ),
              ],
              selected: {aba},
              onSelectionChanged: (escolhida) =>
                  setState(() => _aba = escolhida.single),
            ),
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _carregar,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                  EspacoTocaEssa.base,
                  EspacoTocaEssa.base,
                  EspacoTocaEssa.base,
                  EspacoTocaEssa.enorme),
              children: aba == _AbaDaEscala.hinos
                  ? _construirHinos(louvor)
                  : _construirPessoas(louvor),
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _construirHinos(LouvorDoArtista louvor) {
    final texto = Theme.of(context).textTheme;
    final filtro = _filtro;
    // O hino de agora é o último tocado, como no roteiro.
    final agora = louvor.hinos.where((hino) => hino.tocado).lastOrNull?.itemId;
    if (louvor.hinos.isEmpty) {
      return const [
        EstadoVazio(
          icone: Icons.library_music_outlined,
          titulo: 'Nenhum hino ainda',
          descricao: 'Monte a lista de hinos na aba Hinos, embaixo.',
        ),
      ];
    }
    return [
      if (louvor.hinos.any((hino) => hino.partes.isNotEmpty)) ...[
        FilledButton.icon(
          onPressed: _salvando ? null : _escalarTodos,
          icon: const Icon(Icons.auto_awesome_rounded),
          label: const Text('Escalar todos os hinos'),
        ),
        const SizedBox(height: EspacoTocaEssa.medio),
      ],
      if (louvor.participantes.isNotEmpty) ...[
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              ChoiceChip(
                label: const Text('Sem filtro'),
                selected: filtro == null,
                onSelected: (_) => setState(() => _filtro = null),
              ),
              for (final nome in louvor.participantes) ...[
                const SizedBox(width: EspacoTocaEssa.pequeno),
                ChoiceChip(
                  showCheckmark: false,
                  avatar: _Bolinha(corDaPessoa(louvor.cantores, nome)),
                  label: Text(nome),
                  selected: filtro == nome,
                  onSelected: (_) => setState(() => _filtro = nome),
                ),
              ],
            ],
          ),
        ),
        if (filtro != null) ...[
          const SizedBox(height: EspacoTocaEssa.pequeno),
          Text(_resumoDaPessoa(louvor, filtro),
              style: texto.titleSmall?.copyWith(color: CoresTocaEssa.ouro)),
        ],
        const SizedBox(height: EspacoTocaEssa.medio),
      ],
      for (final (indice, hino) in louvor.hinos.indexed) ...[
        _CartaoDoHino(
          ordem: indice + 1,
          hino: hino,
          cantores: louvor.cantores,
          filtro: filtro,
          aberto: _abertos.contains(hino.itemId),
          ehAgora: hino.itemId == agora,
          alternar: () => setState(() => _abertos.contains(hino.itemId)
              ? _abertos.remove(hino.itemId)
              : _abertos.add(hino.itemId)),
          escolherParte: _salvando
              ? null
              : (indice, rotulo) => _escolherParte(hino, indice, rotulo),
          colarLetra: _salvando ? null : () => _colarLetra(hino),
          escalar: _salvando
              ? null
              : () => _salvar(
                  () => widget.api.escalarHinoDoLouvor(_id, hino.itemId)),
        ),
        const SizedBox(height: EspacoTocaEssa.medio),
      ],
    ];
  }

  /// "Ana: 3 partes em 2 hinos".
  static String _resumoDaPessoa(LouvorDoArtista louvor, String nome) {
    final hinos = louvor.hinos.where(
        (hino) => hino.partes.any((parte) => parte.cantores.contains(nome)));
    final partes =
        hinos.fold<int>(0, (total, hino) => total + hino.partesDe(nome));
    return '$nome: $partes ${partes == 1 ? 'parte' : 'partes'} em '
        '${hinos.length} ${hinos.length == 1 ? 'hino' : 'hinos'}';
  }

  List<Widget> _construirPessoas(LouvorDoArtista louvor) {
    final explicacao = Theme.of(context)
        .textTheme
        .bodySmall
        ?.copyWith(color: CoresTocaEssa.textoSecundario);
    final pontos = {
      for (final item in louvor.placar) item.nome: item.pontos,
    };
    final solos = {
      for (final item in louvor.placarDosSolos) item.nome: item.solos,
    };
    final configuracao = louvor.configuracao;
    return [
      const TituloGrupo('Quem canta no microfone'),
      Wrap(
        spacing: EspacoTocaEssa.pequeno,
        runSpacing: EspacoTocaEssa.pequeno,
        children: [
          for (final nome in louvor.cantores)
            InputChip(
              avatar: _Bolinha(corDoCantor(louvor.cantores, nome)),
              label: Text('$nome · ${pontos[nome] ?? 0}'),
              deleteButtonTooltipMessage: 'Tirar $nome',
              onDeleted: _salvando
                  ? null
                  : () => _definirCantores([
                        for (final outro in louvor.cantores)
                          if (outro != nome) outro,
                      ]),
            ),
          ActionChip(
            avatar: const Icon(Icons.person_add_alt_1_rounded, size: 18),
            label: const Text('Adicionar'),
            onPressed: _salvando ? null : _adicionarCantor,
          ),
        ],
      ),
      const SizedBox(height: EspacoTocaEssa.pequeno),
      Text(
        louvor.cantores.isEmpty
            ? 'Coloque quem vai cantar no microfone. Em cada hino, '
                '"Escalar automático" divide as partes entre eles.'
            : 'O número é de pontos: estrofe vale 1 e coro vale 2.',
        style: explicacao,
      ),
      const SizedBox(height: EspacoTocaEssa.grande),
      const TituloGrupo('Quem toca os solos'),
      Wrap(
        spacing: EspacoTocaEssa.pequeno,
        runSpacing: EspacoTocaEssa.pequeno,
        children: [
          for (final solista in louvor.solistas)
            InputChip(
              avatar: const _Bolinha(corInstrumental),
              label: Text([
                solista.nome,
                if (solista.instrumento.isNotEmpty) solista.instrumento,
                '${solos[solista.nome] ?? 0}',
              ].join(' · ')),
              deleteButtonTooltipMessage: 'Tirar ${solista.nome} dos solos',
              onDeleted: _salvando
                  ? null
                  : () => _definirSolistas([
                        for (final outro in louvor.solistas)
                          if (outro.nome != solista.nome) outro,
                      ]),
            ),
          ActionChip(
            avatar: const Icon(Icons.music_note_rounded, size: 18),
            label: const Text('Adicionar solista'),
            onPressed: _salvando ? null : _adicionarSolista,
          ),
        ],
      ),
      const SizedBox(height: EspacoTocaEssa.pequeno),
      Text(
        'O app dá cada "(Solo sax)" para quem toca o instrumento, '
        'revezando quando tem mais de um. O número é de solos.',
        style: explicacao,
      ),
      const SizedBox(height: EspacoTocaEssa.grande),
      const TituloGrupo('Como escalar'),
      Text('Cantores por hino', style: Theme.of(context).textTheme.bodyMedium),
      const SizedBox(height: EspacoTocaEssa.pequeno),
      Wrap(
        spacing: EspacoTocaEssa.pequeno,
        runSpacing: EspacoTocaEssa.pequeno,
        children: [
          for (final maximo in const [null, 1, 2, 3, 4])
            ChoiceChip(
              label: Text(maximo == null ? 'Sem limite' : '$maximo'),
              selected: configuracao.maximoDeCantoresPorHino == maximo,
              onSelected: _salvando
                  ? null
                  : (_) => _definirConfiguracao(ConfiguracaoDaEscala(
                        maximoDeCantoresPorHino: maximo,
                        corosComTodos: configuracao.corosComTodos,
                      )),
            ),
        ],
      ),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Todos cantam os coros'),
        value: configuracao.corosComTodos,
        onChanged: _salvando
            ? null
            : (valor) => _definirConfiguracao(ConfiguracaoDaEscala(
                  maximoDeCantoresPorHino: configuracao.maximoDeCantoresPorHino,
                  corosComTodos: valor,
                )),
      ),
      Text(
        'Vale para os próximos "Escalar".',
        style: explicacao,
      ),
      const SizedBox(height: EspacoTocaEssa.grande),
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: () => mostrarComoMarcarAsPartes(context),
          icon: const Icon(Icons.help_outline_rounded),
          label: const Text('Como marcar as partes'),
        ),
      ),
    ];
  }
}

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
                        // Uma bolinha por parte, na cor de quem canta.
                        Padding(
                          padding: const EdgeInsets.only(left: 44),
                          child: Wrap(
                            spacing: EspacoTocaEssa.mini,
                            runSpacing: EspacoTocaEssa.mini,
                            children: [
                              for (final parte in hino.partes)
                                Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    color: _corDa(parte),
                                    shape: BoxShape.circle,
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

/// Resposta da escolha de uma parte: [cantores] nulo volta à escala.
class _Escolha {
  const _Escolha(this.cantores);
  final List<String>? cantores;
}

class _EscolhaDaParte extends StatefulWidget {
  const _EscolhaDaParte({
    required this.titulo,
    required this.cantores,
    required this.atuais,
  });

  final String titulo;
  final List<String> cantores;
  final List<String> atuais;

  @override
  State<_EscolhaDaParte> createState() => _EscolhaDaParteState();
}

class _EscolhaDaParteState extends State<_EscolhaDaParte> {
  late final _selecionados = {...widget.atuais};

  void _responder(List<String>? cantores) =>
      Navigator.of(context).pop(_Escolha(cantores));

  @override
  Widget build(BuildContext context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
              EspacoTocaEssa.base, 0, EspacoTocaEssa.base, EspacoTocaEssa.base),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(widget.titulo,
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: EspacoTocaEssa.medio),
              Wrap(
                spacing: EspacoTocaEssa.pequeno,
                runSpacing: EspacoTocaEssa.pequeno,
                children: [
                  for (final nome in widget.cantores)
                    FilterChip(
                      label: Text(nome),
                      selected: _selecionados.contains(nome),
                      onSelected: (marcado) => setState(() => marcado
                          ? _selecionados.add(nome)
                          : _selecionados.remove(nome)),
                    ),
                ],
              ),
              const SizedBox(height: EspacoTocaEssa.grande),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _responder(const []),
                      child: const Text('Todos'),
                    ),
                  ),
                  const SizedBox(width: EspacoTocaEssa.pequeno),
                  Expanded(
                    child: FilledButton(
                      onPressed: _selecionados.isEmpty
                          ? null
                          : () => _responder([
                                for (final nome in widget.cantores)
                                  if (_selecionados.contains(nome)) nome,
                              ]),
                      child: const Text('Salvar'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: EspacoTocaEssa.pequeno),
              TextButton(
                onPressed: () => _responder(null),
                child: const Text('Limpar'),
              ),
            ],
          ),
        ),
      );
}

/// Confirmação do "Escalar todos os hinos": todos os hinos com letra vêm
/// marcados; responde os ids marcados, na ordem da lista.
class _HinosAEscalar extends StatefulWidget {
  const _HinosAEscalar({required this.hinos});

  final List<HinoDoLouvor> hinos;

  @override
  State<_HinosAEscalar> createState() => _HinosAEscalarState();
}

class _HinosAEscalarState extends State<_HinosAEscalar> {
  late final _marcados = {for (final hino in widget.hinos) hino.itemId};

  @override
  Widget build(BuildContext context) {
    final todos = _marcados.length == widget.hinos.length;
    return AlertDialog(
      title: const Text('Escalar quais hinos?'),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView(
          shrinkWrap: true,
          children: [
            Text(
              'Os marcados são refeitos na ordem da lista, inclusive o que '
              'foi trocado à mão. Os outros ficam como estão.',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: CoresTocaEssa.textoSecundario),
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Todos'),
              value: todos,
              onChanged: (_) => setState(() {
                if (todos) {
                  _marcados.clear();
                } else {
                  _marcados.addAll(widget.hinos.map((hino) => hino.itemId));
                }
              }),
            ),
            const Divider(height: 1),
            for (final hino in widget.hinos)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(hino.titulo),
                value: _marcados.contains(hino.itemId),
                onChanged: (marcado) => setState(() => marcado == true
                    ? _marcados.add(hino.itemId)
                    : _marcados.remove(hino.itemId)),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _marcados.isEmpty
              ? null
              : () => Navigator.of(context).pop([
                    for (final hino in widget.hinos)
                      if (_marcados.contains(hino.itemId)) hino.itemId,
                  ]),
          child: Text('Escalar (${_marcados.length})'),
        ),
      ],
    );
  }
}

class _NovoCantor extends StatefulWidget {
  const _NovoCantor();

  @override
  State<_NovoCantor> createState() => _NovoCantorState();
}

class _NovoCantorState extends State<_NovoCantor> {
  final _nome = TextEditingController();

  @override
  void dispose() {
    _nome.dispose();
    super.dispose();
  }

  void _confirmar() => Navigator.of(context).pop(_nome.text);

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Quem vai cantar?'),
        content: TextField(
          controller: _nome,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(hintText: 'Nome'),
          onSubmitted: (_) => _confirmar(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(onPressed: _confirmar, child: const Text('Adicionar')),
        ],
      );
}

class _NovoSolista extends StatefulWidget {
  const _NovoSolista();

  @override
  State<_NovoSolista> createState() => _NovoSolistaState();
}

class _NovoSolistaState extends State<_NovoSolista> {
  final _nome = TextEditingController();
  final _instrumento = TextEditingController();

  @override
  void dispose() {
    _nome.dispose();
    _instrumento.dispose();
    super.dispose();
  }

  void _confirmar() => Navigator.of(context).pop(
      Solista(nome: _nome.text.trim(), instrumento: _instrumento.text.trim()));

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Quem toca os solos?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nome,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Nome'),
            ),
            TextField(
              controller: _instrumento,
              decoration: const InputDecoration(
                  labelText: 'Instrumento', hintText: 'sax tenor'),
              onSubmitted: (_) => _confirmar(),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(onPressed: _confirmar, child: const Text('Adicionar')),
        ],
      );
}
