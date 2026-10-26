import 'package:flutter/material.dart';

import '../dominio/modelos.dart';
import '../infraestrutura/api_toca_essa.dart';
import '../tema/tema_toca_essa.dart';
import 'componentes.dart';
import 'componentes_formulario.dart';
import 'componentes_lista.dart';

/// Da playlist ([musicaId]) ou outra ([titulo] e o link opcional).
typedef MusicaEscolhidaNoKaraoke = ({
  String? musicaId,
  String? titulo,
  String? linkDoVideo,
});

/// A playlist da noite com a busca de sempre, e "Outra música" para o que
/// não está nela.
Future<MusicaEscolhidaNoKaraoke?> escolherMusicaDoKaraoke(BuildContext context,
        {required ApiTocaEssa api,
        required String codigo,
        required String token}) =>
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => _EscolherMusica(api: api, codigo: codigo, token: token),
    ));

class _EscolherMusica extends StatefulWidget {
  const _EscolherMusica(
      {required this.api, required this.codigo, required this.token});

  final ApiTocaEssa api;
  final String codigo;
  final String token;

  @override
  State<_EscolherMusica> createState() => _EscolherMusicaState();
}

class _EscolherMusicaState extends State<_EscolherMusica> {
  final _busca = TextEditingController();
  late final Future<List<MusicaDaPlaylistDoKaraoke>> _playlist =
      widget.api.listarPlaylistDoKaraoke(widget.codigo, widget.token);

  @override
  void dispose() {
    _busca.dispose();
    super.dispose();
  }

  Future<void> _outra() async {
    final outra = await Navigator.of(context).push<MusicaEscolhidaNoKaraoke>(
        MaterialPageRoute(
            fullscreenDialog: true, builder: (_) => const _OutraMusica()));
    if (outra != null && mounted) Navigator.pop(context, outra);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Escolher a música'),
          actions: [
            TextButton(onPressed: _outra, child: const Text('Outra música')),
            const SizedBox(width: EspacoTocaEssa.pequeno),
          ],
        ),
        body: FutureBuilder(
          future: _playlist,
          builder: (context, carga) {
            if (carga.hasError) {
              return Center(child: Text(carga.error.toString()));
            }
            final musicas = carga.data;
            if (musicas == null) {
              return const Center(child: CircularProgressIndicator());
            }
            return ConteudoMobile(
              filho: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  CampoDeBusca(
                    controlador: _busca,
                    dica: 'Buscar na playlist',
                    aoMudar: (_) => setState(() {}),
                  ),
                  const SizedBox(height: EspacoTocaEssa.base),
                  _Lista(musicas: musicas, busca: _busca.text),
                ],
              ),
            );
          },
        ),
      );
}

class _Lista extends StatelessWidget {
  const _Lista({required this.musicas, required this.busca});

  final List<MusicaDaPlaylistDoKaraoke> musicas;
  final String busca;

  @override
  Widget build(BuildContext context) {
    final visiveis = [
      for (final musica in musicas)
        if (combinaComBusca(busca, [musica.titulo])) musica,
    ];
    if (visiveis.isEmpty) {
      return const EstadoVazio(
        icone: Icons.search_off_rounded,
        titulo: 'Não está na playlist',
        descricao: 'Toque em Outra música e escreva o nome (o link do '
            'YouTube é opcional).',
      );
    }
    return GrupoDeLinhas(linhas: [
      for (final musica in visiveis)
        ListTile(
          key: ValueKey(musica.id),
          leading: const Icon(Icons.smart_display_outlined,
              color: CoresTocaEssa.roxoClaro),
          title: Text(musica.titulo),
          onTap: () => Navigator.pop<MusicaEscolhidaNoKaraoke>(
              context, (musicaId: musica.id, titulo: null, linkDoVideo: null)),
        ),
    ]);
  }
}

/// Nome e, se quiser, o link do vídeo; sem link, o Tocar na TV procura o
/// karaokê no YouTube. Confirmar fica no topo, longe do teclado.
class _OutraMusica extends StatefulWidget {
  const _OutraMusica();

  @override
  State<_OutraMusica> createState() => _OutraMusicaState();
}

class _OutraMusicaState extends State<_OutraMusica> {
  final _titulo = TextEditingController();
  final _link = TextEditingController();

  @override
  void dispose() {
    _titulo.dispose();
    _link.dispose();
    super.dispose();
  }

  void _escolher() {
    final titulo = _titulo.text.trim();
    if (titulo.isEmpty) return;
    final link = _link.text.trim();
    Navigator.pop<MusicaEscolhidaNoKaraoke>(context, (
      musicaId: null,
      titulo: titulo,
      linkDoVideo: link.isEmpty ? null : link
    ));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Outra música'),
          actions: [
            TextButton(onPressed: _escolher, child: const Text('Escolher')),
            const SizedBox(width: EspacoTocaEssa.pequeno),
          ],
        ),
        body: ConteudoMobile(
          filho: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CampoTexto(
                rotulo: 'Música',
                controlador: _titulo,
                dica: 'Nome da música e do cantor',
                focoAutomatico: true,
                capitalizacao: TextCapitalization.words,
                acaoTeclado: TextInputAction.next,
              ),
              const SizedBox(height: EspacoTocaEssa.base + 4),
              CampoTexto(
                rotulo: 'Link do YouTube',
                controlador: _link,
                dica: 'Opcional: cole o link do vídeo',
                acaoTeclado: TextInputAction.done,
                aoEnviar: (_) => _escolher(),
              ),
            ],
          ),
        ),
      );
}
