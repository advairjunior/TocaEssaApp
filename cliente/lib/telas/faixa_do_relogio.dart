import 'dart:async';

import 'package:flutter/material.dart';

import '../dominio/modelos.dart';
import '../infraestrutura/api_toca_essa.dart';
import '../infraestrutura/assinatura_tempo_real.dart';
import '../tema/tema_toca_essa.dart';
import 'componentes.dart';

/// Cronômetro do show para a banda: quanto falta das horas contratadas,
/// a hora de terminar e o botão de intervalo. Some quando a apresentação
/// não tem horas contratadas. O público nunca vê esta faixa.
class FaixaDoRelogio extends StatefulWidget {
  const FaixaDoRelogio({
    super.key,
    required this.api,
    required this.apresentacaoId,
    required this.codigo,
  });

  final ApiTocaEssa api;
  final String apresentacaoId;
  final String codigo;

  @override
  State<FaixaDoRelogio> createState() => _FaixaDoRelogioState();
}

class _FaixaDoRelogioState extends State<FaixaDoRelogio> {
  RelogioDoShow? _relogio;
  AssinaturaTempoReal? _tempoReal;
  Timer? _ponteiro;
  Timer? _atualizacao;
  bool _salvando = false;

  @override
  void initState() {
    super.initState();
    _carregar();
    // Outro aparelho da banda pode marcar o intervalo.
    _tempoReal = AssinaturaTempoReal(
      widget.api.enderecoTempoReal(widget.codigo),
      _carregar,
    );
    _ponteiro = Timer.periodic(
      const Duration(seconds: 15),
      (_) => setState(() {}),
    );
    _atualizacao =
        Timer.periodic(const Duration(minutes: 1), (_) => _carregar());
  }

  @override
  void dispose() {
    _tempoReal?.encerrar();
    _ponteiro?.cancel();
    _atualizacao?.cancel();
    super.dispose();
  }

  Future<void> _carregar() async {
    try {
      final relogio = await widget.api.obterRelogio(widget.apresentacaoId);
      if (mounted) setState(() => _relogio = relogio);
    } catch (_) {
      // Sem rede, a faixa segue contando com a última leitura.
    }
  }

  Future<void> _alternarIntervalo(RelogioDoShow relogio) async {
    setState(() => _salvando = true);
    try {
      final atualizado = relogio.emIntervalo
          ? await widget.api.encerrarIntervalo(widget.apresentacaoId)
          : await widget.api.iniciarIntervalo(widget.apresentacaoId);
      if (mounted) setState(() => _relogio = atualizado);
    } catch (erro) {
      if (mounted) mostrarErro(context, erro);
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final relogio = _relogio;
    if (relogio == null || !relogio.ativo) return const SizedBox.shrink();
    final agora = DateTime.now();
    final restante = relogio.restante(agora);
    final alerta = relogio.alerta(agora);
    final cor = switch (alerta) {
      AlertaDoRelogio.normal => CoresTocaEssa.roxoClaro,
      AlertaDoRelogio.trintaMinutos => CoresTocaEssa.atencao,
      AlertaDoRelogio.dezMinutos ||
      AlertaDoRelogio.passou =>
        CoresTocaEssa.perigo,
    };
    final principal = relogio.emIntervalo
        ? 'Intervalo · ${formatarTempoDoShow(relogio.tempoEmIntervalo(agora))}'
        : alerta == AlertaDoRelogio.passou
            ? 'Passou ${formatarTempoDoShow(restante)}'
            : 'Restam ${formatarTempoDoShow(_arredondarParaCima(restante))}';
    final detalhe = alerta == AlertaDoRelogio.passou
        ? 'do horário contratado'
        : relogio.emIntervalo
            ? 'restam ${formatarTempoDoShow(_arredondarParaCima(restante))}'
            : 'termina às ${_hora(relogio.termino(agora))}';
    final texto = Theme.of(context).textTheme;
    final estiloRitmo =
        texto.bodySmall?.copyWith(color: CoresTocaEssa.textoSecundario);
    final linhasDoRitmo = alerta == AlertaDoRelogio.passou
        ? const <String>[]
        : _linhasDoRitmo(relogio, agora);
    return InkWell(
      borderRadius: BorderRadius.circular(RaioTocaEssa.campo),
      onTap: () => _explicarCalculo(context),
      child: _construirFaixa(
        relogio: relogio,
        cor: cor,
        principal: principal,
        detalhe: detalhe,
        rodape: [
          for (final linha in linhasDoRitmo) Text(linha, style: estiloRitmo),
        ],
      ),
    );
  }

  Widget _construirFaixa({
    required RelogioDoShow relogio,
    required Color cor,
    required String principal,
    required String detalhe,
    required List<Widget> rodape,
  }) {
    final texto = Theme.of(context).textTheme;
    return Container(
      margin: const EdgeInsets.fromLTRB(
        EspacoTocaEssa.base,
        EspacoTocaEssa.pequeno,
        EspacoTocaEssa.base,
        0,
      ),
      padding: const EdgeInsets.fromLTRB(
        EspacoTocaEssa.base,
        EspacoTocaEssa.pequeno,
        EspacoTocaEssa.pequeno,
        EspacoTocaEssa.pequeno,
      ),
      decoration: BoxDecoration(
        color: CoresTocaEssa.superficie,
        borderRadius: BorderRadius.circular(RaioTocaEssa.campo),
        border: Border.all(color: cor.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _construirLinhaPrincipal(relogio, cor, principal, detalhe, texto),
          if (rodape.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(
                left: EspacoTocaEssa.grande + EspacoTocaEssa.medio,
                bottom: EspacoTocaEssa.mini,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: rodape,
              ),
            ),
        ],
      ),
    );
  }

  Widget _construirLinhaPrincipal(RelogioDoShow relogio, Color cor,
          String principal, String detalhe, TextTheme texto) =>
      Row(
        children: [
          Icon(
            relogio.emIntervalo
                ? Icons.pause_circle_outline_rounded
                : Icons.timer_outlined,
            color: cor,
          ),
          const SizedBox(width: EspacoTocaEssa.medio),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  principal,
                  style: texto.titleMedium
                      ?.copyWith(color: cor, fontWeight: FontWeight.w700),
                ),
                Text(
                  detalhe,
                  style: texto.bodySmall
                      ?.copyWith(color: CoresTocaEssa.textoSecundario),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: _salvando ? null : () => _alternarIntervalo(relogio),
            child: Text(relogio.emIntervalo ? 'Voltar ao show' : 'Intervalo'),
          ),
        ],
      );

  List<String> _linhasDoRitmo(RelogioDoShow relogio, DateTime agora) {
    final cabem = relogio.musicasQueCabem(agora);
    final ritmo = formatarRitmo(relogio.ritmo(agora));
    final restantes = relogio.musicasRestantes;
    final sobra = relogio.sobraDaSequencia(agora);
    return [
      relogio.ritmoMedido
          ? 'Cabem ~${_musicas(cabem)} no ritmo de $ritmo'
          : 'Cabem ~${_musicas(cabem)} (estimativa: $ritmo cada)',
      if (restantes > 0)
        sobra.isNegative
            ? 'Sequência de ${_musicas(restantes)} passa '
                '~${formatarTempoDoShow(sobra)} do horário'
            : 'Sequência de ${_musicas(restantes)}: '
                'sobram ~${formatarTempoDoShow(sobra)}',
    ];
  }

  void _explicarCalculo(BuildContext context) => showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Como o TocaEssa calcula'),
          content: const Text(
            'O tempo conta a partir do primeiro Iniciar da apresentação. '
            'Até a 3ª música, o TocaEssa estima 3 minutos por música. '
            'Depois, mede o ritmo real do show: o tempo tocado dividido '
            'pelas músicas começadas, já contando a conversa entre elas e '
            'sem contar o intervalo.\n\n'
            'A sequência são as músicas da setlist que faltam e os pedidos '
            'marcados para tocar a seguir.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Entendi'),
            ),
          ],
        ),
      );
}

String _musicas(int quantidade) =>
    quantidade == 1 ? '1 música' : '$quantidade músicas';

// "Restam 1h42" continua até faltar exatamente 1h41, como num cronômetro.
Duration _arredondarParaCima(Duration tempo) =>
    Duration(minutes: (tempo.inSeconds / 60).ceil());

String _hora(DateTime data) {
  final local = data.toLocal();
  return '${local.hour.toString().padLeft(2, '0')}:'
      '${local.minute.toString().padLeft(2, '0')}';
}
