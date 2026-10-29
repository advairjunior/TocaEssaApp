import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../dominio/musicos_da_noite.dart';
import '../infraestrutura/api_toca_essa.dart';
import '../infraestrutura/compartilhar_link.dart';
import '../infraestrutura/link_publico.dart';
import '../tema/tema_toca_essa.dart';
import 'componentes_lista.dart';

/// "Músicos da noite" no Mais da resenha e do louvor: o dono manda o link
/// aos amigos que vão tocar; quem entra vê a setlist e as cifras deste
/// evento, nada da conta. O público continua entrando pelo código.
class MusicosDaNoiteDoDono extends StatefulWidget {
  const MusicosDaNoiteDoDono({
    super.key,
    required this.api,
    required this.apresentacaoId,
    this.compartilhar = compartilharNoAparelho,
  });

  final ApiTocaEssa api;
  final String apresentacaoId;
  // Janela de compartilhar do aparelho; falso onde não existe.
  final Future<bool> Function(String titulo, String url) compartilhar;

  @override
  State<MusicosDaNoiteDoDono> createState() => _MusicosDaNoiteDoDonoState();
}

class _MusicosDaNoiteDoDonoState extends State<MusicosDaNoiteDoDono> {
  List<MusicoDaNoite> _musicos = const [];
  bool _convidando = false;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    try {
      final musicos = await widget.api.listarMusicos(widget.apresentacaoId);
      if (mounted) setState(() => _musicos = musicos);
    } catch (_) {
      // Sem a lista (sem internet), convidar continua possível.
    }
  }

  Future<void> _convidar() async {
    final avisos = ScaffoldMessenger.of(context);
    setState(() => _convidando = true);
    try {
      final link =
          linkDoConvite(await widget.api.gerarConvite(widget.apresentacaoId));
      if (await widget.compartilhar('Toca comigo hoje?', link)) return;
      await _copiar(link, avisos);
    } on FalhaNaApi catch (falha) {
      avisos.showSnackBar(SnackBar(content: Text(falha.mensagem)));
    } finally {
      if (mounted) setState(() => _convidando = false);
    }
  }

  /// Sem a janela de compartilhar (no computador), copia o link.
  Future<void> _copiar(String link, ScaffoldMessengerState avisos) async {
    try {
      await Clipboard.setData(ClipboardData(text: link));
      avisos.showSnackBar(
          const SnackBar(content: Text('Link do convite copiado')));
    } catch (_) {
      avisos.showSnackBar(SnackBar(content: SelectableText(link)));
    }
  }

  Future<void> _tirar(MusicoDaNoite musico) async {
    try {
      await widget.api.tirarMusico(widget.apresentacaoId, musico.artistaId);
      await _carregar();
    } on FalhaNaApi catch (falha) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(falha.mensagem)));
      }
    }
  }

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const TituloGrupo('Músicos da noite'),
          if (_musicos.isNotEmpty)
            GrupoDeLinhas(linhas: [
              for (final musico in _musicos)
                ListTile(
                  key: ValueKey(musico.artistaId),
                  leading: Icon(
                      musico.dono
                          ? Icons.star_rounded
                          : Icons.music_note_rounded,
                      color: CoresTocaEssa.roxoClaro),
                  title: Text(musico.nome),
                  subtitle: musico.dono ? const Text('Dono do evento') : null,
                  trailing: musico.dono
                      ? null
                      : TextButton(
                          onPressed: () => _tirar(musico),
                          child: const Text('Tirar')),
                ),
            ]),
          const SizedBox(height: EspacoTocaEssa.pequeno),
          OutlinedButton.icon(
            onPressed: _convidando ? null : _convidar,
            icon: const Icon(Icons.person_add_alt_1_rounded),
            label: const Text('Convidar músico'),
          ),
          Padding(
            padding: const EdgeInsets.all(EspacoTocaEssa.pequeno),
            child: Text(
              'Quem entra pelo link vê a setlist e as cifras desta noite. '
              'Um link novo desfaz o anterior.',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: CoresTocaEssa.textoSecundario),
            ),
          ),
        ],
      );
}
