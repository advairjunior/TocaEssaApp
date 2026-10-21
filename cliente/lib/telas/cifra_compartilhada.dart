import 'package:flutter/material.dart';

import '../dominio/modelos.dart';
import '../dominio/transpor_cifra.dart';
import '../infraestrutura/api_toca_essa.dart';
import '../tema/tema_toca_essa.dart';
import 'cifra_do_palco.dart';
import 'componentes_lista.dart';
import 'controle_do_tom.dart';

/// Cifra aberta pelo link que o artista compartilhou ("#/cifra/codigo"),
/// sem conta: o mesmo visual do leitor, com pinça, rolagem e o tom para
/// quem recebe tocar no tom dele. Sempre a versão mais nova da cifra.
class CifraCompartilhadaTela extends StatefulWidget {
  const CifraCompartilhadaTela({
    super.key,
    required this.api,
    required this.codigo,
  });

  final ApiTocaEssa api;
  final String codigo;

  @override
  State<CifraCompartilhadaTela> createState() => _CifraCompartilhadaTelaState();
}

class _CifraCompartilhadaTelaState extends State<CifraCompartilhadaTela> {
  CifraCompartilhada? _cifra;
  bool _naoEncontrada = false;
  // Só neste aparelho: quem recebe escolhe o tom dele.
  int _semitons = 0;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    try {
      final cifra = await widget.api.obterCifraCompartilhada(widget.codigo);
      if (mounted) setState(() => _cifra = cifra);
    } catch (_) {
      if (mounted) setState(() => _naoEncontrada = true);
    }
  }

  void _mudarTom(int passo) =>
      setState(() => _semitons = (_semitons + passo).remainder(12));

  String _rotuloDoTom(String? tom) {
    final mudanca =
        _semitons == 0 ? '' : ' (${_semitons > 0 ? '+' : ''}$_semitons)';
    final original = tom?.trim();
    return original == null || original.isEmpty
        ? 'Tom$mudanca'
        : 'Tom ${transporTom(original, _semitons)}$mudanca';
  }

  @override
  Widget build(BuildContext context) {
    final cifra = _cifra;
    final texto = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(cifra?.musica ?? 'Cifra',
            maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      body: switch ((cifra, _naoEncontrada)) {
        (_, true) => const EstadoVazio(
            icone: Icons.link_off_rounded,
            titulo: 'Cifra não encontrada',
            descricao: 'Peça o link de novo a quem compartilhou.',
          ),
        (null, _) => const Center(child: CircularProgressIndicator()),
        (final cifra?, _) => CifraDoPalco(
            pagina: widget.codigo,
            cabecalho: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if ([
                  if (cifra.artista case final artista?) artista,
                  if (cifra.nomeArtistico case final nome?) 'por $nome',
                ].join(' · ')
                    case final autoria when autoria.isNotEmpty)
                  Padding(
                    padding:
                        const EdgeInsets.only(bottom: EspacoTocaEssa.pequeno),
                    child: Text(autoria,
                        style: texto.bodyMedium
                            ?.copyWith(color: CoresTocaEssa.textoSecundario)),
                  ),
                ControleDoTom(
                  tom: _rotuloDoTom(cifra.tom),
                  original: cifra.tom,
                  semitons: _semitons,
                  mudarTom: _mudarTom,
                ),
              ],
            ),
            trechos: [
              TrechoDaCifra(texto: transporCifra(cifra.texto, _semitons)),
            ],
          ),
      },
    );
  }
}
