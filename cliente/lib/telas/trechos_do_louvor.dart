import 'package:flutter/material.dart';

import '../dominio/coral_na_letra.dart';
import '../dominio/modelos.dart';
import '../dominio/transpor_cifra.dart';
import '../tema/tema_toca_essa.dart';
import 'cifra_do_palco.dart';

// Uma cor por cantor, na ordem da lista: a mesma em todos os telefones.
// Doze bem diferentes entre si, sem o amarelo dos solos nem o cinza de Todos.
const _coresDosCantores = [
  CoresTocaEssa.roxoClaro,
  CoresTocaEssa.rosa,
  Color(0xFF60A5FA),
  CoresTocaEssa.sucesso,
  Color(0xFFFB923C),
  Color(0xFF22D3EE),
  Color(0xFFF87171),
  Color(0xFFA3E635),
  Color(0xFFE879F9),
  Color(0xFF2DD4BF),
  Color(0xFFD6A36B),
  Color(0xFF818CF8),
];

/// Cor de quem canta; Todos (ou nome fora da lista) fica discreto.
Color corDoCantor(List<String> cantores, String nome) {
  final indice = cantores.indexOf(nome);
  return indice < 0 ? CoresTocaEssa.textoSecundario : _corNaPosicao(indice);
}

/// Depois das doze, uma cor nova por pessoa, sem limite: o ângulo de ouro
/// afasta cada matiz das anteriores, sempre o mesmo em todos os telefones
/// (sorteio daria uma cor em cada aparelho). Pula o amarelo dos solos.
Color _corNaPosicao(int indice) {
  if (indice < _coresDosCantores.length) return _coresDosCantores[indice];
  var faltam = indice - _coresDosCantores.length;
  for (var passo = 0;; passo++) {
    final matiz = (passo * 137.508 + 15) % 360;
    if (matiz >= 35 && matiz <= 70) continue;
    if (faltam-- == 0) return HSLColor.fromAHSL(1, matiz, .75, .68).toColor();
  }
}

/// Faixa dos solos e partes instrumentais, diferente da dos cantores.
const corInstrumental = CoresTocaEssa.atencao;

/// Cor de uma pessoa do louvor na lista [pessoas] (os participantes:
/// cantores primeiro, depois quem só toca). Quem canta fica com a mesma cor
/// da lista só de cantores; quem só toca ganha a sua, não o amarelo dos solos.
Color corDaPessoa(List<String> pessoas, String nome) =>
    corDoCantor(pessoas, nome);

/// "Estrofe 1", "Refrão", "Solo sax tenor · 2x": o nome de cada parte.
List<String> rotulosDasPartes(HinoDoLouvor hino) {
  var estrofe = 0;
  return [
    for (final parte in hino.partes)
      () {
        final nome = switch (parte.tipo) {
          TipoDaParte.estrofe => 'Estrofe ${++estrofe}',
          TipoDaParte.instrumental => parte.nome ?? parte.tipo.rotulo,
          TipoDaParte.refrao => parte.tipo.rotulo,
        };
        return parte.vezes > 1 ? '$nome · ${parte.vezes}x' : nome;
      }(),
  ];
}

/// "Estrofe 1, Refrão e Estrofe 3": as partes de [nome] no hino, ou nulo
/// se não canta nem toca nele.
String? partesDaPessoa(HinoDoLouvor hino, String nome) {
  final rotulos = rotulosDasPartes(hino);
  final daPessoa = [
    for (final (indice, parte) in hino.partes.indexed)
      if (parte.cantores.contains(nome)) rotulos[indice],
  ];
  return daPessoa.isEmpty ? null : _emLista(daPessoa);
}

/// "você canta Estrofe 1 e toca Solo flauta": o que [nome] faz no hino, ou
/// nulo se não canta nem toca nele.
String? oQueVoceFaz(HinoDoLouvor hino, String nome) {
  final canta = partesNoMicrofone(hino, nome);
  final toca = partesTocadas(hino, nome);
  if (canta == null && toca == null) return null;
  final oQue = [
    if (canta != null) 'canta $canta',
    if (toca != null) 'toca $toca',
  ];
  return 'você ${oQue.join(' e ')}';
}

/// "Estrofe 1 e Refrão": o que [nome] canta no microfone, sem os solos.
String? partesNoMicrofone(HinoDoLouvor hino, String nome) =>
    _partesDe(hino, nome, tocadas: false);

/// "Solo sax": o que [nome] toca no hino.
String? partesTocadas(HinoDoLouvor hino, String nome) =>
    _partesDe(hino, nome, tocadas: true);

String? _partesDe(HinoDoLouvor hino, String nome, {required bool tocadas}) {
  final rotulos = rotulosDasPartes(hino);
  final partes = [
    for (final (indice, parte) in hino.partes.indexed)
      if (parte.cantores.contains(nome) &&
          (parte.tipo == TipoDaParte.instrumental) == tocadas)
        rotulos[indice],
  ];
  return partes.isEmpty ? null : _emLista(partes);
}

/// "Refrão e Estrofe 2": onde [nome] canta no coral (as partes do coral em
/// que não está no microfone), ou nulo. Só quem está nos [cantores] canta
/// no coral; quem só toca, não.
String? partesNoCoral(HinoDoLouvor hino, String nome,
    {required List<String> cantores}) {
  if (!cantores.contains(nome)) return null;
  final rotulos = rotulosDasPartes(hino);
  bool noCoral(ParteDoHino parte) =>
      parte.doCoral && !parte.cantores.contains(nome);
  // Os refrões têm o mesmo nome: vários viram "2 refrões" ou "todos os
  // refrões", no lugar do primeiro, em vez de "Refrão e Refrão".
  final refroes =
      hino.partes.where((parte) => parte.tipo == TipoDaParte.refrao);
  final refroesNoCoral = refroes.where(noCoral).length;
  final refroesJuntos = refroesNoCoral == refroes.length
      ? 'todos os refrões'
      : '$refroesNoCoral refrões';
  var refraoListado = false;
  final partes = <String>[];
  for (final (indice, parte) in hino.partes.indexed) {
    if (!noCoral(parte)) {
      // Só algumas linhas da parte, marcadas com (Coral) na letra.
      if (parte.tipo != TipoDaParte.instrumental &&
          !parte.cantores.contains(nome) &&
          temCoralNaLetra(parte.texto)) {
        final artigo = parte.tipo == TipoDaParte.refrao ? 'do' : 'da';
        partes.add('parte $artigo ${rotulos[indice]}');
      }
      continue;
    }
    if (parte.tipo != TipoDaParte.refrao || refroesNoCoral == 1) {
      partes.add(rotulos[indice]);
    } else if (!refraoListado) {
      refraoListado = true;
      partes.add(refroesJuntos);
    }
  }
  return partes.isEmpty ? null : _emLista(partes);
}

String _emLista(List<String> itens) => itens.length == 1
    ? itens.single
    : '${itens.sublist(0, itens.length - 1).join(', ')} e ${itens.last}';

/// Partes do hino como trechos da cifra: nome de quem canta (ou do solo) na
/// faixa, a vez de [quemSou] em destaque e avisada na parte anterior. Sem
/// [acordes], só a letra; com eles, a cifra no tom escolhido com [semitons].
/// Quem está nos [cantores] e não tem a parte no microfone canta no coral
/// nas partes do coral; as partes em que não canta ficam apagadas, e o
/// coral é avisado de quando entra e de quando para. A parte com "(Coral)"
/// na letra vira um trecho por pedaço, cada um com a sua faixa.
List<TrechoDaCifra> trechosDoHino(
  HinoDoLouvor hino, {
  required List<String> cantores,
  String quemSou = '',
  bool acordes = false,
  int semitons = 0,
}) {
  final pedacos = [
    for (final parte in hino.partes)
      if (parte.tipo == TipoDaParte.instrumental)
        _Pedaco(parte, parte.texto, coral: false, primeiro: true)
      else
        for (final (indice, pedaco) in pedacosDoCoral(parte.texto).indexed)
          _Pedaco(parte, pedaco.texto,
              coral: parte.doCoral || pedaco.coral, primeiro: indice == 0),
  ];
  final cantaNoCoral = quemSou.isNotEmpty && cantores.contains(quemSou);
  bool minha(_Pedaco pedaco) =>
      quemSou.isNotEmpty && pedaco.parte.cantores.contains(quemSou);
  bool noCoral(_Pedaco pedaco) =>
      cantaNoCoral && !minha(pedaco) && pedaco.coral;
  bool canta(_Pedaco pedaco) => minha(pedaco) || noCoral(pedaco);
  String? aviso(int indice) {
    final pedaco = pedacos[indice];
    final seguinte = indice + 1 < pedacos.length ? pedacos[indice + 1] : null;
    if (seguinte == null) return null;
    if (!canta(pedaco) && canta(seguinte)) {
      return minha(seguinte) ? 'você é o próximo' : 'coral entra';
    }
    return noCoral(pedaco) && !canta(seguinte) ? 'depois, para' : null;
  }

  String rotulo(_Pedaco pedaco) {
    final parte = pedaco.parte;
    return [
      if (parte.tipo != TipoDaParte.instrumental)
        parte.deTodos
            ? 'TODOS'
            : '${parte.cantores.join(' e ')}${pedaco.coral ? ' + coral' : ''}'
                .toUpperCase()
      else ...[
        if (!parte.deTodos) parte.quemCanta.toUpperCase(),
        (parte.nome ?? parte.tipo.rotulo).toUpperCase(),
      ],
      if (parte.vezes > 1 && pedaco.primeiro) '${parte.vezes}X',
      // "ANA + CORAL · SUA VEZ": o "+ CORAL" já diz que é no coral, e a
      // faixa cabe no celular junto do aviso.
      if (canta(pedaco)) 'SUA VEZ',
    ].join(' · ');
  }

  String letra(_Pedaco pedaco) {
    final semAcordes = pedaco.texto
        .split('\n')
        .where((linha) => !linhaDeAcordes(linha))
        .join('\n');
    return pedaco.parte.tipo == TipoDaParte.instrumental &&
            semAcordes.trim().isEmpty
        ? 'instrumental'
        : semAcordes;
  }

  return [
    for (final (indice, pedaco) in pedacos.indexed)
      TrechoDaCifra(
        rotulo: rotulo(pedaco),
        cor: pedaco.parte.tipo == TipoDaParte.instrumental
            ? corInstrumental
            : pedaco.parte.deTodos
                ? CoresTocaEssa.textoSecundario
                : corDoCantor(cantores, pedaco.parte.cantores.first),
        destaque: canta(pedaco),
        aviso: aviso(indice),
        apagado: cantaNoCoral && !canta(pedaco),
        // Solo sem acordes escritos avisa que é instrumental mesmo no leitor.
        texto: acordes && pedaco.texto.trim().isNotEmpty
            ? transporCifra(pedaco.texto, semitons)
            : letra(pedaco),
      ),
  ];
}

/// Pedaço de uma parte: a parte inteira, ou as linhas dentro ou fora do
/// "(Coral)" da letra. [primeiro] leva o "2X" da parte.
class _Pedaco {
  const _Pedaco(this.parte, this.texto,
      {required this.coral, required this.primeiro});

  final ParteDoHino parte;
  final String texto;
  final bool coral;
  final bool primeiro;
}
