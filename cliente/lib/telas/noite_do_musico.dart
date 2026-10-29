import 'package:flutter/material.dart';

import '../dominio/modelos.dart';
import '../dominio/musicos_da_noite.dart';
import '../infraestrutura/api_toca_essa.dart';
import '../infraestrutura/assinatura_tempo_real.dart';
import '../tema/tema_toca_essa.dart';
import 'componentes.dart';
import 'leitor_de_cifras.dart';
import 'sequencia_do_palco.dart';

/// A noite de outro artista para o músico convidado: a setlist e os pedidos
/// do dono, em ordem, e o leitor com as cifras que o dono preparou. Montar
/// a setlist, recusar pedido e encerrar continuam com o dono.
class NoiteDoMusico extends StatefulWidget {
  const NoiteDoMusico({
    super.key,
    required this.api,
    required this.evento,
    required this.artistaId,
    required this.abrirUrl,
  });

  final ApiTocaEssa api;
  final EventoConvidado evento;
  // A conta de quem abriu, para sair do evento.
  final String artistaId;
  final Future<void> Function(Uri url) abrirUrl;

  @override
  State<NoiteDoMusico> createState() => _NoiteDoMusicoState();
}

class _NoiteDoMusicoState extends State<NoiteDoMusico> {
  late final _sequencia = SequenciaDoConvidado(
    api: widget.api,
    apresentacaoId: widget.evento.apresentacaoId,
    codigo: widget.evento.codigo,
    vocabulario: widget.evento.tipo.vocabulario,
  )..addListener(_redesenhar);
  AssinaturaTempoReal? _tempoReal;
  bool _carregando = true;
  String? _falha;

  @override
  void initState() {
    super.initState();
    _carregar();
    // O que o dono muda (setlist, pedidos, tocadas) chega na hora.
    _tempoReal = AssinaturaTempoReal(
        widget.api.enderecoTempoReal(widget.evento.codigo),
        _sequencia.recarregar);
  }

  @override
  void dispose() {
    _tempoReal?.encerrar();
    _sequencia
      ..removeListener(_redesenhar)
      ..dispose();
    super.dispose();
  }

  void _redesenhar() {
    if (mounted) setState(() {});
  }

  Future<void> _carregar() async {
    try {
      await _sequencia.carregar();
      _falha = null;
      await _sequencia.buscarCifras();
    } catch (erro) {
      _falha = '$erro';
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  Future<void> _abrirLeitor(MusicaDoPalco musica) =>
      Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => LeitorDeCifras(
          sequencia: _sequencia,
          musicaInicial: musica,
          abrirUrl: widget.abrirUrl,
        ),
      ));

  Future<void> _sair() async {
    final confirmou = await showDialog<bool>(
      context: context,
      builder: (contexto) => AlertDialog(
        title: const Text('Sair do evento?'),
        content: Text('A ${widget.evento.nome} some dos seus Convites. Para '
            'voltar, peça um link novo para ${widget.evento.dono}.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(contexto).pop(false),
              child: const Text('Ficar')),
          FilledButton(
              onPressed: () => Navigator.of(contexto).pop(true),
              child: const Text('Sair')),
        ],
      ),
    );
    if (confirmou != true || !mounted) return;
    final navegador = Navigator.of(context);
    try {
      await widget.api
          .tirarMusico(widget.evento.apresentacaoId, widget.artistaId);
      navegador.pop(true);
    } catch (erro) {
      if (mounted) mostrarErro(context, erro);
    }
  }

  @override
  Widget build(BuildContext context) {
    final paginas = _sequencia.paginasDoLeitor;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.evento.nome),
        actions: [
          IconButton(
            tooltip: 'Sair do evento',
            icon: const Icon(Icons.logout_rounded),
            onPressed: _sair,
          ),
        ],
      ),
      floatingActionButton: paginas.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _abrirLeitor(
                  _sequencia.atual ?? _sequencia.proxima ?? paginas.first),
              icon: const Icon(Icons.menu_book_rounded),
              label: const Text('Leitor'),
            ),
      body: _carregando
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _sequencia.recarregar,
              child: ListView(
                padding: const EdgeInsets.all(EspacoTocaEssa.base),
                children: [
                  Text(
                      'de ${widget.evento.dono} · '
                      '${formatarData(widget.evento.data)}',
                      style: const TextStyle(
                          color: CoresTocaEssa.textoSecundario)),
                  const SizedBox(height: EspacoTocaEssa.base),
                  if (_falha case final falha?) Text(falha),
                  if (paginas.isEmpty && _falha == null)
                    Text('A ${_sequencia.vocabulario.setlist} ainda está '
                        'vazia.'),
                  for (final musica in paginas)
                    _LinhaDaMusica(
                      musica: musica,
                      tocando: _sequencia.estaTocando(musica),
                      abrir: () => _abrirLeitor(musica),
                    ),
                  const SizedBox(height: 88),
                ],
              ),
            ),
    );
  }
}

class _LinhaDaMusica extends StatelessWidget {
  const _LinhaDaMusica({
    required this.musica,
    required this.tocando,
    required this.abrir,
  });

  final MusicaDoPalco musica;
  final bool tocando;
  final VoidCallback abrir;

  @override
  Widget build(BuildContext context) {
    final tocada = musica.item?.tocada ?? false;
    final detalhes = [
      if (musica.artista case final artista? when artista.isNotEmpty) artista,
      if (musica.tom case final tom? when tom.isNotEmpty) 'Tom $tom',
      if (musica.pedido case final pedido?)
        'Pedida por ${pedido.solicitantes.join(', ')}',
    ];
    return ListTile(
      onTap: abrir,
      leading: Icon(
        tocando
            ? Icons.graphic_eq_rounded
            : tocada
                ? Icons.check_circle_rounded
                : Icons.music_note_rounded,
        color: tocando ? CoresTocaEssa.rosa : CoresTocaEssa.textoSecundario,
      ),
      title: Text(musica.titulo,
          style:
              TextStyle(color: tocada ? CoresTocaEssa.textoSecundario : null)),
      subtitle: detalhes.isEmpty ? null : Text(detalhes.join(' · ')),
    );
  }
}
