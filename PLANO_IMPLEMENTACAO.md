# Plano de implementação do TocaEssaApp

## Dois tipos de Apresentação

### Apresentação Pública

Fluxo de entrada rápido, pensado para bares, shows e eventos com muitas pessoas.

- O público entra pelo código ou QR Code, sem criar conta.
- Informa somente um nome curto, que pode continuar opcional.
- Pode enviar Pedido Musical, acompanhar seu pedido e avaliar músicas tocadas.
- Não há foto nem histórico público permanente da pessoa.
- As estatísticas ficam privadas para o artista: músicas mais pedidas, pedidos aceitos e tocados, participação e avaliações recebidas.

### Resenha entre Amigos

Fluxo identificado, pensado para encontros recorrentes de um grupo.

- Cada participante entra com sua conta.
- O Perfil do Público possui nome e foto.
- O histórico acumula entre resenhas: participações, músicas pedidas, aceitas e tocadas, avaliações e preferências.
- A resenha mostra informações mais detalhadas dos participantes e do encontro.
- Estatísticas divertidas entre amigos e retrospectivas compartilháveis entram em uma etapa posterior.
- O artista pode tirar ou escolher uma foto do encontro para compor a retrospectiva visual com as estatísticas.
- Cada pessoa poderá controlar sua foto, visibilidade e exclusão dos próprios dados.

## Perfil Artístico

- Adicionar foto ao Perfil Artístico.
- Mostrar a foto no Painel do Artista e na Área do Público.
- Manter um avatar padrão quando não houver foto.
- Preparar compressão e limite de tamanho para funcionar bem no celular.

## Ordem de implementação

1. ✅ Adicionar `Pública` e `Resenha entre Amigos` na criação e edição da Apresentação. Apresentações existentes serão consideradas públicas.
2. ✅ Ajustar os textos e a Área do Público conforme o tipo, mantendo o fluxo atual intacto para apresentações públicas.
3. ✅ Adicionar foto ao Perfil Artístico e criar a base de armazenamento de imagens.
4. ✅ Migrar os dados locais em JSON para SQLite, com importação automática dos dados existentes.
5. ✅ Implementar autenticação por e-mail e senha, sessão persistente e Perfil do Público com foto somente para Resenha entre Amigos.
6. ✅ Registrar avaliações de 1 a 5 estrelas depois que uma música for tocada e exibi-las ao artista.
7. ✅ Criar estatísticas privadas por Apresentação para o artista e histórico pessoal acumulado para participantes autenticados.
8. ✅ Criar retrospectivas e cartões compartilháveis da Resenha entre Amigos.
9. ✅ Criar conta do artista, sessão persistente e proteger o Painel do Artista.
10. ✅ Detalhar participantes e estatísticas coletivas da Resenha entre Amigos.
11. ✅ Evoluir o compartilhamento para imagens com estatísticas e foto opcional do encontro, prontas para redes sociais.
12. ✅ Substituir a atualização periódica por comunicação em tempo real.

## Regras para manter o produto simples

- Apresentação Pública nunca exigirá cadastro, senha ou foto.
- Resenha entre Amigos exigirá login porque o histórico será acumulado.
- A Fila Musical continuará sendo formada somente por pedidos do público.
- O artista não precisará registrar no aplicativo as músicas do próprio repertório.
- Rankings compartilháveis serão opcionais e evitarão expor recusas ou informações constrangedoras.

## Decisões que podem esperar

- Método de login da Resenha: e-mail e senha, código por e-mail ou provedor social.
- Armazenamento definitivo das fotos quando o aplicativo for publicado.
- Quais estatísticas e cartões poderão ser compartilhados fora do grupo.

## Banco de ideias

Ideias registradas para avaliar no futuro. Nenhuma tem compromisso de entrega;
cada uma começa por uma investigação antes de virar plano.

### Cifra dentro do próprio app

- **Status:** ✅ entregue em 2026-10-13 pelo caminho alternativo: o artista
  cola a cifra no app, guardada junto com a música (`ebadd90`), e o leitor
  de cifras mostra tudo sem sair do TocaEssa (`0280149`). Depois vieram
  tom, rolagem automática, limpeza da cifra colada e o leitor do louvor.
- **Problema:** no palco, cada música abre a cifra numa aba do navegador e o
  artista precisa alternar entre o app e a cifra. Mesmo com uma única aba de
  cifra, essa troca gera silêncio entre uma música e outra.
- **Ideia:** mostrar a cifra dentro do TocaEssa, sem sair do app.
- **Investigar antes:**
  - Se o Cifra Club (e outros sites salvos pelos artistas) permite ser exibido
    numa janela dentro do app ou bloqueia isso.
  - Se é possível trazer o conteúdo pelo servidor e mostrá-lo no app, e se os
    termos de uso dos sites permitem.
  - Alternativa: o artista colar ou digitar a cifra no próprio app, guardada
    junto com a música.
  - Como fica no iPhone, tanto no Safari quanto com o app instalado na tela
    inicial.
- **Registrada em:** 2026-10-08.

### Busca automática do link da cifra

- **Problema:** cadastrar a cifra de um repertório grande, música por música,
  toma tempo, mesmo com o Colar e próxima.
- **Ideia:** um botão "Buscar automaticamente" no aviso de músicas sem cifra,
  que encontra e salva o link de todas de uma vez, marcadas para conferir.
- **Já investigado (2026-10-08):**
  - O Cifra Club bloqueia qualquer acesso automático (proteção anti-robô da
    Akamai, resposta 403 até no `robots.txt`). Montar o link e conferir se a
    página existe não é viável, e contornar o bloqueio está fora de questão.
  - Ler os resultados do Google pelo servidor ou pelo navegador também não é
    possível: o Google bloqueia leitura automática e o navegador impede um
    site de ler outro.
  - Caminho viável: uma API de busca, como a Brave Search API. Exige conta,
    chave guardada como variável de ambiente no Render (fora do repositório)
    e provavelmente cartão. Preço em 2026, a confirmar na página oficial:
    cerca de US$ 5 por 1.000 buscas com US$ 5 de crédito mensal. Cada música
    é buscada uma única vez.
- **Registrada em:** 2026-10-08.

### Tela de carregamento e servidor acordando

- **Status:** ✅ entregue em 2026-10-19. O QR do público era o pior caso: a
  área do show abria direto num carregando sem explicação. Hoje o aviso
  aparece no QR do público, no painel com sessão salva e no login.
- **Problema:** no plano free do Render o servidor dorme sem uso. O primeiro
  acesso (o público escaneando o QR no começo do show, ou o artista abrindo o
  painel) fica uns 30 a 60 s numa tela preta ou com o botão parado, e parece
  que o app quebrou.
- **Ideia:** a mesma solução que já está no ar no Baralho da Resenha
  (BaralhoResenhaApp, commits `83b8427` e `7573dc4`):
  - **Tela de carregamento no `web/index.html`:** um aviso em HTML/CSS puro
    ("Carregando…", com animação) que aparece antes de o Flutter abrir e some
    no evento `flutter-first-frame`.
  - **Cutucar o servidor ao abrir o app:** a tela inicial chama o
    `/api/saude` (que já existe) sem esperar resposta, para o servidor ir
    acordando enquanto a pessoa digita o nome.
  - **Aviso de espera:** se uma ação (entrar no evento, fazer login) passar de
    3 s, aparece um carregando com "Carregando o aplicativo TocaEssa,
    aguarde…".
- **Investigar antes:** onde o TocaEssa mais sofre com o servidor dormindo
  (QR do público ou painel do artista), e se o primeiro acesso ao PostgreSQL
  do Render também demora.
- **Registrada em:** 2026-10-19.

### Trocar acorde para enriquecer a cifra

- **Problema:** a cifra escrita pelo artista às vezes é simples demais; ele
  quer acordes e passagens mais bonitas sem sair do app nem procurar em
  outro lugar.
- **Ideia (caminho escolhido em 2026-10-21: regras, sem IA):** no editor da
  cifra (e talvez no leitor), tocar num acorde mostra substitutos calculados
  pela teoria, e o artista escolhe um por um:
  - **trocar:** G → G7M, G6, G9, G/B (tétrades, extensões e inversões
    conforme a função do acorde no tom);
  - **inserir antes:** dominante secundária (E7 antes do Am), ii–V
    (Bm7(b5) E7 antes do Am), diminuto de passagem (C → C#º → Dm);
  - **baixo caminhando:** C → C/E → F.
  O acorde novo entra alinhado na mesma sílaba; o "Tom:" e as marcações
  "(Estrofe 1)" continuam valendo para a escala do louvor.
- **Por que regras e não IA:** grátis, funciona sem internet, sem chave de
  API nem custo; o artista fica no controle de cada troca. A IA (enriquecer
  a cifra inteira de uma vez) fica como possível passo seguinte.
- **Investigado em 2026-10-21:** não existe pronto em Flutter nem fora algo
  confiável que enriqueça a cifra sozinho. Em Dart há bibliotecas de teoria
  musical: `music_notes` (a mais completa: acordes, escalas, funções
  harmônicas, tonalidades), `saavy_music` e `crisp_notation_core`. Fora,
  PyTheory (Python), opendaw-mcp e JMove aplicam receitas de rearmonização
  (dominante secundária, trítono, diminuto de passagem, empréstimo modal).
  O app já transpõe cifras (`transpor_cifra.dart`), base para calcular os
  substitutos sem dependência nova.
- **Investigar antes:** usar `music_notes` ou estender `transpor_cifra.dart`;
  como mostrar as opções no toque sem atrapalhar a edição no iPhone;
  guardar a versão anterior da cifra para "Voltar à original" (nunca perder
  o que o artista escreveu).
- **Registrada em:** 2026-10-21.

### Compartilhar repertório com outra conta

- **Status:** parcial. Em 2026-10-21 entrou o compartilhamento de **uma**
  música por link, sem conta: a cifra colada (`744e3c3`, `#/cifra/{codigo}`)
  e o hino do louvor (`f1044e2`). Copiar o repertório inteiro para outra
  conta continua como ideia.
- **Problema:** um colega de banda ou de louvor precisa montar de novo, na
  conta dele, um repertório que já existe, com cifras e letras coladas uma a
  uma.
- **Ideia (caminho escolhido em 2026-10-21):** enviar uma **cópia por
  link**. No repertório, "Compartilhar" gera um link com código difícil de
  adivinhar; o colega, logado, vê a prévia ("Barzinho · 42 músicas · 38 com
  cifra · de Duo Aurora") e toca em "Copiar para minha conta". Vão título,
  cantor, tom, cifra colada (letras dos hinos com as marcações de estrofe)
  e link da cifra. Depois de copiado, o repertório é dele e não muda com o
  original. "Parar de compartilhar" desativa o link.
- **Decisões já tomadas:**
  - Nada é sobrescrito: cifra que o colega já tem para a mesma música fica
    a dele ("35 cifras copiadas · 3 você já tinha, mantidas").
  - Copiar de novo o mesmo link **completa o que falta** no repertório já
    copiado, em vez de criar outro.
  - Não vão: tom do "b Tom #" (guardado no aparelho), setlists e pedidos.
  - A prévia mostra só nome e contagens; copiar exige estar logado.
- **Descartado por enquanto:** repertório vivo editado pelas duas contas
  (muda o modelo de dono, permissões e conflitos). Só se o uso pedir.
- **Esforço estimado:** médio. Servidor: tabela nova
  `RepertoriosCompartilhados` (código, repertório, dono, data, revogado),
  criada só se não existir; rotas para gerar/revogar o link, prévia e
  copiar; testes de isolamento entre contas. App: botão Compartilhar, tela
  que abre o link e aviso do resultado.
- **Investigar antes:** como guardar a ligação entre a cópia e o link para
  o "completar o que falta"; abrir o link no iPhone com o app instalado na
  Tela de Início.
- **Registrada em:** 2026-10-21.

### Visual próprio para o Louvor

- **Problema:** o Louvor usa o mesmo visual de show (roxo neon, foto de palco
  com público), mas acontece de dia ou em casa iluminada, com cada um lendo a
  letra no próprio telefone. Texto branco no preto cansa num ambiente claro, e
  o clima de bar não combina com um encontro de hinos.
- **Ideia:** automática pelo tipo de evento, sem botão de tema. O leitor da
  letra fica claro (fundo creme tipo papel, letra quase preta, acordes num
  tom escuro). O resto do Louvor continua escuro, mas troca o roxo pelo
  dourado (`CoresTocaEssa.ouro`) e a foto de palco por um fundo liso e quente.
  O show continua como está.
- **Prévia aprovada para avaliar:** https://claude.ai/artifact/2oqkzWg2dQF3aLAo2ARXQ3
  (leitor hoje × claro, escala roxa × dourada, as 12 cores no escuro × claro).
- **Cuidado:** as 12 cores dos cantores (`_coresDosCantores`) foram feitas para
  o fundo escuro; o claro precisa de uma versão mais escura de cada uma, na
  mesma ordem. Verde-limão e caramelo são as mais fracas no creme.
- **Investigar antes:** observar o encontro de 2026-10-24 (letra legível na
  sala? alguém aumenta o brilho?); escolher creme ou branco e acordes roxos ou
  marrons pela prévia.
- **Registrada em:** 2026-10-22.

### No palco

- **Salvar a setlist como repertório:** ✅ entregue em 2026-10-21
  ("Adicionar ao repertório" no Editar da setlist e dos hinos, também
  para os pedidos do show).
- **Copiar ou mover música entre repertórios:** reaproveitar a folha
  "Adicionar ao repertório" a partir do próprio repertório.
- **Blocos do show:** "1º set · Intervalo · 2º set" na setlist, ligados ao
  botão Intervalo do cronômetro.
- **Estilo ou energia por música** ("calma", "animada") e filtro ao montar a
  setlist.

- **Tom, capotraste e observação por música no repertório:** salvar uma vez
  ("Tom G, capo 2, começa só voz") e mostrar na barra da próxima música.
- **Cronômetro do show:** ✅ entregue em 2026-10-13 (contagem regressiva,
  intervalo, ritmo real e estimativa da setlist antes do show com o ritmo
  médio; plano em `docs/superpowers/plans/2026-10-13-cronometro-do-show.md`).
- **Modo sem internet:** ✅ entregue em 2026-10-13 (leituras guardadas no
  aparelho, fila de marcações e aviso no topo).

### Para o público

- **Gorjeta ligada ao pedido:** selo de "pedido com apoio" ou prioridade na
  fila. Mexe com dinheiro e com a percepção do público; decidir com cuidado.
- **Seguir o artista:** deixar contato para saber da próxima apresentação.

### Carreira e negócio do artista

- **Músicas que mais funcionam:** juntar todas as apresentações (hoje o
  ranking de mais pedidas é por apresentação) e cruzar com o repertório:
  mais pedidas e ainda fora do repertório, mais bem avaliadas. A parte
  "mais pedidas e fora do repertório" foi entregue em 2026-10-21 (cartão
  em Meus repertórios); falta a das mais bem avaliadas.
- **Agenda pública do artista:** página com as próximas apresentações.
- **Avisar seguidores do próximo show:** depende de Seguir o artista.
- **Relatório do show para o contratante:** público pelo app, pedidos e
  avaliação média, como argumento para negociar cachê.
