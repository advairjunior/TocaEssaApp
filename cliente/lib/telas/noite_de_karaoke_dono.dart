import 'package:flutter/material.dart';

import '../dominio/modelos.dart';
import '../infraestrutura/api_toca_essa.dart';
import '../infraestrutura/assinatura_tempo_real.dart';
import '../tema/tema_toca_essa.dart';
import 'componentes.dart';
import 'componentes_lista.dart';

part 'noite_de_karaoke_dono_linhas.dart';

/// A noite do dono: o modo das músicas, a playlist, a galera e o sorteio da
/// ordem. Nada daqui é preciso durante as músicas: cada um canta e
/// transmite do próprio celular.
class NoiteDeKaraokeDoDono extends StatefulWidget {
  const NoiteDeKaraokeDoDono(
      {super.key, required this.api, required this.apresentacao});

  final ApiTocaEssa api;
  final Apresentacao apresentacao;

  @override
  State<NoiteDeKaraokeDoDono> createState() => _NoiteDeKaraokeDoDonoState();
}

class _NoiteDeKaraokeDoDonoState extends State<NoiteDeKaraokeDoDono> {
  NoiteDeKaraoke? _noite;
  List<Repertorio> _repertorios = [];
  bool _ocupado = false;
  AssinaturaTempoReal? _tempoReal;

  String get _id => widget.apresentacao.id;

  @override
  void initState() {
    super.initState();
    _carregar();
    _carregarRepertorios();
    // Quem entra pelo QR aparece na galera sem precisar recarregar.
    _tempoReal = AssinaturaTempoReal(
        widget.api.enderecoTempoReal(widget.apresentacao.codigo), _carregar);
  }

  @override
  void dispose() {
    _tempoReal?.encerrar();
    super.dispose();
  }

  Future<void> _carregar() =>
      _executar(() => widget.api.obterNoiteDeKaraoke(_id), mostrarFalha: false);

  Future<void> _carregarRepertorios() async {
    try {
      final repertorios = await widget.api.listarRepertorios();
      if (mounted) setState(() => _repertorios = repertorios);
    } catch (_) {
      // Sem a lista, a linha da playlist só não mostra o nome.
    }
  }

  Future<void> _executar(Future<NoiteDeKaraoke> Function() acao,
      {bool mostrarFalha = true}) async {
    setState(() => _ocupado = true);
    try {
      final noite = await acao();
      if (mounted) setState(() => _noite = noite);
    } catch (erro) {
      if (mounted && mostrarFalha) mostrarErro(context, erro);
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<void> _configurar({String? repertorioId, ModoDasMusicas? modo}) {
    final atual = _noite;
    return _executar(() => widget.api.configurarKaraoke(_id,
        repertorioId: repertorioId ?? atual?.repertorioId,
        modo: modo ?? atual?.modo ?? ModoDasMusicas.livre));
  }

  Future<void> _escolherPlaylist() async {
    final escolhido = await showModalBottomSheet<String>(
      context: context,
      builder: (contexto) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final repertorio in _repertorios)
              ListTile(
                leading: const Icon(Icons.queue_music_rounded),
                title: Text(repertorio.nome),
                subtitle: Text(_quantasMusicas(repertorio)),
                selected: repertorio.id == _noite?.repertorioId,
                onTap: () => Navigator.pop(contexto, repertorio.id),
              ),
          ],
        ),
      ),
    );
    if (escolhido != null && mounted) {
      await _configurar(repertorioId: escolhido);
    }
  }

  Future<void> _sortear() =>
      _executar(() => widget.api.sortearOrdemDoKaraoke(_id));

  Future<void> _corrigir(_Correcao correcao, PessoaDoKaraoke pessoa) =>
      _executar(() => switch (correcao) {
            _Correcao.passar =>
              widget.api.passarAVezNoKaraoke(_id, pessoa.publicoId),
            _Correcao.tirar =>
              widget.api.tirarDaOrdemDoKaraoke(_id, pessoa.publicoId),
            _Correcao.devolver =>
              widget.api.devolverAOrdemDoKaraoke(_id, pessoa.publicoId),
          });

  @override
  Widget build(BuildContext context) {
    final noite = _noite;
    if (noite == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return ConteudoMobile(
      filho: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const TituloGrupo('Músicas'),
          _ModoDaNoite(
              modo: noite.modo,
              mudar: _ocupado ? null : (modo) => _configurar(modo: modo)),
          const SizedBox(height: EspacoTocaEssa.base),
          _LinhaDaPlaylist(
            repertorio: _repertorioDa(noite),
            escolher: _repertorios.isEmpty ? null : _escolherPlaylist,
          ),
          const SizedBox(height: EspacoTocaEssa.grande),
          ..._ordem(noite),
        ],
      ),
    );
  }

  Repertorio? _repertorioDa(NoiteDeKaraoke noite) {
    for (final repertorio in _repertorios) {
      if (repertorio.id == noite.repertorioId) return repertorio;
    }
    return null;
  }

  List<Widget> _ordem(NoiteDeKaraoke noite) {
    if (noite.ordem.isEmpty && noite.foraDaOrdem.isEmpty) {
      return const [
        EstadoVazio(
          icone: Icons.mic_external_on_rounded,
          titulo: 'Ninguém na galera ainda',
          descricao: 'Mostre o QR da noite (aba Mais): quem entra com a conta '
              'aparece aqui para o sorteio.',
        ),
      ];
    }
    return [
      TituloGrupo(noite.sorteada
          ? 'Ordem da noite'
          : 'Na galera · ${noite.ordem.length}'),
      GrupoDeLinhas(linhas: [
        for (final (indice, pessoa) in noite.ordem.indexed)
          _LinhaDaPessoa(
            key: ValueKey(pessoa.publicoId),
            pessoa: pessoa,
            posicao: noite.sorteada ? indice + 1 : null,
            corrigir: _ocupado ? null : (c) => _corrigir(c, pessoa),
          ),
      ]),
      const SizedBox(height: EspacoTocaEssa.base),
      if (_botaoDoSorteio(noite) case final botao?) botao,
      if (noite.foraDaOrdem.isNotEmpty) ...[
        const SizedBox(height: EspacoTocaEssa.grande),
        const TituloGrupo('Fora da ordem'),
        GrupoDeLinhas(linhas: [
          for (final pessoa in noite.foraDaOrdem)
            _LinhaForaDaOrdem(
              pessoa: pessoa,
              devolver:
                  _ocupado ? null : () => _corrigir(_Correcao.devolver, pessoa),
            ),
        ]),
      ],
    ];
  }

  Widget? _botaoDoSorteio(NoiteDeKaraoke noite) {
    final acao = _ocupado ? null : _sortear;
    if (!noite.sorteada && noite.ordem.isNotEmpty) {
      return FilledButton.icon(
        onPressed: acao,
        icon: const Icon(Icons.casino_rounded),
        label: const Text('Sortear a ordem'),
      );
    }
    if (noite.sorteada && noite.podeSortearDeNovo) {
      return OutlinedButton.icon(
        onPressed: acao,
        icon: const Icon(Icons.shuffle_rounded),
        label: const Text('Sortear de novo'),
      );
    }
    return null;
  }
}

String _quantasMusicas(Repertorio repertorio) {
  final total = repertorio.musicas.length;
  return '$total ${total == 1 ? 'música' : 'músicas'}';
}
