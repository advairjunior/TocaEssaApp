import 'package:flutter/material.dart';

import '../dominio/modelos.dart';
import '../infraestrutura/abrir_url_externa.dart';
import '../infraestrutura/api_toca_essa.dart';
import 'componentes.dart';
import 'escolher_cifra.dart';
import 'sequencia_do_palco.dart';

/// Ações de palco compartilhadas pela setlist e pelo modo palco: tocar a
/// próxima, abrir e escolher cifras.
mixin AcoesDoPalco<T extends StatefulWidget> on State<T> {
  SequenciaDoPalco get sequencia;
  ApiTocaEssa get api;
  Future<void> Function(Uri url) get abrirUrl;
  FinalizarAberturaExterna Function() get prepararAbertura;

  /// Abre a cifra da próxima música e a começa num único toque.
  /// A cifra abre antes de qualquer espera para o Safari aceitar a nova aba.
  Future<void> tocarProxima() async {
    final musica = sequencia.proxima;
    if (musica == null) return;
    final preBuscada = sequencia.cifraDe(musica);
    final url = preBuscada?.cifra?.url;
    if (url != null) {
      abrirUrl(Uri.parse(url)).catchError((Object erro) {
        if (mounted) mostrarErro(context, erro);
      });
    } else if (preBuscada == null) {
      abrirCifra(musica);
    }
    final Future<void> Function() desfazer;
    try {
      desfazer = await sequencia.comecar(musica);
    } catch (erro) {
      if (mounted) mostrarErro(context, erro);
      return;
    }
    if (!mounted) return;
    // O desfazer fica na própria barra: um aviso no rodapé cobriria a
    // próxima música justamente quando o artista precisa vê-la.
    setState(() {
      ultimaComecada = musica;
      _desfazerUltima = desfazer;
    });
    if (url == null && preBuscada != null) {
      await mostrarEscolhaDaCifra(musica, preBuscada);
    }
  }

  /// Última música começada pelo Tocar, enquanto ainda dá para desfazer.
  MusicaDoPalco? ultimaComecada;
  Future<void> Function()? _desfazerUltima;

  Future<void> desfazerUltima() async {
    final desfazer = _desfazerUltima;
    if (desfazer == null) return;
    setState(() {
      ultimaComecada = null;
      _desfazerUltima = null;
    });
    await executar(desfazer);
  }

  Future<void> executar(Future<void> Function() acao) async {
    try {
      await acao();
    } catch (erro) {
      if (mounted) mostrarErro(context, erro);
    }
  }

  Future<void> abrirCifra(MusicaDoPalco musica) async {
    FinalizarAberturaExterna? finalizar;
    try {
      finalizar = prepararAbertura();
      final resultado = await api.consultarCifra(musica.titulo, musica.artista);
      if (!mounted) {
        await finalizar(null);
        return;
      }
      if (resultado.cifra != null) {
        await finalizar(Uri.parse(resultado.cifra!.url));
        return;
      }
      await finalizar(null);
      await mostrarEscolhaDaCifra(musica, resultado);
    } catch (erro) {
      await finalizar?.call(null);
      if (mounted) mostrarErro(context, erro);
    }
  }

  Future<void> escolherCifra(MusicaDoPalco musica) async {
    try {
      final resultado = await api.consultarCifra(musica.titulo, musica.artista);
      await mostrarEscolhaDaCifra(musica, resultado);
    } catch (erro) {
      if (mounted) mostrarErro(context, erro);
    }
  }

  /// Responde se o artista decidiu algo; falso quando fechou sem escolher.
  Future<bool> mostrarEscolhaDaCifra(
      MusicaDoPalco musica, ResultadoCifraDoArtista resultado,
      {String? rotuloColarEProxima}) async {
    if (!mounted) return false;
    final decisao = await mostrarEscolhaDeCifra(
      context,
      musica: musica.titulo,
      artista: musica.artista,
      resultado: resultado,
      abrirUrl: abrirUrl,
      rotuloColarEProxima: rotuloColarEProxima,
    );
    if (decisao == null || !mounted) return false;
    switch (decisao.tipo) {
      case TipoDecisaoCifra.remover:
        final cifra = resultado.cifra;
        if (cifra == null) return false;
        await api.removerCifra(cifra.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Link da cifra removido.')),
          );
        }
      case TipoDecisaoCifra.salvar:
        await api.salvarCifra(musica.titulo, musica.artista, decisao.url!);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Cifra salva.')),
          );
        }
    }
    await sequencia.atualizarCifra(musica);
    return true;
  }
}
