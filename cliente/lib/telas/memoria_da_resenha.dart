import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../dominio/modelos.dart';
import '../tema/tema_toca_essa.dart';
import 'componentes.dart';
import 'componentes_formulario.dart';
import 'componentes_memoria.dart';

part 'memoria_da_resenha_noite.dart';

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
    final foto = await escolherFotoDoCartao(
      context,
      cartao: (_, fundo) => _CartaoDaNoite(
        encontro: widget.encontro,
        nome: widget.nome,
        minhaFoto: null,
        enderecoFoto: null,
        fundo: fundo,
      ),
    );
    if (foto != null && mounted) setState(() => _minhaFoto = foto);
  }

  Future<void> _salvar() async {
    setState(() => _gerando = true);
    try {
      await compartilharCartaoComoImagem(
        _chaveCartao,
        'tocaessa-${nomeDeArquivo(_apresentacao.nome)}-meu-resumo.png',
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
                            : 'Compartilhar imagem'),
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
