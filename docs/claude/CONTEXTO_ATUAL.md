# TocaEssaApp — Contexto atual

> Atualizado em: 2026-10-19

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
  cifra colada; tocar na música da setlist abre o leitor. Também: −/+ meio
  tom (guardado por música no aparelho) e rolagem automática (0,5x, 0,75x
  e 1x a 5x).
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
  grava quem fica com cada parte. Só o coro final é de Todos; estrofes e
  coros do meio vão para quem tem menos pontos nos outros hinos (cada parte
  cantada vale 1), depois quem está há mais tempo sem cantar; ninguém duas
  seguidas; solos pelo instrumento. A troca à mão continua; "Limpar" deixa
  a parte sem escala. No roteiro, parte sem escala aparece como Todos.
- Aba Escala (`escala_do_louvor.dart`) em duas partes: "Por hino" (cartão
  fechado por hino com a ordem, tom, resumo "João · Ana · solo José · 1 sem
  escala", uma bolinha por parte na cor de quem canta, "Agora" no último
  tocado e os já tocados apagados; tocar abre as partes e o "Escalar
  automático"; "Ver por pessoa" destaca as partes de alguém) e "Pessoas"
  (cantores, solistas e "Como marcar as partes").
- Cantores e escolhas à mão em JSON nas colunas `Apresentacoes.CantoresDoLouvor`
  e `EscolhasDoLouvor`. Rotas privadas `/api/apresentacoes/{id}/louvor`
  (`/cantores`, `/partes`); pública `GET /api/publico/apresentacoes/{codigo}/roteiro`,
  só para Louvor. O hino de agora é o último tocado na ordem da setlist.
- Pelo código, cada participante vê o roteiro (`roteiro_do_louvor.dart`):
  "Quem é você?" guardado no aparelho, segue o Tocar do artista, tela acesa.
- Cifra no jeito de teleprompter (`cifra_do_palco.dart`, tirada do leitor):
  cada parte tem uma faixa com o nome de quem canta, presa no topo enquanto
  a parte passa (`PinnedHeaderSliver` em `SliverMainAxisGroup`); uma cor por
  cantor (`trechos_do_louvor.dart`); a vez da pessoa em destaque e "você é o
  próximo" na parte anterior; o refrão escrito de novo. Pinça, rolagem
  automática e toque no acorde valem no leitor e no roteiro. No roteiro,
  "Acordes" (guardado no aparelho) mostra a cifra e o −/+ meio tom por hino;
  sem ele, só a letra. No leitor do artista, "Quem sou eu" destaca as partes
  dele.
- No louvor as telas da setlist, leitor e montar falam de hinos e letras
  (`Vocabulario` em `dominio/vocabulario.dart`).
- Fica para depois: roteiro sem internet.

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
