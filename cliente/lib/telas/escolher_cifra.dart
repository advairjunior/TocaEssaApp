import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../dominio/modelos.dart';
import '../infraestrutura/url_externa_validacao.dart';
import '../tema/tema_toca_essa.dart';
import 'componentes.dart';
import 'componentes_formulario.dart';
import 'componentes_lista.dart';

enum TipoDecisaoCifra { salvar, remover }

class DecisaoCifra {
  const DecisaoCifra(this.tipo, [this.url]);

  final TipoDecisaoCifra tipo;
  final String? url;
}

/// Abre a escolha de cifra em tela cheia: o link fica no topo e o botão de
/// confirmar fica na barra superior, onde o teclado virtual nunca o cobre.
///
/// Com [rotuloColarEProxima], a escolha faz parte de uma sequência: em cima
/// ficam Pesquisar na web e um botão que cola o link copiado e já confirma.
Future<DecisaoCifra?> mostrarEscolhaDeCifra(
  BuildContext context, {
  required String musica,
  required String? artista,
  required ResultadoCifraDoArtista resultado,
  required Future<void> Function(Uri url) abrirUrl,
  String? rotuloColarEProxima,
}) =>
    Navigator.of(context).push<DecisaoCifra>(MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => _EscolherCifra(
        musica: musica,
        artista: artista,
        resultado: resultado,
        abrirUrl: abrirUrl,
        rotuloColarEProxima: rotuloColarEProxima,
      ),
    ));

class _EscolherCifra extends StatefulWidget {
  const _EscolherCifra({
    required this.musica,
    required this.artista,
    required this.resultado,
    required this.abrirUrl,
    required this.rotuloColarEProxima,
  });

  final String musica;
  final String? artista;
  final ResultadoCifraDoArtista resultado;
  final Future<void> Function(Uri url) abrirUrl;
  final String? rotuloColarEProxima;

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

  Future<void> _colarLink() async {
    final dados = await Clipboard.getData(Clipboard.kTextPlain);
    final texto = dados?.text?.trim();
    if (texto == null || texto.isEmpty || !mounted) return;
    _url.text = texto;
  }

  /// Cola o link copiado da pesquisa e já confirma, num único toque.
  Future<void> _colarEConfirmar() async {
    final dados = await Clipboard.getData(Clipboard.kTextPlain);
    if (!mounted) return;
    final texto = dados?.text?.trim() ?? '';
    final endereco = Uri.tryParse(texto);
    if (endereco == null || !urlExternaPermitida(endereco)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Copie o link da cifra antes de colar.')),
      );
      return;
    }
    _salvar(texto);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: 'Fechar',
            icon: const Icon(Icons.close_rounded),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text('Escolher cifra'),
          actions: [
            TextButton(
              onPressed: () => _salvar(_url.text),
              child: const Text('Confirmar cifra'),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: ConteudoMobile(
          filho: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(widget.musica,
                  style: Theme.of(context).textTheme.titleLarge),
              if (widget.artista?.isNotEmpty == true)
                Text(
                  widget.artista!,
                  style: Theme.of(context)
                      .textTheme
                      .bodyLarge
                      ?.copyWith(color: CoresTocaEssa.textoSecundario),
                ),
              if (widget.rotuloColarEProxima case final rotulo?) ...[
                const SizedBox(height: EspacoTocaEssa.grande),
                OutlinedButton.icon(
                  onPressed: () => _abrir(widget.resultado.urlPesquisa),
                  icon: const Icon(Icons.search_rounded),
                  label: const Text('Pesquisar na web'),
                ),
                const SizedBox(height: EspacoTocaEssa.medio),
                FilledButton.icon(
                  onPressed: _colarEConfirmar,
                  icon: const Icon(Icons.content_paste_go_rounded),
                  label: Text(rotulo),
                ),
              ],
              const SizedBox(height: EspacoTocaEssa.grande),
              CampoTexto(
                rotulo: 'Link da cifra',
                controlador: _url,
                dica: 'https://...',
                teclado: TextInputType.url,
                aoEnviar: _salvar,
                sufixo: IconButton(
                  tooltip: 'Colar link',
                  icon: const Icon(Icons.content_paste_rounded),
                  onPressed: _colarLink,
                ),
              ),
              const SizedBox(height: EspacoTocaEssa.mini),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => _abrir(_url.text),
                  icon: const Icon(Icons.open_in_new_rounded),
                  label: const Text('Abrir link para conferir'),
                ),
              ),
              if (widget.rotuloColarEProxima == null ||
                  widget.resultado.urlSugerida != null) ...[
                const SizedBox(height: EspacoTocaEssa.enorme),
                const TituloGrupo('Não tem o link?'),
                const SizedBox(height: EspacoTocaEssa.mini),
              ],
              if (widget.resultado.urlSugerida case final sugestao?) ...[
                FilledButton.icon(
                  onPressed: () => _abrirSugestao(sugestao),
                  icon: const Icon(Icons.auto_awesome_rounded),
                  label: const Text('Abrir sugestão'),
                ),
                const SizedBox(height: 12),
              ],
              if (widget.rotuloColarEProxima == null)
                OutlinedButton.icon(
                  onPressed: () => _abrir(widget.resultado.urlPesquisa),
                  icon: const Icon(Icons.search_rounded),
                  label: const Text('Pesquisar na web'),
                ),
              if (widget.resultado.cifra != null) ...[
                const SizedBox(height: 32),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: CoresTocaEssa.rosa,
                    ),
                    onPressed: () => Navigator.pop(
                      context,
                      const DecisaoCifra(TipoDecisaoCifra.remover),
                    ),
                    icon: const Icon(Icons.link_off_rounded),
                    label: const Text('Remover link'),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
}
