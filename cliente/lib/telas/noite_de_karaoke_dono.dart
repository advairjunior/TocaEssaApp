import 'package:flutter/material.dart';

import '../dominio/modelos.dart';
import '../infraestrutura/api_toca_essa.dart';
import '../infraestrutura/assinatura_tempo_real.dart';
import '../tema/tema_toca_essa.dart';
import 'componentes.dart';
import 'componentes_lista.dart';
import 'gerenciar_repertorios.dart';

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

  // Só as playlists vindas do YouTube: as músicas do show não têm vídeo.
  List<Repertorio> get _comVideos => [
        for (final repertorio in _repertorios)
          if (repertorio.musicas.any((musica) => musica.linkDoVideo != null))
            repertorio,
      ];

  Future<void> _escolherPlaylist() async {
    const colar = '';
    final escolhido = await showModalBottomSheet<String>(
      context: context,
      builder: (contexto) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final repertorio in _comVideos)
              ListTile(
                leading: const Icon(Icons.smart_display_outlined),
                title: Text(repertorio.nome),
                subtitle: Text(_quantasMusicas(repertorio)),
                selected: repertorio.id == _noite?.repertorioId,
                onTap: () => Navigator.pop(contexto, repertorio.id),
              ),
            ListTile(
              leading: const Icon(Icons.link_rounded),
              title: const Text('Colar link da playlist do YouTube'),
              onTap: () => Navigator.pop(contexto, colar),
            ),
          ],
        ),
      ),
    );
    if (escolhido == null || !mounted) return;
    if (escolhido == colar) return _importarPlaylist();
    await _configurar(repertorioId: escolhido);
  }

  /// Lê a playlist do YouTube e guarda os vídeos num repertório com o nome
  /// dela (o mesmo de antes, se já foi importada: só os novos entram), que
  /// passa a ser a playlist da noite.
  Future<void> _importarPlaylist() async {
    final link = await pedirLinkDaPlaylistDoYouTube(context);
    if (link == null || !mounted) return;
    setState(() => _ocupado = true);
    try {
      final playlist = await widget.api.lerPlaylistDoYouTube(link);
      final mesmo = _comVideos
          .where((r) =>
              normalizarMusica(r.nome) == normalizarMusica(playlist.titulo))
          .firstOrNull;
      final resultado = await widget.api.adicionarMusicasAoRepertorio(
        repertorioId: mesmo?.id,
        nomeNovo: mesmo == null ? playlist.titulo : null,
        musicas: [
          for (final video in playlist.musicas)
            (
              titulo: video.titulo,
              artista: null,
              tom: null,
              linkDoVideo: video.linkDoVideo
            ),
        ],
      );
      await _carregarRepertorios();
      if (!mounted) return;
      setState(() => _ocupado = false);
      await _configurar(repertorioId: resultado.repertorio.id);
      if (!mounted) return;
      final novas = resultado.adicionadas;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('$novas ${novas == 1 ? 'música nova' : 'músicas novas'}'
              ' da playlist "${playlist.titulo}".')));
    } catch (erro) {
      if (mounted) mostrarErro(context, erro);
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<void> _terminarVez() =>
      _executar(() => widget.api.terminarVezDoKaraokeComoDono(_id));

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
            escolher: _ocupado
                ? null
                : _comVideos.isEmpty
                    ? _importarPlaylist
                    : _escolherPlaylist,
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
      if (noite.cantando case final cantando?) ...[
        _CantandoAgora(
            cantando: cantando, terminar: _ocupado ? null : _terminarVez),
        const SizedBox(height: EspacoTocaEssa.grande),
      ],
      TituloGrupo(noite.sorteada
          ? 'Ordem da noite'
          : 'Na galera · ${noite.ordem.length}'),
      GrupoDeLinhas(linhas: [
        for (final (indice, pessoa) in noite.ordem.indexed)
          _LinhaDaPessoa(
            key: ValueKey(pessoa.publicoId),
            pessoa: pessoa,
            posicao: noite.sorteada ? indice + 1 : null,
            proximo: noite.sorteada && noite.proximo == pessoa.publicoId,
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
