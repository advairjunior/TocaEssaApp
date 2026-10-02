import 'package:flutter/material.dart';

import '../dominio/modelos.dart';
import '../tema/tema_toca_essa.dart';
import 'componentes.dart';
import 'componentes_lista.dart';
import 'fundo_toca_essa.dart';
import 'progresso_do_publico.dart';

void abrirPerfilParticipante(BuildContext context,
    ParticipanteDaResenha participante, String? enderecoFoto) {
  Navigator.push<void>(
      context,
      MaterialPageRoute(
          builder: (_) => PerfilParticipante(
              participante: participante, enderecoFoto: enderecoFoto)));
}

class PerfilParticipante extends StatefulWidget {
  const PerfilParticipante(
      {super.key, required this.participante, required this.enderecoFoto});
  final ParticipanteDaResenha participante;
  final String? enderecoFoto;
  @override
  State<PerfilParticipante> createState() => _PerfilParticipanteState();
}

class _PerfilParticipanteState extends State<PerfilParticipante> {
  static const _avaliacoesPorPagina = 5;
  int _pagina = 0;
  bool _nestaResenha = false;

  List<_Conquista> _conquistas(ParticipanteDaResenha pessoa) => [
        const _Conquista(
            'Na roda', 'Participou desta resenha.', 1, 1, Icons.groups_rounded),
        _Conquista('Solta o som', 'Fez um pedido nesta resenha.',
            pessoa.pedidos, 1, Icons.music_note_rounded),
        _Conquista('Tocou a minha', 'Teve um pedido tocado nesta resenha.',
            pessoa.pedidosTocados, 1, Icons.check_circle_outline),
        _Conquista('Ouvido atento', 'Avaliou três músicas nesta resenha.',
            pessoa.avaliacoes.length, 3, Icons.headphones_rounded),
        _Conquista('VIP da noite', 'Teve cinco pedidos tocados nesta resenha.',
            pessoa.pedidosTocados, 5, Icons.emoji_events_rounded),
        _Conquista('Pede mais uma', 'Fez cinco pedidos nesta resenha.',
            pessoa.pedidos, 5, Icons.queue_music_rounded),
      ];

  @override
  Widget build(BuildContext context) {
    final pessoa = widget.participante;
    final texto = Theme.of(context).textTheme;
    final secundario =
        texto.bodyMedium?.copyWith(color: CoresTocaEssa.textoSecundario);
    return Scaffold(
      appBar: AppBar(title: const Text('Perfil do participante')),
      body: FundoTocaEssa(
        variante: VarianteFundoTocaEssa.atmosfera,
        intensidade: IntensidadeFundoTocaEssa.suave,
        child: ConteudoMobile(
          filho: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FotoPerfilArtistico(
                enderecoFoto: widget.enderecoFoto,
                tamanho: 112,
                iconeFallback:
                    pessoa.ehArtista ? Icons.mic_rounded : Icons.person_rounded,
              ),
              const SizedBox(height: EspacoTocaEssa.base),
              Text(pessoa.nome,
                  textAlign: TextAlign.center, style: texto.headlineSmall),
              const SizedBox(height: EspacoTocaEssa.mini),
              Text(
                pessoa.ehArtista ? 'Artista · anfitrião' : 'Galera da resenha',
                textAlign: TextAlign.center,
                style:
                    texto.labelLarge?.copyWith(color: CoresTocaEssa.roxoClaro),
              ),
              const SizedBox(height: EspacoTocaEssa.enorme),
              if (pessoa.ehArtista)
                Text(
                  'Quem faz o som acontecer. As estatísticas da apresentação '
                  'ficam no Painel do Artista.',
                  textAlign: TextAlign.center,
                  style: secundario,
                )
              else ...[
                Row(
                  children: [
                    Flexible(
                      child: AbaDeTexto(
                        rotulo: 'Geral',
                        selecionada: !_nestaResenha,
                        tocar: () => setState(() => _nestaResenha = false),
                      ),
                    ),
                    const SizedBox(width: EspacoTocaEssa.base),
                    Flexible(
                      child: AbaDeTexto(
                        rotulo: 'Nesta resenha',
                        selecionada: _nestaResenha,
                        tocar: () => setState(() => _nestaResenha = true),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: EspacoTocaEssa.base),
                if (!_nestaResenha)
                  if (pessoa.estatisticasGerais != null)
                    ProgressoDoPublico(dados: pessoa.estatisticasGerais!)
                  else
                    Padding(
                      padding: const EdgeInsets.all(EspacoTocaEssa.grande),
                      child: Text(
                        'O perfil geral está indisponível no momento. '
                        'Veja os dados desta resenha.',
                        textAlign: TextAlign.center,
                        style: secundario,
                      ),
                    )
                else
                  ..._construirNestaResenha(context, pessoa),
              ],
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _construirNestaResenha(
    BuildContext context,
    ParticipanteDaResenha pessoa,
  ) {
    final texto = Theme.of(context).textTheme;
    final secundario =
        texto.bodyMedium?.copyWith(color: CoresTocaEssa.textoSecundario);
    final notas = pessoa.avaliacoes;
    final conquistas = _conquistas(pessoa);
    final conquistadas = conquistas.where((c) => c.liberada).length;
    final totalPaginas = (notas.length / _avaliacoesPorPagina).ceil();
    const entreSecoes = SizedBox(height: EspacoTocaEssa.enorme);
    return [
      Container(
        padding: const EdgeInsets.symmetric(vertical: EspacoTocaEssa.base),
        decoration: BoxDecoration(
          color: CoresTocaEssa.superficie,
          borderRadius: BorderRadius.circular(RaioTocaEssa.cartao),
          border: Border.all(color: CoresTocaEssa.borda),
        ),
        child: IntrinsicHeight(
          child: Row(
            children: [
              _Numero(valor: '${pessoa.pedidos}', rotulo: 'pedidos'),
              const VerticalDivider(width: 1),
              _Numero(valor: '${pessoa.pedidosTocados}', rotulo: 'tocados'),
              const VerticalDivider(width: 1),
              _Numero(valor: '${notas.length}', rotulo: 'avaliações'),
              const VerticalDivider(width: 1),
              _Numero(
                valor: pessoa.mediaAvaliacoes?.toStringAsFixed(1) ?? '—',
                rotulo: 'nota média',
              ),
            ],
          ),
        ),
      ),
      entreSecoes,
      const TituloGrupo('Do pedido ao palco'),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: EspacoTocaEssa.mini),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              pessoa.pedidos == 0
                  ? 'Ainda não fez pedidos nesta resenha.'
                  : '${(100 * pessoa.pedidosTocados / pessoa.pedidos).round()}% '
                      'dos pedidos foram tocados',
              style: texto.bodyLarge,
            ),
            const SizedBox(height: EspacoTocaEssa.pequeno),
            LinearProgressIndicator(
              minHeight: 6,
              borderRadius: BorderRadius.circular(RaioTocaEssa.pilula),
              value: pessoa.pedidos == 0
                  ? 0
                  : (pessoa.pedidosTocados / pessoa.pedidos).clamp(0, 1),
            ),
          ],
        ),
      ),
      entreSecoes,
      TituloGrupo('Conquistas da resenha · $conquistadas/${conquistas.length}'),
      GrupoDeLinhas(
        linhas: [
          for (final conquista in conquistas) _LinhaConquista(conquista)
        ],
      ),
      entreSecoes,
      const TituloGrupo('Mais pedidas aqui'),
      FavoritasDoPerfil(musicas: pessoa.musicasMaisPedidas),
      entreSecoes,
      const TituloGrupo('Histórico de avaliações'),
      if (notas.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: EspacoTocaEssa.mini),
          child: Text('Nenhuma avaliação por enquanto.', style: secundario),
        )
      else
        GrupoDeLinhas(
          linhas: [
            for (final nota in notas
                .skip(_pagina * _avaliacoesPorPagina)
                .take(_avaliacoesPorPagina))
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: EspacoTocaEssa.base,
                  vertical: EspacoTocaEssa.medio,
                ),
                child: Row(
                  children: [
                    const Icon(Icons.music_note_rounded,
                        size: 20, color: CoresTocaEssa.roxoClaro),
                    const SizedBox(width: EspacoTocaEssa.base),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(nota.musica, style: texto.titleMedium),
                          Text(formatarData(nota.avaliadoEm.toLocal()),
                              style: secundario),
                        ],
                      ),
                    ),
                    Text(
                      '${nota.estrelas} ★',
                      style: texto.labelLarge
                          ?.copyWith(color: const Color(0xFFFFC857)),
                    ),
                  ],
                ),
              ),
          ],
        ),
      if (totalPaginas > 1)
        Row(
          children: [
            IconButton(
              tooltip: 'Página anterior',
              onPressed: _pagina == 0 ? null : () => setState(() => _pagina--),
              icon: const Icon(Icons.chevron_left_rounded),
            ),
            Expanded(
              child: Text('${_pagina + 1} de $totalPaginas',
                  textAlign: TextAlign.center, style: secundario),
            ),
            IconButton(
              tooltip: 'Próxima página',
              onPressed: _pagina + 1 >= totalPaginas
                  ? null
                  : () => setState(() => _pagina++),
              icon: const Icon(Icons.chevron_right_rounded),
            ),
          ],
        ),
      const SizedBox(height: EspacoTocaEssa.base),
    ];
  }
}

class _Conquista {
  const _Conquista(
      this.titulo, this.descricao, this.atual, this.meta, this.icone);
  final String titulo;
  final String descricao;
  final int atual;
  final int meta;
  final IconData icone;
  bool get liberada => atual >= meta;
}

class _LinhaConquista extends StatelessWidget {
  const _LinhaConquista(this.conquista);
  final _Conquista conquista;

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    final liberada = conquista.liberada;
    return Opacity(
      opacity: liberada ? 1 : .6,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: EspacoTocaEssa.base,
          vertical: EspacoTocaEssa.medio,
        ),
        child: Row(
          children: [
            Icon(
              liberada ? conquista.icone : Icons.lock_outline_rounded,
              size: 20,
              color: CoresTocaEssa.roxoClaro,
            ),
            const SizedBox(width: EspacoTocaEssa.base),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(conquista.titulo, style: texto.titleMedium),
                  Text(
                    conquista.descricao,
                    style: texto.bodyMedium
                        ?.copyWith(color: CoresTocaEssa.textoSecundario),
                  ),
                ],
              ),
            ),
            const SizedBox(width: EspacoTocaEssa.pequeno),
            liberada
                ? const Icon(Icons.check_circle_rounded,
                    size: 20, color: Color(0xFF54D98C))
                : Text(
                    '${conquista.atual.clamp(0, conquista.meta)}/${conquista.meta}',
                    style: texto.labelLarge
                        ?.copyWith(color: CoresTocaEssa.textoSecundario),
                  ),
          ],
        ),
      ),
    );
  }
}

class _Numero extends StatelessWidget {
  const _Numero({required this.valor, required this.rotulo});
  final String valor;
  final String rotulo;

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    return Expanded(
      child: Column(
        children: [
          Text(valor, style: texto.titleLarge),
          const SizedBox(height: 2),
          Text(
            rotulo,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: texto.labelMedium
                ?.copyWith(color: CoresTocaEssa.textoSecundario),
          ),
        ],
      ),
    );
  }
}
