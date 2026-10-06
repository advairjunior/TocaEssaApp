part of 'area_do_publico.dart';

extension _RetrospectivaAreaDoPublico on _AreaDoPublicoState {
  Future<void> _escolherFotoDaMinhaRetrospectiva() async {
    final foto = await escolherFotoDoCartao(context);
    if (foto != null && mounted) {
      _mudarEstado(() => _fotoRetrospectivaPublico = foto);
    }
  }

  Future<void> _baixarMinhaRetrospectiva(Apresentacao apresentacao) async {
    _mudarEstado(() => _gerandoRetrospectiva = true);
    try {
      await baixarCartaoComoImagem(
        _chaveRetrospectivaPublico,
        'tocaessa-${nomeDeArquivo(apresentacao.nome)}-meu-resumo.png',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sua retrospectiva foi salva.')),
      );
    } catch (erro) {
      if (mounted) mostrarErro(context, erro);
    } finally {
      if (mounted) _mudarEstado(() => _gerandoRetrospectiva = false);
    }
  }

  List<Widget> _construirRetrospectivaDoPublico(
    Apresentacao apresentacao,
    ParticipanteDaResenha participante,
  ) =>
      [
        Text(
          'Minha retrospectiva',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: EspacoTocaEssa.mini),
        Text(
          'Salve e compartilhe seu momento na resenha — com a sua foto, '
          'se quiser.',
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: CoresTocaEssa.textoSecundario),
        ),
        const SizedBox(height: EspacoTocaEssa.base),
        RepaintBoundary(
          key: _chaveRetrospectivaPublico,
          child: _CartaoRetrospectivaDoPublico(
            apresentacao: apresentacao,
            participante: participante,
            companhia: [
              for (final pessoa in _participantesDaResenha)
                if (!pessoa.ehArtista &&
                    pessoa.publicoId != participante.publicoId)
                  PessoaDoEncontro(
                    publicoId: pessoa.publicoId,
                    nome: pessoa.nome,
                    fotoUrl: pessoa.fotoUrl,
                  ),
            ],
            foto: _fotoRetrospectivaPublico,
            enderecoFotoDoEncontro:
                _api.enderecoArquivo(apresentacao.fotoRetrospectivaUrl),
          ),
        ),
        const SizedBox(height: EspacoTocaEssa.base),
        // Sem foto própria o cartão usa a do encontro ou o fundo da marca,
        // então já pode ser salvo; a foto pessoal é um extra.
        FilledButton.icon(
          onPressed: _gerandoRetrospectiva
              ? null
              : () => _baixarMinhaRetrospectiva(apresentacao),
          icon: const Icon(Icons.ios_share_rounded),
          label: Text(_gerandoRetrospectiva
              ? 'Gerando imagem...'
              : 'Salvar imagem para compartilhar'),
        ),
        TextButton.icon(
          onPressed: _escolherFotoDaMinhaRetrospectiva,
          icon: const Icon(Icons.add_a_photo_outlined, size: 18),
          label: Text(_fotoRetrospectivaPublico == null
              ? 'Colocar minha foto'
              : 'Trocar minha foto'),
        ),
      ];
}

class _CartaoRetrospectivaDoPublico extends StatelessWidget {
  const _CartaoRetrospectivaDoPublico({
    required this.apresentacao,
    required this.participante,
    required this.companhia,
    required this.foto,
    required this.enderecoFotoDoEncontro,
  });

  final Apresentacao apresentacao;
  final ParticipanteDaResenha participante;

  /// Quem mais estava na resenha, sem o artista e sem a própria pessoa.
  final List<PessoaDoEncontro> companhia;
  final Uint8List? foto;

  /// Foto que o artista publicou do encontro; fundo quando não há foto própria.
  final String? enderecoFotoDoEncontro;

  // Fundo da marca para quando não há foto nenhuma.
  static const _fundoDaMarca = DecoratedBox(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFF3A1C6E),
          CoresTocaEssa.destaqueFundo,
          Color(0xFF100B18)
        ],
        stops: [0, .45, 1],
      ),
    ),
    child: Align(
      alignment: Alignment(1.6, -.2),
      child:
          Icon(Icons.graphic_eq_rounded, size: 260, color: Color(0x14FFFFFF)),
    ),
  );

  @override
  Widget build(BuildContext context) => AspectRatio(
        aspectRatio: 9 / 16,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(26),
          child: DecoratedBox(
            decoration: const BoxDecoration(color: Color(0xFF100B18)),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (foto != null)
                  Image.memory(foto!, fit: BoxFit.cover)
                else if (enderecoFotoDoEncontro != null)
                  Image.network(
                    enderecoFotoDoEncontro!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _fundoDaMarca,
                  )
                else
                  _fundoDaMarca,
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      // Faixa do meio transparente: a foto precisa aparecer.
                      colors: [
                        Color(0xB308050D),
                        Color(0x0008050D),
                        Color(0x0008050D),
                        Color(0xF208050D),
                      ],
                      stops: [0, .3, .5, .92],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Image.asset('assets/marca/toca_essa_icone.png',
                              width: 34, height: 34),
                          const SizedBox(width: 8),
                          const Text('TocaEssa',
                              style: TextStyle(
                                  fontSize: 20, fontWeight: FontWeight.w700)),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Text(participante.nome,
                          style: const TextStyle(
                              fontSize: 26, fontWeight: FontWeight.w700)),
                      Text(
                        '${apresentacao.nome} · ${formatarData(apresentacao.data)}',
                        style: const TextStyle(color: Color(0xFFD8CFDF)),
                      ),
                      if (companhia.isNotEmpty)
                        Text(
                          textoDaCompanhia(companhia),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 13, color: CoresTocaEssa.roxoClaro),
                        ),
                      const Spacer(),
                      if (participante.musicasMaisPedidas.isNotEmpty) ...[
                        const Text('MINHA MÚSICA DA RESENHA',
                            style: TextStyle(
                                color: CoresTocaEssa.roxoClaro,
                                fontSize: 11,
                                fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        Text(participante.musicasMaisPedidas.first.musica,
                            style: const TextStyle(
                                fontSize: 22, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 18),
                      ],
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 16),
                        decoration: BoxDecoration(
                          color: const Color(0xBB100B18),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: const Color(0xFF665578)),
                        ),
                        child: Row(
                          children: [
                            _DadoDoPublico(
                                valor: '${participante.pedidos}',
                                rotulo: 'pedidos'),
                            _DadoDoPublico(
                                valor: '${participante.pedidosTocados}',
                                rotulo: 'tocados'),
                            _DadoDoPublico(
                                valor: participante.mediaAvaliacoes
                                        ?.toStringAsFixed(1) ??
                                    '—',
                                rotulo: 'avaliação'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}

class _DadoDoPublico extends StatelessWidget {
  const _DadoDoPublico({required this.valor, required this.rotulo});
  final String valor;
  final String rotulo;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(
          children: [
            Text(valor,
                style:
                    const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
            Text(rotulo,
                style: const TextStyle(
                    fontSize: 11, color: CoresTocaEssa.textoSecundario)),
          ],
        ),
      );
}
