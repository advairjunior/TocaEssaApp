# Sistema de fundos do TocaEssaApp — Plano de implementação

> **Para agentes executores:** SUB-SKILL OBRIGATÓRIA: use `superpowers:subagent-driven-development` (recomendado) ou `superpowers:executing-plans` para implementar este plano tarefa por tarefa. Os passos usam caixas de seleção (`- [ ]`) para acompanhamento.

**Objetivo:** Aplicar três famílias visuais coerentes às telas de entrada, artista e público sem comprometer legibilidade, desempenho ou regras de negócio.

**Arquitetura:** Um componente compartilhado `FundoTocaEssa` renderizará gradiente de fallback, imagem responsiva, filtro de contraste e o conteúdo da tela. As telas escolherão apenas variante e intensidade; recursos fotográficos não conhecerão navegação nem estado de negócio.

**Stack:** Flutter, Material 3, imagens locais geradas pelo ImageGen, testes de widget com `flutter_test`.

**Especificação:** `docs/superpowers/specs/2026-09-11-sistema-de-fundos-design.md`

## Restrições globais

- Manter somente três imagens finais: palco, bastidores e atmosfera.
- Não adicionar pacotes Flutter.
- Não usar vídeo, download remoto, texto dentro das imagens ou rostos reconhecíveis.
- Preservar cartões e superfícies escuras nas telas operacionais.
- Retrospectivas continuam usando a fotografia real da resenha.
- Cada arquivo Dart deve permanecer abaixo de 350 linhas.
- `.vs/` nunca deve entrar em commits.

---

### Tarefa 1: Componente compartilhado e fundo Palco

**Arquivos:**

- Criar: `cliente/lib/telas/fundo_toca_essa.dart`
- Criar: `cliente/test/fundo_toca_essa_test.dart`
- Modificar: `cliente/lib/telas/inicio.dart`
- Modificar: `cliente/pubspec.yaml`
- Usar: `cliente/assets/fundos/inicio_palco.png`

**Interfaces:**

- Produz: `enum VarianteFundoTocaEssa { palco, bastidores, atmosfera }`
- Produz: `enum IntensidadeFundoTocaEssa { imersiva, suave, cabecalho }`
- Produz: `FundoTocaEssa({required Widget child, required VarianteFundoTocaEssa variante, IntensidadeFundoTocaEssa intensidade = IntensidadeFundoTocaEssa.suave})`
- Consome: `CoresTocaEssa` e imagens declaradas em `pubspec.yaml`.

- [ ] **Passo 1: escrever o teste que falha**

Criar `fundo_toca_essa_test.dart` com um teste para cada variante e um teste de responsividade:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:toca_essa_app/telas/fundo_toca_essa.dart';

void main() {
  testWidgets('seleciona uma imagem para cada família visual', (tester) async {
    for (final caso in const [
      (VarianteFundoTocaEssa.palco, 'assets/fundos/inicio_palco.png'),
      (VarianteFundoTocaEssa.bastidores, 'assets/fundos/bastidores.png'),
      (VarianteFundoTocaEssa.atmosfera, 'assets/fundos/atmosfera.png'),
    ]) {
      await tester.pumpWidget(MaterialApp(
        home: FundoTocaEssa(variante: caso.$1, child: const Text('Conteúdo')),
      ));
      expect(find.image(AssetImage(caso.$2)), findsOneWidget);
    }
  });

  testWidgets('preserva o conteúdo acima do fundo', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: FundoTocaEssa(
        variante: VarianteFundoTocaEssa.palco,
        intensidade: IntensidadeFundoTocaEssa.imersiva,
        child: Text('Ação principal'),
      ),
    ));
    expect(find.text('Ação principal'), findsOneWidget);
  });
}
```

- [ ] **Passo 2: confirmar a falha**

Executar:

```powershell
cd cliente
flutter test test/fundo_toca_essa_test.dart
```

Resultado esperado: falha porque `fundo_toca_essa.dart` e seus tipos ainda não existem.

- [ ] **Passo 3: implementar o componente mínimo**

Criar um `Stack` com esta ordem:

1. `DecoratedBox` com gradiente escuro de fallback;
2. `Image.asset` correspondente à variante, usando `errorBuilder` que retorna `SizedBox.expand()`;
3. gradiente de contraste conforme a intensidade;
4. `child` em primeiro plano.

Usar `LayoutBuilder` para definir o alinhamento: palco em telas abaixo de 700 px usa `Alignment(-.72, -.15)` e desktop usa `Alignment.topCenter`. A intensidade `cabecalho` limita imagem e overlay a 280 px de altura e termina em transparência.

Refatorar `inicio.dart` para substituir seu `Stack` local por:

```dart
FundoTocaEssa(
  variante: VarianteFundoTocaEssa.palco,
  intensidade: IntensidadeFundoTocaEssa.imersiva,
  child: ConteudoMobile(filho: conteudo),
)
```

- [ ] **Passo 4: confirmar o teste verde**

Executar `flutter test test/fundo_toca_essa_test.dart` e esperar todos os testes aprovados.

- [ ] **Passo 5: registrar a tarefa**

```powershell
git add cliente/lib/telas/fundo_toca_essa.dart cliente/lib/telas/inicio.dart cliente/pubspec.yaml cliente/assets/fundos/inicio_palco.png cliente/test/fundo_toca_essa_test.dart
git commit -m "feat: criar sistema compartilhado de fundos"
```

---

### Tarefa 2: Família Bastidores e acessos do artista

**Arquivos:**

- Criar: `cliente/assets/fundos/bastidores.png`
- Modificar: `cliente/pubspec.yaml`
- Modificar: `cliente/lib/telas/acesso_do_artista.dart`
- Modificar: `cliente/lib/telas/painel_do_artista.dart`
- Modificar: `cliente/lib/telas/painel_do_artista_construcao.dart`
- Modificar: `cliente/test/widget_test.dart`

**Interfaces:**

- Consome: `FundoTocaEssa`, `VarianteFundoTocaEssa.bastidores` e as três intensidades criadas na Tarefa 1.
- Produz: acesso do artista imersivo e painel com ambientação somente no cabeçalho.

- [ ] **Passo 1: gerar o recurso Bastidores**

Usar ImageGen integrado com o prompt:

```text
Fundo responsivo para painel de artista musical; bastidores elegantes com microfone, violão, cabos e luzes violetas; composição cinematográfica escura; centro calmo para interface; sem texto, logotipo, marcas ou pessoas reconhecíveis; enquadramento adaptável a desktop e celular.
```

Salvar o resultado em `cliente/assets/fundos/bastidores.png` e declarar o recurso no `pubspec.yaml`.

- [ ] **Passo 2: escrever o teste que falha**

No teste existente `artista cria conta e acessa painel protegido`, após abrir `/artista`, adicionar:

```dart
expect(
  find.image(const AssetImage('assets/fundos/bastidores.png')),
  findsOneWidget,
);
```

Adicionar outro teste de painel autenticado que confirme a mesma imagem e preserve a barra `Apresentações`, `Criar` e `Perfil geral`.

- [ ] **Passo 3: confirmar a falha**

Executar:

```powershell
flutter test test/widget_test.dart --plain-name "artista cria conta e acessa painel protegido"
```

Resultado esperado: a imagem Bastidores não é encontrada na tela.

- [ ] **Passo 4: aplicar Bastidores**

Em `acesso_do_artista.dart`, substituir o `DecoratedBox` radial por `FundoTocaEssa` com intensidade `imersiva`.

Em `painel_do_artista_construcao.dart`, envolver o corpo do `Scaffold` com `FundoTocaEssa`, usando `cabecalho` nas apresentações, fila e estatísticas, e `suave` no perfil geral. Não envolver o `NavigationBar`, garantindo contraste constante.

- [ ] **Passo 5: confirmar os testes verdes**

Executar os dois testes do artista e esperar aprovação.

- [ ] **Passo 6: registrar a tarefa**

```powershell
git add cliente/assets/fundos/bastidores.png cliente/pubspec.yaml cliente/lib/telas/acesso_do_artista.dart cliente/lib/telas/painel_do_artista.dart cliente/lib/telas/painel_do_artista_construcao.dart cliente/test/widget_test.dart
git commit -m "feat: ambientar acesso e painel do artista"
```

---

### Tarefa 3: Família Atmosfera e área do público

**Arquivos:**

- Criar: `cliente/assets/fundos/atmosfera.png`
- Modificar: `cliente/pubspec.yaml`
- Modificar: `cliente/lib/telas/area_do_publico.dart`
- Modificar: `cliente/lib/telas/area_do_publico_construcao.dart`
- Modificar: `cliente/lib/telas/conta_do_publico.dart`
- Modificar: `cliente/lib/telas/conta_do_publico_construcao.dart`
- Modificar: `cliente/lib/telas/perfil_participante.dart`
- Modificar: `cliente/test/widget_test.dart`
- Modificar: `cliente/test/conta_do_publico_test.dart`
- Modificar: `cliente/test/perfil_participante_test.dart`

**Interfaces:**

- Consome: `FundoTocaEssa` com `VarianteFundoTocaEssa.atmosfera`.
- Produz: ambientação discreta nas áreas públicas, sem modificar navegação, autenticação, fila ou perfil.

- [ ] **Passo 1: gerar o recurso Atmosfera**

Usar ImageGen integrado com o prompt:

```text
Fundo abstrato responsivo para aplicativo musical; bokeh violeta e magenta, fumaça suave, pequenos reflexos de palco e profundidade; sofisticado, escuro e de baixo contraste; sem texto, logotipo, símbolos, objetos centrais ou pessoas; adequado para listas e cartões legíveis.
```

Salvar em `cliente/assets/fundos/atmosfera.png` e declarar em `pubspec.yaml`.

- [ ] **Passo 2: escrever testes que falham**

Nos testes das três superfícies, confirmar que a imagem é renderizada e que o conteúdo principal continua disponível:

```dart
expect(
  find.image(const AssetImage('assets/fundos/atmosfera.png')),
  findsOneWidget,
);
expect(find.text('Área do Público'), findsOneWidget);
```

Para conta, manter a expectativa `Minha conta`. Para participante, manter `Perfil do participante` e o nome da pessoa.

- [ ] **Passo 3: confirmar as falhas**

Executar:

```powershell
flutter test test/widget_test.dart test/conta_do_publico_test.dart test/perfil_participante_test.dart
```

Resultado esperado: os conteúdos continuam encontrados, mas a imagem Atmosfera não aparece.

- [ ] **Passo 4: aplicar Atmosfera**

Importar o componente nos três arquivos raiz. Envolver somente os corpos dos `Scaffold`:

```dart
FundoTocaEssa(
  variante: VarianteFundoTocaEssa.atmosfera,
  intensidade: IntensidadeFundoTocaEssa.suave,
  child: conteudoAtual,
)
```

Usar intensidade `cabecalho` na fila e na galera, `suave` nos perfis e `imersiva` apenas quando o usuário ainda estiver na tela de autenticação. Não envolver cartões de retrospectiva que já usam a fotografia da resenha.

- [ ] **Passo 5: confirmar os testes verdes**

Repetir os três arquivos de teste e esperar aprovação completa.

- [ ] **Passo 6: registrar a tarefa**

```powershell
git add cliente/assets/fundos/atmosfera.png cliente/pubspec.yaml cliente/lib/telas/area_do_publico.dart cliente/lib/telas/area_do_publico_construcao.dart cliente/lib/telas/conta_do_publico.dart cliente/lib/telas/conta_do_publico_construcao.dart cliente/lib/telas/perfil_participante.dart cliente/test/widget_test.dart cliente/test/conta_do_publico_test.dart cliente/test/perfil_participante_test.dart
git commit -m "feat: ambientar area e perfis do publico"
```

---

### Tarefa 4: Validação visual, desempenho e integração

**Arquivos:**

- Verificar: `cliente/assets/fundos/inicio_palco.png`
- Verificar: `cliente/assets/fundos/bastidores.png`
- Verificar: `cliente/assets/fundos/atmosfera.png`
- Verificar: todos os arquivos modificados nas tarefas anteriores.

**Interfaces:**

- Consome: todas as variantes do `FundoTocaEssa`.
- Produz: versão web compilada e sistema visual consistente.

- [ ] **Passo 1: conferir tamanho e quantidade dos recursos**

Confirmar exatamente três imagens finais e registrar seus tamanhos. Nenhum arquivo individual deve exceder 1,6 MB; otimizar antes de continuar se exceder.

- [ ] **Passo 2: executar validação completa**

```powershell
cd cliente
flutter test
flutter analyze
flutter build web --dart-define=API_URL=http://127.0.0.1:5080
```

Resultado esperado: todos os testes aprovados, nenhuma ocorrência na análise e build web concluído.

- [ ] **Passo 3: inspecionar visualmente**

Executar o aplicativo local e conferir em largura móvel e desktop:

- imagem claramente perceptível nas entradas;
- cabeçalhos ambientados sem reduzir a leitura;
- listas longas sobre fundo estável;
- cartões e botões com contraste suficiente;
- nenhum corte indesejado, overflow ou rolagem bloqueada;
- retrospectivas sem fundo temático concorrente.

- [ ] **Passo 4: revisar o diff**

Executar `git diff --check`, confirmar arquivos abaixo de 350 linhas e garantir que `.vs/` não esteja preparado.

- [ ] **Passo 5: registrar integração final**

```powershell
git add cliente
git commit -m "feat: consolidar identidade visual do TocaEssaApp"
```

Não fazer push sem solicitação explícita do usuário.
