# Montar setlist a partir do acervo — plano

Aprovado pelo proprietário em 2026-10-13.

## Objetivo

Repertórios viram o acervo da banda. A setlist de cada show é montada
escolhendo músicas de vários repertórios (ou um inteiro), e pode ser editada.

## Regras aprovadas

- **Setlist independente:** depois de montada, música nova, música removida
  ou nova ordem no repertório não mexem na setlist. Correções de título,
  cantor e tom feitas no acervo continuam sendo repassadas.
- Adicionar coloca as músicas **no fim**, sem apagar nada.
- A mesma música (título e cantor, sem acento nem maiúscula) não entra duas
  vezes na setlist, mesmo vindo de repertórios diferentes.
- Durante o show, as músicas tocadas ficam onde estão; só as que faltam podem
  ser removidas ou reordenadas.
- **Música avulsa:** entra direto na setlist, com a opção de salvar também
  num repertório.
- "Trocar repertório" vira "Limpar setlist", com confirmação.

## Servidor (rotas privadas, sem migração)

- `POST /api/apresentacoes/{id}/setlist/musicas` — `{ musicaIds }` do acervo.
- `POST /api/apresentacoes/{id}/setlist/avulsa` — `{ titulo, artista, tom, repertorioId? }`.
- `DELETE /api/apresentacoes/{id}/setlist/{itemId}` — só música não tocada.
- `PUT /api/apresentacoes/{id}/setlist/ordem` — `{ itemIds }` das não tocadas.
- A rota antiga de importar continua existindo.

## Cliente

- Tela "Montar setlist": chips dos repertórios, caixas de marcar, "Selecionar
  todas", busca no acervo, marcação "na setlist", rodapé com a duração
  estimada e as horas contratadas, botão "Adicionar à setlist" e "Música
  avulsa".
- Setlist: arrastar para reordenar e remover as que faltam; "Limpar setlist".

## Tarefas (um commit cada)

1. Servidor: repertório deixa de mexer na setlist (exceto correções).
2. Servidor: adicionar do acervo, avulsa, remover e reordenar.
3. Cliente: API e tela Montar setlist.
4. Cliente: setlist editável e Limpar setlist.
5. Docs.

Para depois (banco de ideias): salvar setlist como repertório, blocos do show,
estilo/energia por música.
