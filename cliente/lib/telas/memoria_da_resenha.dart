import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../dominio/modelos.dart';
import '../tema/tema_toca_essa.dart';
import 'componentes.dart';
import 'componentes_formulario.dart';
import 'componentes_memoria.dart';

/// Uma noite que já passou, contada como memória: capa em tela cheia, o que
/// foi seu naquela noite e um cartão pronto para compartilhar.
class MemoriaDaResenha extends StatefulWidget {
  const MemoriaDaResenha({
    super.key,
    required this.encontro,
    required this.nome,
    required this.enderecoArquivo,
    required this.abrirResenha,
  });

  final EncontroDoPublico encontro;

  /// Nome de quem está vendo, impresso no cartão compartilhável.
  final String nome;
  final String? Function(String?) enderecoArquivo;

  /// Abre a área completa da resenha (fila, galera e artista).
  final VoidCallback abrirResenha;

  @override
  State<MemoriaDaResenha> createState() => _MemoriaDaResenhaState();
}

class _MemoriaDaResenhaState extends State<MemoriaDaResenha> {
  final _chaveCartao = GlobalKey();
  Uint8List? _minhaFoto;
  bool _gerando = false;

  Apresentacao get _apresentacao => widget.encontro.apresentacao;

  String? get _enderecoCapa => widget.enderecoArquivo(
        _apresentacao.fotoRetrospectivaUrl ??
            _apresentacao.perfilArtistico.fotoUrl,
      );

  Future<void> _escolherFoto() async {
    final foto = await escolherFotoDoCartao(context);
    if (foto != null && mounted) setState(() => _minhaFoto = foto);
  }

  Future<void> _salvar() async {
    setState(() => _gerando = true);
    try {
      await baixarCartaoComoImagem(
        _chaveCartao,
        'tocaessa-${nomeDeArquivo(_apresentacao.nome)}-meu-resumo.png',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sua retrospectiva foi salva.')),
      );
    } catch (erro) {
      if (mounted) mostrarErro(context, erro);
    } finally {
      if (mounted) setState(() => _gerando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    final secundario =
        texto.bodyMedium?.copyWith(color: CoresTocaEssa.textoSecundario);
    return Scaffold(
      backgroundColor: CoresTocaEssa.fundo,
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _CapaDaMemoria(
                  apresentacao: _apresentacao,
                  endereco: _enderecoCapa,
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _SuaNoite(
                        key: const ValueKey('sua-noite'),
                        encontro: widget.encontro,
                        enderecoFoto: widget.enderecoArquivo,
                      ),
                      const SizedBox(height: 44),
                      Text('Guarde essa noite', style: texto.titleLarge),
                      const SizedBox(height: EspacoTocaEssa.mini),
                      Text(
                        'Um cartão no formato de story, com a sua foto se '
                        'quiser.',
                        style: secundario,
                      ),
                      const SizedBox(height: EspacoTocaEssa.base + 4),
                      RepaintBoundary(
                        key: _chaveCartao,
                        child: _CartaoDaNoite(
                          encontro: widget.encontro,
                          nome: widget.nome,
                          minhaFoto: _minhaFoto,
                          enderecoFoto: widget.enderecoArquivo(
                              _apresentacao.fotoRetrospectivaUrl),
                        ),
                      ),
                      const SizedBox(height: EspacoTocaEssa.base + 4),
                      FilledButton.icon(
                        onPressed: _gerando ? null : _salvar,
                        icon: const Icon(Icons.ios_share_rounded),
                        label: Text(_gerando
                            ? 'Gerando imagem...'
                            : 'Salvar imagem para compartilhar'),
                      ),
                      const SizedBox(height: EspacoTocaEssa.mini),
                      TextButton.icon(
                        onPressed: _escolherFoto,
                        icon: const Icon(Icons.add_a_photo_outlined, size: 18),
                        label: Text(_minhaFoto == null
                            ? 'Colocar minha foto'
                            : 'Trocar minha foto'),
                      ),
                      const SizedBox(height: EspacoTocaEssa.grande),
                      const Divider(height: 1),
                      _LinhaAbrirResenha(tocar: widget.abrirResenha),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Foto da noite em tela cheia, que se dissolve no fundo, com data, nome e
/// artista sobre ela.
class _CapaDaMemoria extends StatelessWidget {
  const _CapaDaMemoria({required this.apresentacao, required this.endereco});
  final Apresentacao apresentacao;
  final String? endereco;

  @override
  Widget build(BuildContext context) {
    final resenha = apresentacao.tipo == TipoApresentacao.resenhaEntreAmigos;
    final altura =
        (MediaQuery.sizeOf(context).height * .52).clamp(340.0, 480.0);
    return SizedBox(
      height: altura,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CapaDaNoite(endereco: endereco, alinhamento: Alignment.topCenter),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x590B080F),
                  Color(0x000B080F),
                  Color(0x330B080F),
                  CoresTocaEssa.fundo,
                ],
                stops: [0, .22, .6, 1],
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const BotaoVoltarRedondo(),
                  const Spacer(),
                  Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        RotuloVersalete(
                          '${formatarDiaEMes(apresentacao.data).toUpperCase()}'
                          ' · ${resenha ? 'RESENHA' : 'SHOW'}',
                        ),
                        const SizedBox(height: EspacoTocaEssa.pequeno),
                        Text(
                          apresentacao.nome,
                          style: const TextStyle(
                            fontSize: 34,
                            fontWeight: FontWeight.w600,
                            height: 1.1,
                            letterSpacing: -.5,
                          ),
                        ),
                        const SizedBox(height: EspacoTocaEssa.pequeno),
                        Text(
                          '${apresentacao.perfilArtistico.nomeArtistico} · '
                          '${apresentacao.local}',
                          style: const TextStyle(
                            fontSize: 15,
                            color: CoresTocaEssa.textoSecundario,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// O que foi seu naquela noite: a música, os números e quem estava junto.
class _SuaNoite extends StatelessWidget {
  const _SuaNoite({
    super.key,
    required this.encontro,
    required this.enderecoFoto,
  });

  final EncontroDoPublico encontro;
  final String? Function(String?) enderecoFoto;

  @override
  Widget build(BuildContext context) {
    final musicas = encontro.minhasMusicas;
    final secundario = Theme.of(context)
        .textTheme
        .bodyMedium
        ?.copyWith(color: CoresTocaEssa.textoSecundario);
    String plural(int valor, String singular, String varios) =>
        valor == 1 ? singular : varios;
    final outras = switch (musicas.length) {
      0 || 1 => null,
      2 => 'também pediu ${musicas[1].musica}',
      _ => 'também pediu ${musicas[1].musica} e mais ${musicas.length - 2}',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (musicas.isNotEmpty) ...[
          const RotuloVersalete('SUA MÚSICA DA NOITE'),
          const SizedBox(height: EspacoTocaEssa.pequeno),
          Text(
            musicas.first.musica,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w600,
              height: 1.2,
            ),
          ),
          if (outras != null) ...[
            const SizedBox(height: EspacoTocaEssa.mini),
            Text(outras, style: secundario),
          ],
          const SizedBox(height: EspacoTocaEssa.grande + 4),
        ],
        Row(
          children: [
            _NumeroGrande(
              valor: encontro.pedidos,
              rotulo: plural(encontro.pedidos, 'pedido', 'pedidos'),
            ),
            Container(
              width: 1,
              height: 40,
              margin: const EdgeInsets.symmetric(horizontal: 24),
              color: CoresTocaEssa.borda,
            ),
            _NumeroGrande(
              valor: encontro.pedidosTocados,
              rotulo: plural(encontro.pedidosTocados, 'tocada', 'tocadas'),
            ),
          ],
        ),
        if (encontro.companhia.isNotEmpty) ...[
          const SizedBox(height: 36),
          const RotuloVersalete('QUEM ESTAVA COM VOCÊ'),
          const SizedBox(height: EspacoTocaEssa.base),
          Wrap(
            spacing: 18,
            runSpacing: 16,
            children: [
              for (final pessoa in encontro.companhia)
                SizedBox(
                  width: 56,
                  child: Column(
                    children: [
                      RostoDoPublico(
                        nome: pessoa.nome,
                        endereco: enderecoFoto(pessoa.fotoUrl),
                        tamanho: 52,
                        contorno: CoresTocaEssa.destaqueBorda,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        pessoa.nome,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 12,
                          color: CoresTocaEssa.textoSecundario,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _NumeroGrande extends StatelessWidget {
  const _NumeroGrande({required this.valor, required this.rotulo});
  final int valor;
  final String rotulo;

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(
            '$valor',
            style: const TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.w600,
              height: 1,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            rotulo,
            style: const TextStyle(
              fontSize: 14,
              color: CoresTocaEssa.textoSecundario,
            ),
          ),
        ],
      );
}

/// Cartão 9:16 que vira imagem: a foto aparece de verdade, com o texto só
/// nas faixas de cima e de baixo.
class _CartaoDaNoite extends StatelessWidget {
  const _CartaoDaNoite({
    required this.encontro,
    required this.nome,
    required this.minhaFoto,
    required this.enderecoFoto,
  });

  final EncontroDoPublico encontro;
  final String nome;
  final Uint8List? minhaFoto;
  final String? enderecoFoto;

  @override
  Widget build(BuildContext context) {
    final apresentacao = encontro.apresentacao;
    return AspectRatio(
      aspectRatio: 9 / 16,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(RaioTocaEssa.cartao + 4),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (minhaFoto != null)
              Image.memory(minhaFoto!, fit: BoxFit.cover)
            else
              CapaDaNoite(endereco: enderecoFoto),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
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
                          width: 28, height: 28),
                      const SizedBox(width: 8),
                      const Text('TocaEssa',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    '${apresentacao.nome} · ${formatarData(apresentacao.data)}',
                    style:
                        const TextStyle(fontSize: 13, color: Color(0xFFD8CFDF)),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    nome,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w600,
                      height: 1.15,
                    ),
                  ),
                  if (encontro.companhia.isNotEmpty)
                    Text(
                      textoDaCompanhia(encontro.companhia),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 13, color: Color(0xFFD8CFDF)),
                    ),
                  if (encontro.minhasMusicas.isNotEmpty) ...[
                    const SizedBox(height: 18),
                    const RotuloVersalete('MINHA MÚSICA'),
                    const SizedBox(height: 2),
                    Text(
                      encontro.minhasMusicas.first.musica,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.w600),
                    ),
                  ],
                  const SizedBox(height: 18),
                  Text(
                    '${encontro.pedidos} '
                    '${encontro.pedidos == 1 ? 'pedido' : 'pedidos'}  ·  '
                    '${encontro.pedidosTocados} '
                    '${encontro.pedidosTocados == 1 ? 'tocada' : 'tocadas'}  ·  '
                    '${apresentacao.perfilArtistico.nomeArtistico}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 13, color: CoresTocaEssa.textoSecundario),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LinhaAbrirResenha extends StatelessWidget {
  const _LinhaAbrirResenha({required this.tocar});
  final VoidCallback tocar;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        child: InkWell(
          onTap: tocar,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 18),
            child: Row(
              children: [
                const Icon(Icons.queue_music_rounded,
                    color: CoresTocaEssa.roxoClaro),
                const SizedBox(width: EspacoTocaEssa.base),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Abrir a resenha completa',
                          style: Theme.of(context).textTheme.titleMedium),
                      const Text(
                        'Fila, galera e perfil do artista',
                        style: TextStyle(
                          fontSize: 13,
                          color: CoresTocaEssa.textoSecundario,
                        ),
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
