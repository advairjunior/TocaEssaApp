import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../dominio/musicos_da_noite.dart';
import '../infraestrutura/abrir_url_externa.dart';
import '../infraestrutura/api_toca_essa.dart';
import '../tema/tema_toca_essa.dart';
import 'componentes.dart';
import 'componentes_lista.dart';
import 'convite_do_musico.dart';
import 'noite_do_musico.dart';

/// "Convites" no início do painel: os eventos de outros artistas em que a
/// conta entrou como músico. Some quando não há nenhum. Também abre o
/// convite que a pessoa abriu antes de entrar na conta.
class ConvitesDoMusico extends StatefulWidget {
  const ConvitesDoMusico({
    super.key,
    required this.api,
    required this.artistaId,
    this.abrirUrl = abrirNaAbaDaCifra,
  });

  final ApiTocaEssa api;
  final String artistaId;
  final Future<void> Function(Uri url) abrirUrl;

  @override
  State<ConvitesDoMusico> createState() => _ConvitesDoMusicoState();
}

class _ConvitesDoMusicoState extends State<ConvitesDoMusico> {
  List<EventoConvidado> _convites = const [];

  @override
  void initState() {
    super.initState();
    _carregar();
    _abrirConvitePendente();
  }

  Future<void> _carregar() async {
    try {
      final convites = await widget.api.listarConvites();
      if (mounted) setState(() => _convites = convites);
    } catch (_) {
      // Sem a lista (sem internet), a seção espera a próxima abertura.
    }
  }

  Future<void> _abrirConvitePendente() async {
    final preferencias = await SharedPreferences.getInstance();
    final codigo = preferencias.getString(chaveDoConvitePendente);
    if (codigo == null || !mounted) return;
    await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => ConviteDoMusico(api: widget.api, codigo: codigo)));
    await preferencias.remove(chaveDoConvitePendente);
    await _carregar();
  }

  Future<void> _abrir(EventoConvidado evento) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => NoiteDoMusico(
        api: widget.api,
        evento: evento,
        artistaId: widget.artistaId,
        abrirUrl: widget.abrirUrl,
      ),
    ));
    await _carregar();
  }

  @override
  Widget build(BuildContext context) {
    if (_convites.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const TituloGrupo('Convites'),
        GrupoDeLinhas(linhas: [
          for (final evento in _convites)
            ListTile(
              key: ValueKey(evento.apresentacaoId),
              onTap: () => _abrir(evento),
              leading: const Icon(Icons.music_note_rounded,
                  color: CoresTocaEssa.roxoClaro),
              title: Text(evento.nome),
              subtitle:
                  Text('de ${evento.dono} · ${formatarData(evento.data)}'),
              trailing: const Icon(Icons.chevron_right_rounded),
            ),
        ]),
        const SizedBox(height: EspacoTocaEssa.grande),
      ],
    );
  }
}
