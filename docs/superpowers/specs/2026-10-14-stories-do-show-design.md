# Stories do show — desenho

Aprovado pelo proprietário em 2026-10-14.

Princípio: quem está no show grava, e o vídeo ou a foto vira **story do
show**: todo mundo com o código assiste, como stories. O artista assiste
depois para ter feedback e salva no celular o que gostar. Sem curtidas nem
comentários.

Decisões do proprietário: envio **sem conta**; **vídeos e fotos**; o
público vê **desde a criação do show até 24 h depois do fim** (cada story
no máximo 7 dias); o artista guarda **7 dias**; o **artista também posta**;
envio **aparece na hora**, com **denúncia** do público e apagar do artista.

## Para o público

```
 Noite Acústica · Duo Aurora
 ─────────────────────────────
  (◉)(◉)(◉)(◉)  →   stories do show
  [ 🎥 Enviar vídeo ou foto ]
    Todo mundo do show vê por 24 h.
```

- Fileira de bolinhas no topo da tela pública (rota por código, sem login);
  bolinha com anel roxo = ainda não vista neste aparelho.
- Tocar abre em tela cheia, no jeito dos stories: barrinhas de progresso no
  topo, passa sozinho (foto 5 s, vídeo até o fim), toque à direita avança,
  à esquerda volta, arrastar para baixo fecha. Nome de quem mandou e hora.
- **Denunciar** no menu do story: com 3 denúncias de aparelhos diferentes
  o story some para o público até o artista olhar.
- Visível para o público desde a criação do show até 24 h depois do fim;
  cada story no máximo 7 dias (quando o arquivo some).

### Enviar

- Botão "Enviar vídeo ou foto" na mesma tela.
- Abre a câmera ou a galeria do celular (vídeo até 60 s, ou foto).
- Nome opcional ("Ana, mesa 4"), lembrado no aparelho como nos pedidos.
- Barra de progresso; se a internet cair, **Tentar de novo** sem escolher o
  arquivo outra vez.
- Janela de envio: show **agendado**, **em andamento** ou **encerrado há até**
  **24 h** (o que se posta antes também é sobre o evento; dá para mandar
  em casa, no Wi-Fi). Revisão de 2026-10-14.
- Aviso antes do primeiro envio: "Todo mundo do show vai ver até 24 h depois
  do fim, e o artista guarda por 7 dias. Não envie quem não quer
  aparecer."

## Para o artista

- **Posta nos stories** pela aba Mais do show ("Postar nos stories do show"):
  aparece para o público com o nome artístico e destaque, fora do limite
  por aparelho e sem sumir por denúncia (revisão de 2026-10-14: o público
  vê e se anima a postar também). Rotas privadas
  `POST /api/apresentacoes/{id}/envios` e `.../envios/{envioId}/confirmar`.

```
 Stories do show · 12          expiram em 6 dias
 ┌──────┐ ┌──────┐ ┌──────┐
 │ ▶ 0:42│ │ foto │ │ ▶ 0:15│
 │ Ana   │ │ Leo  │ │ —     │
 └──────┘ └──────┘ └──────┘
```

- Nova seção na apresentação (ao vivo e encerrada): grade com fotos e
  vídeos, nome de quem mandou (ou "—") e hora.
- Tocar abre em tela cheia: o vídeo toca no próprio app; a foto amplia.
- **Salvar no celular**: compartilhar do sistema; no iPhone, "Salvar vídeo"
  / "Salvar imagem" vai para o app Fotos.
- **Apagar** na hora o que não quiser: some para todos.
- Story escondido por denúncia aparece marcado ("Escondido por denúncias");
  o artista **Mostra de novo** ou **Apaga**.
- Ao vivo, o artista vê os stories pela mesma tela do público, com Apagar
  à mão, sem sair do show.
- Cada item mostra quanto falta para expirar; expirado some da lista.
- Selo "N novos" na apresentação quando chegar envio desde a última visita.

## Como o arquivo viaja (sem pesar no Render)

```
 celular ──1. pede envio──▶ API (Render) ──grava registro──▶ Neon
 celular ◀─2. URL assinada─┘
 celular ──3. PUT direto do arquivo──────────────────────▶ R2
 celular ──4. confirma────▶ API ──confere tamanho no R2──▶ marca pronto
 artista ──5. lista───────▶ API ──URLs assinadas de leitura (1 h)
 artista ──6. assiste/baixa direto──────────────────────▶ R2
```

- O vídeo **nunca passa pelo servidor**: o plano grátis do Render tem pouca
  memória e banda; o R2 não cobra saída.
- URL de envio vale 15 min e já leva tipo e tamanho declarados na
  assinatura; o R2 recusa arquivo diferente do declarado.
- Na confirmação a API consulta o objeto no R2 (tamanho e tipo); se não
  bater ou passar do limite, apaga e recusa.
- Envio não confirmado não aparece para o artista.

## Dados

Tabela nova `EnviosDoPublico` (criada só se não existir; migração
idempotente, nada existente muda):

| Campo | |
|---|---|
| `Id` | Guid |
| `ApresentacaoId`, `ArtistaId` | do show pelo código; nunca do cliente |
| `Chave` | `envios/{apresentacaoId}/{id}.{mp4,mov,jpg,png,heic}` no R2 |
| `Tipo` | Video ou Foto |
| `TipoDeConteudo`, `Tamanho` | declarados e conferidos na confirmação |
| `Nome` | opcional, até 40 caracteres |
| `IdentificadorDoAparelho` | aleatório, guardado no aparelho (limites) |
| `CriadoEm`, `ExpiraEm` | `ExpiraEm = CriadoEm + 7 dias` (artista) |
| `Confirmado` | só confirmados aparecem |
| `Escondido` | 3 denúncias escondem do público; o artista desfaz |

Tabela nova `DenunciasDeEnvio` (`EnvioId`, `IdentificadorDoAparelho`,
`CriadaEm`; um aparelho denuncia uma vez).

Para o público, o story vale desde a criação do show até
`EncerradaEm + 24 h` (campo que o show já tem).

## Rotas

Públicas (novas; nenhuma rota pública existente muda):

- `POST /api/publico/apresentacoes/{codigo}/envios`
  `{ tipo, tipoDeConteudo, tamanho, nome?, aparelho }` →
  `{ id, urlDeEnvio, cabecalhos }`
- `POST /api/publico/apresentacoes/{codigo}/envios/{id}/confirmar`
- `GET /api/publico/apresentacoes/{codigo}/stories` → stories confirmados,
  não escondidos, dentro da janela, com URL assinada de leitura (1 h); sem
  o identificador do aparelho de ninguém
- `POST /api/publico/apresentacoes/{codigo}/stories/{id}/denuncia`
  `{ aparelho }`

Privadas (token do artista dono; de outro artista responde 404):

- `GET /api/apresentacoes/{id}/envios` → todos (inclusive escondidos) com URL
  assinada de leitura
- `DELETE /api/apresentacoes/{id}/envios/{envioId}` → apaga no R2 e no banco
- `POST /api/apresentacoes/{id}/envios/{envioId}/mostrar` → desfaz o
  esconder por denúncia

O aviso de "stories novos" usa a atualização em tempo real que a tela
pública já tem; sem tempo real, a lista é buscada ao abrir e a cada minuto.

## Limites contra abuso (sem conta)

- Vídeo até 100 MB e 60 s (duração conferida no aparelho; o servidor
  garante o tamanho). Foto até 15 MB.
- Tipos aceitos: `video/mp4`, `video/quicktime`, `image/jpeg`, `image/png`,
  `image/heic`.
- Por aparelho: 10 envios por show. Por show: 300 envios ou 3 GB.
- Fora da janela (encerrado há mais de 24 h): recusado.
- Público vê na hora; 3 denúncias escondem; o artista apaga com um toque;
  some para o público 24 h após o show e para o artista em 7 dias.
- Risco aceito pelo proprietário: entre o envio e a denúncia ou o apagar,
  um conteúdo impróprio pode ficar visível para quem está no show.

## Expiração

- A lista ignora `ExpiraEm` vencido; a API apaga esses registros e objetos
  quando o artista abre a lista (sem tarefa agendada).
- Regra de ciclo de vida no R2 apaga `envios/` com mais de 7 dias, como
  rede de segurança mesmo se ninguém abrir a lista.

## Ações do proprietário no painel da Cloudflare (passo a passo à parte)

1. **CORS** no bucket: permitir `PUT` e `GET` vindos de
   `https://tocaessaapp.onrender.com` (envio pelo navegador, fotos e
   download para salvar).
2. **Ciclo de vida**: apagar objetos com prefixo `envios/` após 7 dias.

## Sem R2 (local e testes)

Mesma interface de armazenamento com uma versão em pasta local: a "URL de
envio" aponta para uma rota da própria API que só existe fora de produção.
Os testes usam o repositório real em SQLite e essa versão local.

## Custo e capacidade

- R2 grátis: 10 GB guardados, saída sem custo (o público assistindo não
  custa banda). Show com 20 vídeos de ~40 MB ≈ 800 MB; com 7 dias de
  validade cabem vários shows por semana. Acima disso, ~US$ 0,015 por
  GB/mês. Leituras: 10 milhões por mês grátis; 100 pessoas vendo 20 stories
  são 2 mil.
- Vídeo de 40 MB no 4G do bar demora para carregar para quem assiste: o
  story mostra carregando e permite pular.
- Neon: só os registros (alguns KB por show).

## Limitações conhecidas

- iPhone grava em HEVC: toca no iPhone/Safari; alguns Androids podem não
  reproduzir no app (o download funciona).
- Sem compressão no navegador; por isso o limite de 60 s.
- Salvar vídeo grande no iPhone carrega o arquivo na memória antes do
  compartilhar; se falhar, há **Abrir** (baixa para o app Arquivos).
- O primeiro envio depois de 15 min sem uso espera o Render acordar
  (~30 s).

## Fora (para simplificar)

Curtidas, comentários, respostas, edição (texto, filtros), guardar além de
7 dias no app (salvar no celular é o "guardar"), miniatura gerada no
servidor, envio pela conta do público, stories fora de um show.

## Ordem de entrega

1. Servidor: tabelas, armazenamento (R2 e local), rotas, limites, denúncia,
   testes de segurança (dono, 404 para outro artista, janela, limites,
   rotas públicas sem token, lista pública sem dado do aparelho).
2. Público: enviar (seleção, progresso, tentar de novo, aviso).
3. Público: fileira de stories e tela cheia (progresso, avançar, voltar,
   denunciar).
4. Artista: galeria, tela cheia, salvar, apagar, mostrar de novo,
   expiração, selo de novos.
5. Proprietário configura CORS e ciclo de vida no R2; teste no iPhone.
