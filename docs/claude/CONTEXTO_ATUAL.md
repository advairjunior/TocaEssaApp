# TocaEssaApp — Contexto atual

> Atualizado em: 2026-10-23

## Arquitetura

| Camada | Tecnologia |
|--------|-----------|
| Cliente | Flutter Web / PWA |
| Servidor | ASP.NET Core Minimal APIs (.NET 10) |
| Banco local | SQLite (desenvolvimento e testes) |
| Banco produção | PostgreSQL no Render |
| Deploy | Render — automático via push na `main` |

### Modelo de propriedade multiartista

```
ContaArtista
├── PerfilArtistico (1:1, isolado por ArtistaId)
├── CifrasDoArtista (1:N, isoladas por ArtistaId)
├── Repertorios (1:N, isolados por ArtistaId)
└── Apresentacoes (1:N, isoladas por ArtistaId)
    ├── Pedidos e fila
    ├── Setlist
    ├── ParticipacoesResenha
    ├── Avaliacoes
    ├── Fotos
    ├── Estatisticas
    └── Retrospectiva
```

Rotas públicas (por código de apresentação) continuam acessíveis sem token.
Operações privadas sempre extraem a conta do token — nunca aceitam `ArtistaId` do cliente.

## Estado atual (2026-10-08)

O roadmap do `PLANO_IMPLEMENTACAO.md` está todo entregue. Novas ideias ficam na
seção **Banco de ideias** do mesmo arquivo. O estado do Git muda a cada sessão:
confira com `git status` e `git log --oneline -15` em vez de confiar neste
arquivo.

### O que o app faz hoje

**Público (sem conta, pelo código ou QR Code)**
- Entra no evento, faz Pedido Musical, acompanha a fila e avalia músicas tocadas.
- Sem conta, o nome é obrigatório (pelo menos 2 letras) para pedir música ou
  alô; a rota pública responde 400 "Informe seu nome." (contrato alterado com
  autorização em 2026-10-13). O nome fica salvo no aparelho.
- Pix do artista (copia e cola ou chave), contagem de quem abriu o evento.
- Resenha entre Amigos: conta com foto, histórico em linha do tempo,
  retrospectiva do ano e cartões compartilháveis com foto do encontro.
- Meus encontros (2026-10-26, antes "Minhas resenhas"): a conta do público
  guarda os três tipos. `POST .../participacoes` (rota pública, mudança
  autorizada) vale para todos: na resenha como antes; no show público o
  app registra a presença de quem abre com conta (falha não atrapalha); no
  louvor o roteiro manda `{ nome }` ao escolher ou ao abrir com nome
  guardado, se houver `token_do_publico` no aparelho. Nome fora da escala
  ou vazio ("Só acompanhar") fica sem nome; sem corpo não mexe no nome.
  Coluna `ParticipacoesResenha.NomeNoLouvor` (ADD COLUMN só se faltar). O
  histórico traz `nomeNoLouvor` e `hinosNoLouvor` (hinos com parte no
  microfone ou solo, contados na hora pela escala); cartão, detalhe e
  cartão de compartilhar dizem "Como Ana · em 3 hinos". Os encontros
  contam no resumo ("3 encontros"). Sem conta no aparelho, o "Quem é
  você?" do roteiro oferece "Guardar este louvor na minha conta"
  (`entrar_para_guardar.dart`, tela própria por causa do teclado do
  iPhone): entra ou cria a conta e já guarda o louvor com o nome; quem
  ainda não escolheu guarda ao escolher. Louvor agendado aparece em
  Próximas sem o "Como Ana", que vem no histórico.

**Artista (conta própria, isolado por `ArtistaId`)**
- Perfil artístico com foto e perfil público; apresentações Pública ou Resenha.
- Fila musical em tempo real (SSE em `/api/tempo-real/{codigo}`, com
  atualização periódica como reserva).
- Repertórios ordenáveis formam o acervo. A setlist de cada show é montada
  na tela Montar setlist (`montar_setlist.dart`): chips dos repertórios,
  marcar músicas ou todas, busca no acervo, rodapé com duração estimada e
  horas contratadas, música avulsa (pode ficar no acervo). Adiciona no fim,
  sem repetir a mesma música (sem acento nem maiúscula). Editar: arrastar e
  remover só as que faltam; Limpar setlist com confirmação. Depois de
  montada a setlist é independente: só correções de título, cantor e tom do
  acervo são repassadas (decisão de 2026-10-13). Rotas privadas
  `/setlist/musicas`, `/setlist/avulsa`, `/setlist/ordem`, `DELETE /setlist/{itemId}`.
- Levar ao repertório (2026-10-21): a folha `adicionar_ao_repertorio.dart`
  escolhe um repertório (com "N já estão") ou cria um novo com nome
  sugerido; a tela `escolher_para_repertorio.dart` marca músicas ("Todas",
  busca a partir de 10). Rota privada `POST /api/artista/repertorios/musicas`
  (`{ repertorioId | nomeNovo, musicas }`, devolve `adicionadas` e
  `jaEstavam`): não repete música e liga as avulsas da setlist à música
  nova. Entradas: "Adicionar ao repertório" no menu "⋯" da setlist/hinos
  (todas marcadas; nome "Show · dd/mm"); na Fila, selo "Fora do acervo"
  no pedido de música e "Adicionar pedidos ao repertório" no Histórico e
  nas Memórias musicais (mais pedidos primeiro, os de fora já marcados;
  sem alôs nem cancelados; o tom preferido de quem pediu não vai). Em
  Meus repertórios, cartão "Pedidas pelo público" com as mais pedidas de
  todos os shows fora do acervo (`GET /api/artista/repertorios/pedidas-fora`).
- Setlist e hinos mostram o que está fora dos repertórios: faixa "5 músicas
  fora do repertório · Adicionar" abaixo do aviso de cifras (leva só essas)
  e um ícone na linha da música (desde a revisão das telas, chips e ícone). "Limpar setlist" também foi
  para o menu "⋯"; o Editar ficou só com arrastar e remover.
- Busca na setlist e nos hinos (a partir de 10): título ou cantor, sem
  acento; mostra "Nº 12" da achada; some no Editar.
- Setlist (desde 2026-10-13 é o centro do show, no jeito do iPhone):
  - tocar na música abre o leitor; o círculo à esquerda marca como tocada;
    deslizar para a esquerda (`flutter_slidable`) mostra Cifra (colar no app
    primeiro, link do site como reserva) e Remover (só as que faltam);
  - ponto verde/amarelo = tem ou não cifra colada; selo cinza com o número
    de pedidos daquela música;
  - aviso "X músicas sem cifra · Colar" conta a cifra colada e leva ao
    Colar e próxima (`colar_cifras.dart`);
  - selo "N pedidos novos ›" leva à aba Fila; no topo só Editar e ＋ (montar);
  - todas as cifras são buscadas ao abrir; barra "Próxima" translúcida com
    Tocar (abre o leitor se houver cifra colada, senão o link), tom e a
    música seguinte; uma única aba de cifra para links;
  - acompanha outros aparelhos pelo tempo real e a cada 30 s.
- Tocar a seguir: na fila, o pedido aceito pode ser marcado para entrar
  antes do setlist na barra Próxima. A sequência fica no servidor, na
  coluna `Apresentacoes.PedidosASeguir` (rotas privadas
  `/api/apresentacoes/{id}/pedidos-a-seguir`), para todos os aparelhos da
  banda verem a mesma. Tocar um pedido o coloca em Tocando agora e encerra
  o que estava tocando.
- O antigo modo palco foi removido em 2026-10-13: o leitor é a tela do
  palco (tela acesa, Tocar, próxima) e os pedidos ficam na aba Fila.
- Cronômetro do show (só artistas veem): horas contratadas e "intervalo
  pausa o relógio" no formulário; o relógio começa no primeiro Iniciar. Faixa
  acima das abas do show ao vivo: quanto falta, hora
  de terminar, aviso aos 30 e 10 min, "Passou X min", botão Intervalo/Voltar
  ao show. Ritmo: 3 min por música até a 3ª, depois tempo tocado (sem
  intervalo) ÷ músicas começadas; mostra quantas cabem e se a sequência sobra
  ou passa. Colunas em `Apresentacoes` (`DuracaoContratadaMinutos`,
  `IntervaloPausaRelogio`, `IniciadaEm`, `EmIntervaloDesde`,
  `SegundosEmIntervalo`, `EncerradaEm`), fora do registro público; rotas
  privadas `/api/apresentacoes/{id}/relogio` e `.../relogio/intervalo`.
  Antes de medir, usa o ritmo médio dos shows encerrados do artista; na
  setlist de show agendado, cartão com a duração estimada e a comparação
  com as horas contratadas. Pout-pourri ("Evidências / Página Virada")
  conta cada música separada por barra em todas essas contas (servidor e
  app); partes sem letra, como "24/7", não separam.
- Recarregar a página com show em andamento volta à apresentação e à aba
  onde o artista estava (guardado no aparelho).
- Leitor de cifras (`leitor_de_cifras.dart`, desenho em
  `docs/superpowers/specs/2026-10-13-leitor-de-cifras-design.md`): cifra
  colada no app, separada do link (tabela `CifrasEmTexto`, rota privada
  `PUT /api/artista/cifras/texto`; a consulta da cifra traz `texto`). Tela só
  com a cifra em JetBrains Mono (acordes em roxo, tamanho automático, pinça),
  setas sempre visíveis que só trocam de música, Tocar no meio ("Tocando ✓"),
  pedal/teclado vira a página. Tocar e Abrir cifra abrem o leitor quando há
  cifra colada; tocar na música da setlist abre o leitor. Também: controle
  "b Tom #" no topo da cifra (`controle_do_tom.dart`, o mesmo do roteiro;
  guardado por música no aparelho) e rolagem automática (0,5x, 0,75x
  e 1x a 5x, com ícones de andar e correr). Tocar ou puxar a letra não para
  a rolagem: com o dedo na tela ela espera e segue dali; só o pausar para.
  Com a pinça, linha que não cabe quebra em vez de rolar para o lado
  (`quebrar_cifra.dart`): acordes e letra quebram juntos no mesmo ponto e o
  acorde segue na sílaba; tablatura também quebra.
  O "Tom: E" da cifra colada preenche o tom vazio no acervo e na setlist;
  trocar o "Tom:" depois leva junto o tom que veio da cifra, e o tom
  escolhido à mão fica. Setlist e repertório recarregam o tom ao salvar.
  Sem internet (2026-10-13): `ClienteHttpComReserva` guarda no aparelho as
  leituras do artista (separadas por token) e responde com elas sem rede,
  inclusive ao recarregar; marcar tocada sem rede vai para uma fila que sobe
  quando a internet volta; o login só sai se o servidor recusar o token;
  faixa "Sem internet · dados salvos às HH:MM" no topo (`aviso_sem_internet.dart`).
  Pedidos e mudanças na setlist continuam exigindo rede.
  Servidor dormindo (2026-10-19): o `web/index.html` mostra "Carregando o
  aplicativo TocaEssa, aguarde…" até o `flutter-first-frame`; início e
  acesso do artista chamam `api.acordar()` (`/api/saude`, sem esperar); o
  `AvisoDeDemora` (`componentes.dart`) repete o aviso quando o QR do
  público, o painel com sessão ou o login passam de 3 s.
- Tocar e ensaiar sem show (2026-10-26, `tocar_musicas.dart`): linha
  "Tocar e ensaiar" no Acervo do Início (só com música no acervo) e botão
  ▶ Tocar em cada repertório (abre já nele). Busca sem acento sempre
  visível, chips "Todas" + repertórios (Todas não repete a mesma música;
  a busca procura no acervo inteiro); tocar na música abre o leitor, e as
  setas andam pela lista que está na tela. `SequenciaDoEnsaio`
  (`sequencia_do_palco_ensaio.dart`) não grava nada no servidor (sem
  tocada, relógio, histórico nem ritmo médio) e busca só a cifra da página
  aberta e da seguinte; o leitor troca o Tocar por "3 de 25" e diz "Fim da
  lista". Tom, pinça, rolagem, colar cifra e compartilhar continuam.
- Lógica do show compartilhada: `SequenciaDoPalco` (estado) e o mixin
  `AcoesDoPalco` (tocar, abrir e escolher cifra) servem setlist e leitor.
- Estatísticas da apresentação e retrospectiva do artista; câmera no app para
  as fotos dos cartões. O cartão usa só o bloco `retrospectiva` das
  estatísticas (`RepositorioTocaEssa.Retrospectiva.cs`), validado no
  servidor: cada pessoa conta uma vez por música (sem acento nem
  maiúscula); favorita só tocada e pedida por 2 pessoas; músicas a pedido
  contam músicas; nota exige 3 pessoas e vale o último voto de cada pessoa
  por música; alôs só dados; duração ("21h00 às 00h12 · 3h12 de show") só
  de show encerrado entre 30 min e 12 h. Horas contratadas e ritmo nunca
  entram no cartão. Limite: quem pede sem conta e muda o nome conta como
  outra pessoa.
- Cartão da retrospectiva no jeito do Strava (2026-10-13): a selfie com o
  público é a estrela; a foto do perfil não entra. Sem selfie, um convite
  por cima (fora da imagem compartilhada) lembra de tirar. Números só quando
  valorizam: tempo, músicas e pedidas pelo público (rótulo em até 2 linhas);
  público no app, atendimento e alôs não entram. A nota saiu do cartão do
  show e da resenha (2026-10-19): "4,7" sem dizer que é de 5 parecia nota
  baixa. Fecham o cartão a mais pedida e o convite para o próximo show. A
  resenha usa o mesmo visual, sem a contagem de gente no app.
- Encerrar o show sem selfie oferece tirar uma antes: a câmera abre com a
  prévia do cartão, a foto é guardada e o show é encerrado. Encerrar sem foto
  continua possível; desistir da câmera não encerra.

**Louvor com revezamento (2026-10-19)** — desenho em
`docs/superpowers/specs/2026-10-19-louvor-com-revezamento-design.md`.
- Terceiro tipo de evento, `Louvor` (fim do enum `TipoApresentacao`). Sem
  pedidos, fila, nota, alô nem Pix. Abas do artista: Escala, Hinos (a setlist)
  e Mais; ao vivo abre em Hinos.
- A cifra colada (mesma `CifrasEmTexto` das cifras, com acordes) vira
  estrofes e refrão em `LetraDoHino.Separar`. Marcadores mandam: "(Estrofe
  1)", "[Estrofe 2]", "Estrofe 3:", "1ª estrofe", "(Coro)", "Refrão:"; o que
  vem antes do primeiro não é cantado; "(Coro)" com texto define o coro e
  sem texto o repete. Sem marcadores: linhas em branco e tamanho da primeira
  estrofe. A linha "Tom:" nunca vira parte; os espaços dos acordes ficam; o
  refrão entra depois de toda estrofe (antes de um solo, inclusive).
- Partes instrumentais (`TipoDaParte.Instrumental`, com `Nome` e `Vezes`):
  "(Solo sax tenor)", "(Introdução)", "(Interlúdio)", "(Final)"; "2x" no fim
  de qualquer marcação. Não contam no placar de estrofes. "Quem toca os
  solos" (nome e instrumento, coluna `Apresentacoes.SolistasDoLouvor`, rota
  `PUT .../louvor/solistas`): cada "(Solo sax tenor)" vai para quem toca o
  instrumento (exato; senão parecido, como "sax" para "sax tenor"; "(Solo)"
  sozinho para qualquer solista), revezando, com placar de solos próprio.
  Introdução, interlúdio e final são da banda toda. Solistas também
  aparecem no "Quem é você?". Sumário "Como marcar as partes"
  em `como_marcar_hinos.dart` (editor da letra e aba Escala).
- Nada é escalado sozinho (mudança de 2026-10-19): o hino começa sem
  ninguém ("—") e o botão "Escalar automático" do hino
  (`EscalaDeCantores.EscalarHino`, `POST .../louvor/hinos/{itemId}/escalar`)
  grava quem fica com cada parte. Só o coro final é de Todos; cada estrofe
  vai, junto com o coro que vem depois dela, para quem tem menos pontos nos
  outros hinos (estrofe vale 1, coro vale 2), depois quem está há mais tempo
  sem cantar; ninguém duas estrofes seguidas; solos pelo instrumento; quem
  acabou de tocar não começa a cantar em seguida e vice-versa (inclusive na
  virada de um hino para o outro), se houver outra pessoa; introdução para um solista (qualquer
  instrumento). "Escalar todos os hinos" (`EscalarTodos`, `POST
  .../louvor/escalar`, com confirmação) faz a lista inteira na ordem e
  refaz as trocas à mão. A confirmação lista os hinos com letra, todos
  marcados (com "Todos" para marcar ou desmarcar): só os marcados são
  refeitos (`EscalarSelecionados`, corpo opcional `{ itens }`); os outros
  ficam como estão e os pontos deles contam. Colar a cifra com "(Estrofe N)" marcadas já
  escala o hino que ainda não tem ninguém (`EscalarHinosDaLetraNova`); hino
  já escalado não muda. A troca à mão continua; "Limpar" deixa
  a parte sem escala. No roteiro, parte sem escala aparece como Todos.
- "Como escalar" na aba Pessoas (`ConfiguracaoDaEscala`, coluna
  `Apresentacoes.ConfiguracaoDoLouvor`, `PUT .../louvor/configuracao`):
  "Cantores por hino" (Sem limite, 1 a 4) faz só os N de menos pontos
  revezarem em cada hino; "Todos cantam os coros" deixa todo coro com
  Todos. Vale para os próximos "Escalar"; a escala feita não muda sozinha.
- Aba Escala (`escala_do_louvor.dart`) em duas partes: "Por hino" (no topo,
  resumo "2 hinos · 1 sem letra · 1 parte sem escala" e "Pontos: de 3 a 36",
  fechado; um toque abre uma barra de pontos por cantor e os solos; cartão fechado por hino com a ordem, tom, resumo
  "João · Ana · solo José · 1 sem escala", uma faixa com um pedaço por parte
  na cor de quem canta, "Agora" no último tocado e os já tocados apagados;
  tocar abre as partes, com o nome na cor da pessoa, e o "Escalar
  automático"; o filtro por pessoa, com a bolinha da cor, destaca as partes
  de alguém) e "Pessoas" (cantores e solistas com a bolinha da cor, "Como
  escalar" e "Como marcar as partes"). A escolha à mão mostra os pontos (ou
  solos) de cada nome e os botões "Todos cantam"/"Banda toda", "Salvar" e
  "Deixar sem escala".
- Cor de cada pessoa (`corDaPessoa` em `trechos_do_louvor.dart`), na ordem
  dos participantes (cantores, depois quem só toca): as 12 cores fixas e,
  da 13ª em diante, uma cor gerada pelo ângulo de ouro, sem limite e igual
  em todos os aparelhos (sem sorteio), pulando o amarelo. Desde 2026-10-21
  quem só toca tem cor própria; as partes de solo continuam amarelas na
  faixa e na cifra. Solo sem acordes escritos mostra "instrumental"
  também no leitor.
- Cantores e escolhas à mão em JSON nas colunas `Apresentacoes.CantoresDoLouvor`
  e `EscolhasDoLouvor`. Rotas privadas `/api/apresentacoes/{id}/louvor`
  (`/cantores`, `/partes`); pública `GET /api/publico/apresentacoes/{codigo}/roteiro`,
  só para Louvor. O hino de agora é o último tocado na ordem da setlist.
- Pelo código, cada participante vê o roteiro (`roteiro_do_louvor.dart`):
  "Quem é você?" (um botão por pessoa na cor da sua faixa) guardado no
  aparelho, segue o Tocar do artista com o aviso "Agora: <hino>", tela
  acesa. O topo do hino diz "Suas partes: Estrofe 1 e Refrão"; a barra de
  baixo mostra "Depois: <hino>" e "sua vez: ..." no próximo hino.
- Cifra no jeito de teleprompter (`cifra_do_palco.dart`, tirada do leitor):
  cada parte tem uma faixa com o nome de quem canta, presa no topo enquanto
  a parte passa (`PinnedHeaderSliver` em `SliverMainAxisGroup`); uma cor por
  cantor (`trechos_do_louvor.dart`); a vez da pessoa em destaque e "você é o
  próximo" na parte anterior; o refrão escrito de novo. Pinça, rolagem
  automática e toque no acorde valem no leitor e no roteiro. No roteiro, a
  nota no topo ("Mostrar acordes", guardado no aparelho) mostra a cifra e o
  controle "b Tom A (+2) #" por hino (b e # porque as fontes do app não têm
  ♭/♯; tocar no tom mudado volta ao original); "Agora" fica na linha do título;
  sem ele, só a letra. No leitor do artista, "Quem sou eu" destaca as partes
  dele.
- No louvor as telas da setlist, leitor e montar falam de hinos e letras
  (`Vocabulario` em `dominio/vocabulario.dart`).
- Coral (2026-10-23): o coral canta junto de quem tem a parte no
  microfone. Cada parte pode ter o coral ("Coral canta junto" na escolha
  à mão; rota privada `PUT .../louvor/coral`, coluna
  `Apresentacoes.CoralDoLouvor`, separada das escolhas para que escalar de
  novo não apague) e "Coral canta nos refrões" (`CoralNosRefroes` na
  configuração) põe o coral em todo refrão dos hinos escalados. O roteiro
  público ganhou `coral` em cada parte (autorizado). As pessoas do coral
  são cantores cadastrados (fora do automático, se não forem ao
  microfone) e escolhem o próprio nome: nas partes do coral (as marcadas e
  as de Todos já escaladas) quem não está no microfone vê "SUA VEZ NO
  CORAL", o resto fica apagado, "coral entra" e "depois, para" avisam, e
  o topo diz "No coral: todos os refrões e Estrofe 2". Parte sem escala não
  é do coral. Quem só toca não entra no coral.
  A faixa diz "ANA + CORAL · SUA VEZ" também para quem canta no coral (o
  "+ CORAL" já explica; o texto longo cortava com o aviso).
- Coral em algumas linhas (2026-10-23): na letra, `(Coral)` … `(Fim do
  coral)` (também `[Coral]`, `Coral:`, `(Coral fim)`, `(Fim coral)`; sem
  o fim, vai até o fim da parte) marcam só as linhas do coral dentro de
  uma parte. Só no app (`dominio/coral_na_letra.dart`): o servidor mantém
  essas linhas no texto da parte (teste `MarcasDoCoralFicamDentroDaParte`).
  A parte continua uma só na escala e nos pontos; no roteiro e no leitor
  vira um trecho por pedaço ("JOÃO", "JOÃO + CORAL"), sem as linhas de
  marca, com os avisos de entrar e parar; o topo diz "parte da Estrofe 3".
  Explicado em "Como marcar as partes". Letra sem "(Estrofe N)" separa
  pelo tamanho e as linhas de marca entram na conta.
- Ícones dos papéis (2026-10-23): em Meus hinos, uma linha por papel com
  ícone do app (microfone na cor da pessoa, coral, solo) e o tom à
  direita; o topo do hino usa os mesmos ícones em "Suas partes", "No
  coral" e "Você toca" (solos saíram de "Suas partes"). Ícones, não
  emoji: o emoji baixaria uma fonte na internet fraca do encontro.
- Fica para depois: roteiro sem internet.

### Revisão das telas (2026-10-21)

Feita com capturas reais (Playwright, largura do iPhone) e prints do
proprietário:
- Louvor sem a faixa só com "Iniciar": Iniciar/Encerrar fica na barra do
  topo; nos shows com pedidos a faixa "Recebendo pedidos | Encerrar" fica.
  A foto do cabeçalho fica escura em toda a faixa do texto (o pedestal
  cortava as letras) e a aba Mais usa a foto só no topo.
- Início do artista: sem seta de voltar ("Tela inicial" no menu da conta);
  seção Acervo com Meus repertórios e o resumo; show agendado com data
  passada vai para o fim de Próximas com "Já passou".
- Escala: "Escalar todos" no cartão do resumo; na aba Pessoas o × só
  aparece no Editar, números como "6 pts" e "2 solos", sem parágrafos de
  explicação. Arquivo dividido em `escala_do_louvor_{hinos,pessoas,dialogos}.dart`.
  "Quem é você?" do leitor com a cor de cada pessoa.
- Busca única: `combinaComBusca` (domínio) e `CampoDeBusca` (componentes)
  em setlist, fila, montar e escolha; a da Fila passou a ignorar acento.
- Topo da setlist: avisos em chips numa faixa só (pedidos novos, sem
  cifra, fora do repertório), progresso numa frase só e ícone discreto de
  fora do repertório na linha.

### Compartilhar e limpar escala (2026-10-21)

- Compartilhar no leitor (`compartilhar_link.dart`: janela do aparelho
  pelo `navigator.share`; sem ela, copia o link). No louvor, manda o link do
  roteiro aberto no hino (`#/publico/CODIGO?hino=itemId`): quem recebe
  responde "Quem é você?" e cai no hino, com acordes ligados se não
  escolheu escondê-los. Fora do louvor, manda `#/cifra/{codigo}`
  (`cifra_compartilhada.dart`, sem conta, com tom e pinça). O código é o id
  da cifra colada (`CifrasEmTexto.Id`, não muda ao corrigir: link vivo);
  rotas `GET /api/artista/cifras/compartilhar` (privada) e
  `GET /api/publico/cifras/{codigo}` (pública, nova). O leitor busca o
  código ao abrir a página: no iPhone o share só abre direto no toque.
- Quem fica fora do automático: na aba Pessoas, tocar no nome (cantor ou
  solista) põe "fora" sem tirar da lista; `ConfiguracaoDaEscala.CantoresFora`
  e `SolistasFora` (JSON na configuração do louvor, sem coluna nova). Quem
  canta e toca pode sair só de um dos dois. A escala feita não muda sozinha.
- "Limpar escala" no resumo da Escala (com confirmação): todas as partes
  ficam sem ninguém, inclusive as trocadas à mão; rota
  `DELETE /api/apresentacoes/{id}/louvor/escala`.

### Letra na TV (2026-10-29)

Desenho em `docs/superpowers/specs/2026-10-29-letra-na-tv-design.md` e
`...-letra-na-tv-extras-design.md`.
- A TV abre `tocaessaapp.onrender.com/tv` (o servidor redireciona para
  `/#/tv`, `tela_da_tv.dart`), mostra um código de 4 letras e fica presa à
  conta pelo "Conectar TV" do Mais da resenha (`letra_na_tv_do_artista.dart`).
  Tabela `TelasDaTv` (só TVs conectadas); código e conteúdo ficam na memória.
- O servidor não entende de letra: o celular do dono manda o texto (`PUT
  /api/artista/telas/conteudo`) e a linha (`.../conteudo/linha`, 409 sem
  conteúdo: o celular manda tudo de novo). Tempo real próprio da TV
  (`/api/publico/telas/{id}/tempo-real`, evento `linha:versão:linha`).
- `LetraDaTela` (`dominio/letra_da_tela.dart`) numera só as linhas de letra;
  roda igual no celular e na TV. A seta fixa no terço de cima da
  `CifraDoPalco` (`aoLerALinha`) avisa a linha que passa nela; o
  `TransmissorDaLetra` segura o ritmo. Chave "Letra na TV" no aparelho.
- Extras: "A seguir · pedida por Carla", QR da resenha, intervalo 20 s depois
  da última linha (A seguir, QR e fotos dos stories), velocidade da rolagem
  por música, louvor com o nome de quem canta no selo (sem o "sua vez").
  Karaokê na TV ficou de fora (a TV está no YouTube na vez de cada um).
- Setas do controle da TV mudam o tamanho da letra (60% a 160%, guardado na
  TV, `tamanho_da_letra_na_tv.dart`).

- Comando da TV (`docs/superpowers/specs/2026-10-29-comando-da-tv-design.md`):
  o dono passa a linha da TV a um ajudante sem conta (link `#/comando/<token>`,
  `comando_do_ajudante.dart`); com ajudante, a linha do dono é ignorada e a
  música continua vindo dele; Retomar desfaz o link. Comando só na memória.

### Novidades do app (2026-10-29)

`dominio/novidades.dart` guarda a lista (mais nova primeiro: Novo, Melhoria,
Correção). Só o artista vê: aviso no topo do início do painel enquanto há
novidade não vista (`novidades_vistas_ate` no aparelho) e Novidades no menu da
conta. **A cada push com algo que a pessoa nota, acrescentar a entrada no
mesmo push**; correção técnica invisível fica de fora.

### Músicos convidados para o evento da noite (2026-10-29)

Desenho em `docs/superpowers/specs/2026-10-29-evento-compartilhado-design.md`.
Duas portas: músicos pelo link de convite, público pelo código como sempre.
- Só resenha e louvor (karaokê: todos são público). Tabelas
  `MusicosDaApresentacao` e `ConvitesDaApresentacao`; link novo desfaz o
  anterior; evento encerrado não aceita nem aparece.
- O acesso é ao evento, não à conta. `ObterApresentacaoDoArtista` continua só
  do dono; `ObterApresentacaoDaNoite` (dono ou convidado) vale só para ler a
  setlist, a fila, os pedidos a seguir e o louvor, marcar tocada e mudar o
  pedido para tocando/finalizado/aceito (recusar é do dono). Cifra do dono
  por `GET /api/apresentacoes/{id}/cifras`, só de músicas da setlist ou dos
  pedidos daquele evento.
- App: Mais → Músicos da noite (`musicos_da_noite_do_dono.dart`), link
  `#/convite/<código>` (`convite_do_musico.dart`; sem conta guarda
  `convite_pendente`), Convites no início do painel (`convites_do_musico.dart`,
  aparece mesmo sem perfil) e a noite do músico (`noite_do_musico.dart`) com
  `SequenciaDoConvidado` (lê a cifra pelo evento, `colaCifra` falso).

### Lições do iPhone/Safari

O proprietário testa e usa no iPhone. Testes de widget não pegam:
- Safari só abre aba nova como resposta direta a um toque: abrir a aba antes
  de qualquer `await` (`prepararAbertura`).
- Área de transferência só é lida com o app em primeiro plano e pode pedir
  confirmação ("Colar").
- Gestos de arrastar precisaram de ajuste específico para o iPhone.
- Manter a tela acesa (Wake Lock) é solto quando a aba fica escondida e
  precisa ser pedido de novo ao voltar (`tela_acesa_web.dart`).
- A aba de cifra aberta em branco antes da resposta do servidor podia ficar
  branca no palco: cifra já buscada abre direto no toque; a espera mostra
  aviso escuro (`pagina_de_espera_da_cifra.dart`).
- Site não instalado pode ter os dados do aparelho apagados pelo Safari
  depois de dias sem uso; instalado na Tela de Início, não. "Instalar no
  celular" no grupo Conta dos perfis do artista e do público
  (`instalar_app.dart`): some quando aberto pelo ícone; no Chrome/Android usa
  o `beforeinstallprompt` guardado no `index.html`; no iPhone (sem instalação
  automática) mostra o passo a passo do Compartilhar.

### Investigações registradas

- Cifra Club bloqueia acesso automático (Akamai, 403). Ler resultados do
  Google também não é viável. Detalhes no Banco de ideias.

## Decisões de arquitetura registradas

- Minimal APIs sem controllers: reduz boilerplate e mantém o código próximo ao domínio.
- Repositório em arquivos parciais: evita arquivos gigantes sem introduzir camadas desnecessárias.
- Testes com banco real (SQLite): garante que migrações e queries funcionam de verdade.
- ArtistaId gravado pelo servidor, nunca pelo cliente: evita spoofing de propriedade.
- Rotas públicas por código: QR code compartilhável não expira e não exige login.

## Comandos úteis

```powershell
# Executar localmente (API + Flutter + Chrome)
.\rodar.ps1

# Verificar antes de commitar
dotnet build TocaEssaApp.sln --no-restore
dotnet test TocaEssaApp.sln --no-build
cd cliente; flutter analyze; flutter test

# Rodar testes específicos
dotnet test TocaEssaApp.sln --filter "FullyQualifiedName~NomeDaClasseTestes"

# Ver estado do git
git status
git log --oneline -15
```

## Riscos conhecidos

| Risco | Mitigação |
|-------|----------|
| Deploy quebra migração do banco de produção | Migração idempotente; não apagar banco do Render; smoke test após deploy |
| Push acidental da `main` com código sem testes | Verificação completa antes de qualquer push |
| `.vs/` entrar no repositório | Adicionado ao `.gitignore` |
| Token de artista exposto em log | Nenhum log de token; erros genéricos sem detalhes de sessão |

## Estrutura de pastas relevante

```
TocaEssaApp/
├── CLAUDE.md                          → regras do projeto
├── PLANO_IMPLEMENTACAO.md             → roadmap de produto
├── rodar.ps1                          → script para rodar localmente
├── render.yaml                        → configuração de deploy
├── servidor/TocaEssaApp.Api/          → API .NET
├── cliente/                           → Flutter Web/PWA
├── testes/TocaEssaApp.Testes/         → testes xUnit
└── docs/
    ├── DEPLOY_RENDER.md               → deploy e smoke test
    ├── claude/                        → contexto para Claude Code
    └── superpowers/
        ├── plans/                     → planos de implementação detalhados
        └── specs/                     → especificações de design
```
