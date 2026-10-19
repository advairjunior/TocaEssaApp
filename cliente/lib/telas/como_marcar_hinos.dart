import 'package:flutter/material.dart';

import '../tema/tema_toca_essa.dart';

// Cada marcação que o app entende e o que ela faz.
const _marcacoes = [
  ('Tom: G', 'O tom do hino. Não vira parte.'),
  ('(Estrofe 1)', 'Começa uma estrofe. O app reveza quem canta cada uma.'),
  (
    '(Coro)',
    'Com a letra embaixo, é o coro. Ele entra sozinho depois de toda '
        'estrofe; sem letra embaixo, só repete. "(Refrão)" também vale.'
  ),
  (
    '(Solo sax tenor)',
    'Parte instrumental: ninguém canta. Vale qualquer instrumento depois '
        'de "Solo", como (Solo trompete).'
  ),
  ('(Introdução)', 'Instrumental antes da primeira estrofe. "(Intro)" vale.'),
  ('(Interlúdio)', 'Instrumental no meio do hino.'),
  ('(Final)', 'Instrumental no fim do hino.'),
  ('(Coro 2x)', 'O "2x" no fim repete a parte. Vale para todas.'),
];

const _exemplo = '''Tom: G

(Introdução)
G   D

(Estrofe 1)
G        Bm
Cristo Jesus, o santo Cordeiro

(Coro)
G           Bm
Por Cristo, resgatado

(Solo sax tenor)
G   D   G

(Estrofe 2)
G      Bm
Preso estava na iniquidade''';

/// Sumário das marcações da letra do louvor, para quem for colar um hino.
Future<void> mostrarComoMarcarAsPartes(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (contexto) {
        final texto = Theme.of(contexto).textTheme;
        const mono = TextStyle(fontFamily: 'JetBrainsMono');
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(contexto).height * .85),
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(EspacoTocaEssa.base, 0,
                  EspacoTocaEssa.base, EspacoTocaEssa.grande),
              children: [
                Text('Como marcar as partes', style: texto.titleLarge),
                const SizedBox(height: EspacoTocaEssa.pequeno),
                Text(
                  'Escreva cada marcação numa linha sozinha, antes da parte. '
                  'Maiúscula e acento tanto faz; também valem [Estrofe 1], '
                  'Estrofe 1: e 1ª estrofe.',
                  style: texto.bodyMedium
                      ?.copyWith(color: CoresTocaEssa.textoSecundario),
                ),
                const SizedBox(height: EspacoTocaEssa.base),
                for (final (marcacao, explicacao) in _marcacoes)
                  Padding(
                    padding:
                        const EdgeInsets.only(bottom: EspacoTocaEssa.medio),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(marcacao,
                            style: mono.copyWith(
                                color: CoresTocaEssa.roxoClaro,
                                fontWeight: FontWeight.w700)),
                        Text(explicacao, style: texto.bodyMedium),
                      ],
                    ),
                  ),
                const SizedBox(height: EspacoTocaEssa.pequeno),
                Text('Exemplo', style: texto.titleMedium),
                const SizedBox(height: EspacoTocaEssa.pequeno),
                Container(
                  padding: const EdgeInsets.all(EspacoTocaEssa.medio),
                  decoration: BoxDecoration(
                    color: CoresTocaEssa.superficie,
                    borderRadius: BorderRadius.circular(RaioTocaEssa.campo),
                    border: Border.all(color: CoresTocaEssa.borda),
                  ),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Text(_exemplo, style: mono.copyWith(fontSize: 13)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
