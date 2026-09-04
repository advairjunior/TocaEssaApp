import 'package:flutter/material.dart';

import '../infraestrutura/api_toca_essa.dart';
import '../tema/tema_toca_essa.dart';
import 'componentes.dart';

class Inicio extends StatefulWidget {
  const Inicio({super.key, required this.api});
  final ApiTocaEssa api;

  @override
  State<Inicio> createState() => _InicioState();
}

class _InicioState extends State<Inicio> {
  final _codigo = TextEditingController();

  @override
  void dispose() {
    _codigo.dispose();
    super.dispose();
  }

  void _entrar() {
    final codigo = _codigo.text.trim().toUpperCase();
    if (codigo.isEmpty) return;
    Navigator.pushNamed(context, '/publico/$codigo');
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(0, -0.85),
              radius: 1.15,
              colors: [Color(0xFF24143C), CoresTocaEssa.fundo],
              stops: [0, 0.72],
            ),
          ),
          child: ConteudoMobile(
            filho: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 42),
                Image.asset(
                  'assets/marca/toca_essa_horizontal.png',
                  height: 104,
                  fit: BoxFit.contain,
                  semanticLabel: 'TocaEssa',
                ),
                const SizedBox(height: 14),
                Text(
                  'A música que você quer ouvir,\nmais perto do palco.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 10),
                const Text(
                  'Entre na Apresentação e envie seu Pedido Musical.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: CoresTocaEssa.textoSecundario),
                ),
                const SizedBox(height: 36),
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF25183A), CoresTocaEssa.superficie],
                    ),
                    border: Border.all(color: const Color(0xFF503778)),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x33784DFF),
                        blurRadius: 30,
                        offset: Offset(0, 14),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Row(
                        children: [
                          _IconeInicio(
                            icone: Icons.people_alt_rounded,
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Área do Público',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Use o código mostrado pelo artista',
                                  style: TextStyle(
                                    color: CoresTocaEssa.textoSecundario,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      TextField(
                        controller: _codigo,
                        textCapitalization: TextCapitalization.characters,
                        maxLength: 6,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 3,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Código da Apresentação',
                          hintText: 'A1B2C3',
                          counterText: '',
                          prefixIcon: Icon(Icons.tag_rounded),
                        ),
                        onSubmitted: (_) => _entrar(),
                      ),
                      const SizedBox(height: 14),
                      FilledButton.icon(
                        onPressed: _entrar,
                        icon: const Icon(Icons.arrow_forward_rounded),
                        label: const Text('Entrar'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: CoresTocaEssa.superficie.withValues(alpha: 0.72),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: CoresTocaEssa.borda),
                  ),
                  child: Column(
                    children: [
                      const Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          _IconeInicio(icone: Icons.mic_rounded),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Você é o artista?',
                                  style: TextStyle(fontWeight: FontWeight.w600),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Gerencie apresentações e pedidos.',
                                  style: TextStyle(
                                    color: CoresTocaEssa.textoSecundario,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () =>
                              Navigator.pushNamed(context, '/artista'),
                          icon: const Icon(Icons.arrow_forward_rounded),
                          label: const Text('Acessar Painel do Artista'),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      );
}

class _IconeInicio extends StatelessWidget {
  const _IconeInicio({required this.icone});

  final IconData icone;

  @override
  Widget build(BuildContext context) => Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: CoresTocaEssa.roxo.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(icone, color: CoresTocaEssa.roxoClaro),
      );
}
