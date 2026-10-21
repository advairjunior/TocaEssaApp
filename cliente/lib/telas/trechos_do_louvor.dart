import 'package:flutter/material.dart';

import '../dominio/modelos.dart';
import '../dominio/transpor_cifra.dart';
import '../tema/tema_toca_essa.dart';
import 'cifra_do_palco.dart';

// Uma cor por cantor, na ordem da lista: a mesma em todos os telefones.
const _coresDosCantores = [
  CoresTocaEssa.roxoClaro,
  CoresTocaEssa.rosa,
  Color(0xFF60A5FA),
  CoresTocaEssa.sucesso,
  Color(0xFFFB923C),
  Color(0xFF22D3EE),
  Color(0xFFF472B6),
  Color(0xFFA3E635),
];

/// Cor de quem canta; Todos (ou nome fora da lista) fica discreto.
Color corDoCantor(List<String> cantores, String nome) {
  final indice = cantores.indexOf(nome);
  return indice < 0
      ? CoresTocaEssa.textoSecundario
      : _coresDosCantores[indice % _coresDosCantores.length];
}

/// Faixa dos solos e partes instrumentais, diferente da dos cantores.
const corInstrumental = CoresTocaEssa.atencao;

/// Cor de uma pessoa do louvor: a do cantor ou, de quem só toca, a dos solos.
Color corDaPessoa(List<String> cantores, String nome) =>
    cantores.contains(nome) ? corDoCantor(cantores, nome) : corInstrumental;

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
  if (daPessoa.isEmpty) return null;
  if (daPessoa.length == 1) return daPessoa.single;
  return '${daPessoa.sublist(0, daPessoa.length - 1).join(', ')} '
      'e ${daPessoa.last}';
}

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
        texto: acordes ? transporCifra(parte.texto, semitons) : letra(parte),
      ),
  ];
}
