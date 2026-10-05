import 'dart:async';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:toca_essa_app/infraestrutura/atualizacao_espalhada.dart';

void main() {
  testWidgets('rajada de avisos gera uma única atualização após o atraso',
      (tester) async {
    var atualizacoes = 0;
    final atualizacao = AtualizacaoEspalhada(
      () async => atualizacoes++,
      sorteio: _SorteioFixo(2000),
    );

    atualizacao.solicitar();
    atualizacao.solicitar();
    await tester.pump(const Duration(milliseconds: 1999));
    atualizacao.solicitar();
    expect(atualizacoes, 0);

    await tester.pump(const Duration(milliseconds: 1));
    expect(atualizacoes, 1);

    await tester.pump(const Duration(seconds: 10));
    expect(atualizacoes, 1);
    atualizacao.encerrar();
  });

  testWidgets('aviso durante uma atualização em andamento não se perde',
      (tester) async {
    var atualizacoes = 0;
    final emAndamento = Completer<void>();
    final atualizacao = AtualizacaoEspalhada(
      () async {
        atualizacoes++;
        if (atualizacoes == 1) await emAndamento.future;
      },
      sorteio: _SorteioFixo(500),
    );

    atualizacao.solicitar();
    await tester.pump(const Duration(milliseconds: 500));
    expect(atualizacoes, 1);

    atualizacao.solicitar();
    atualizacao.solicitar();
    await tester.pump(const Duration(seconds: 5));
    expect(atualizacoes, 1);

    emAndamento.complete();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(atualizacoes, 2);

    await tester.pump(const Duration(seconds: 5));
    expect(atualizacoes, 2);
    atualizacao.encerrar();
  });

  testWidgets('encerrar cancela a atualização agendada', (tester) async {
    var atualizacoes = 0;
    final atualizacao = AtualizacaoEspalhada(
      () async => atualizacoes++,
      sorteio: _SorteioFixo(1000),
    );

    atualizacao.solicitar();
    atualizacao.encerrar();
    atualizacao.solicitar();
    await tester.pump(const Duration(seconds: 5));

    expect(atualizacoes, 0);
  });

  testWidgets('atraso padrão espalha as atualizações em até três segundos',
      (tester) async {
    for (var semente = 0; semente < 20; semente++) {
      var atualizacoes = 0;
      final atualizacao = AtualizacaoEspalhada(
        () async => atualizacoes++,
        sorteio: Random(semente),
      );

      atualizacao.solicitar();
      await tester.pump(const Duration(seconds: 3));

      expect(atualizacoes, 1);
      atualizacao.encerrar();
    }
  });
}

class _SorteioFixo implements Random {
  _SorteioFixo(this._valor);

  final int _valor;

  @override
  int nextInt(int max) => min(_valor, max - 1);

  @override
  bool nextBool() => false;

  @override
  double nextDouble() => 0;
}
