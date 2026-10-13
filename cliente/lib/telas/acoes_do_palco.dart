import 'package:flutter/material.dart';

import '../dominio/modelos.dart';
import '../infraestrutura/abrir_url_externa.dart';
import '../infraestrutura/api_toca_essa.dart';
import 'componentes.dart';
import 'escolher_cifra.dart';
import 'leitor_de_cifras.dart';
import 'sequencia_do_palco.dart';

/// Ações de palco da setlist e do leitor de cifras: tocar a
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
    final colada = preBuscada?.texto != null;
    final url = colada ? null : preBuscada?.cifra?.url;
    if (colada) {
      abrirLeitor(musica);
    } else if (url != null) {
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
      _ultimaComecada = musica;
      _desfazerUltima = desfazer;
    });
    if (!colada && url == null && preBuscada != null) {
      await mostrarEscolhaDaCifra(musica, preBuscada);
    }
  }

  /// Leitor de cifras na música pedida, usando a mesma sequência do show.
  Future<void> abrirLeitor(MusicaDoPalco musica) =>
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => LeitorDeCifras(
          sequencia: sequencia,
          musicaInicial: musica,
          abrirUrl: abrirUrl,
        ),
      ));

  /// Botão Leitor: abre na música tocando ou, sem ela, na próxima.
  Future<void> abrirLeitorDoShow() async {
    final musica = sequencia.atual ??
        sequencia.proxima ??
        sequencia.paginasDoLeitor.firstOrNull;
    if (musica != null) await abrirLeitor(musica);
  }

  /// Última música começada pelo Tocar, enquanto ainda dá para desfazer.
  /// Some quando outro aparelho da banda começa outra música: desfazer
  /// aqui atrapalharia a música do colega.
  MusicaDoPalco? get ultimaComecada =>
      identical(_ultimaComecada, sequencia.atual) ? _ultimaComecada : null;
  MusicaDoPalco? _ultimaComecada;
  Future<void> Function()? _desfazerUltima;

  Future<void> desfazerUltima() async {
    final desfazer = _desfazerUltima;
    if (desfazer == null || ultimaComecada == null) return;
    setState(() {
      _ultimaComecada = null;
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

  /// Cifra já buscada abre direto no toque: a aba em branco à espera do
  /// servidor podia ficar branca no iPhone com a internet fraca do show.
  Future<void> abrirCifra(MusicaDoPalco musica) async {
    if (sequencia.cifraDe(musica)?.texto != null) {
      await abrirLeitor(musica);
      return;
    }
    final preBuscada = sequencia.cifraDe(musica)?.cifra?.url;
    if (preBuscada != null) {
      try {
        await abrirUrl(Uri.parse(preBuscada));
      } catch (erro) {
        if (mounted) mostrarErro(context, erro);
      }
      return;
    }
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
