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
import 'cifra_do_palco.dart';
import 'componentes_lista.dart';
import 'trechos_do_louvor.dart';

/// Roteiro do louvor no telefone de cada participante, pelo código: a letra
/// do hino com quem canta cada parte, a vez da pessoa em destaque e o hino
/// de agora acompanhando o Tocar do artista.
class RoteiroDoLouvorTela extends StatefulWidget {
  const RoteiroDoLouvorTela({
    super.key,
    required this.api,
    required this.codigo,
    this.manterTelaAcesa = manterTelaAcesaNoAparelho,
  });

  final ApiTocaEssa api;
  final String codigo;
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
  String? _hinoAbertoId;
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
    if (!mounted) return;
    setState(() {
      _preferencias = preferencias;
      if (salvo != null) _quemSou = salvo;
      _acordes = preferencias.getBool(_chaveAcordes) ?? false;
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
  }

  Future<void> _carregar() async {
    try {
      final roteiro = await widget.api.obterRoteiroDoLouvor(_codigo);
      if (!mounted) return;
      setState(() {
        _roteiro = roteiro;
        _erro = null;
        // O artista começou outro hino: todos os telefones vão para ele.
        if (roteiro.hinoAtualId != _ultimoAtual) {
          _ultimoAtual = roteiro.hinoAtualId;
          _hinoAbertoId = null;
        }
      });
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
    return Column(
      children: [
        Expanded(
          child: CifraDoPalco(
            pagina: hino.itemId,
            cabecalho: _CabecalhoDoHino(
              hino: hino,
              ehAgora: ehAgora,
              quemSou: _quemSou ?? '',
              acordes: _acordes,
              tom: _rotuloDoTom(hino, semitons),
              alternarAcordes: _alternarAcordes,
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
          depois: indice < roteiro.hinos.length - 1
              ? roteiro.hinos[indice + 1].titulo
              : null,
        ),
      ],
    );
  }

  Future<void> _mostrarLista(RoteiroDoLouvor roteiro) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (contexto) => SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(contexto).height * .8),
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final hino in roteiro.hinos)
                  ListTile(
                    selected: hino.itemId == _hinoMostrado?.itemId,
                    leading: Icon(hino.itemId == roteiro.hinoAtualId
                        ? Icons.graphic_eq_rounded
                        : hino.tocado
                            ? Icons.check_rounded
                            : Icons.music_note_outlined),
                    title: Text(hino.titulo),
                    subtitle: Text([
                      if (hino.tom case final tom?) 'Tom $tom',
                      if (_quemSou case final nome? when nome.isNotEmpty)
                        if (hino.partesDe(nome) case final partes
                            when partes > 0)
                          'você canta $partes',
                    ].join(' · ')),
                    onTap: () {
                      Navigator.of(contexto).pop();
                      _abrirHino(hino);
                    },
                  ),
              ],
            ),
          ),
        ),
      );
}

/// Cada pessoa num botão grande na cor da sua faixa, para ela já se achar
/// pela cor na letra.
class _EscolhaDeQuemSou extends StatelessWidget {
  const _EscolhaDeQuemSou({
    required this.participantes,
    required this.cantores,
    required this.escolher,
  });

  final List<String> participantes;
  final List<String> cantores;
  final ValueChanged<String> escolher;

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    return ConteudoMobile(
      filho: Column(
        children: [
          const SizedBox(height: EspacoTocaEssa.enorme),
          const Icon(Icons.mic_none_rounded,
              size: 40, color: CoresTocaEssa.roxoClaro),
          const SizedBox(height: EspacoTocaEssa.base),
          Text('Quem é você?', style: texto.headlineSmall),
          const SizedBox(height: EspacoTocaEssa.pequeno),
          Text(
            'Suas partes ficam em destaque na letra, na sua cor.',
            textAlign: TextAlign.center,
            style: texto.bodyMedium
                ?.copyWith(color: CoresTocaEssa.textoSecundario),
          ),
          const SizedBox(height: EspacoTocaEssa.grande),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: EspacoTocaEssa.pequeno,
            runSpacing: EspacoTocaEssa.pequeno,
            children: [
              for (final nome in participantes)
                _BotaoDaPessoa(
                  nome: nome,
                  cor: corDaPessoa(cantores, nome),
                  escolher: () => escolher(nome),
                ),
            ],
          ),
          const SizedBox(height: EspacoTocaEssa.base),
          TextButton(
            onPressed: () => escolher(''),
            child: const Text('Só acompanhar'),
          ),
        ],
      ),
    );
  }
}

class _BotaoDaPessoa extends StatelessWidget {
  const _BotaoDaPessoa({
    required this.nome,
    required this.cor,
    required this.escolher,
  });

  final String nome;
  final Color cor;
  final VoidCallback escolher;

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
        onPressed: escolher,
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(120, 52),
          backgroundColor: cor.withValues(alpha: .12),
          side: BorderSide(color: cor.withValues(alpha: .7), width: 1.5),
        ),
        icon: Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: cor, shape: BoxShape.circle),
        ),
        label: Text(nome,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(color: cor, fontWeight: FontWeight.w700)),
      );
}

/// Topo do hino, que rola junto com a letra: título, tom, se é o de agora,
/// quantas partes a pessoa canta e o botão dos acordes para quem toca.
class _CabecalhoDoHino extends StatelessWidget {
  const _CabecalhoDoHino({
    required this.hino,
    required this.ehAgora,
    required this.quemSou,
    required this.acordes,
    required this.tom,
    required this.alternarAcordes,
    required this.mudarTom,
  });

  final HinoDoLouvor hino;
  final bool ehAgora;
  final String quemSou;
  final bool acordes;
  final String? tom;
  final VoidCallback alternarAcordes;
  final ValueChanged<int> mudarTom;

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    final minhas = quemSou.isEmpty ? null : partesDaPessoa(hino, quemSou);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(hino.titulo, style: texto.headlineSmall),
        const SizedBox(height: EspacoTocaEssa.pequeno),
        Wrap(
          spacing: EspacoTocaEssa.pequeno,
          runSpacing: EspacoTocaEssa.mini,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (tom != null) _Selo(texto: tom!, cor: CoresTocaEssa.roxoClaro),
            if (ehAgora)
              const _Selo(texto: 'Agora', cor: CoresTocaEssa.sucesso),
          ],
        ),
        if (minhas != null) ...[
          const SizedBox(height: EspacoTocaEssa.medio),
          Text(
            'Suas partes: $minhas',
            style: texto.bodyMedium?.copyWith(color: CoresTocaEssa.ouro),
          ),
        ],
        const SizedBox(height: EspacoTocaEssa.pequeno),
        Row(
          children: [
            FilterChip(
              label: const Text('Acordes'),
              selected: acordes,
              onSelected: (_) => alternarAcordes(),
            ),
            if (acordes) ...[
              const Spacer(),
              IconButton(
                tooltip: 'Baixar meio tom',
                icon: const Icon(Icons.remove_rounded),
                onPressed: () => mudarTom(-1),
              ),
              IconButton(
                tooltip: 'Subir meio tom',
                icon: const Icon(Icons.add_rounded),
                onPressed: () => mudarTom(1),
              ),
            ],
          ],
        ),
        if (!hino.temLetra) ...[
          const SizedBox(height: EspacoTocaEssa.grande),
          Text(
            'A letra deste hino ainda não foi colada.',
            style:
                texto.bodyLarge?.copyWith(color: CoresTocaEssa.textoSecundario),
          ),
        ],
      ],
    );
  }
}

class _Selo extends StatelessWidget {
  const _Selo({required this.texto, required this.cor});

  final String texto;
  final Color cor;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(
            horizontal: EspacoTocaEssa.medio, vertical: EspacoTocaEssa.mini),
        decoration: BoxDecoration(
          color: cor.withValues(alpha: .14),
          borderRadius: BorderRadius.circular(RaioTocaEssa.pilula),
          border: Border.all(color: cor.withValues(alpha: .5)),
        ),
        child: Text(texto,
            style:
                Theme.of(context).textTheme.labelLarge?.copyWith(color: cor)),
      );
}

class _BarraDosHinos extends StatelessWidget {
  const _BarraDosHinos({
    required this.anterior,
    required this.proximo,
    required this.voltarAoAgora,
    required this.depois,
  });

  final VoidCallback? anterior;
  final VoidCallback? proximo;
  final VoidCallback? voltarAoAgora;
  final String? depois;

  @override
  Widget build(BuildContext context) => Container(
        decoration: const BoxDecoration(
          color: CoresTocaEssa.superficie,
          border: Border(top: BorderSide(color: CoresTocaEssa.borda)),
        ),
        padding: const EdgeInsets.symmetric(
            horizontal: EspacoTocaEssa.pequeno, vertical: EspacoTocaEssa.mini),
        child: Row(
          children: [
            IconButton(
              tooltip: 'Hino anterior',
              iconSize: 32,
              icon: const Icon(Icons.chevron_left_rounded),
              onPressed: anterior,
            ),
            Expanded(
              child: voltarAoAgora != null
                  ? TextButton(
                      onPressed: voltarAoAgora,
                      child: const Text('Voltar ao hino de agora'),
                    )
                  : Text(
                      depois == null ? 'Último hino' : 'Depois: $depois',
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: CoresTocaEssa.textoSecundario),
                    ),
            ),
            IconButton(
              tooltip: 'Próximo hino',
              iconSize: 32,
              icon: const Icon(Icons.chevron_right_rounded),
              onPressed: proximo,
            ),
          ],
        ),
      );
}
