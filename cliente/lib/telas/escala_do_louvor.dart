import 'package:flutter/material.dart';

import '../dominio/modelos.dart';
import '../dominio/transpor_cifra.dart';
import '../infraestrutura/api_toca_essa.dart';
import '../tema/tema_toca_essa.dart';
import 'como_marcar_hinos.dart';
import 'componentes.dart';
import 'componentes_lista.dart';
import 'componentes_movimento.dart';
import 'editor_de_cifra.dart';
import 'trechos_do_louvor.dart';

part 'escala_do_louvor_dialogos.dart';
part 'escala_do_louvor_hinos.dart';
part 'escala_do_louvor_pessoas.dart';

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
  // Na aba Pessoas, o × de tirar alguém só aparece no Editar.
  bool _editandoPessoas = false;

  void _alternarEdicaoDePessoas() =>
      setState(() => _editandoPessoas = !_editandoPessoas);

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
    final solo = parte.tipo == TipoDaParte.instrumental;
    // No solo, quem toca; sem solistas cadastrados, todo mundo.
    final nomes = solo
        ? (_louvor!.solistas.isEmpty
            ? _louvor!.participantes
            : [for (final solista in _louvor!.solistas) solista.nome])
        : _louvor!.cantores;
    // Ao lado de cada nome, os pontos (ou solos) de agora.
    final contagem = solo
        ? {
            for (final item in _louvor!.placarDosSolos)
              item.nome: '${item.solos} ${item.solos == 1 ? 'solo' : 'solos'}',
          }
        : {
            for (final item in _louvor!.placar)
              item.nome: '${item.pontos} ${item.pontos == 1 ? 'pt' : 'pts'}',
          };
    final escolha = await showModalBottomSheet<_Escolha>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => _EscolhaDaParte(
        titulo: '$rotulo · ${hino.titulo}',
        cantores: nomes,
        atuais: parte.cantores,
        contagem: contagem,
        solo: solo,
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

  /// Tira todo mundo de todas as partes, para reescalar do zero; confirma
  /// porque desfaz também as trocas feitas à mão.
  Future<void> _limparEscala() async {
    final confirmou = await showDialog<bool>(
          context: context,
          builder: (contexto) => AlertDialog(
            title: const Text('Limpar a escala de todos os hinos?'),
            content: const Text(
                'Todas as partes ficam sem ninguém, inclusive as trocadas à '
                'mão. Cantores e solistas continuam.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(contexto, false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                style:
                    FilledButton.styleFrom(backgroundColor: CoresTocaEssa.rosa),
                onPressed: () => Navigator.pop(contexto, true),
                child: const Text('Limpar'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmou || !mounted) return;
    await _salvar(() => widget.api.limparEscalaDoLouvor(_id));
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
          ? const EsqueletoDeLista()
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
      _ResumoDaEscala(
        louvor: louvor,
        // Só quando há o que escalar: hino sem letra não tem partes.
        temOQueEscalar: louvor.hinos.any((hino) => hino.partes.isNotEmpty),
        escalarTodos: _salvando ? null : _escalarTodos,
        temEscala: louvor.hinos
            .any((hino) => hino.partes.any((parte) => parte.definida)),
        limparEscala: _salvando ? null : _limparEscala,
      ),
      const SizedBox(height: EspacoTocaEssa.medio),
      if (louvor.participantes.isNotEmpty) ...[
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              ChoiceChip(
                showCheckmark: false,
                label: const Text('Todos'),
                selected: filtro == null,
                onSelected: (_) => setState(() => _filtro = null),
              ),
              for (final nome in louvor.participantes) ...[
                const SizedBox(width: EspacoTocaEssa.pequeno),
                ChoiceChip(
                  showCheckmark: false,
                  avatar: _Bolinha(corDaPessoa(louvor.participantes, nome)),
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
}
