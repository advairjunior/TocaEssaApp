import 'dart:async';

import 'package:flutter/material.dart';

import '../dominio/modelos.dart';
import '../infraestrutura/abrir_url_externa.dart';
import '../infraestrutura/api_toca_essa.dart';
import '../infraestrutura/assinatura_tempo_real.dart';
import '../infraestrutura/tela_acesa.dart';
import '../tema/tema_toca_essa.dart';
import 'acoes_do_palco.dart';
import 'componentes.dart';
import 'componentes_lista.dart';
import 'componentes_palco.dart';
import 'sequencia_do_palco.dart';

/// Tela única para o show: o que está tocando, a próxima com Tocar e os
/// pedidos e alôs que chegam, com a tela sempre acesa.
class ModoPalco extends StatefulWidget {
  const ModoPalco({
    super.key,
    required this.api,
    required this.apresentacao,
    this.abrirUrl = abrirNaAbaDaCifra,
    this.prepararAbertura = prepararAberturaNaAbaDaCifra,
    this.manterTelaAcesa = manterTelaAcesaNoAparelho,
  });

  final ApiTocaEssa api;
  final Apresentacao apresentacao;
  final Future<void> Function(Uri url) abrirUrl;
  final FinalizarAberturaExterna Function() prepararAbertura;
  final LiberarTelaAcesa Function() manterTelaAcesa;

  @override
  State<ModoPalco> createState() => _ModoPalcoState();
}

class _ModoPalcoState extends State<ModoPalco> with AcoesDoPalco<ModoPalco> {
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
  )..addListener(_redesenhar);
  late final LiberarTelaAcesa _liberarTela;
  AssinaturaTempoReal? _tempoReal;
  Timer? _atualizacaoAutomatica;
  bool _carregando = true;

  @override
  void initState() {
    super.initState();
    _liberarTela = widget.manterTelaAcesa();
    _carregar();
    _tempoReal = AssinaturaTempoReal(
      widget.api.enderecoTempoReal(widget.apresentacao.codigo),
      _sequencia.recarregarPedidos,
    );
    _atualizacaoAutomatica = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _sequencia.recarregarPedidos(),
    );
  }

  @override
  void dispose() {
    _liberarTela();
    _tempoReal?.encerrar();
    _atualizacaoAutomatica?.cancel();
    _sequencia.dispose();
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

  void _alterar(GrupoPedidoMusical pedido, StatusPedidoMusical status) =>
      executar(() => _sequencia.alterarStatus(pedido, status));

  @override
  Widget build(BuildContext context) {
    final proxima = _sequencia.proxima;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Sair do modo palco',
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Modo palco'),
      ),
      body: _carregando
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(child: _construirConteudo(context)),
                if (proxima != null)
                  BarraProximaMusica(
                    titulo: proxima.titulo,
                    detalhe: _sequencia.detalheDaProxima,
                    salvando: _sequencia.salvando,
                    tocar: tocarProxima,
                  ),
              ],
            ),
    );
  }

  Widget _construirConteudo(BuildContext context) {
    final alos = _sequencia.alosPendentes;
    final novos = _sequencia.pedidosNovos;
    final aceitos = _sequencia.pedidosAceitos;
    return ConteudoMobile(
      filho: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const TituloGrupo('Tocando agora'),
          _TocandoAgora(
            musica: _sequencia.atual,
            abrirCifra: abrirCifra,
          ),
          if (alos.isNotEmpty) ...[
            const SizedBox(height: EspacoTocaEssa.grande),
            const TituloGrupo('Alôs'),
            for (final alo in alos)
              _CartaoDoPalco(
                titulo: 'Alô para ${alo.destinatarioAlo ?? 'a galera'}',
                recado: alo.recado,
                acoes: [
                  FilledButton.tonal(
                    onPressed: () =>
                        _alterar(alo, StatusPedidoMusical.finalizado),
                    child: const Text('Alô dado'),
                  ),
                ],
              ),
          ],
          if (novos.isNotEmpty) ...[
            const SizedBox(height: EspacoTocaEssa.grande),
            const TituloGrupo('Pedidos novos'),
            for (final pedido in novos)
              _CartaoDoPalco(
                titulo: pedido.musica,
                detalhe: _quemPediu(pedido),
                recado: pedido.recado,
                acoes: [
                  FilledButton.tonal(
                    onPressed: () =>
                        _alterar(pedido, StatusPedidoMusical.aceito),
                    child: const Text('Aceitar'),
                  ),
                  TextButton(
                    onPressed: () =>
                        _alterar(pedido, StatusPedidoMusical.naoConhecemos),
                    child: const Text('Recusar'),
                  ),
                ],
              ),
          ],
          if (aceitos.isNotEmpty) ...[
            const SizedBox(height: EspacoTocaEssa.grande),
            const TituloGrupo('Aceitos'),
            for (final pedido in aceitos)
              _CartaoDoPalco(
                titulo: pedido.musica,
                detalhe: _quemPediu(pedido),
                acoes: [
                  _BotaoASeguir(
                    marcado: _sequencia.aSeguir
                        .contains(pedido.pedidoRepresentativoId),
                    alternar: () =>
                        executar(() => _sequencia.alternarASeguir(pedido)),
                  ),
                ],
              ),
          ],
          const SizedBox(height: EspacoTocaEssa.base),
        ],
      ),
    );
  }

  String _quemPediu(GrupoPedidoMusical pedido) => pedido.quantidadePedidos > 1
      ? '${pedido.quantidadePedidos} pedidos'
      : pedido.solicitantes.isEmpty
          ? 'Pedido'
          : 'Pedido de ${pedido.solicitantes.first}';
}

/// A música em andamento, em letra grande para ler de longe.
class _TocandoAgora extends StatelessWidget {
  const _TocandoAgora({required this.musica, required this.abrirCifra});

  final MusicaDoPalco? musica;
  final ValueChanged<MusicaDoPalco> abrirCifra;

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    final atual = musica;
    if (atual == null) {
      return Text(
        'Toque em Tocar para começar.',
        style: texto.bodyLarge?.copyWith(color: CoresTocaEssa.textoSecundario),
      );
    }
    final detalhes = [
      if (atual.artista?.isNotEmpty == true) atual.artista!,
      if (atual.tom?.isNotEmpty == true) 'Tom ${atual.tom}',
      if (atual.pedido != null) 'Pedido do público',
    ].join(' · ');
    return Container(
      padding: const EdgeInsets.all(EspacoTocaEssa.base),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(RaioTocaEssa.cartao),
        border: Border.all(color: CoresTocaEssa.destaqueBorda),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [CoresTocaEssa.destaqueFundo, CoresTocaEssa.superficie],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(atual.titulo, style: texto.headlineMedium),
          if (detalhes.isNotEmpty)
            Text(
              detalhes,
              style: texto.bodyLarge
                  ?.copyWith(color: CoresTocaEssa.textoSecundario),
            ),
          const SizedBox(height: EspacoTocaEssa.medio),
          OutlinedButton.icon(
            onPressed: () => abrirCifra(atual),
            icon: const Icon(Icons.menu_book_rounded),
            label: const Text('Abrir cifra'),
          ),
        ],
      ),
    );
  }
}

class _CartaoDoPalco extends StatelessWidget {
  const _CartaoDoPalco({
    required this.titulo,
    required this.acoes,
    this.detalhe,
    this.recado,
  });

  final String titulo;
  final String? detalhe;
  final String? recado;
  final List<Widget> acoes;

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    return Container(
      margin: const EdgeInsets.only(top: EspacoTocaEssa.pequeno),
      padding: const EdgeInsets.all(EspacoTocaEssa.base),
      decoration: BoxDecoration(
        color: CoresTocaEssa.superficie,
        borderRadius: BorderRadius.circular(RaioTocaEssa.cartao),
        border: Border.all(color: CoresTocaEssa.borda),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titulo, style: texto.titleLarge),
          if (detalhe != null)
            Text(
              detalhe!,
              style: texto.bodyMedium
                  ?.copyWith(color: CoresTocaEssa.textoSecundario),
            ),
          if (recado?.isNotEmpty == true) ...[
            const SizedBox(height: EspacoTocaEssa.mini),
            Text(
              '“$recado”',
              style: texto.bodyLarge?.copyWith(fontStyle: FontStyle.italic),
            ),
          ],
          const SizedBox(height: EspacoTocaEssa.pequeno),
          Wrap(
            spacing: EspacoTocaEssa.pequeno,
            runSpacing: EspacoTocaEssa.mini,
            children: acoes,
          ),
        ],
      ),
    );
  }
}

class _BotaoASeguir extends StatelessWidget {
  const _BotaoASeguir({required this.marcado, required this.alternar});

  final bool marcado;
  final VoidCallback alternar;

  @override
  Widget build(BuildContext context) => marcado
      ? OutlinedButton.icon(
          onPressed: alternar,
          icon: const Icon(Icons.remove_circle_outline_rounded),
          label: const Text('Tirar da sequência'),
        )
      : FilledButton.tonalIcon(
          onPressed: alternar,
          icon: const Icon(Icons.playlist_add_rounded),
          label: const Text('Tocar a seguir'),
        );
}
