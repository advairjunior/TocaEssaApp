import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../infraestrutura/api_toca_essa.dart';
import '../tema/tema_toca_essa.dart';
import 'componentes.dart';

/// Uma música sem cifra colada e onde achar a cifra dela.
typedef MusicaParaColar = ({
  String titulo,
  String? artista,
  // Link salvo da cifra; sem ele, abre a pesquisa pronta.
  String? url,
  String urlPesquisa,
});

/// Passa pelas músicas sem cifra, uma por vez: abrir no site, copiar lá,
/// voltar e Colar e próxima. Fecha ao acabar ou ao pular a última.
class ColarCifras extends StatefulWidget {
  const ColarCifras({
    super.key,
    required this.api,
    required this.musicas,
    required this.abrirUrl,
  });

  final ApiTocaEssa api;
  final List<MusicaParaColar> musicas;
  final Future<void> Function(Uri url) abrirUrl;

  @override
  State<ColarCifras> createState() => _ColarCifrasState();
}

class _ColarCifrasState extends State<ColarCifras> {
  int _indice = 0;
  bool _salvando = false;

  MusicaParaColar get _atual => widget.musicas[_indice];
  bool get _ultima => _indice == widget.musicas.length - 1;

  void _avancar() {
    if (_ultima) {
      Navigator.pop(context);
    } else {
      setState(() => _indice++);
    }
  }

  Future<void> _abrirNoSite() async {
    final atual = _atual;
    try {
      await widget.abrirUrl(Uri.parse(atual.url ?? atual.urlPesquisa));
    } catch (erro) {
      if (mounted) mostrarErro(context, erro);
    }
  }

  Future<void> _colarEProxima() async {
    final copiado = (await Clipboard.getData(Clipboard.kTextPlain))?.text;
    if (!mounted) return;
    if (copiado == null || copiado.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Copie a cifra antes de colar.')));
      return;
    }
    setState(() => _salvando = true);
    try {
      final musica = _atual;
      await widget.api
          .salvarCifraEmTexto(musica.titulo, musica.artista, copiado);
      if (mounted) _avancar();
    } catch (erro) {
      if (mounted) mostrarErro(context, erro);
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    final musica = _atual;
    return Scaffold(
      appBar: AppBar(title: const Text('Colar cifras')),
      body: ConteudoMobile(
        filho: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('${_indice + 1} de ${widget.musicas.length}',
                style: texto.labelLarge
                    ?.copyWith(color: CoresTocaEssa.textoSecundario)),
            const SizedBox(height: EspacoTocaEssa.pequeno),
            Text(musica.titulo, style: texto.headlineSmall),
            if (musica.artista != null)
              Text(musica.artista!,
                  style: texto.bodyLarge
                      ?.copyWith(color: CoresTocaEssa.textoSecundario)),
            const SizedBox(height: EspacoTocaEssa.grande),
            OutlinedButton.icon(
              onPressed: _abrirNoSite,
              icon: const Icon(Icons.open_in_new_rounded),
              label: const Text('Abrir no Cifra Club'),
            ),
            const SizedBox(height: EspacoTocaEssa.pequeno),
            Text(
              'Lá, selecione e copie a cifra. Depois volte aqui.',
              textAlign: TextAlign.center,
              style: texto.bodySmall
                  ?.copyWith(color: CoresTocaEssa.textoSecundario),
            ),
            const SizedBox(height: EspacoTocaEssa.grande),
            FilledButton.icon(
              style: FilledButton.styleFrom(minimumSize: const Size(0, 52)),
              onPressed: _salvando ? null : _colarEProxima,
              icon: const Icon(Icons.content_paste_rounded),
              label: Text(_ultima ? 'Colar e concluir' : 'Colar e próxima'),
            ),
            const SizedBox(height: EspacoTocaEssa.pequeno),
            TextButton(
              onPressed: _salvando ? null : _avancar,
              child: const Text('Pular'),
            ),
          ],
        ),
      ),
    );
  }
}
