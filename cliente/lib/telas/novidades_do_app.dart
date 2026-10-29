import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../dominio/novidades.dart';
import '../tema/tema_toca_essa.dart';
import 'componentes.dart';

const _chaveDasVistas = 'novidades_vistas_ate';

/// Data da novidade mais nova que este aparelho já viu; o aviso do painel
/// e o menu da conta olham o mesmo valor.
final _vistasAte = ValueNotifier<DateTime?>(null);
bool _vistasLidas = false;

Future<void> _lerVistas() async {
  if (_vistasLidas) return;
  try {
    final preferencias = await SharedPreferences.getInstance();
    _vistasAte.value =
        DateTime.tryParse(preferencias.getString(_chaveDasVistas) ?? '');
  } catch (_) {
    // Sem o guardado, tudo conta como novo.
  }
  _vistasLidas = true;
}

String _dia(DateTime data) =>
    '${data.year}-${data.month.toString().padLeft(2, '0')}-'
    '${data.day.toString().padLeft(2, '0')}';

/// Abre a lista e marca tudo como visto.
Future<void> abrirNovidades(BuildContext context,
    {List<Novidade>? novidades}) async {
  final lista = novidades ?? novidadesDoApp;
  await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => NovidadesDoApp(novidades: lista)));
  if (lista.isEmpty) return;
  _vistasAte.value = lista.first.data;
  try {
    final preferencias = await SharedPreferences.getInstance();
    await preferencias.setString(_chaveDasVistas, _dia(lista.first.data));
  } catch (_) {
    // Só não fica guardado: o aviso volta na próxima abertura.
  }
}

/// "Novidades no app · 2 novas" no topo do painel, até a pessoa abrir.
class AvisoDeNovidades extends StatefulWidget {
  const AvisoDeNovidades({super.key, this.novidades});

  final List<Novidade>? novidades;

  @override
  State<AvisoDeNovidades> createState() => _AvisoDeNovidadesState();
}

class _AvisoDeNovidadesState extends State<AvisoDeNovidades> {
  @override
  void initState() {
    super.initState();
    _vistasLidas = false;
    _lerVistas().then((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<DateTime?>(
        valueListenable: _vistasAte,
        builder: (context, vistasAte, _) {
          final lista = widget.novidades ?? novidadesDoApp;
          final novas = !_vistasLidas
              ? 0
              : lista
                  .where((n) => vistasAte == null || n.data.isAfter(vistasAte))
                  .length;
          if (novas == 0) return const SizedBox.shrink();
          return Padding(
            padding: const EdgeInsets.only(bottom: EspacoTocaEssa.base),
            child: Material(
              color: CoresTocaEssa.roxo.withValues(alpha: .25),
              borderRadius: BorderRadius.circular(RaioTocaEssa.pilula),
              child: ListTile(
                onTap: () => abrirNovidades(context, novidades: lista),
                leading: const Icon(Icons.auto_awesome_rounded,
                    color: CoresTocaEssa.rosa),
                title: Text(
                    'Novidades no app · $novas ${novas == 1 ? 'nova' : 'novas'}'),
                trailing: const Icon(Icons.chevron_right_rounded),
              ),
            ),
          );
        },
      );
}

/// A lista de novidades, agrupada por dia.
class NovidadesDoApp extends StatelessWidget {
  const NovidadesDoApp({super.key, required this.novidades});

  final List<Novidade> novidades;

  @override
  Widget build(BuildContext context) {
    final dias = <DateTime, List<Novidade>>{};
    for (final novidade in novidades) {
      dias.putIfAbsent(novidade.data, () => []).add(novidade);
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Novidades')),
      body: ListView(
        padding: const EdgeInsets.all(EspacoTocaEssa.base),
        children: [
          for (final MapEntry(key: dia, value: doDia) in dias.entries) ...[
            Padding(
              padding: const EdgeInsets.only(
                  top: EspacoTocaEssa.base, bottom: EspacoTocaEssa.pequeno),
              child: Text(formatarData(dia),
                  style: const TextStyle(
                      color: CoresTocaEssa.textoSecundario,
                      fontWeight: FontWeight.w600)),
            ),
            for (final novidade in doDia) _CartaoDaNovidade(novidade),
          ],
        ],
      ),
    );
  }
}

class _CartaoDaNovidade extends StatelessWidget {
  const _CartaoDaNovidade(this.novidade);

  final Novidade novidade;

  Color get _cor => switch (novidade.tipo) {
        TipoDeNovidade.novo => CoresTocaEssa.rosa,
        TipoDeNovidade.melhoria => CoresTocaEssa.roxoClaro,
        TipoDeNovidade.correcao => CoresTocaEssa.sucesso,
      };

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: EspacoTocaEssa.medio),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: EspacoTocaEssa.pequeno, vertical: 2),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(RaioTocaEssa.pilula),
                  border: Border.all(color: _cor.withValues(alpha: .6)),
                ),
                child: Text(novidade.tipo.rotulo,
                    style: TextStyle(color: _cor, fontSize: 12)),
              ),
              const SizedBox(width: EspacoTocaEssa.pequeno),
              Expanded(
                child: Text(novidade.titulo,
                    style: Theme.of(context).textTheme.titleMedium),
              ),
            ]),
            const SizedBox(height: EspacoTocaEssa.mini),
            Text(novidade.texto,
                style: const TextStyle(color: CoresTocaEssa.textoSecundario)),
          ],
        ),
      );
}
