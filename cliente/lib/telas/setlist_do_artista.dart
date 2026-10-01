import 'package:flutter/material.dart';

import '../dominio/modelos.dart';
import '../infraestrutura/api_toca_essa.dart';
import '../infraestrutura/abrir_url_externa.dart';
import '../tema/tema_toca_essa.dart';
import 'componentes.dart';
import 'escolher_cifra.dart';

class SetlistDoArtista extends StatefulWidget {
  const SetlistDoArtista({
    super.key,
    required this.api,
    required this.apresentacao,
    this.incorporada = false,
    this.abrirUrl = abrirUrlExterna,
    this.prepararAbertura = prepararAberturaExterna,
  });

  final ApiTocaEssa api;
  final Apresentacao apresentacao;
  final bool incorporada;
  final Future<void> Function(Uri url) abrirUrl;
  final FinalizarAberturaExterna Function() prepararAbertura;

  @override
  State<SetlistDoArtista> createState() => _SetlistDoArtistaState();
}

class _SetlistDoArtistaState extends State<SetlistDoArtista> {
  List<ItemDoSetlist> _itens = [];
  bool _carregando = true;
  bool _salvando = false;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    try {
      final itens = await widget.api.obterSetlist(widget.apresentacao.id);
      if (!mounted) return;
      setState(() => _itens = itens);
    } catch (erro) {
      if (mounted) mostrarErro(context, erro);
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  Future<void> _marcar(ItemDoSetlist item, bool tocada) async {
    setState(() => _salvando = true);
    try {
      final atualizado = await widget.api
          .marcarItemDoSetlist(widget.apresentacao.id, item.id, tocada);
      if (!mounted) return;
      setState(() {
        _itens = _itens
            .map((i) => i.id == atualizado.id ? atualizado : i)
            .toList();
      });
    } catch (erro) {
      if (mounted) mostrarErro(context, erro);
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  Future<void> _abrirCifra(ItemDoSetlist item) async {
    FinalizarAberturaExterna? finalizar;
    try {
      finalizar = widget.prepararAbertura();
      final resultado =
          await widget.api.consultarCifra(item.titulo, item.artista);
      if (!mounted) {
        await finalizar(null);
        return;
      }
      if (resultado.cifra != null) {
        await finalizar(Uri.parse(resultado.cifra!.url));
        return;
      }
      await finalizar(null);
      if (!mounted) return;
      final decisao = await mostrarEscolhaDeCifra(
        context,
        musica: item.titulo,
        artista: item.artista,
        resultado: resultado,
        abrirUrl: widget.abrirUrl,
      );
      if (decisao == null || !mounted) return;
      if (decisao.tipo == TipoDecisaoCifra.salvar) {
        await widget.api.salvarCifra(item.titulo, item.artista, decisao.url!);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Cifra salva.')),
          );
        }
      }
    } catch (erro) {
      await finalizar?.call(null);
      if (mounted) mostrarErro(context, erro);
    }
  }

  Future<void> _mostrarImportarRepertorio() async {
    List<Repertorio>? repertorios;
    try {
      repertorios = await widget.api.listarRepertorios();
    } catch (erro) {
      if (mounted) mostrarErro(context, erro);
      return;
    }
    if (!mounted) return;

    if (repertorios.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Nenhum repertório criado. Crie um na aba Perfil geral.'),
        ),
      );
      return;
    }

    final selecionado = await showModalBottomSheet<Repertorio>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: CoresTocaEssa.superficie,
      builder: (_) => _SelecionarRepertorioSheet(repertorios: repertorios!),
    );
    if (selecionado == null || !mounted) return;

    setState(() => _carregando = true);
    try {
      final novos = await widget.api.importarRepertorioParaSetlist(
          widget.apresentacao.id, selecionado.id);
      if (!mounted) return;
      setState(() => _itens = novos);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                'Repertório "${selecionado.nome}" importado.')),
      );
    } catch (erro) {
      if (mounted) mostrarErro(context, erro);
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  int get _tocadas => _itens.where((i) => i.tocada).length;

  @override
  Widget build(BuildContext context) {
    if (!widget.incorporada) {
      return Scaffold(
        appBar: AppBar(title: const Text('Setlist')),
        body: _construirCorpo(context),
      );
    }
    return _construirCorpo(context);
  }

  Widget _construirCorpo(BuildContext context) {
    if (_carregando) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_itens.isEmpty) {
      return _construirVazio(context);
    }
    return Column(
      children: [
        Expanded(child: _construirLista()),
        _construirRodape(context),
      ],
    );
  }

  Widget _construirVazio(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.playlist_play_rounded,
                  size: 64, color: CoresTocaEssa.borda),
              const SizedBox(height: 16),
              Text(
                'Nenhum repertório nesta apresentação',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              const Text(
                'Importe um repertório para começar.',
                textAlign: TextAlign.center,
                style: TextStyle(color: CoresTocaEssa.textoSecundario),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _mostrarImportarRepertorio,
                icon: const Icon(Icons.playlist_add_rounded),
                label: const Text('Importar repertório'),
              ),
            ],
          ),
        ),
      );

  Widget _construirLista() => ListView.builder(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
        itemCount: _itens.length,
        itemBuilder: (context, index) {
          final item = _itens[index];
          return _CartaoItemSetlist(
            item: item,
            salvando: _salvando,
            onMarcar: (tocada) => _marcar(item, tocada),
            onCifra: () => _abrirCifra(item),
          );
        },
      );

  Widget _construirRodape(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: CoresTocaEssa.borda)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                '$_tocadas/${_itens.length} tocadas',
                style: const TextStyle(color: CoresTocaEssa.textoSecundario),
              ),
            ),
            TextButton.icon(
              onPressed: _mostrarImportarRepertorio,
              icon: const Icon(Icons.swap_horiz_rounded, size: 18),
              label: const Text('Trocar repertório'),
            ),
          ],
        ),
      );
}

class _CartaoItemSetlist extends StatelessWidget {
  const _CartaoItemSetlist({
    required this.item,
    required this.salvando,
    required this.onMarcar,
    required this.onCifra,
  });

  final ItemDoSetlist item;
  final bool salvando;
  final ValueChanged<bool> onMarcar;
  final VoidCallback onCifra;

  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.symmetric(vertical: 4),
        color: item.tocada
            ? CoresTocaEssa.superficieElevada.withValues(alpha: 0.5)
            : CoresTocaEssa.superficieElevada,
        child: ListTile(
          contentPadding: const EdgeInsets.fromLTRB(4, 0, 8, 0),
          leading: Checkbox(
            value: item.tocada,
            onChanged: salvando ? null : (v) => onMarcar(v ?? false),
            activeColor: CoresTocaEssa.roxo,
          ),
          title: Text(
            item.titulo,
            style: TextStyle(
              decoration: item.tocada ? TextDecoration.lineThrough : null,
              color: item.tocada ? CoresTocaEssa.textoSecundario : null,
            ),
          ),
          subtitle: item.artista != null
              ? Text(
                  item.artista!,
                  style: const TextStyle(
                    color: CoresTocaEssa.textoSecundario,
                    fontSize: 12,
                  ),
                )
              : null,
          trailing: IconButton(
            tooltip: 'Ver cifra',
            icon: const Icon(Icons.library_music_outlined,
                color: CoresTocaEssa.roxoClaro, size: 20),
            onPressed: onCifra,
          ),
        ),
      );
}

class _SelecionarRepertorioSheet extends StatelessWidget {
  const _SelecionarRepertorioSheet({required this.repertorios});
  final List<Repertorio> repertorios;

  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
            child: Text(
              'Selecionar repertório',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          for (final rep in repertorios)
            ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
              title: Text(rep.nome),
              subtitle: Text(
                '${rep.musicas.length} '
                '${rep.musicas.length == 1 ? 'música' : 'músicas'}',
                style: const TextStyle(color: CoresTocaEssa.textoSecundario),
              ),
              trailing:
                  const Icon(Icons.arrow_forward_ios_rounded, size: 14),
              onTap: () => Navigator.pop(context, rep),
            ),
          const SizedBox(height: 16),
        ],
      );
}
