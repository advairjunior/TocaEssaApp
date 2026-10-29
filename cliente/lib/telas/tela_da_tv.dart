import 'package:flutter/material.dart';

import '../dominio/letra_da_tela.dart';
import '../dominio/tela_da_tv.dart';
import '../infraestrutura/api_toca_essa.dart';
import '../infraestrutura/assinatura_tempo_real.dart';
import '../infraestrutura/tela_acesa.dart';
import '../tema/tema_toca_essa.dart';
import 'controle_da_tv.dart';

part 'tela_da_tv_letra.dart';

/// Tempo real da TV pelo navegador, com o dado de cada evento.
AssinaturaDaTv assinarNoNavegador(
    String endereco, void Function(String dado) aoReceber) {
  final assinatura = AssinaturaTempoReal(endereco, () {}, aoReceber: aoReceber);
  return assinatura.encerrar;
}

/// A TV da Letra na TV ("#/tv"), aberta no navegador da televisão e salva
/// nos favoritos: mostra o código até alguém conectá-la; depois, a letra que
/// o celular do dono manda, deitada e em letra grande. Ninguém mexe nela.
class TelaDaTv extends StatefulWidget {
  const TelaDaTv({
    super.key,
    required this.api,
    this.assinar = assinarNoNavegador,
    this.manterTelaAcesa = manterTelaAcesaNoAparelho,
  });

  final ApiTocaEssa api;
  final AssinarTempoRealDaTv assinar;
  final LiberarTelaAcesa Function() manterTelaAcesa;

  @override
  State<TelaDaTv> createState() => _TelaDaTvState();
}

class _TelaDaTvState extends State<TelaDaTv> {
  late final _controle = ControleDaTv(api: widget.api, assinar: widget.assinar);
  late final LiberarTelaAcesa _liberarTela;

  @override
  void initState() {
    super.initState();
    _liberarTela = widget.manterTelaAcesa();
    _controle.addListener(_redesenhar);
    _controle.comecar();
  }

  void _redesenhar() => setState(() {});

  @override
  void dispose() {
    _controle.removeListener(_redesenhar);
    _controle.dispose();
    _liberarTela();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: CoresTocaEssa.fundo,
        body: switch ((_controle.pareada, _controle.conteudo)) {
          (false, _) => _CodigoParaConectar(codigo: _controle.codigo),
          (true, null) => const _Aviso(
              titulo: 'TV conectada', texto: 'Conectada · esperando a música'),
          (true, final conteudo?) => _LetraNaTv(conteudo: conteudo),
        },
      );
}

/// Código grande no centro, com o caminho no celular.
class _CodigoParaConectar extends StatelessWidget {
  const _CodigoParaConectar({required this.codigo});

  final String? codigo;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, limites) {
          final u = limites.maxWidth / 100;
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Conectar esta TV',
                    style: TextStyle(
                        fontSize: 2.4 * u,
                        color: CoresTocaEssa.textoSecundario)),
                SizedBox(height: 2 * u),
                Text(codigo ?? '····',
                    style: TextStyle(
                        fontSize: 12 * u,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 2 * u,
                        color: CoresTocaEssa.texto)),
                SizedBox(height: 2 * u),
                Text('No celular: Mais → Letra na TV → Conectar TV',
                    style: TextStyle(
                        fontSize: 1.8 * u,
                        color: CoresTocaEssa.textoSecundario)),
              ],
            ),
          );
        },
      );
}

class _Aviso extends StatelessWidget {
  const _Aviso({required this.titulo, required this.texto});

  final String titulo;
  final String texto;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, limites) {
          final u = limites.maxWidth / 100;
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(titulo,
                    style: TextStyle(
                        fontSize: 4 * u,
                        fontWeight: FontWeight.w800,
                        color: CoresTocaEssa.texto)),
                SizedBox(height: u),
                Text(texto,
                    style: TextStyle(
                        fontSize: 1.8 * u,
                        color: CoresTocaEssa.textoSecundario)),
              ],
            ),
          );
        },
      );
}
