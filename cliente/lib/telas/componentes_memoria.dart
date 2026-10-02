import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:image_picker/image_picker.dart';

import '../dominio/modelos.dart';
import '../infraestrutura/baixar_arquivo.dart';
import '../tema/tema_toca_essa.dart';
import 'componentes.dart';

/// Botão redondo e translúcido que flutua sobre fotos e fundos, no lugar da
/// barra de app.
class BotaoRedondo extends StatelessWidget {
  const BotaoRedondo({
    super.key,
    required this.icone,
    required this.dica,
    required this.tocar,
  });

  final IconData icone;
  final String dica;
  final VoidCallback tocar;

  @override
  Widget build(BuildContext context) => Tooltip(
        message: dica,
        child: Semantics(
          button: true,
          label: dica,
          excludeSemantics: true,
          child: Material(
            color: const Color(0x8C0B080F),
            shape: const CircleBorder(
              side: BorderSide(color: Color(0x1FFFFFFF)),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: tocar,
              child: SizedBox.square(
                dimension: 44,
                child: Icon(icone, size: 20, color: CoresTocaEssa.texto),
              ),
            ),
          ),
        ),
      );
}

/// Volta para a tela anterior; some quando não há para onde voltar (link
/// aberto direto no navegador).
class BotaoVoltarRedondo extends StatelessWidget {
  const BotaoVoltarRedondo({super.key, this.dica = 'Voltar', this.tocar});
  final String dica;
  final VoidCallback? tocar;

  @override
  Widget build(BuildContext context) {
    if (tocar == null && !Navigator.canPop(context)) {
      return const SizedBox.square(dimension: 44);
    }
    return BotaoRedondo(
      icone: Icons.arrow_back_rounded,
      dica: dica,
      tocar: tocar ?? () => Navigator.maybePop(context),
    );
  }
}

/// Foto de capa de uma noite: a do encontro, a do artista ou, sem nenhuma,
/// um dos fundos de palco da marca — nunca um ícone solto.
class CapaDaNoite extends StatelessWidget {
  const CapaDaNoite({
    super.key,
    required this.endereco,
    this.fundoAlternativo = 'assets/fundos/inicio_palco.png',
    this.alinhamento = Alignment.center,
  });

  final String? endereco;
  final String fundoAlternativo;
  final Alignment alinhamento;

  @override
  Widget build(BuildContext context) {
    final alternativa = Image.asset(
      fundoAlternativo,
      fit: BoxFit.cover,
      alignment: alinhamento,
      width: double.infinity,
      height: double.infinity,
      errorBuilder: (_, __, ___) =>
          const ColoredBox(color: CoresTocaEssa.destaqueFundo),
    );
    if (endereco == null) return alternativa;
    return Image.network(
      endereco!,
      fit: BoxFit.cover,
      alignment: alinhamento,
      width: double.infinity,
      height: double.infinity,
      errorBuilder: (_, __, ___) => alternativa,
    );
  }
}

/// Avatar redondo de quem participou, com a inicial quando não há foto.
class RostoDoPublico extends StatelessWidget {
  const RostoDoPublico({
    super.key,
    required this.nome,
    required this.endereco,
    this.tamanho = 24,
    this.contorno = CoresTocaEssa.fundo,
  });

  final String nome;
  final String? endereco;
  final double tamanho;
  final Color contorno;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(1.5),
        decoration: BoxDecoration(color: contorno, shape: BoxShape.circle),
        child: CircleAvatar(
          radius: tamanho / 2 - 1.5,
          backgroundColor: CoresTocaEssa.destaqueFundo,
          foregroundImage: endereco == null ? null : NetworkImage(endereco!),
          onForegroundImageError: endereco == null ? null : (_, __) {},
          child: Text(
            nome.characters.first.toUpperCase(),
            style: TextStyle(
              fontSize: tamanho * .4,
              fontWeight: FontWeight.w600,
              color: CoresTocaEssa.roxoClaro,
            ),
          ),
        ),
      );
}

/// Até três rostos sobrepostos de quem estava no encontro.
class PilhaDeRostos extends StatelessWidget {
  const PilhaDeRostos({
    super.key,
    required this.pessoas,
    required this.enderecoFoto,
    this.contorno = CoresTocaEssa.fundo,
  });

  final List<PessoaDoEncontro> pessoas;
  final String? Function(String?) enderecoFoto;
  final Color contorno;

  static const _tamanho = 24.0;
  static const _passo = 16.0;

  @override
  Widget build(BuildContext context) {
    final visiveis = pessoas.take(3).toList();
    return SizedBox(
      width: _tamanho + _passo * (visiveis.length - 1),
      height: _tamanho,
      child: Stack(
        children: [
          for (final (indice, pessoa) in visiveis.indexed)
            Positioned(
              left: _passo * indice,
              child: RostoDoPublico(
                nome: pessoa.nome,
                endereco: enderecoFoto(pessoa.fotoUrl),
                contorno: contorno,
              ),
            ),
        ],
      ),
    );
  }
}

/// Texto curto de companhia: "com Bia, Caio e mais 2".
String textoDaCompanhia(List<PessoaDoEncontro> pessoas) =>
    switch (pessoas.length) {
      0 => '',
      1 => 'com ${pessoas[0].nome}',
      2 => 'com ${pessoas[0].nome} e ${pessoas[1].nome}',
      _ => 'com ${pessoas[0].nome}, ${pessoas[1].nome} '
          'e mais ${pessoas.length - 2}',
    };

/// Rótulo em versalete usado sobre fotos e nos destaques das memórias.
class RotuloVersalete extends StatelessWidget {
  const RotuloVersalete(this.texto, {super.key, this.cor});
  final String texto;
  final Color? cor;

  @override
  Widget build(BuildContext context) => Text(
        texto,
        style: TextStyle(
          color: cor ?? CoresTocaEssa.roxoClaro,
          fontSize: 11,
          letterSpacing: 1.2,
          fontWeight: FontWeight.w600,
        ),
      );
}

/// Pede uma foto da câmera ou da galeria para o cartão compartilhável.
/// Devolve `null` quando a pessoa desiste ou a imagem passa de 8 MB.
Future<Uint8List?> escolherFotoDoCartao(BuildContext context) async {
  final origem = await showModalBottomSheet<ImageSource>(
    context: context,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined),
            title: const Text('Tirar foto agora'),
            onTap: () => Navigator.pop(context, ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Escolher da galeria'),
            onTap: () => Navigator.pop(context, ImageSource.gallery),
          ),
        ],
      ),
    ),
  );
  if (origem == null || !context.mounted) return null;
  final arquivo = await ImagePicker().pickImage(
    source: origem,
    maxWidth: 1800,
    maxHeight: 1800,
    imageQuality: 86,
  );
  if (arquivo == null || !context.mounted) return null;
  final bytes = await arquivo.readAsBytes();
  if (bytes.length > 8 * 1024 * 1024) {
    if (context.mounted) {
      mostrarErro(context, 'Escolha uma imagem de até 8 MB.');
    }
    return null;
  }
  return bytes;
}

/// Transforma o cartão sob [chave] em PNG de ~1080px de largura e baixa.
Future<void> baixarCartaoComoImagem(GlobalKey chave, String nomeArquivo) async {
  await WidgetsBinding.instance.endOfFrame;
  final limite =
      chave.currentContext?.findRenderObject() as RenderRepaintBoundary?;
  if (limite == null) throw StateError('Não foi possível gerar a imagem.');
  final proporcao = (1080 / limite.size.width).clamp(1.0, 4.0).toDouble();
  final imagem = await limite.toImage(pixelRatio: proporcao);
  final dados = await imagem.toByteData(format: ui.ImageByteFormat.png);
  if (dados == null) throw StateError('Não foi possível gerar a imagem.');
  baixarArquivo(dados.buffer.asUint8List(), nomeArquivo);
}

/// Nome de arquivo seguro a partir do nome da apresentação.
String nomeDeArquivo(String nome, {String padrao = 'resenha'}) {
  final limpo = nome
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-|-$'), '');
  return limpo.isEmpty ? padrao : limpo;
}
