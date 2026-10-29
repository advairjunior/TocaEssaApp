# Músicos convidados para o evento da noite

Pedido do proprietário em 2026-10-29. Cenário dele: "Hoje vamos fazer uma
resenha, então eu crio o evento Resenha House e convido meus amigos músicos
para entrar **nesse evento** e ver as músicas e cifras que eu preparei. É
acesso ao evento da noite." Veio junto com o relato da cantata de
2026-10-24, em que ninguém tinha conta e todo mundo se perdia do link.

## Duas portas para o mesmo evento

- **Músicos:** pelo link de convite novo, que o dono manda para os amigos
  que vão tocar e cantar.
- **Público:** pelo código do evento, como hoje (QR, link público, conta do
  público). Nada muda para quem pede música.

## Decisões do proprietário

1. **Entrada por convite**, para um evento só.
2. **O acesso é ao evento da noite, não à conta.** O convidado vê a setlist
   daquele evento e abre as cifras que o dono preparou para ela. Não vê o
   acervo, os repertórios, os outros eventos, as estatísticas, o Pix nem o
   perfil do dono.
3. **As cifras são as do dono.** O convidado lê; não corrige.
4. **Vale para a resenha e para o louvor.** No louvor, o convidado vê o
   roteiro com as letras e cifras e a escala de quem canta.
5. **Karaokê fica de fora.** Na noite de karaokê todo mundo canta, então
   não existe a separação entre artista e público: não há convite de
   músico. Quem quiser participar entra como todos, pelo link público e
   pela conta do público (como já é: cada um transmite do próprio celular).

## O que o convidado faz no evento

Ele recebe só o que precisa para tocar junto naquela noite:

| Pode | Fica só com o dono |
| --- | --- |
| Ver a setlist e a fila de pedidos | Montar, reordenar e limpar a setlist |
| Abrir o leitor com as cifras do dono (as músicas da setlist e as pedidas) | Corrigir ou colar cifra |
| Mudar o tom no próprio celular (fica guardado só nele) | Configurar, encerrar e apagar o evento |
| Tocar: marcar como tocada (a setlist do dono anda junto) | Escala do louvor, cantores e partes |
| Ligar a Letra na TV no próprio celular | Cronômetro, estatísticas, stories e retrospectiva |
| | Convidar e tirar músicos |

O "Tocar" fica com o convidado porque, na roda, quem puxa a música é quem
marca. Se o dono preferir que só ele marque, basta tirar essa linha da
tabela: a regra fica num lugar só.

## Como funciona

- **Convidar:** no evento (resenha ou louvor), **Mais → Músicos da noite →
  Convidar músico** gera o link `…/#/convite/<código>` para mandar no
  WhatsApp. Gerar outro desfaz o anterior, para um link que vazou não
  continuar aceitando gente.
- **Aceitar:** quem abre o link entra na conta de artista (ou cria uma) e
  volta ao convite: "Advair convidou você para Resenha House" → **Entrar no
  evento**. O dono não se convida; aceitar duas vezes não duplica.
- **No painel do convidado**, o evento aparece numa seção separada,
  **Convites**, com "de Advair". Ao abrir, ele vê a versão do evento para
  músico: setlist, fila e leitor, sem as ações da coluna do dono.
- **Tirar e sair:** em Músicos da noite o dono vê quem entrou e pode tirar;
  o convidado tem **Sair do evento**. Encerrado o evento, ele some da seção
  Convites do convidado; a memória da noite continua sendo do dono.
- **O público não muda:** a página pública, o perfil e o Pix continuam do
  dono. Mostrar os nomes dos músicos na página pública fica para depois (é
  mudança de rota pública).

## Servidor

- **Tabelas novas** (`CREATE TABLE IF NOT EXISTS`; nada apagado nem
  renumerado):
  - `MusicosDaApresentacao` (ApresentacaoId, ArtistaId, EntrouEm), com chave
    nas duas colunas.
  - `ConvitesDaApresentacao` (ApresentacaoId como chave, Codigo, CriadoEm).
- **Autorização por lista do que é permitido:** `ObterApresentacaoDoArtista`
  continua aceitando só o dono, então todas as rotas de hoje seguem fechadas
  para o convidado sem mexer nelas. Nasce
  `ObterApresentacaoDaNoite(token, id)`, que aceita o dono ou um convidado
  de evento aberto, de resenha ou louvor. Ela é usada só nas leituras e no
  marcar como tocada da tabela acima. Esses métodos passam a usar
  `apresentacao.ArtistaId` (o dono) onde hoje filtram por `conta.Id`, para
  o convidado enxergar a mesma setlist.
- **Cifras do evento:** rota nova
  `GET /api/apresentacoes/{id}/cifras?musica=&artista=`. Ela devolve a cifra
  colada do dono só se a música está na setlist ou nos pedidos daquele
  evento. Assim o convidado não consegue ler o acervo inteiro adivinhando
  títulos.
- **Rotas novas** (privadas, conta pelo token):
  - `POST /api/apresentacoes/{id}/convite` (só o dono): devolve o código.
  - `GET /api/apresentacoes/{id}/musicos` (dono): quem entrou.
  - `DELETE /api/apresentacoes/{id}/musicos/{artistaId}`: o dono tira
    alguém, ou o convidado sai (o próprio id).
  - `GET /api/convites/{codigo}`: nome do evento e do dono, para a tela do
    convite.
  - `POST /api/convites/{codigo}`: entra no evento.
  - `GET /api/convites`: os eventos em que a conta é convidada.
- **Erros:** convite de karaokê, de evento encerrado ou código trocado
  responde "Convite não encontrado". O convidado que chama uma rota do dono
  recebe "não encontrado", como qualquer outro artista.
- **Testes obrigatórios de segurança:**
  - Um terceiro artista não lê nem marca nada no evento.
  - O convidado lê a setlist e as cifras do evento, mas não lê uma cifra
    do dono fora do evento.
  - O convidado não monta a setlist, não corrige cifra, não encerra e não
    vê estatísticas.
  - Tirado do evento (ou depois de sair), perde o acesso na hora.
  - O evento de karaokê não gera convite.
  - As rotas públicas continuam respondendo sem token.

## App

- Rota `/convite/<código>` (abre sozinha, sem o início embaixo, como os
  outros links), com a tela de entrar no evento.
- Seção **Convites** no painel do artista e a tela do evento em modo músico:
  setlist e fila só para ler, leitor com as cifras do evento, Tocar e Letra
  na TV.
- **Mais → Músicos da noite** para o dono: convidar, ver e tirar.
- O leitor do convidado busca a cifra pela rota do evento. O tom mudado
  fica no aparelho, como hoje.
- Tempo real: o convidado assina o canal da apresentação. O que o dono muda
  (setlist, pedidos, tocadas) chega na hora, e o que o convidado marca
  chega no dono.

## Ordem de implementação (um commit por etapa, cada uma nascendo de teste)

1. Servidor: tabelas, convite (gerar, ver, entrar, sair, tirar) e
   `GET /api/convites`.
2. Servidor: `ObterApresentacaoDaNoite`, as leituras da setlist, da fila e
   do louvor, e o marcar como tocada para o convidado.
3. Servidor: cifras do evento, limitadas à setlist e aos pedidos.
4. App: Músicos da noite (dono) e a tela do convite.
5. App: seção Convites e o evento em modo músico, com o leitor.
6. Documentação: contexto atual e roteiro de smoke test.

## Fora desta versão

- Nomes dos músicos na página pública.
- Comando da TV passado para outra pessoa (spec à parte). Por enquanto, as
  TVs são de cada conta: a TV da casa segue o celular de quem a conectou.
- Permissões diferentes por convidado.
