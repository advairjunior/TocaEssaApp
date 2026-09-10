import 'package:flutter/material.dart';

import '../dominio/modelos.dart';
import '../tema/tema_toca_essa.dart';

enum TipoDecisaoCifra { salvar, remover }

class DecisaoCifra {
  const DecisaoCifra(this.tipo, [this.url]);

  final TipoDecisaoCifra tipo;
  final String? url;
}

Future<DecisaoCifra?> mostrarEscolhaDeCifra(
  BuildContext context, {
  required String musica,
  required String? artista,
  required ResultadoCifraDoArtista resultado,
  required Future<void> Function(Uri url) abrirUrl,
}) =>
    showDialog<DecisaoCifra>(
      context: context,
      builder: (_) => _EscolherCifra(
        musica: musica,
        artista: artista,
        resultado: resultado,
        abrirUrl: abrirUrl,
      ),
    );

class _EscolherCifra extends StatefulWidget {
  const _EscolherCifra({
    required this.musica,
    required this.artista,
    required this.resultado,
    required this.abrirUrl,
  });

  final String musica;
  final String? artista;
  final ResultadoCifraDoArtista resultado;
  final Future<void> Function(Uri url) abrirUrl;

  @override
  State<_EscolherCifra> createState() => _EscolherCifraState();
}

class _EscolherCifraState extends State<_EscolherCifra> {
  late final TextEditingController _url;

  @override
  void initState() {
    super.initState();
    _url = TextEditingController(text: widget.resultado.cifra?.url ?? '');
  }

  @override
  void dispose() {
    _url.dispose();
    super.dispose();
  }

  void _salvar(String url) {
    final valor = url.trim();
    if (valor.isEmpty) return;
    Navigator.pop(
      context,
      DecisaoCifra(TipoDecisaoCifra.salvar, valor),
    );
  }

  Future<void> _abrir(String url) async {
    final endereco = Uri.tryParse(url.trim());
    if (endereco == null || !endereco.hasScheme) return;
    try {
      await widget.abrirUrl(endereco);
    } catch (erro) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(erro.toString())),
      );
    }
  }

  Future<void> _abrirSugestao(String sugestao) async {
    _url.text = sugestao;
    await _abrir(sugestao);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Escolher cifra'),
        content: SizedBox(
          width: 440,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(widget.musica,
                    style: Theme.of(context).textTheme.titleMedium),
                if (widget.artista?.isNotEmpty == true)
                  Text(widget.artista!,
                      style: const TextStyle(
                          color: CoresTocaEssa.textoSecundario)),
                if (widget.resultado.urlSugerida case final sugestao?) ...[
                  const SizedBox(height: 20),
                  const Text('Sugestão do Cifra Club'),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: () => _abrirSugestao(sugestao),
                    icon: const Icon(Icons.auto_awesome_rounded),
                    label: const Text('Abrir sugestão'),
                  ),
                ],
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => _abrir(widget.resultado.urlPesquisa),
                  icon: const Icon(Icons.search_rounded),
                  label: const Text('Pesquisar na web'),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _url,
                  keyboardType: TextInputType.url,
                  decoration: const InputDecoration(
                    labelText: 'Link da cifra',
                    hintText: 'https://...',
                    prefixIcon: Icon(Icons.link_rounded),
                  ),
                  onSubmitted: _salvar,
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () => _abrir(_url.text),
                  icon: const Icon(Icons.open_in_new_rounded),
                  label: const Text('Abrir link para conferir'),
                ),
              ],
            ),
          ),
        ),
        actions: [
          if (widget.resultado.cifra != null)
            TextButton(
              onPressed: () => Navigator.pop(
                context,
                const DecisaoCifra(TipoDecisaoCifra.remover),
              ),
              child: const Text('Remover link'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => _salvar(_url.text),
            child: const Text('Confirmar cifra'),
          ),
        ],
      );
}
