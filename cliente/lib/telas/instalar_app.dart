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
      builder: (_) => _PassoAPasso(iPhone: instalacao.iPhone),
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

/// Caminho no navegador quando ele não oferece a própria janela.
class _PassoAPasso extends StatelessWidget {
  const _PassoAPasso({required this.iPhone});

  final bool iPhone;

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    final passos = iPhone
        ? const [
            'No Safari, toque em Compartilhar (o quadrado com a seta para cima).',
            'Role e toque em "Adicionar à Tela de Início".',
            'Toque em Adicionar. O TocaEssa aparece com os outros apps.',
          ]
        : const [
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
            // No iPhone, o app instalado guarda os dados separado do Safari.
            if (iPhone) ...[
              const SizedBox(height: EspacoTocaEssa.pequeno),
              Container(
                padding: const EdgeInsets.all(EspacoTocaEssa.medio),
                decoration: BoxDecoration(
                  color: CoresTocaEssa.superficie,
                  borderRadius: BorderRadius.circular(RaioTocaEssa.cartao),
                  border: Border.all(color: CoresTocaEssa.borda),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline_rounded,
                        size: 20, color: CoresTocaEssa.roxoClaro),
                    const SizedBox(width: EspacoTocaEssa.pequeno),
                    Expanded(
                      child: Text(
                        'Na primeira vez pelo ícone, entre de novo na sua '
                        'conta. As cifras ficam guardadas para usar sem '
                        'internet depois de abrir a setlist uma vez com '
                        'internet.',
                        style: texto.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
