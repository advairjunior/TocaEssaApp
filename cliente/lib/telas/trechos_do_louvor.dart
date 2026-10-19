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
