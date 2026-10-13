# TocaEssaApp — Contexto atual

> Atualizado em: 2026-10-13

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
- Cifras por música (link salvo por conta). Na setlist:
  - todas as cifras são buscadas ao abrir, para abrir na hora no palco;
  - barra fixa "Próxima" com Tocar (abre a cifra e marca como tocada), tom e
    a música seguinte;
  - aviso "X músicas sem cifra" com Resolver em sequência (Pesquisar na web e
    Colar e próxima); ícone de cifra em amarelo quando falta;
  - uma única aba de cifra: cada cifra nova fecha a anterior.
- Tocar a seguir: na fila, o pedido aceito pode ser marcado para entrar
  antes do setlist na barra Próxima. A sequência fica no servidor, na
  coluna `Apresentacoes.PedidosASeguir` (rotas privadas
  `/api/apresentacoes/{id}/pedidos-a-seguir`), para todos os aparelhos da
  banda verem a mesma. Tocar um pedido o coloca em Tocando agora e encerra
  o que estava tocando.
- Modo palco (botão no topo da setlist): tela única com a música atual em
  letra grande, a barra Próxima, alôs, pedidos novos (aceitar/recusar) e
  aceitos (tocar a seguir); tempo real e tela sempre acesa (Wake Lock).
  Acompanha outros aparelhos: a cada aviso recarrega setlist, pedidos e
  sequência; a música começada pelo colega vira Tocando agora (cifra pelo
  botão Abrir cifra) e o Desfazer local some.
- Cronômetro do show (só artistas veem): horas contratadas e "intervalo
  pausa o relógio" no formulário; o relógio começa no primeiro Iniciar. Faixa
  acima das abas do show ao vivo e no alto do modo palco: quanto falta, hora
  de terminar, aviso aos 30 e 10 min, "Passou X min", botão Intervalo/Voltar
  ao show. Ritmo: 3 min por música até a 3ª, depois tempo tocado (sem
  intervalo) ÷ músicas começadas; mostra quantas cabem e se a sequência sobra
  ou passa. Colunas em `Apresentacoes` (`DuracaoContratadaMinutos`,
  `IntervaloPausaRelogio`, `IniciadaEm`, `EmIntervaloDesde`,
  `SegundosEmIntervalo`, `EncerradaEm`), fora do registro público; rotas
  privadas `/api/apresentacoes/{id}/relogio` e `.../relogio/intervalo`.
  Antes de medir, usa o ritmo médio dos shows encerrados do artista; na
  setlist de show agendado, cartão com a duração estimada e a comparação
  com as horas contratadas.
- Recarregar a página com show em andamento volta à apresentação e à aba
  onde o artista estava (guardado no aparelho).
- Leitor de cifras (`leitor_de_cifras.dart`, desenho em
  `docs/superpowers/specs/2026-10-13-leitor-de-cifras-design.md`): cifra
  colada no app, separada do link (tabela `CifrasEmTexto`, rota privada
  `PUT /api/artista/cifras/texto`; a consulta da cifra traz `texto`). Tela só
  com a cifra em JetBrains Mono (acordes em roxo, tamanho automático, pinça),
  setas sempre visíveis que só trocam de música, Tocar no meio ("Tocando ✓"),
  pedal/teclado vira a página. Tocar e Abrir cifra abrem o leitor quando há
  cifra colada; botão Leitor no modo palco e na setlist. Etapa 2 (sem
  internet) ainda não feita.
- Lógica do show compartilhada: `SequenciaDoPalco` (estado) e o mixin
  `AcoesDoPalco` (tocar, abrir e escolher cifra) servem setlist e modo palco.
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
