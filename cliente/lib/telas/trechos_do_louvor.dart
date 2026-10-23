import 'package:flutter/material.dart';

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
  final rotulos = rotulosDasPartes(hino);
  List<String> partes({required bool tocadas}) => [
        for (final (indice, parte) in hino.partes.indexed)
          if (parte.cantores.contains(nome) &&
              (parte.tipo == TipoDaParte.instrumental) == tocadas)
            rotulos[indice],
      ];
  final canta = partes(tocadas: false);
  final toca = partes(tocadas: true);
  if (canta.isEmpty && toca.isEmpty) return null;
  final oQue = [
    if (canta.isNotEmpty) 'canta ${_emLista(canta)}',
    if (toca.isNotEmpty) 'toca ${_emLista(toca)}',
  ];
  return 'você ${oQue.join(' e ')}';
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
    if (!noCoral(parte)) continue;
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
/// coral é avisado de quando entra e de quando para.
List<TrechoDaCifra> trechosDoHino(
  HinoDoLouvor hino, {
  required List<String> cantores,
  String quemSou = '',
  bool acordes = false,
  int semitons = 0,
}) {
  final cantaNoCoral = quemSou.isNotEmpty && cantores.contains(quemSou);
  bool minha(ParteDoHino parte) =>
      quemSou.isNotEmpty && parte.cantores.contains(quemSou);
  bool noCoral(ParteDoHino parte) =>
      cantaNoCoral && !minha(parte) && parte.doCoral;
  bool canta(ParteDoHino parte) => minha(parte) || noCoral(parte);
  String? aviso(int indice) {
    final parte = hino.partes[indice];
    final seguinte =
        indice + 1 < hino.partes.length ? hino.partes[indice + 1] : null;
    if (seguinte == null) return null;
    if (!canta(parte) && canta(seguinte)) {
      return minha(seguinte) ? 'você é o próximo' : 'coral entra';
    }
    return noCoral(parte) && !canta(seguinte) ? 'depois, para' : null;
  }

  String rotulo(ParteDoHino parte) => [
        if (parte.tipo != TipoDaParte.instrumental)
          parte.quemCanta.toUpperCase()
        else ...[
          if (!parte.deTodos) parte.quemCanta.toUpperCase(),
          (parte.nome ?? parte.tipo.rotulo).toUpperCase(),
        ],
        if (parte.vezes > 1) '${parte.vezes}X',
        if (minha(parte) || (noCoral(parte) && parte.deTodos))
          'SUA VEZ'
        else if (noCoral(parte))
          'SUA VEZ NO CORAL',
      ].join(' · ');
  String letra(ParteDoHino parte) {
    final semAcordes = parte.texto
        .split('\n')
        .where((linha) => !linhaDeAcordes(linha))
        .join('\n');
    return parte.tipo == TipoDaParte.instrumental && semAcordes.trim().isEmpty
        ? 'instrumental'
        : semAcordes;
  }

  return [
    for (final (indice, parte) in hino.partes.indexed)
      TrechoDaCifra(
        rotulo: rotulo(parte),
        cor: parte.tipo == TipoDaParte.instrumental
            ? corInstrumental
            : parte.deTodos
                ? CoresTocaEssa.textoSecundario
                : corDoCantor(cantores, parte.cantores.first),
        destaque: canta(parte),
        aviso: aviso(indice),
        apagado: cantaNoCoral && !canta(parte),
        // Solo sem acordes escritos avisa que é instrumental mesmo no leitor.
        texto: acordes && parte.texto.trim().isNotEmpty
            ? transporCifra(parte.texto, semitons)
            : letra(parte),
      ),
  ];
}
