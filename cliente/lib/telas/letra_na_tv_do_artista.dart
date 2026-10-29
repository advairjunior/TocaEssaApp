import 'package:flutter/material.dart';

import '../dominio/tela_da_tv.dart';
import '../infraestrutura/api_toca_essa.dart';
import '../infraestrutura/link_publico.dart';
import '../infraestrutura/preferencia_da_letra_na_tv.dart';
import '../tema/tema_toca_essa.dart';
import 'componentes.dart';
import 'componentes_lista.dart';

/// "Letra na TV" no Mais: a chave liga a seta na cifra deste aparelho; as
/// TVs ficam presas à conta pelo código que aparece nelas.
class LetraNaTvDoArtista extends StatefulWidget {
  const LetraNaTvDoArtista({super.key, required this.api});

  final ApiTocaEssa api;

  @override
  State<LetraNaTvDoArtista> createState() => _LetraNaTvDoArtistaState();
}

class _LetraNaTvDoArtistaState extends State<LetraNaTvDoArtista> {
  bool _ligada = false;
  List<TvDaConta> _tvs = const [];

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    final ligada = await PreferenciaDaLetraNaTv.ler();
    if (!mounted) return;
    setState(() => _ligada = ligada);
    if (ligada) await _carregarTvs();
  }

  Future<void> _carregarTvs() async {
    try {
      final tvs = await widget.api.listarTvs();
      if (mounted) setState(() => _tvs = tvs);
    } catch (_) {
      // Sem a lista (sem internet), conectar continua possível.
    }
  }

  Future<void> _ligar(bool ligada) async {
    setState(() => _ligada = ligada);
    await PreferenciaDaLetraNaTv.guardar(ligada);
    if (ligada) await _carregarTvs();
  }

  Future<void> _conectar() async {
    final codigo = await showDialog<String>(
        context: context, builder: (_) => const _PedirCodigo());
    if (codigo == null || !mounted) return;
    final avisos = ScaffoldMessenger.of(context);
    try {
      await widget.api.parearTv(codigo);
      avisos.showSnackBar(const SnackBar(content: Text('TV conectada')));
      await _carregarTvs();
    } on FalhaNaApi catch (falha) {
      avisos.showSnackBar(SnackBar(content: Text(falha.mensagem)));
    }
  }

  Future<void> _desconectar(TvDaConta tv) async {
    try {
      await widget.api.desconectarTv(tv.id);
      await _carregarTvs();
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
          const TituloGrupo('Letra na TV'),
          GrupoDeLinhas(linhas: [
            SwitchListTile(
              value: _ligada,
              onChanged: _ligar,
              secondary: const Icon(Icons.tv_rounded),
              title: const Text('Letra na TV'),
              subtitle: const Text('A seta na cifra mostra a linha da TV'),
            ),
            if (_ligada)
              for (final tv in _tvs)
                ListTile(
                  key: ValueKey(tv.id),
                  leading: const Icon(Icons.cast_connected_rounded,
                      color: CoresTocaEssa.sucesso),
                  title: const Text('TV conectada'),
                  subtitle: Text('Desde ${formatarData(tv.criadaEm)}'),
                  trailing: TextButton(
                      onPressed: () => _desconectar(tv),
                      child: const Text('Desconectar')),
                ),
          ]),
          if (_ligada) ...[
            const SizedBox(height: EspacoTocaEssa.pequeno),
            OutlinedButton.icon(
              onPressed: _conectar,
              icon: const Icon(Icons.add_to_queue_rounded),
              label: const Text('Conectar TV'),
            ),
            Padding(
              padding: const EdgeInsets.all(EspacoTocaEssa.pequeno),
              child: Text(
                'Na TV, abra ${enderecoDaTv()} e salve nos favoritos.',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: CoresTocaEssa.textoSecundario),
              ),
            ),
          ],
        ],
      );
}

/// O código de 4 letras que aparece na TV.
class _PedirCodigo extends StatefulWidget {
  const _PedirCodigo();

  @override
  State<_PedirCodigo> createState() => _PedirCodigoState();
}

class _PedirCodigoState extends State<_PedirCodigo> {
  final _codigo = TextEditingController();

  @override
  void dispose() {
    _codigo.dispose();
    super.dispose();
  }

  void _confirmar() =>
      Navigator.of(context).pop(_codigo.text.trim().toUpperCase());

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Código da TV'),
        content: TextField(
          controller: _codigo,
          autofocus: true,
          maxLength: 4,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(hintText: 'K7Q2'),
          onSubmitted: (_) => _confirmar(),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar')),
          FilledButton(onPressed: _confirmar, child: const Text('Conectar')),
        ],
      );
}
