import 'package:flutter/material.dart';

import '../dominio/modelos.dart';
import '../infraestrutura/abrir_url_externa.dart';
import '../infraestrutura/api_toca_essa.dart';
import '../tema/tema_toca_essa.dart';
import 'colar_cifras.dart';
import 'componentes.dart';
import 'componentes_formulario.dart';
import 'componentes_lista.dart';
import 'escolher_para_repertorio.dart';
import 'leitor_de_cifras.dart';
import 'lista_reordenavel.dart';

part 'gerenciar_repertorios_detalhe.dart';
part 'gerenciar_repertorios_formularios.dart';

class GerenciarRepertorios extends StatefulWidget {
  const GerenciarRepertorios({
    super.key,
    required this.api,
    this.abrirUrl = abrirNaAbaDaCifra,
  });
  final ApiTocaEssa api;
  final Future<void> Function(Uri url) abrirUrl;

  @override
  State<GerenciarRepertorios> createState() => _GerenciarRepertoriosState();
}

class _GerenciarRepertoriosState extends State<GerenciarRepertorios> {
  List<Repertorio> _repertorios = [];
  // Pedidas pelo público nos shows e ainda fora de todos os repertórios.
  List<PedidaForaDoRepertorio> _pedidas = [];
  bool _carregando = true;

  @override
  void initState() {
    super.initState();
    _carregar();
    _carregarPedidas();
  }

  Future<void> _carregarPedidas() async {
    try {
      final pedidas = await widget.api.listarPedidasForaDoRepertorio();
      if (mounted) setState(() => _pedidas = pedidas);
    } catch (_) {
      // Sem a lista, a tela segue só com os repertórios.
    }
  }

  Future<void> _levarPedidas() async {
    await escolherParaRepertorio(
      context,
      api: widget.api,
      titulo: 'Pedidas pelo público',
      opcoes: [
        for (final pedida in _pedidas)
          OpcaoParaRepertorio(
            musica: (titulo: pedida.musica, artista: pedida.artista, tom: null),
            detalhe: pedida.resumo,
          ),
      ],
    );
    if (!mounted) return;
    await Future.wait([_carregar(), _carregarPedidas()]);
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
    final nome = await _pedirNome(context,
        titulo: 'Novo repertório', rotulo: 'Nome do repertório');
    if (nome == null || !mounted) return;
    try {
      final criado = await widget.api.criarRepertorio(nome);
      if (!mounted) return;
      _abrirDetalhe(criado); // a lista é recarregada ao voltar via _carregar()
    } catch (erro) {
      if (mounted) mostrarErro(context, erro);
    }
  }

  void _abrirDetalhe(Repertorio rep) {
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => _DetalheRepertorio(
            api: widget.api, repertorio: rep, abrirUrl: widget.abrirUrl),
      ),
    ).then((_) {
      if (mounted) _carregar();
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Meus repertórios'),
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
                ? Center(
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const EstadoVazio(
                            icone: Icons.queue_music_rounded,
                            titulo: 'Nenhum repertório ainda',
                            descricao:
                                'Crie um repertório com as músicas do seu show '
                                'e importe no setlist de cada apresentação.',
                          ),
                          FilledButton.icon(
                            onPressed: _criarRepertorio,
                            icon: const Icon(Icons.add_rounded),
                            label: const Text('Criar repertório'),
                          ),
                        ],
                      ),
                    ),
                  )
                : ConteudoMobile(
                    filho: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (_pedidas.isNotEmpty) ...[
                          _CartaoPedidas(pedidas: _pedidas, ver: _levarPedidas),
                          const SizedBox(height: EspacoTocaEssa.base),
                        ],
                        GrupoDeLinhas(
                          linhas: [
                            for (final rep in _repertorios)
                              _LinhaRepertorio(
                                repertorio: rep,
                                abrir: () => _abrirDetalhe(rep),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
      );
}

/// As três mais pedidas fora do acervo e o atalho para levar todas.
class _CartaoPedidas extends StatelessWidget {
  const _CartaoPedidas({required this.pedidas, required this.ver});

  final List<PedidaForaDoRepertorio> pedidas;
  final VoidCallback ver;

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(EspacoTocaEssa.base),
      decoration: BoxDecoration(
        color: CoresTocaEssa.superficie,
        borderRadius: BorderRadius.circular(RaioTocaEssa.cartao),
        border: Border.all(color: CoresTocaEssa.borda),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Pedidas pelo público', style: texto.titleMedium),
          Text('Ainda fora dos seus repertórios',
              style: texto.bodySmall
                  ?.copyWith(color: CoresTocaEssa.textoSecundario)),
          const SizedBox(height: EspacoTocaEssa.pequeno),
          for (final pedida in pedidas.take(3))
            Padding(
              padding: const EdgeInsets.only(top: EspacoTocaEssa.mini),
              child: Text('${pedida.musica} · ${pedida.resumo}'),
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: ver,
              icon: const Icon(Icons.library_add_rounded),
              label: Text(pedidas.length == 1
                  ? 'Ver e adicionar'
                  : 'Ver as ${pedidas.length} e adicionar'),
            ),
          ),
        ],
      ),
    );
  }
}

class _LinhaRepertorio extends StatelessWidget {
  const _LinhaRepertorio({required this.repertorio, required this.abrir});
  final Repertorio repertorio;
  final VoidCallback abrir;

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    final total = repertorio.musicas.length;
    return Semantics(
      button: true,
      child: InkWell(
        onTap: abrir,
        child: Padding(
          padding: const EdgeInsets.all(EspacoTocaEssa.base),
          child: Row(
            children: [
              const Icon(Icons.queue_music_rounded,
                  size: 20, color: CoresTocaEssa.roxoClaro),
              const SizedBox(width: EspacoTocaEssa.base),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(repertorio.nome, style: texto.titleMedium),
                    Text(
                      '$total ${total == 1 ? 'música' : 'músicas'}',
                      style: texto.bodyMedium
                          ?.copyWith(color: CoresTocaEssa.textoSecundario),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded,
                  color: CoresTocaEssa.textoSecundario),
            ],
          ),
        ),
      ),
    );
  }
}
