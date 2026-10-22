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

String _emLista(List<String> itens) => itens.length == 1
    ? itens.single
    : '${itens.sublist(0, itens.length - 1).join(', ')} e ${itens.last}';

/// Partes do hino como trechos da cifra: nome de quem canta (ou do solo) na
/// faixa, a vez de [quemSou] em destaque e avisada na parte anterior. Sem
/// [acordes], só a letra; com eles, a cifra no tom escolhido com [semitons].
List<TrechoDaCifra> trechosDoHino(
  HinoDoLouvor hino, {
  required List<String> cantores,
  String quemSou = '',
  bool acordes = false,
  int semitons = 0,
}) {
  bool minha(ParteDoHino parte) =>
      quemSou.isNotEmpty && parte.cantores.contains(quemSou);
  String rotulo(ParteDoHino parte) => [
        if (parte.tipo != TipoDaParte.instrumental)
          parte.quemCanta.toUpperCase()
        else ...[
          if (!parte.deTodos) parte.quemCanta.toUpperCase(),
          (parte.nome ?? parte.tipo.rotulo).toUpperCase(),
        ],
        if (parte.vezes > 1) '${parte.vezes}X',
        if (minha(parte)) 'SUA VEZ',
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
        destaque: minha(parte),
        aviso: !minha(parte) &&
                indice + 1 < hino.partes.length &&
                minha(hino.partes[indice + 1])
            ? 'você é o próximo'
            : null,
        // Solo sem acordes escritos avisa que é instrumental mesmo no leitor.
        texto: acordes && parte.texto.trim().isNotEmpty
            ? transporCifra(parte.texto, semitons)
            : letra(parte),
      ),
  ];
}
