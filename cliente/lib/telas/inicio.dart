import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../infraestrutura/api_toca_essa.dart';
import '../tema/tema_toca_essa.dart';
import 'componentes.dart';
import 'componentes_formulario.dart';
import 'fundo_toca_essa.dart';

class Inicio extends StatefulWidget {
  const Inicio({super.key, required this.api});
  final ApiTocaEssa api;

  @override
  State<Inicio> createState() => _InicioState();
}

class _InicioState extends State<Inicio> {
  static const _tamanhoCodigo = 6;
  final _codigo = TextEditingController();
  bool _artistaComSessao = false;

  @override
  void initState() {
    super.initState();
    // Habilita "Entrar" assim que o código fica completo.
    _codigo.addListener(() => setState(() {}));
    _verificarSessaoDoArtista();
  }

  @override
  void dispose() {
    _codigo.dispose();
    super.dispose();
  }

  bool get _codigoCompleto => _codigo.text.length == _tamanhoCodigo;

  Future<void> _verificarSessaoDoArtista() async {
    final preferencias = await SharedPreferences.getInstance();
    final temSessao = preferencias.getString('token_do_artista') != null;
    if (mounted) setState(() => _artistaComSessao = temSessao);
  }

  Future<void> _abrirPainelDoArtista() async {
    await Navigator.pushNamed(context, '/artista');
    // O artista pode ter entrado ou saído da conta no painel.
    await _verificarSessaoDoArtista();
  }

  void _entrar() {
    if (!_codigoCompleto) return;
    FocusManager.instance.primaryFocus?.unfocus();
    Navigator.pushNamed(context, '/publico/${_codigo.text}');
  }

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    return Scaffold(
      body: FundoTocaEssa(
        variante: VarianteFundoTocaEssa.palco,
        intensidade: IntensidadeFundoTocaEssa.imersiva,
        child: ConteudoMobile(
          filho: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: EspacoTocaEssa.enorme),
              Image.asset(
                'assets/marca/toca_essa_horizontal.png',
                height: 96,
                fit: BoxFit.contain,
                semanticLabel: 'TocaEssa',
              ),
              const SizedBox(height: EspacoTocaEssa.base),
              Text(
                'A música que você quer ouvir, mais perto do palco.',
                textAlign: TextAlign.center,
                style: texto.headlineSmall,
              ),
              const SizedBox(height: EspacoTocaEssa.enorme),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(EspacoTocaEssa.base),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Vai curtir um show?',
                        textAlign: TextAlign.center,
                        style: texto.titleMedium,
                      ),
                      const SizedBox(height: EspacoTocaEssa.base),
                      CampoCodigo(
                        controlador: _codigo,
                        tamanho: _tamanhoCodigo,
                        aoCompletar: (_) => _entrar(),
                      ),
                      const SizedBox(height: EspacoTocaEssa.pequeno),
                      Text(
                        'Peça o código ao artista ou leia o QR Code do palco.',
                        textAlign: TextAlign.center,
                        style: texto.bodyMedium
                            ?.copyWith(color: CoresTocaEssa.textoSecundario),
                      ),
                      const SizedBox(height: EspacoTocaEssa.base),
                      FilledButton(
                        onPressed: _codigoCompleto ? _entrar : null,
                        child: const Text('Entrar'),
                      ),
                      const SizedBox(height: EspacoTocaEssa.pequeno),
                      TextButton.icon(
                        onPressed: () =>
                            Navigator.pushNamed(context, '/minha-conta'),
                        icon: const Icon(Icons.history_rounded, size: 18),
                        label: const Text('Shows que eu curti'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: EspacoTocaEssa.grande),
              const _SeparadorOu(),
              const SizedBox(height: EspacoTocaEssa.pequeno),
              _AcessoDoArtista(
                comSessao: _artistaComSessao,
                aoAbrir: _abrirPainelDoArtista,
              ),
              const SizedBox(height: EspacoTocaEssa.enorme + 8),
              const _AssinaturaInicio(),
              const SizedBox(height: EspacoTocaEssa.base),
            ],
          ),
        ),
      ),
    );
  }
}

class _SeparadorOu extends StatelessWidget {
  const _SeparadorOu();

  @override
  Widget build(BuildContext context) => const Row(
        children: [
          Expanded(child: Divider()),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 14),
            child: Text(
              'ou',
              style: TextStyle(color: CoresTocaEssa.textoSecundario),
            ),
          ),
          Expanded(child: Divider()),
        ],
      );
}

class _AcessoDoArtista extends StatelessWidget {
  const _AcessoDoArtista({required this.comSessao, required this.aoAbrir});

  final bool comSessao;
  final VoidCallback aoAbrir;

  @override
  Widget build(BuildContext context) => Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          const Icon(
            Icons.mic_rounded,
            size: 18,
            color: CoresTocaEssa.textoSecundario,
          ),
          const SizedBox(width: 6),
          const Text(
            'É artista?',
            style: TextStyle(color: CoresTocaEssa.textoSecundario),
          ),
          TextButton(
            onPressed: aoAbrir,
            child: Text(
              comSessao ? 'Continuar no meu painel' : 'Acessar meu painel',
            ),
          ),
        ],
      );
}

class _AssinaturaInicio extends StatelessWidget {
  const _AssinaturaInicio();

  @override
  Widget build(BuildContext context) => Row(
        children: [
          const Expanded(child: Divider()),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.auto_awesome_rounded,
                  size: 15,
                  color: CoresTocaEssa.roxoClaro,
                ),
                const SizedBox(width: 7),
                Text.rich(
                  const TextSpan(
                    text: 'Feito por ',
                    style: TextStyle(
                      color: CoresTocaEssa.textoSecundario,
                      fontSize: 12,
                    ),
                    children: [
                      TextSpan(
                        text: 'Advair',
                        style: TextStyle(
                          color: CoresTocaEssa.roxoClaro,
                          fontWeight: FontWeight.w700,
                          letterSpacing: .4,
                        ),
                      ),
                    ],
                  ),
                  semanticsLabel: 'Feito por Advair',
                ),
              ],
            ),
          ),
          const Expanded(child: Divider()),
        ],
      );
}
