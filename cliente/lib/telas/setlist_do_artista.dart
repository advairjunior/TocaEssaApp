import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

import '../dominio/modelos.dart';
import '../infraestrutura/api_toca_essa.dart';
import '../infraestrutura/abrir_url_externa.dart';
import '../tema/tema_toca_essa.dart';
import 'componentes.dart';
import 'componentes_lista.dart';
import 'componentes_movimento.dart';
import 'componentes_palco.dart';
import '../infraestrutura/assinatura_tempo_real.dart';
import 'acoes_do_palco.dart';
import 'colar_cifras.dart';
import 'escolher_para_repertorio.dart';
import 'leitor_de_cifras.dart';
import 'lista_reordenavel.dart';
import 'montar_setlist.dart';
import 'sequencia_do_palco.dart';

part 'setlist_do_artista_acoes.dart';
part 'setlist_do_artista_construcao.dart';
part 'setlist_do_artista_linhas.dart';

class SetlistDoArtista extends StatefulWidget {
  const SetlistDoArtista({
    super.key,
    required this.api,
    required this.apresentacao,
    this.incorporada = false,
    this.abrirUrl = abrirNaAbaDaCifra,
    this.prepararAbertura = prepararAberturaNaAbaDaCifra,
    this.abrirFila,
  });

  final ApiTocaEssa api;
  final Apresentacao apresentacao;
  final bool incorporada;
  // Selo de pedidos novos leva à aba Fila do painel.
  final VoidCallback? abrirFila;
  final Future<void> Function(Uri url) abrirUrl;
  final FinalizarAberturaExterna Function() prepararAbertura;

  @override
  State<SetlistDoArtista> createState() => _SetlistDoArtistaState();
}

class _SetlistDoArtistaState extends State<SetlistDoArtista>
    with AcoesDoPalco<SetlistDoArtista> {
  @override
  SequenciaDoPalco get sequencia => _sequencia;
  @override
  ApiTocaEssa get api => widget.api;
  @override
  Future<void> Function(Uri url) get abrirUrl => widget.abrirUrl;
  @override
  FinalizarAberturaExterna Function() get prepararAbertura =>
      widget.prepararAbertura;

  late final SequenciaDoPalco _sequencia = SequenciaDoPalco(
    api: widget.api,
    apresentacaoId: widget.apresentacao.id,
    codigo: widget.apresentacao.codigo,
    vocabulario: _v,
  )..addListener(_redesenhar);
  Vocabulario get _v => widget.apresentacao.tipo.vocabulario;
  bool _carregando = true;
  bool _editando = false;
  // Busca pelo título ou cantor; com muitas músicas, rolar cansa.
  final _busca = TextEditingController();
  static const _musicasParaBuscar = 10;
  // Acervo do artista, para avisar o que está fora dele.
  List<Repertorio>? _repertorios;
  // Só antes do show: horas contratadas e ritmo médio para estimar a setlist.
  RelogioDoShow? _relogio;

  AssinaturaTempoReal? _tempoReal;
  Timer? _atualizacaoAutomatica;

  @override
  void initState() {
    super.initState();
    _carregar();
    _carregarRelogio();
    _carregarRepertorios();
    // Acompanha o que os outros aparelhos da banda fazem no show.
    _tempoReal = AssinaturaTempoReal(
      widget.api.enderecoTempoReal(widget.apresentacao.codigo),
      _sequencia.recarregar,
    );
    _atualizacaoAutomatica = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _sequencia.recarregar(),
    );
  }

  Future<void> _carregarRelogio() async {
    try {
      final relogio = await widget.api.obterRelogio(widget.apresentacao.id);
      if (mounted) setState(() => _relogio = relogio);
    } catch (_) {
      // Sem a estimativa, a setlist segue normal.
    }
  }

  @override
  void dispose() {
    _tempoReal?.encerrar();
    _atualizacaoAutomatica?.cancel();
    _sequencia.dispose();
    _busca.dispose();
    super.dispose();
  }

  void _redesenhar() {
    if (mounted) setState(() {});
  }

  Future<void> _carregar() async {
    try {
      await _sequencia.carregar();
    } catch (erro) {
      if (mounted) mostrarErro(context, erro);
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  void _mudarEstado(VoidCallback acao) => setState(acao);

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
      return const EsqueletoDeLista();
    }
    if (_sequencia.itens.isEmpty) {
      return _construirVazio();
    }
    final proxima = _sequencia.proxima;
    final temBarra = proxima != null || ultimaComecada != null;
    // A lista passa por trás da barra translúcida, como no iPhone.
    return Stack(
      children: [
        Positioned.fill(
          child: _construirLista(context, proxima?.item, temBarra: temBarra),
        ),
        if (temBarra)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: BarraProximaMusica(
              titulo: proxima?.titulo,
              detalhe: _sequencia.detalheDaProxima,
              salvando: _sequencia.salvando,
              tocar: tocarProxima,
              comecou: ultimaComecada?.titulo,
              desfazer: desfazerUltima,
            ),
          ),
      ],
    );
  }

  bool get _mostraBusca =>
      !_editando && _sequencia.itens.length >= _musicasParaBuscar;

  String get _termo => _mostraBusca ? normalizarMusica(_busca.text) : '';

  bool _achada(ItemDoSetlist item) =>
      combinaComBusca(_termo, [item.titulo, item.artista]);

  void _limparBusca() => setState(_busca.clear);
}

/// Busca sem nenhuma música achada, com o atalho para limpar.
class _SemResultado extends StatelessWidget {
  const _SemResultado({required this.texto, required this.limpar});

  final String texto;
  final VoidCallback limpar;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: EspacoTocaEssa.medio),
        child: Column(
          children: [
            Text(texto,
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: CoresTocaEssa.textoSecundario)),
            TextButton(onPressed: limpar, child: const Text('Limpar busca')),
          ],
        ),
      );
}
