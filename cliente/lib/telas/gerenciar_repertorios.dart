import 'package:flutter/material.dart';

import '../dominio/modelos.dart';
import '../infraestrutura/api_toca_essa.dart';
import '../tema/tema_toca_essa.dart';
import 'componentes.dart';

class GerenciarRepertorios extends StatefulWidget {
  const GerenciarRepertorios({super.key, required this.api});
  final ApiTocaEssa api;

  @override
  State<GerenciarRepertorios> createState() => _GerenciarRepertoriosState();
}

class _GerenciarRepertoriosState extends State<GerenciarRepertorios> {
  List<Repertorio> _repertorios = [];
  bool _carregando = true;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    try {
      final lista = await widget.api.listarRepertorios();
      if (!mounted) return;
      setState(() => _repertorios = lista);
    } catch (erro) {
      if (mounted) mostrarErro(context, erro);
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  Future<void> _criarRepertorio() async {
    final nome = await _pedirNome(context, titulo: 'Novo repertório',
        rotulo: 'Nome do repertório');
    if (nome == null || !mounted) return;
    try {
      final criado = await widget.api.criarRepertorio(nome);
      if (!mounted) return;
      _abrirDetalhe(criado); // a lista é recarregada ao voltar via _carregar()
    } catch (erro) {
      if (mounted) mostrarErro(context, erro);
    }
  }

  Future<void> _excluirRepertorio(Repertorio rep) async {
    final confirmou = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Excluir repertório?'),
            content: Text(
                '"${rep.nome}" e suas ${rep.musicas.length} músicas serão removidos.'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancelar')),
              FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Excluir')),
            ],
          ),
        ) ??
        false;
    if (!confirmou || !mounted) return;
    try {
      await widget.api.excluirRepertorio(rep.id);
      if (!mounted) return;
      setState(
          () => _repertorios = _repertorios.where((r) => r.id != rep.id).toList());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('"${rep.nome}" excluído.')),
      );
    } catch (erro) {
      if (mounted) mostrarErro(context, erro);
    }
  }

  void _abrirDetalhe(Repertorio rep) {
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => _DetalheRepertorio(api: widget.api, repertorio: rep),
      ),
    ).then((_) { if (mounted) _carregar(); });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Meus Repertórios'),
          actions: [
            IconButton(
              tooltip: 'Novo repertório',
              icon: const Icon(Icons.add_rounded),
              onPressed: _criarRepertorio,
            ),
          ],
        ),
        body: _carregando
            ? const Center(child: CircularProgressIndicator())
            : _repertorios.isEmpty
                ? _construirVazio(context)
                : _construirLista(context),
      );

  Widget _construirVazio(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.queue_music_rounded,
                  size: 64, color: CoresTocaEssa.borda),
              const SizedBox(height: 16),
              Text(
                'Nenhum repertório ainda',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              const Text(
                'Crie um repertório com as músicas do seu show.',
                textAlign: TextAlign.center,
                style: TextStyle(color: CoresTocaEssa.textoSecundario),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _criarRepertorio,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Criar repertório'),
              ),
            ],
          ),
        ),
      );

  Widget _construirLista(BuildContext context) => ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _repertorios.length,
        itemBuilder: (context, index) {
          final rep = _repertorios[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            color: CoresTocaEssa.superficieElevada,
            child: ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: CoresTocaEssa.roxo.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.queue_music_rounded,
                    color: CoresTocaEssa.roxoClaro, size: 20),
              ),
              title: Text(rep.nome,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(
                '${rep.musicas.length} '
                '${rep.musicas.length == 1 ? 'música' : 'músicas'}',
                style: const TextStyle(color: CoresTocaEssa.textoSecundario),
              ),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline_rounded,
                    color: CoresTocaEssa.textoSecundario),
                tooltip: 'Excluir',
                onPressed: () => _excluirRepertorio(rep),
              ),
              onTap: () => _abrirDetalhe(rep),
            ),
          );
        },
      );
}

class _DetalheRepertorio extends StatefulWidget {
  const _DetalheRepertorio({required this.api, required this.repertorio});
  final ApiTocaEssa api;
  final Repertorio repertorio;

  @override
  State<_DetalheRepertorio> createState() => _DetalheRepertorioState();
}

class _DetalheRepertorioState extends State<_DetalheRepertorio> {
  late List<MusicaDoRepertorio> _musicas;
  bool _salvando = false;

  @override
  void initState() {
    super.initState();
    _musicas = List.from(widget.repertorio.musicas);
  }

  Future<void> _adicionarMusica() async {
    final resultado = await _pedirMusica(context);
    if (resultado == null || !mounted) return;
    setState(() => _salvando = true);
    try {
      final nova = await widget.api.adicionarMusicaAoRepertorio(
        widget.repertorio.id,
        resultado.$1,
        resultado.$2,
        tom: resultado.$3,
      );
      if (!mounted) return;
      setState(() => _musicas = [..._musicas, nova]);
    } catch (erro) {
      if (mounted) mostrarErro(context, erro);
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  Future<void> _editarMusica(MusicaDoRepertorio musica) async {
    final resultado = await _pedirMusica(
      context,
      tituloInicial: musica.titulo,
      artistaInicial: musica.artista,
      tomInicial: musica.tom,
    );
    if (resultado == null || !mounted) return;
    setState(() => _salvando = true);
    try {
      final editada = await widget.api.editarMusicaDoRepertorio(
        widget.repertorio.id,
        musica.id,
        resultado.$1,
        artista: resultado.$2,
        tom: resultado.$3,
      );
      if (!mounted) return;
      setState(() => _musicas =
          _musicas.map((m) => m.id == editada.id ? editada : m).toList());
    } catch (erro) {
      if (mounted) mostrarErro(context, erro);
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  Future<void> _removerMusica(MusicaDoRepertorio musica) async {
    setState(() => _salvando = true);
    try {
      await widget.api
          .removerMusicaDoRepertorio(widget.repertorio.id, musica.id);
      if (!mounted) return;
      setState(() =>
          _musicas = _musicas.where((m) => m.id != musica.id).toList());
    } catch (erro) {
      if (mounted) mostrarErro(context, erro);
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: Text(widget.repertorio.nome),
          actions: [
            IconButton(
              tooltip: 'Adicionar música',
              icon: const Icon(Icons.add_rounded),
              onPressed: _salvando ? null : _adicionarMusica,
            ),
          ],
        ),
        body: _musicas.isEmpty
            ? _construirVazio(context)
            : _construirLista(context),
      );

  Widget _construirVazio(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.music_note_rounded,
                  size: 48, color: CoresTocaEssa.borda),
              const SizedBox(height: 16),
              const Text(
                'Nenhuma música ainda',
                style: TextStyle(color: CoresTocaEssa.textoSecundario),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _adicionarMusica,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Adicionar música'),
              ),
            ],
          ),
        ),
      );

  Widget _construirLista(BuildContext context) => Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: _musicas.length,
              itemBuilder: (context, index) {
                final musica = _musicas[index];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: CoresTocaEssa.roxo.withValues(alpha: 0.15),
                    foregroundColor: CoresTocaEssa.roxoClaro,
                    radius: 18,
                    child: Text('${index + 1}',
                        style: const TextStyle(fontSize: 13)),
                  ),
                  title: Text(musica.titulo),
                  subtitle: (musica.artista != null || musica.tom != null)
                      ? Text(
                          [
                            if (musica.artista != null) musica.artista!,
                            if (musica.tom != null) 'Tom ${musica.tom}',
                          ].join(' · '),
                          style: const TextStyle(
                              color: CoresTocaEssa.textoSecundario,
                              fontSize: 12),
                        )
                      : null,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined,
                            color: CoresTocaEssa.roxoClaro, size: 20),
                        tooltip: 'Editar',
                        onPressed:
                            _salvando ? null : () => _editarMusica(musica),
                      ),
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline_rounded,
                            color: CoresTocaEssa.textoSecundario, size: 20),
                        tooltip: 'Remover',
                        onPressed:
                            _salvando ? null : () => _removerMusica(musica),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _salvando ? null : _adicionarMusica,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Adicionar música'),
              ),
            ),
          ),
        ],
      );
}

Future<String?> _pedirNome(
  BuildContext context, {
  required String titulo,
  required String rotulo,
}) async {
  final controller = TextEditingController();
  try {
    return await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(titulo),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(labelText: rotulo),
          textCapitalization: TextCapitalization.words,
          onSubmitted: (v) =>
              Navigator.pop(context, v.trim().isEmpty ? null : v.trim()),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar')),
          FilledButton(
            onPressed: () {
              final v = controller.text.trim();
              Navigator.pop(context, v.isEmpty ? null : v);
            },
            child: const Text('Criar'),
          ),
        ],
      ),
    );
  } finally {
    controller.dispose();
  }
}

Future<(String titulo, String? artista, String? tom)?> _pedirMusica(
    BuildContext context, {
  String? tituloInicial,
  String? artistaInicial,
  String? tomInicial,
}) async {
  final tituloCtrl = TextEditingController(text: tituloInicial);
  final artistaCtrl = TextEditingController(text: artistaInicial ?? '');
  final tomCtrl = TextEditingController(text: tomInicial ?? '');
  try {
    final editando = tituloInicial != null;
    return await showDialog<(String, String?, String?)>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(editando ? 'Editar música' : 'Adicionar música'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: tituloCtrl,
              autofocus: true,
              decoration:
                  const InputDecoration(labelText: 'Título da música'),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: artistaCtrl,
              decoration: const InputDecoration(
                  labelText: 'Artista (opcional)'),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: tomCtrl,
              decoration: const InputDecoration(
                labelText: 'Tom preferido (opcional)',
                hintText: 'Ex: Lá, Mi, Ré menor…',
                prefixIcon: Icon(Icons.music_note_rounded),
              ),
              textCapitalization: TextCapitalization.sentences,
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar')),
          FilledButton(
            onPressed: () {
              final t = tituloCtrl.text.trim();
              if (t.isEmpty) return;
              final a = artistaCtrl.text.trim();
              final tom = tomCtrl.text.trim();
              Navigator.pop(
                  context, (t, a.isEmpty ? null : a, tom.isEmpty ? null : tom));
            },
            child: Text(editando ? 'Salvar' : 'Adicionar'),
          ),
        ],
      ),
    );
  } finally {
    tituloCtrl.dispose();
    artistaCtrl.dispose();
    tomCtrl.dispose();
  }
}
