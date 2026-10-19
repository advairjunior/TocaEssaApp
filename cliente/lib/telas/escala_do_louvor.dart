import 'package:flutter/material.dart';

import '../dominio/modelos.dart';
import '../infraestrutura/api_toca_essa.dart';
import '../tema/tema_toca_essa.dart';
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

  Future<void> _escolherParte(
      HinoDoLouvor hino, int indice, String rotulo) async {
    final escolha = await showModalBottomSheet<_Escolha>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => _EscolhaDaParte(
        titulo: '$rotulo · ${hino.titulo}',
        cantores: _louvor!.cantores,
        atuais: hino.partes[indice].cantores,
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
    final estrofes = {
      for (final item in louvor.placar) item.nome: item.estrofes,
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
                  label: Text('$nome · ${estrofes[nome] ?? 0}'),
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
                ? 'Coloque quem vai cantar no microfone: o app divide as '
                    'estrofes entre eles. Refrão e última estrofe são de todos.'
                : 'O número é de estrofes de cada um. Toque numa parte para '
                    'trocar quem canta.',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: CoresTocaEssa.textoSecundario),
          ),
          const SizedBox(height: EspacoTocaEssa.grande),
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
  });

  final HinoDoLouvor hino;
  final void Function(int indice, String rotulo)? escolherParte;
  final VoidCallback? colarLetra;

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    var estrofe = 0;
    return GrupoDeLinhas(
      recuoDivisoria: EspacoTocaEssa.base,
      linhas: [
        Padding(
          padding: const EdgeInsets.all(EspacoTocaEssa.base),
          child: Row(
            children: [
              Expanded(child: Text(hino.titulo, style: texto.titleMedium)),
              if (hino.tom case final tom?)
                Text('Tom $tom',
                    style: texto.labelLarge
                        ?.copyWith(color: CoresTocaEssa.roxoClaro)),
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
            final rotulo = parte.tipo == TipoDaParte.estrofe
                ? 'Estrofe ${++estrofe}'
                : parte.tipo.rotulo;
            return ListTile(
              onTap: escolherParte == null
                  ? null
                  : () => escolherParte!(indice, rotulo),
              title: Text(rotulo),
              subtitle: Text(
                parte.texto.split('\n').first,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (parte.escolhidaAMao)
                    const Tooltip(
                      message: 'Escolhida à mão',
                      child: Padding(
                        padding: EdgeInsets.only(right: EspacoTocaEssa.pequeno),
                        child: Icon(Icons.circle,
                            size: 8, color: CoresTocaEssa.ouro),
                      ),
                    ),
                  Text(
                    parte.quemCanta,
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
                child: const Text('Automático'),
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
