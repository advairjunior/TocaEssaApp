import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../dominio/modelos.dart';
import '../dominio/transpor_cifra.dart';
import '../infraestrutura/api_toca_essa.dart';
import '../infraestrutura/assinatura_tempo_real.dart';
import '../infraestrutura/atualizacao_espalhada.dart';
import '../infraestrutura/tela_acesa.dart';
import '../tema/tema_toca_essa.dart';
import 'componentes.dart';
import 'controle_do_tom.dart';
import 'cifra_do_palco.dart';
import 'componentes_lista.dart';
import 'trechos_do_louvor.dart';

part 'roteiro_do_louvor_componentes.dart';
part 'roteiro_do_louvor_listas.dart';

/// Roteiro do louvor no telefone de cada participante, pelo código: a letra
/// do hino com quem canta cada parte, a vez da pessoa em destaque e o hino
/// de agora acompanhando o Tocar do artista.
class RoteiroDoLouvorTela extends StatefulWidget {
  const RoteiroDoLouvorTela({
    super.key,
    required this.api,
    required this.codigo,
    this.hinoInicial,
    this.manterTelaAcesa = manterTelaAcesaNoAparelho,
  });

  final ApiTocaEssa api;
  final String codigo;
  // Hino do link compartilhado ("#/publico/ABC123?hino=..."): abre nele.
  final String? hinoInicial;
  final LiberarTelaAcesa Function() manterTelaAcesa;

  @override
  State<RoteiroDoLouvorTela> createState() => _RoteiroDoLouvorTelaState();
}

class _RoteiroDoLouvorTelaState extends State<RoteiroDoLouvorTela> {
  RoteiroDoLouvor? _roteiro;
  Object? _erro;
  // Nulo: ainda não escolheu; vazio: só acompanha, sem parte no microfone.
  String? _quemSou;
  bool _escolhendo = false;
  // Hino aberto pela pessoa; nulo segue o hino de agora.
  late String? _hinoAbertoId = widget.hinoInicial;
  String? _ultimoAtual;
  Timer? _atualizacaoPeriodica;
  AssinaturaTempoReal? _tempoReal;
  AtualizacaoEspalhada? _atualizacaoPorAviso;
  late final LiberarTelaAcesa _liberarTela;

  String get _codigo => widget.codigo.trim().toUpperCase();
  String get _chaveQuemSou => 'louvor_quem_sou_$_codigo';

  @override
  void initState() {
    super.initState();
    _liberarTela = widget.manterTelaAcesa();
    _restaurarQuemSou();
    _carregar();
    _atualizacaoPeriodica =
        Timer.periodic(const Duration(seconds: 15), (_) => _carregar());
    _atualizacaoPorAviso = AtualizacaoEspalhada(_carregar);
    _tempoReal = AssinaturaTempoReal(
      widget.api.enderecoTempoReal(_codigo),
      _atualizacaoPorAviso!.solicitar,
    );
  }

  @override
  void dispose() {
    _atualizacaoPeriodica?.cancel();
    _tempoReal?.encerrar();
    _atualizacaoPorAviso?.encerrar();
    _liberarTela();
    super.dispose();
  }

  Future<void> _restaurarQuemSou() async {
    final preferencias = await SharedPreferences.getInstance();
    final salvo = preferencias.getString(_chaveQuemSou);
    if (salvo != null) _guardarNaConta(preferencias, salvo);
    if (!mounted) return;
    setState(() {
      _preferencias = preferencias;
      if (salvo != null) _quemSou = salvo;
      // Quem recebe o link de um hino quer ver a cifra: sem escolha
      // guardada, os acordes já vêm ligados.
      _acordes =
          preferencias.getBool(_chaveAcordes) ?? widget.hinoInicial != null;
    });
  }

  // Quem toca liga os acordes; a escolha vale para todos os louvores.
  static const _chaveAcordes = 'louvor_acordes';
  SharedPreferences? _preferencias;
  bool _acordes = false;

  Future<void> _alternarAcordes() async {
    setState(() => _acordes = !_acordes);
    try {
      await _preferencias?.setBool(_chaveAcordes, _acordes);
    } catch (_) {
      // A escolha só não fica guardada para a próxima vez.
    }
  }

  // Tom escolhido por hino neste telefone; os outros não mudam.
  String _chaveDoTom(HinoDoLouvor hino) => 'louvor_tom|$_codigo|${hino.itemId}';

  int _semitonsDe(HinoDoLouvor hino) =>
      _preferencias?.getInt(_chaveDoTom(hino)) ?? 0;

  Future<void> _mudarTom(HinoDoLouvor hino, int passo) async {
    // Entre -11 e +11: uma oitava inteira volta ao tom original.
    final semitons = (_semitonsDe(hino) + passo).remainder(12);
    try {
      if (semitons == 0) {
        await _preferencias?.remove(_chaveDoTom(hino));
      } else {
        await _preferencias?.setInt(_chaveDoTom(hino), semitons);
      }
    } catch (_) {
      // O tom só não fica guardado para a próxima vez.
    }
    if (mounted) setState(() {});
  }

  String? _rotuloDoTom(HinoDoLouvor hino, int semitons) {
    final tom = hino.tom?.trim();
    if (tom == null || tom.isEmpty) return null;
    final mudanca =
        semitons == 0 ? '' : ' (${semitons > 0 ? '+' : ''}$semitons)';
    return 'Tom ${transporTom(tom, semitons)}$mudanca';
  }

  Future<void> _escolherQuemSou(String nome) async {
    setState(() {
      _quemSou = nome;
      _escolhendo = false;
    });
    final preferencias = await SharedPreferences.getInstance();
    await preferencias.setString(_chaveQuemSou, nome);
    _guardarNaConta(preferencias, nome);
  }

  /// Com conta do público neste aparelho, o louvor fica na memória dela com
  /// quem a pessoa foi. Sem internet ou sem conta, o roteiro segue igual.
  void _guardarNaConta(SharedPreferences preferencias, String nome) {
    final token = preferencias.getString('token_do_publico');
    if (token == null) return;
    unawaited(widget.api
        .registrarParticipacao(_codigo, token, nomeNoLouvor: nome)
        .catchError((_) {}));
  }

  Future<void> _carregar() async {
    try {
      final roteiro = await widget.api.obterRoteiroDoLouvor(_codigo);
      if (!mounted) return;
      final primeira = _roteiro == null;
      final mudou = !primeira && roteiro.hinoAtualId != _ultimoAtual;
      setState(() {
        _roteiro = roteiro;
        _erro = null;
        // O artista começou outro hino: todos os telefones vão para ele.
        // Na primeira leitura, fica o hino do link.
        if (primeira) {
          _ultimoAtual = roteiro.hinoAtualId;
        } else if (roteiro.hinoAtualId != _ultimoAtual) {
          _ultimoAtual = roteiro.hinoAtualId;
          _hinoAbertoId = null;
        }
      });
      // Avisa por que a tela mudou sozinha.
      final atual = roteiro.hinos
          .where((hino) => hino.itemId == roteiro.hinoAtualId)
          .firstOrNull;
      if (mudou && atual != null) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text('Agora: ${atual.titulo}')));
      }
    } catch (erro) {
      // Com o roteiro na tela, a falha fica para a próxima atualização.
      if (mounted && _roteiro == null) setState(() => _erro = erro);
    }
  }

  HinoDoLouvor? get _hinoMostrado {
    final hinos = _roteiro?.hinos ?? const <HinoDoLouvor>[];
    if (hinos.isEmpty) return null;
    final id = _hinoAbertoId ?? _roteiro?.hinoAtualId;
    return hinos.where((hino) => hino.itemId == id).firstOrNull ?? hinos.first;
  }

  void _abrirHino(HinoDoLouvor hino) => setState(() => _hinoAbertoId =
      hino.itemId == _roteiro?.hinoAtualId ? null : hino.itemId);

  void _irPara(int deslocamento) {
    final hinos = _roteiro!.hinos;
    final indice = hinos.indexOf(_hinoMostrado!) + deslocamento;
    if (indice >= 0 && indice < hinos.length) _abrirHino(hinos[indice]);
  }

  @override
  Widget build(BuildContext context) {
    final roteiro = _roteiro;
    final escolhendo = roteiro != null && (_quemSou == null || _escolhendo);
    return Scaffold(
      appBar: AppBar(
        title: Text(roteiro?.nome ?? 'Louvor'),
        actions: [
          if (roteiro != null && !escolhendo) ...[
            IconButton(
              tooltip: _acordes ? 'Esconder acordes' : 'Mostrar acordes',
              isSelected: _acordes,
              icon: const Icon(Icons.music_note_outlined),
              selectedIcon: const Icon(Icons.music_note_rounded,
                  color: CoresTocaEssa.roxoClaro),
              onPressed: _alternarAcordes,
            ),
            if ((_quemSou ?? '').isNotEmpty)
              IconButton(
                tooltip: 'Meus hinos',
                icon: const Icon(Icons.assignment_ind_outlined),
                onPressed: () => _mostrarMeusHinos(roteiro),
              ),
            IconButton(
              tooltip: 'Lista de hinos',
              icon: const Icon(Icons.format_list_numbered_rounded),
              onPressed: () => _mostrarLista(roteiro),
            ),
            IconButton(
              tooltip: 'Trocar quem sou eu',
              icon: const Icon(Icons.person_outline_rounded),
              onPressed: () => setState(() => _escolhendo = true),
            ),
          ],
        ],
      ),
      body: SafeArea(
        child: switch ((roteiro, _erro)) {
          (null, final Object erro) => EstadoVazio(
              icone: Icons.wifi_off_rounded,
              titulo: 'Não foi possível abrir o louvor',
              descricao: '$erro',
            ),
          (null, _) => const Center(child: CircularProgressIndicator()),
          (final RoteiroDoLouvor roteiro, _) when escolhendo =>
            _EscolhaDeQuemSou(
                participantes: roteiro.participantes,
                cantores: roteiro.cantores,
                escolher: _escolherQuemSou),
          (final RoteiroDoLouvor roteiro, _) when roteiro.hinos.isEmpty =>
            const EstadoVazio(
              icone: Icons.library_music_outlined,
              titulo: 'Os hinos ainda não foram separados',
              descricao: 'Assim que a lista ficar pronta, ela aparece aqui.',
            ),
          (final RoteiroDoLouvor roteiro, _) => _construirHino(roteiro),
        },
      ),
    );
  }

  Widget _construirHino(RoteiroDoLouvor roteiro) {
    final hino = _hinoMostrado!;
    final indice = roteiro.hinos.indexOf(hino);
    final ehAgora = hino.itemId == roteiro.hinoAtualId;
    final semitons = _semitonsDe(hino);
    final proximo =
        indice < roteiro.hinos.length - 1 ? roteiro.hinos[indice + 1] : null;
    return Column(
      children: [
        Expanded(
          child: CifraDoPalco(
            pagina: hino.itemId,
            cabecalho: _CabecalhoDoHino(
              hino: hino,
              ehAgora: ehAgora,
              quemSou: _quemSou ?? '',
              noCoral: partesNoCoral(hino, _quemSou ?? '',
                  cantores: roteiro.cantores),
              acordes: _acordes,
              tom: _rotuloDoTom(hino, semitons),
              semitons: semitons,
              mudarTom: (passo) => _mudarTom(hino, passo),
            ),
            trechos: trechosDoHino(
              hino,
              cantores: roteiro.cantores,
              quemSou: _quemSou ?? '',
              acordes: _acordes,
              semitons: semitons,
            ),
          ),
        ),
        _BarraDosHinos(
          anterior: indice > 0 ? () => _irPara(-1) : null,
          proximo: indice < roteiro.hinos.length - 1 ? () => _irPara(1) : null,
          voltarAoAgora: !ehAgora && roteiro.hinoAtualId != null
              ? () => setState(() => _hinoAbertoId = null)
              : null,
          depois: proximo?.titulo,
          suaVezDepois: proximo == null || (_quemSou ?? '').isEmpty
              ? null
              : partesDaPessoa(proximo, _quemSou!),
        ),
      ],
    );
  }
}
