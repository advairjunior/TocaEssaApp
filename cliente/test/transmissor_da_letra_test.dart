import 'package:flutter_test/flutter_test.dart';
import 'package:toca_essa_app/dominio/tela_da_tv.dart';
import 'package:toca_essa_app/dominio/transmissor_da_letra.dart';

class _SaidaFalsa implements SaidaDaTela {
  final enviados = <String>[];
  var semMusicaNaProxima = false;

  @override
  Future<void> mostrar(ConteudoParaTv conteudo) async =>
      enviados.add('mostrar ${conteudo.titulo} ${conteudo.linha}');

  @override
  Future<void> irParaALinha(int linha) async {
    if (semMusicaNaProxima) {
      semMusicaNaProxima = false;
      throw const TvAindaSemMusica();
    }
    enviados.add('linha $linha');
  }

  @override
  Future<void> limpar() async => enviados.add('limpar');
}

ConteudoParaTv _musica(String titulo) =>
    ConteudoParaTv(titulo: titulo, texto: 'Letra', linha: 0);

void main() {
  late _SaidaFalsa saida;
  late TransmissorDaLetra transmissor;

  setUp(() {
    saida = _SaidaFalsa();
    transmissor = TransmissorDaLetra(saida);
  });

  tearDown(() => transmissor.encerrar());

  testWidgets('a música nova vai na hora, já na linha zero', (tester) async {
    transmissor.mostrar(_musica('Fim de tarde'));
    await tester.pump();

    expect(saida.enviados, ['mostrar Fim de tarde 0']);
  });

  testWidgets('linha repetida não é mandada de novo', (tester) async {
    transmissor.mostrar(_musica('Fim de tarde'));
    transmissor.lerALinha(0);
    transmissor.lerALinha(1);
    await tester.pump(const Duration(seconds: 1));
    transmissor.lerALinha(1);
    await tester.pump(const Duration(seconds: 1));

    expect(saida.enviados, ['mostrar Fim de tarde 0', 'linha 1']);
  });

  testWidgets(
      'rolagem rápida manda no máximo uma linha por intervalo, '
      'e a última sempre chega', (tester) async {
    transmissor.mostrar(_musica('Fim de tarde'));
    await tester.pump();
    for (var linha = 1; linha <= 5; linha++) {
      transmissor.lerALinha(linha);
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.pump(const Duration(seconds: 1));

    expect(saida.enviados, ['mostrar Fim de tarde 0', 'linha 1', 'linha 5']);
  });

  testWidgets(
      'linha antes da música (servidor dormiu) manda a música de novo '
      'naquela linha', (tester) async {
    transmissor.mostrar(_musica('Fim de tarde'));
    await tester.pump();
    saida.semMusicaNaProxima = true;

    transmissor.lerALinha(3);
    await tester.pump(const Duration(seconds: 1));

    expect(
        saida.enviados, ['mostrar Fim de tarde 0', 'mostrar Fim de tarde 3']);
  });

  testWidgets('linha sem música nenhuma não vai para a TV', (tester) async {
    transmissor.lerALinha(2);
    await tester.pump(const Duration(seconds: 1));

    expect(saida.enviados, isEmpty);
  });

  testWidgets('trocar de música esquece a linha pendente da anterior',
      (tester) async {
    transmissor.mostrar(_musica('Uma'));
    await tester.pump();
    transmissor.lerALinha(1);
    transmissor.lerALinha(2);
    transmissor.mostrar(_musica('Outra'));
    await tester.pump(const Duration(seconds: 1));

    expect(saida.enviados, ['mostrar Uma 0', 'linha 1', 'mostrar Outra 0']);
  });

  testWidgets('falha de internet não derruba a cifra', (tester) async {
    final transmissorQueFalha = TransmissorDaLetra(_SaidaSemInternet());

    transmissorQueFalha.mostrar(_musica('Fim de tarde'));
    transmissorQueFalha.lerALinha(1);
    await tester.pump(const Duration(seconds: 1));
    transmissorQueFalha.encerrar();
  });
}

class _SaidaSemInternet implements SaidaDaTela {
  @override
  Future<void> mostrar(ConteudoParaTv conteudo) => Future.error('sem rede');

  @override
  Future<void> irParaALinha(int linha) => Future.error('sem rede');

  @override
  Future<void> limpar() => Future.error('sem rede');
}
