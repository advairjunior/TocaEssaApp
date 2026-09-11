import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:toca_essa_app/telas/fundo_toca_essa.dart';

void main() {
  testWidgets('seleciona uma imagem para cada família visual', (
    tester,
  ) async {
    for (final caso in const [
      (VarianteFundoTocaEssa.palco, 'assets/fundos/inicio_palco.png'),
      (VarianteFundoTocaEssa.bastidores, 'assets/fundos/bastidores.png'),
      (VarianteFundoTocaEssa.atmosfera, 'assets/fundos/atmosfera.png'),
    ]) {
      await tester.pumpWidget(
        MaterialApp(
          home: FundoTocaEssa(
            variante: caso.$1,
            child: const Text('Conteúdo'),
          ),
        ),
      );

      expect(find.image(AssetImage(caso.$2)), findsOneWidget);
    }
  });

  testWidgets('preserva o conteúdo acima do fundo', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: FundoTocaEssa(
          variante: VarianteFundoTocaEssa.palco,
          intensidade: IntensidadeFundoTocaEssa.imersiva,
          child: Text('Ação principal'),
        ),
      ),
    );

    expect(find.text('Ação principal'), findsOneWidget);
  });

  testWidgets('alinha o palco para celular e desktop', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    for (final caso in const [
      (Size(699, 800), Alignment(-.72, -.15)),
      (Size(700, 800), Alignment.topCenter),
    ]) {
      tester.view.physicalSize = caso.$1;
      tester.view.devicePixelRatio = 1;

      await tester.pumpWidget(
        const MaterialApp(
          home: FundoTocaEssa(
            variante: VarianteFundoTocaEssa.palco,
            child: SizedBox(),
          ),
        ),
      );

      final imagem = tester.widget<Image>(
        find.image(const AssetImage('assets/fundos/inicio_palco.png')),
      );
      expect(imagem.alignment, caso.$2);
    }
  });

  testWidgets('desvanece a composição do cabeçalho sobre o fallback', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: FundoTocaEssa(
          variante: VarianteFundoTocaEssa.bastidores,
          intensidade: IntensidadeFundoTocaEssa.cabecalho,
          child: SizedBox(),
        ),
      ),
    );

    final mascara = tester.widget<ShaderMask>(find.byType(ShaderMask));
    final composicao = mascara.child! as Stack;
    final restricao = tester
        .widgetList<SizedBox>(find.byType(SizedBox))
        .singleWhere((caixa) => caixa.height == 280);

    expect(mascara.blendMode, BlendMode.dstIn);
    expect(composicao.children.first, isA<Image>());
    expect(composicao.children[1], isA<DecoratedBox>());
    expect(restricao.width, double.infinity);
  });

  testWidgets('mantém fallback e conteúdo acionável quando a imagem falha', (
    tester,
  ) async {
    var acionado = false;

    await tester.pumpWidget(
      DefaultAssetBundle(
        bundle: _BundleQueFalha(),
        child: MaterialApp(
          home: FundoTocaEssa(
            variante: VarianteFundoTocaEssa.palco,
            child: FilledButton(
              onPressed: () => acionado = true,
              child: const Text('Continuar'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is DecoratedBox &&
            (widget.decoration as BoxDecoration?)?.gradient is RadialGradient,
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('Continuar'));
    await tester.pump();

    expect(acionado, isTrue);
  });
}

class _BundleQueFalha extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) =>
      Future<ByteData>.error(FlutterError('Asset indisponível: $key'));
}
