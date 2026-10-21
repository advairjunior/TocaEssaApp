import 'package:flutter/material.dart';

import '../dominio/modelos.dart';
import '../infraestrutura/api_toca_essa.dart';
import '../tema/tema_toca_essa.dart';
import 'adicionar_ao_repertorio.dart';
import 'componentes.dart';

/// Uma linha da escolha: a música, o que ajuda a decidir ("pedida 3x ·
/// fora do acervo") e se começa marcada.
class OpcaoParaRepertorio {
  const OpcaoParaRepertorio({
    required this.musica,
    this.detalhe,
    this.marcada = true,
  });

  final MusicaParaRepertorio musica;
  final String? detalhe;
  final bool marcada;
}

/// Tela para marcar músicas (da setlist, hinos ou pedidos) e levá-las a um
/// repertório pela folha [adicionarAoRepertorio]; fecha depois de salvar.
Future<void> escolherParaRepertorio(
  BuildContext context, {
  required ApiTocaEssa api,
  required String titulo,
  required List<OpcaoParaRepertorio> opcoes,
  String nomeSugerido = '',
  Vocabulario vocabulario = Vocabulario.musical,
}) =>
    Navigator.of(context).push<void>(MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => _EscolherParaRepertorio(
        api: api,
        titulo: titulo,
        opcoes: opcoes,
        nomeSugerido: nomeSugerido,
        v: vocabulario,
      ),
    ));

class _EscolherParaRepertorio extends StatefulWidget {
  const _EscolherParaRepertorio({
    required this.api,
    required this.titulo,
    required this.opcoes,
    required this.nomeSugerido,
    required this.v,
  });

  final ApiTocaEssa api;
  final String titulo;
  final List<OpcaoParaRepertorio> opcoes;
  final String nomeSugerido;
  final Vocabulario v;

  @override
  State<_EscolherParaRepertorio> createState() =>
      _EscolherParaRepertorioState();
}

class _EscolherParaRepertorioState extends State<_EscolherParaRepertorio> {
  // Posições marcadas; a ordem enviada é sempre a da lista.
  late final Set<int> _marcadas = {
    for (final (indice, opcao) in widget.opcoes.indexed)
      if (opcao.marcada) indice,
  };
  final _busca = TextEditingController();
  static const _opcoesParaBuscar = 10;

  Vocabulario get _v => widget.v;

  @override
  void dispose() {
    _busca.dispose();
    super.dispose();
  }

  bool _achada(OpcaoParaRepertorio opcao) {
    final termo = normalizarMusica(_busca.text);
    return normalizarMusica(
            '${opcao.musica.titulo} ${opcao.musica.artista ?? ''}')
        .contains(termo);
  }

  void _alternar(int indice) => setState(() => _marcadas.contains(indice)
      ? _marcadas.remove(indice)
      : _marcadas.add(indice));

  void _alternarTodas(bool todas) => setState(() => todas
      ? _marcadas.addAll(List.generate(widget.opcoes.length, (i) => i))
      : _marcadas.clear());

  Future<void> _adicionar() async {
    final resultado = await adicionarAoRepertorio(
      context,
      api: widget.api,
      musicas: [
        for (final (indice, opcao) in widget.opcoes.indexed)
          if (_marcadas.contains(indice)) opcao.musica,
      ],
      nomeSugerido: widget.nomeSugerido,
      vocabulario: _v,
    );
    if (resultado != null && mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    final quantas = _marcadas.length;
    final todas = quantas == widget.opcoes.length;
    return Scaffold(
      appBar: AppBar(title: Text(widget.titulo)),
      body: ConteudoMobile(
        filho: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.opcoes.length >= _opcoesParaBuscar) ...[
              TextField(
                controller: _busca,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: _v.buscar,
                  prefixIcon: const Icon(Icons.search_rounded),
                ),
              ),
              const SizedBox(height: EspacoTocaEssa.pequeno),
            ],
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: todas ? true : (quantas == 0 ? false : null),
              tristate: true,
              onChanged: (_) => _alternarTodas(!todas),
              title: Text(_v.todas, style: texto.titleMedium),
            ),
            const Divider(height: 1),
            for (final (indice, opcao) in widget.opcoes.indexed)
              if (_achada(opcao))
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: _marcadas.contains(indice),
                  onChanged: (_) => _alternar(indice),
                  title: Text(opcao.musica.titulo),
                  subtitle: switch ([
                    if (opcao.musica.artista case final artista?) artista,
                    if (opcao.detalhe case final detalhe?) detalhe,
                  ]) {
                    final partes when partes.isNotEmpty => Text(
                        partes.join(' · '),
                        style: texto.bodySmall
                            ?.copyWith(color: CoresTocaEssa.textoSecundario)),
                    _ => null,
                  },
                ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(EspacoTocaEssa.base),
          child: FilledButton.icon(
            onPressed: quantas == 0 ? null : _adicionar,
            icon: const Icon(Icons.library_add_rounded),
            label: Text(quantas == 0
                ? 'Nada marcado'
                : 'Adicionar $quantas '
                    '${quantas == 1 ? _v.musica : _v.musicas} ao repertório'),
          ),
        ),
      ),
    );
  }
}
