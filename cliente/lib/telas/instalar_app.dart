import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../infraestrutura/instalacao_do_app.dart';
import '../tema/tema_toca_essa.dart';

/// "Instalar no celular", para o grupo Conta dos perfis. Instalado na tela
/// de início, o TocaEssa abre como app e o iPhone não apaga o que ficou
/// guardado (login e dados para usar sem internet). Já instalado, some.
class LinhaInstalarApp extends StatelessWidget {
  LinhaInstalarApp({super.key, InstalacaoDoApp? instalacao})
      : instalacao = instalacao ?? instalacaoDoNavegador();

  final InstalacaoDoApp instalacao;

  Future<void> _instalar(BuildContext context) async {
    if (instalacao.podePedirAoNavegador) {
      await instalacao.pedir();
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) =>
          instalacao.iPhone ? const _JanelaDoIphone() : const _PassoAPasso(),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (instalacao.instalado) return const SizedBox.shrink();
    final texto = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      child: InkWell(
        onTap: () => _instalar(context),
        child: Padding(
          padding: const EdgeInsets.all(EspacoTocaEssa.base),
          child: Row(
            children: [
              const Icon(Icons.install_mobile_rounded,
                  size: 20, color: CoresTocaEssa.roxoClaro),
              const SizedBox(width: EspacoTocaEssa.base),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Instalar no celular', style: texto.bodyLarge),
                    Text(
                      'Abre como app e não perde o que ficou guardado',
                      style: texto.bodyMedium
                          ?.copyWith(color: CoresTocaEssa.textoSecundario),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded,
                  color: CoresTocaEssa.textoSecundario),
            ],
          ),
        ),
      ),
    );
  }
}

/// No jeito da folha de instalação do iOS: o ícone do app, os passos com os
/// símbolos do Safari e uma seta apontando para a barra do Safari, embaixo.
/// O Safari não instala sites sozinho; a janela só mostra o caminho.
class _JanelaDoIphone extends StatelessWidget {
  const _JanelaDoIphone();

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    final secundario =
        texto.bodyMedium?.copyWith(color: CoresTocaEssa.textoSecundario);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
            EspacoTocaEssa.base, 0, EspacoTocaEssa.base, EspacoTocaEssa.base),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                ClipRRect(
                  key: const Key('icone-do-app'),
                  borderRadius: BorderRadius.circular(14),
                  child: Image.asset('assets/marca/toca_essa_icone.png',
                      width: 60, height: 60),
                ),
                const SizedBox(width: EspacoTocaEssa.base),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('TocaEssa', style: texto.titleLarge),
                      Text('Instale no seu iPhone', style: secundario),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: EspacoTocaEssa.base),
            Text(
              'Na tela de início, o TocaEssa abre como app e o iPhone não '
              'apaga o que ficou guardado.',
              style: secundario,
            ),
            const SizedBox(height: EspacoTocaEssa.base),
            Container(
              decoration: BoxDecoration(
                color: CoresTocaEssa.superficie,
                borderRadius: BorderRadius.circular(RaioTocaEssa.cartao),
                border: Border.all(color: CoresTocaEssa.borda),
              ),
              child: const Column(
                children: [
                  _PassoDoIphone(
                    numero: 1,
                    icone: CupertinoIcons.share,
                    texto: 'Toque em Compartilhar na barra do Safari. '
                        'No iOS 26, ele fica dentro do ···',
                  ),
                  Divider(height: 1, indent: 52),
                  _PassoDoIphone(
                    numero: 2,
                    icone: CupertinoIcons.plus_app,
                    texto: 'Role e toque em "Adicionar à Tela de Início"',
                  ),
                  Divider(height: 1, indent: 52),
                  _PassoDoIphone(
                    numero: 3,
                    icone: CupertinoIcons.checkmark_alt,
                    texto: 'Toque em Adicionar',
                  ),
                ],
              ),
            ),
            const SizedBox(height: EspacoTocaEssa.medio),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline_rounded,
                    size: 18, color: CoresTocaEssa.roxoClaro),
                const SizedBox(width: EspacoTocaEssa.pequeno),
                Expanded(
                  child: Text(
                    'Na primeira vez pelo ícone, entre de novo na sua conta. '
                    'As cifras ficam guardadas para usar sem internet depois '
                    'de abrir a setlist uma vez com internet.',
                    style: secundario,
                  ),
                ),
              ],
            ),
            const SizedBox(height: EspacoTocaEssa.base),
            const _SetaParaOSafari(),
          ],
        ),
      ),
    );
  }
}

class _PassoDoIphone extends StatelessWidget {
  const _PassoDoIphone(
      {required this.numero, required this.icone, required this.texto});

  final int numero;
  final IconData icone;
  final String texto;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: EspacoTocaEssa.medio, vertical: EspacoTocaEssa.medio),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                  color: CoresTocaEssa.roxoClaro, shape: BoxShape.circle),
              child: Text('$numero',
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w600)),
            ),
            const SizedBox(width: EspacoTocaEssa.medio),
            Expanded(
                child: Text(texto,
                    style: Theme.of(context).textTheme.bodyLarge)),
            const SizedBox(width: EspacoTocaEssa.pequeno),
            Icon(icone, size: 22, color: CoresTocaEssa.roxoClaro),
          ],
        ),
      );
}

/// Seta que pula algumas vezes, apontando para a barra do Safari logo abaixo
/// da janela. Para depois de alguns pulos, sem distrair.
class _SetaParaOSafari extends StatefulWidget {
  const _SetaParaOSafari();

  @override
  State<_SetaParaOSafari> createState() => _SetaParaOSafariState();
}

class _SetaParaOSafariState extends State<_SetaParaOSafari>
    with SingleTickerProviderStateMixin {
  late final _pulo = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 600),
  )..repeat(reverse: true, count: 8);

  @override
  void dispose() {
    _pulo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
        label: 'Seta apontando para a barra do Safari',
        child: ExcludeSemantics(
          child: Column(
            children: [
              Text('O Compartilhar fica na barra do Safari, aqui embaixo',
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: CoresTocaEssa.textoSecundario)),
              AnimatedBuilder(
                animation: _pulo,
                builder: (_, seta) => Transform.translate(
                  offset: Offset(
                      0, 8 * Curves.easeInOut.transform(_pulo.value)),
                  child: seta,
                ),
                child: const Icon(Icons.keyboard_double_arrow_down_rounded,
                    size: 36, color: CoresTocaEssa.roxoClaro),
              ),
            ],
          ),
        ),
      );
}

/// Caminho no navegador quando ele não oferece a própria janela.
class _PassoAPasso extends StatelessWidget {
  const _PassoAPasso();

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    const passos = [
      'No navegador, abra o menu (⋮).',
      'Toque em "Instalar app" ou "Adicionar à tela inicial".',
      'Confirme. O TocaEssa aparece com os outros apps.',
    ];
    return SafeArea(
      // Fonte grande ou tela baixa: o passo a passo rola.
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(EspacoTocaEssa.base, 0,
            EspacoTocaEssa.base, EspacoTocaEssa.grande),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Instalar o TocaEssa', style: texto.titleLarge),
            const SizedBox(height: EspacoTocaEssa.pequeno),
            Text(
              'Instalado, ele abre como app e o celular não apaga o que '
              'ficou guardado, como o login e as cifras para usar sem '
              'internet.',
              style: texto.bodyMedium
                  ?.copyWith(color: CoresTocaEssa.textoSecundario),
            ),
            const SizedBox(height: EspacoTocaEssa.base),
            for (final (indice, passo) in passos.indexed)
              Padding(
                padding: const EdgeInsets.only(bottom: EspacoTocaEssa.medio),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${indice + 1}.',
                        style: texto.bodyLarge
                            ?.copyWith(color: CoresTocaEssa.roxoClaro)),
                    const SizedBox(width: EspacoTocaEssa.pequeno),
                    Expanded(child: Text(passo, style: texto.bodyLarge)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
