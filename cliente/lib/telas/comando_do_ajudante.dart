import 'package:flutter/material.dart';

import '../dominio/letra_da_tela.dart';
import '../dominio/tela_da_tv.dart';
import '../infraestrutura/api_toca_essa.dart';
import '../infraestrutura/tela_acesa.dart';
import '../tema/tema_toca_essa.dart';
import 'controle_da_tv.dart';
import 'tela_da_tv.dart' show assinarNoNavegador;

/// O link `#/comando/<token>` que o dono passa a quem vai cuidar da TV:
/// sem conta, só a letra que está na TV, sem acordes, uma linha por toque.
/// A música vem do celular do dono; a linha, daqui.
class ComandoDoAjudante extends StatefulWidget {
  const ComandoDoAjudante({
    super.key,
    required this.api,
    required this.token,
    this.assinar = assinarNoNavegador,
    this.manterTelaAcesa = manterTelaAcesaNoAparelho,
  });

  final ApiTocaEssa api;
  final String token;
  final AssinarTempoRealDaTv assinar;
  final LiberarTelaAcesa Function() manterTelaAcesa;

  @override
  State<ComandoDoAjudante> createState() => _ComandoDoAjudanteState();
}

class _ComandoDoAjudanteState extends State<ComandoDoAjudante> {
  late final LiberarTelaAcesa _liberarTela;
  AssinaturaDaTv? _encerrarTempoReal;
  ConteudoDaTv? _conteudo;
  bool _carregando = true;
  bool _encerrado = false;

  @override
  void initState() {
    super.initState();
    _liberarTela = widget.manterTelaAcesa();
    _consultar();
  }

  @override
  void dispose() {
    _encerrarTempoReal?.call();
    _liberarTela();
    super.dispose();
  }

  Future<void> _consultar() async {
    try {
      final comando = await widget.api.obterComando(widget.token);
      _encerrarTempoReal ??= widget.assinar(
          widget.api.enderecoTempoRealDoComando(comando.canal), _receber);
      _conteudo = comando.conteudo;
    } on ComandoEncerrado {
      _encerrar();
    } catch (_) {
      // Sem internet: a próxima linha recebida tenta de novo.
    }
    if (mounted) setState(() => _carregando = false);
  }

  /// Linha da mesma música só move o destaque; música nova busca tudo.
  void _receber(String dado) {
    final evento = EventoDaTv.ler(dado);
    final atual = _conteudo;
    if (evento != null && atual != null && evento.versao == atual.versao) {
      setState(() => _conteudo = atual.naLinha(evento.linha));
    } else if (evento != null || dado == 'conectado') {
      _consultar();
    }
  }

  Future<void> _irPara(int linha) async {
    final atual = _conteudo;
    if (atual == null) return;
    setState(() => _conteudo = atual.naLinha(linha));
    try {
      await widget.api.irParaALinhaPeloAjudante(widget.token, linha);
    } on ComandoEncerrado {
      _encerrar();
    } on TvAindaSemMusica {
      await _consultar();
    } catch (_) {
      // Sem internet: o toque seguinte manda de novo.
    }
  }

  void _encerrar() {
    _encerrarTempoReal?.call();
    _encerrarTempoReal = null;
    if (mounted) setState(() => _encerrado = true);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: Text(_conteudo?.titulo ?? 'Comando da TV'),
        ),
        body: switch ((_carregando, _encerrado, _conteudo)) {
          (true, _, _) => const Center(child: CircularProgressIndicator()),
          (_, true, _) => const _Aviso(
              'O comando voltou para quem toca. Obrigado pela ajuda!'),
          (_, _, null) => const _Aviso(
              'TV com você · esperando a música no celular de quem toca'),
          (_, _, final conteudo?) =>
            _LetraParaTocar(conteudo: conteudo, irPara: _irPara),
        },
      );
}

/// Cada linha da letra é um botão; a da vez fica acesa, como na TV.
class _LetraParaTocar extends StatelessWidget {
  const _LetraParaTocar({required this.conteudo, required this.irPara});

  final ConteudoDaTv conteudo;
  final ValueChanged<int> irPara;

  Color _corDa(int numero) => numero == conteudo.linha
      ? CoresTocaEssa.texto
      : CoresTocaEssa.textoSecundario
          .withValues(alpha: numero < conteudo.linha ? .35 : .7);

  @override
  Widget build(BuildContext context) {
    final letra = LetraDaTela.doTexto(conteudo.texto);
    return ListView(
      padding: const EdgeInsets.all(EspacoTocaEssa.base),
      children: [
        Text('Toque na linha que a galera está cantando',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: CoresTocaEssa.textoSecundario)),
        for (final parte in letra.partes) ...[
          if (parte.rotulo case final rotulo?)
            Padding(
              padding: const EdgeInsets.only(top: EspacoTocaEssa.grande),
              child: Text(rotulo,
                  style: const TextStyle(
                      color: CoresTocaEssa.roxoClaro, letterSpacing: 1.5)),
            ),
          for (final linha in parte.linhas)
            InkWell(
              onTap: () => irPara(linha.numero),
              borderRadius: BorderRadius.circular(RaioTocaEssa.pilula),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: EspacoTocaEssa.medio),
                child: Text(linha.texto,
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: _corDa(linha.numero))),
              ),
            ),
        ],
        const SizedBox(height: 120),
      ],
    );
  }
}

class _Aviso extends StatelessWidget {
  const _Aviso(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(EspacoTocaEssa.grande),
          child: Text(texto,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium),
        ),
      );
}
