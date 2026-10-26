import 'package:flutter/material.dart';

import '../dominio/modelos.dart';
import '../infraestrutura/abrir_url_externa.dart';
import '../infraestrutura/api_toca_essa.dart';
import '../tema/tema_toca_essa.dart';
import 'componentes.dart';
import 'componentes_lista.dart';
import 'componentes_movimento.dart';
import 'leitor_de_cifras.dart';
import 'sequencia_do_palco.dart';

/// Tocar e ensaiar as músicas do acervo sem criar um show: busca, chips dos
/// repertórios e um toque abre o leitor. As setas andam pela lista que está
/// na tela, e nada é marcado como tocado.
class TocarMusicas extends StatefulWidget {
  const TocarMusicas({
    super.key,
    required this.api,
    this.repertorioInicialId,
    this.abrirUrl = abrirNaAbaDaCifra,
  });

  final ApiTocaEssa api;
  // Aberta pelo Tocar de um repertório, começa nele; senão, em Todas.
  final String? repertorioInicialId;
  final Future<void> Function(Uri url) abrirUrl;

  @override
  State<TocarMusicas> createState() => _TocarMusicasState();
}

class _TocarMusicasState extends State<TocarMusicas> {
  List<Repertorio>? _repertorios;
  // Nulo é Todas.
  late String? _repertorioId = widget.repertorioInicialId;
  final _busca = TextEditingController();

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  @override
  void dispose() {
    _busca.dispose();
    super.dispose();
  }

  Future<void> _carregar() async {
    try {
      final repertorios = await widget.api.listarRepertorios();
      if (mounted) setState(() => _repertorios = repertorios);
    } catch (erro) {
      if (!mounted) return;
      setState(() => _repertorios = const []);
      mostrarErro(context, erro);
    }
  }

  /// Músicas do repertório escolhido, ou de todos sem repetir a mesma
  /// música; a busca procura no acervo inteiro.
  List<MusicaDoRepertorio> get _visiveis {
    final buscando = _busca.text.trim().isNotEmpty;
    final repertorios = [
      for (final repertorio in _repertorios ?? const <Repertorio>[])
        if (buscando || _repertorioId == null || repertorio.id == _repertorioId)
          repertorio,
    ];
    final musicas = <MusicaDoRepertorio>[];
    for (final repertorio in repertorios) {
      for (final musica in repertorio.musicas) {
        if (!combinaComBusca(_busca.text, [musica.titulo, musica.artista])) {
          continue;
        }
        if (musicas.any((ja) => mesmaMusica(
            ja.titulo, ja.artista, musica.titulo, musica.artista))) {
          continue;
        }
        musicas.add(musica);
      }
    }
    return musicas;
  }

  Future<void> _abrir(
      List<MusicaDoRepertorio> lista, MusicaDoRepertorio musica) async {
    final sequencia = SequenciaDoEnsaio(api: widget.api, musicas: lista);
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => LeitorDeCifras(
        sequencia: sequencia,
        musicaInicial: MusicaDoPalco.doSetlist(
            sequencia.itens.singleWhere((item) => item.id == musica.id)),
        abrirUrl: widget.abrirUrl,
      ),
    ));
    sequencia.dispose();
    // A cifra colada no leitor pode ter trazido o tom da música.
    if (mounted) await _carregar();
  }

  void _limparBusca() => setState(_busca.clear);

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Tocar e ensaiar')),
        body: _repertorios == null
            ? const EsqueletoDeLista()
            : _construirCorpo(context),
      );

  Widget _construirCorpo(BuildContext context) {
    final repertorios = _repertorios!;
    if (repertorios.every((repertorio) => repertorio.musicas.isEmpty)) {
      return const Center(
        child: EstadoVazio(
          icone: Icons.library_music_outlined,
          titulo: 'Nenhuma música no acervo',
          descricao: 'Adicione músicas em Meus repertórios para tocar aqui.',
        ),
      );
    }
    final visiveis = _visiveis;
    final buscando = _busca.text.trim().isNotEmpty;
    return ConteudoMobile(
      filho: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CampoDeBusca(
            controlador: _busca,
            dica: 'Buscar música',
            aoMudar: (_) => setState(() {}),
          ),
          if (!buscando && repertorios.length > 1)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(top: EspacoTocaEssa.medio),
              child: Row(
                children: [
                  for (final (id, nome) in [
                    (null, 'Todas'),
                    for (final repertorio in repertorios)
                      (repertorio.id, repertorio.nome),
                  ])
                    Padding(
                      padding:
                          const EdgeInsets.only(right: EspacoTocaEssa.pequeno),
                      child: ChoiceChip(
                        label: Text(nome),
                        selected: id == _repertorioId,
                        onSelected: (_) => setState(() => _repertorioId = id),
                      ),
                    ),
                ],
              ),
            ),
          const SizedBox(height: EspacoTocaEssa.base),
          if (visiveis.isEmpty)
            Column(
              children: [
                Text(
                  buscando
                      ? 'Nenhuma música com "${_busca.text.trim()}"'
                      : 'Este repertório ainda não tem músicas.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: CoresTocaEssa.textoSecundario),
                ),
                if (buscando)
                  TextButton(
                      onPressed: _limparBusca,
                      child: const Text('Limpar busca')),
              ],
            )
          else
            GrupoDeLinhas(
              linhas: [
                for (final musica in visiveis)
                  _LinhaParaTocar(
                    musica: musica,
                    abrir: () => _abrir(visiveis, musica),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _LinhaParaTocar extends StatelessWidget {
  const _LinhaParaTocar({required this.musica, required this.abrir});

  final MusicaDoRepertorio musica;
  final VoidCallback abrir;

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    final detalhes = [
      if (musica.artista != null) musica.artista!,
      if (musica.tom != null) 'Tom ${musica.tom}',
    ].join(' · ');
    return Semantics(
      button: true,
      child: InkWell(
        onTap: abrir,
        child: Padding(
          padding: const EdgeInsets.all(EspacoTocaEssa.base),
          child: Row(
            children: [
              const Icon(Icons.play_arrow_rounded,
                  color: CoresTocaEssa.roxoClaro),
              const SizedBox(width: EspacoTocaEssa.base),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(musica.titulo, style: texto.titleMedium),
                    if (detalhes.isNotEmpty)
                      Text(detalhes,
                          style: texto.bodyMedium
                              ?.copyWith(color: CoresTocaEssa.textoSecundario)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
