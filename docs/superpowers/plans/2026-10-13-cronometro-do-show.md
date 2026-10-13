# Cronômetro do show — plano

Aprovado pelo proprietário em 2026-10-13. Origem: banco de ideias, "No palco".

## Objetivo

A banda vê, o tempo todo e em todos os aparelhos, quanto falta das horas
contratadas e quantas músicas ainda cabem no ritmo real do show.

## Regras aprovadas

- **Só artistas veem.** Nada do cronômetro aparece nas rotas públicas nem na
  área do público. O registro `Apresentacao` (compartilhado com as rotas
  públicas) não muda: o cronômetro tem rotas próprias, privadas, como a
  sequência "tocar a seguir".
- **Duração contratada** opcional por apresentação. Sem ela, nada muda.
- **Relógio começa no primeiro "Iniciar"**; reiniciar não zera.
- **Intervalo simples:** botão "Intervalo" e "Voltar ao show", sem duração
  escolhida. Opção por apresentação: "O intervalo pausa o relógio do
  contrato?" (padrão: não, horas corridas).
- O tempo em intervalo **nunca** entra no cálculo do ritmo.
- **Ritmo:** 3 min por música até a 3ª música começada; depois, tempo tocado
  (sem intervalos) ÷ músicas começadas. O app diz qual dos dois está usando.
- Faixa muda de cor com 30 e 10 min restantes; depois do horário mostra
  "Passou X min".

## Servidor

Colunas novas em `Apresentacoes`, adicionadas só quando faltam (Postgres
`ADD COLUMN IF NOT EXISTS`; SQLite `AdicionarColunaSqliteSeNecessario`):

| Coluna | Tipo | Padrão |
|---|---|---|
| `DuracaoContratadaMinutos` | inteiro, nulo | nulo |
| `IntervaloPausaRelogio` | booleano | falso |
| `IniciadaEm` | data/hora, nulo | nulo |
| `EmIntervaloDesde` | data/hora, nulo | nulo |
| `SegundosEmIntervalo` | inteiro | 0 |

Rotas privadas (exigem o dono; outro artista recebe 404, sem token 401):

- `GET /api/apresentacoes/{id}/relogio`
- `PUT /api/apresentacoes/{id}/relogio` — `{ duracaoContratadaMinutos, intervaloPausaRelogio }`
- `POST /api/apresentacoes/{id}/relogio/intervalo` — entra em intervalo
- `DELETE /api/apresentacoes/{id}/relogio/intervalo` — volta ao show

Resposta: duração, opção de pausa, `iniciadaEm`, `emIntervaloDesde`,
`segundosEmIntervalo`, `musicasComecadas` (setlist tocada + pedidos de música
tocando ou finalizados), `musicasRestantes` (setlist não tocada + pedidos a
seguir) e `agora` (hora do servidor, para corrigir relógio do aparelho).

Show que já estava em andamento antes desta versão não tem `IniciadaEm`:
ao configurar a duração, o início passa a ser aquele momento.

## Cliente

- Cálculo puro e testado (`relogio_do_show.dart`): restante, término,
  alerta, passou, ritmo e músicas que cabem.
- Formulário da apresentação: duração (sem duração, ou horas e minutos) e a
  opção de pausa.
- Faixa do cronômetro com botão de intervalo, na barra do show ao vivo do
  painel (visível em Fila, Setlist, Estatísticas e Mais) e no modo palco.
  Atualiza pelo tempo real já existente e a cada 15 s.

## Tarefas (um commit cada)

1. Servidor: relógio no repositório, persistência e migração.
2. Servidor: rotas privadas do relógio e garantia das rotas públicas.
3. Cliente: modelo, cálculo e API do relógio.
4. Cliente: duração e opção de pausa no formulário.
5. Cliente: faixa do cronômetro com intervalo no painel e no modo palco.
6. Cliente: ritmo do show e músicas que cabem (fase 2).
7. Docs: contexto atual e banco de ideias.

## Fase 3 (aprovada em 2026-10-13)

- Encerrar a apresentação grava `EncerradaEm` (coluna nova, adicionada só
  quando falta).
- O relógio devolve `ritmoMedioSegundos`: tempo tocado (sem intervalo) somado
  dos shows encerrados do próprio artista ÷ músicas começadas neles. Ficam
  de fora shows com menos de 3 músicas ou ritmo fora de 1 a 15 min
  (esquecidos abertos).
- Setlist de apresentação agendada: cartão "N músicas ≈ duração", com o
  ritmo usado e a comparação com as horas contratadas.
- Ao vivo, até a 3ª música, o ritmo é o médio do artista; sem histórico,
  3 minutos.
- Shows anteriores a 2026-10-13 não têm horários gravados: o histórico
  começa no primeiro show encerrado depois desta versão.
