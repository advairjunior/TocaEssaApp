import 'package:flutter/material.dart';

import '../dominio/modelos.dart';
import '../dominio/transpor_cifra.dart';
import '../infraestrutura/api_toca_essa.dart';
import '../tema/tema_toca_essa.dart';
import 'como_marcar_hinos.dart';
import 'componentes.dart';
import 'componentes_lista.dart';
import 'editor_de_cifra.dart';

/// Escala do louvor, vista pelo artista: quem canta no microfone, o placar
/// de estrofes e quem canta cada parte de cada hino. O app escala sozinho;
/// tocar numa parte troca à mão.
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

  String get _id => widget.apresentacao.id;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    try {
      final louvor = await widget.api.obterLouvor(_id);
      if (mounted) setState(() => _louvor = louvor);
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
    final pontos = {
      for (final item in louvor.placar) item.nome: item.pontos,
    };
    final solos = {
      for (final item in louvor.placarDosSolos) item.nome: item.solos,
    };
    return RefreshIndicator(
      onRefresh: _carregar,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(EspacoTocaEssa.base,
            EspacoTocaEssa.base, EspacoTocaEssa.base, EspacoTocaEssa.enorme),
        children: [
          const TituloGrupo('Quem canta no microfone'),
          Wrap(
            spacing: EspacoTocaEssa.pequeno,
            runSpacing: EspacoTocaEssa.pequeno,
            children: [
              for (final nome in louvor.cantores)
                InputChip(
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
                : 'O número é de pontos: cada estrofe ou coro cantado vale 1. '
                    'Toque numa parte para trocar quem canta.',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: CoresTocaEssa.textoSecundario),
          ),
          const SizedBox(height: EspacoTocaEssa.grande),
          const TituloGrupo('Quem toca os solos'),
          Wrap(
            spacing: EspacoTocaEssa.pequeno,
            runSpacing: EspacoTocaEssa.pequeno,
            children: [
              for (final solista in louvor.solistas)
                InputChip(
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
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: CoresTocaEssa.textoSecundario),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => mostrarComoMarcarAsPartes(context),
              icon: const Icon(Icons.help_outline_rounded),
              label: const Text('Como marcar as partes'),
            ),
          ),
          const SizedBox(height: EspacoTocaEssa.base),
          if (louvor.hinos.isEmpty)
            const EstadoVazio(
              icone: Icons.library_music_outlined,
              titulo: 'Nenhum hino ainda',
              descricao: 'Monte a lista de hinos na aba Hinos.',
            ),
          for (final hino in louvor.hinos) ...[
            _CartaoDoHino(
              hino: hino,
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
        ],
      ),
    );
  }
}

class _CartaoDoHino extends StatelessWidget {
  const _CartaoDoHino({
    required this.hino,
    required this.escolherParte,
    required this.colarLetra,
    required this.escalar,
  });

  final HinoDoLouvor hino;
  final void Function(int indice, String rotulo)? escolherParte;
  final VoidCallback? colarLetra;
  final VoidCallback? escalar;

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    var estrofe = 0;
    return GrupoDeLinhas(
      recuoDivisoria: EspacoTocaEssa.base,
      linhas: [
        Padding(
          padding: const EdgeInsets.all(EspacoTocaEssa.base),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text(hino.titulo, style: texto.titleMedium)),
                  if (hino.tom case final tom?)
                    Text('Tom $tom',
                        style: texto.labelLarge
                            ?.copyWith(color: CoresTocaEssa.roxoClaro)),
                ],
              ),
              if (hino.partes.isNotEmpty) ...[
                const SizedBox(height: EspacoTocaEssa.pequeno),
                FilledButton.tonalIcon(
                  onPressed: escalar,
                  icon: const Icon(Icons.auto_awesome_rounded, size: 18),
                  label: const Text('Escalar automático'),
                ),
              ],
            ],
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
        for (final (indice, parte) in hino.partes.indexed)
          Builder(builder: (context) {
            final nome = switch (parte.tipo) {
              TipoDaParte.estrofe => 'Estrofe ${++estrofe}',
              TipoDaParte.instrumental => parte.nome ?? parte.tipo.rotulo,
              TipoDaParte.refrao => parte.tipo.rotulo,
            };
            final rotulo = parte.vezes > 1 ? '$nome · ${parte.vezes}x' : nome;
            return ListTile(
              onTap: escolherParte == null
                  ? null
                  : () => escolherParte!(indice, rotulo),
              title: Text(rotulo),
              subtitle: Text(
                // A primeira linha da letra, não a dos acordes.
                parte.texto
                        .split('\n')
                        .where((linha) =>
                            linha.trim().isNotEmpty && !linhaDeAcordes(linha))
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
                    style: texto.labelLarge?.copyWith(
                      color: parte.deTodos
                          ? CoresTocaEssa.textoSecundario
                          : CoresTocaEssa.roxoClaro,
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded,
                      color: CoresTocaEssa.textoSecundario),
                ],
              ),
            );
          }),
      ],
    );
  }
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
