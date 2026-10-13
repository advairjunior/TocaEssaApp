# Leitor de cifras — desenho

Aprovado pelo proprietário em 2026-10-13. Princípio: o app é para tocar;
nada de ajuste ou passo que não ajude no palco.

## Tela

```
 Evidências · Tom G                     ✎
 ─────────────────────────────────────────
   (cifra colada, rolando livremente)
 ─────────────────────────────────────────
  ‹            [  Tocar  ]             ›
          Depois: Pense em Mim
```

- Topo: nome, tom e lápis para colar ou corrigir a cifra.
- Meio: só a cifra, fonte de largura fixa, linhas de acordes em roxo.
- Embaixo, sempre visíveis: setas (só trocam de música) e **Tocar** (começa a
  música, como o Tocar da barra Próxima). Se a música da página já está
  tocando, o botão mostra **Tocando ✓**.
- Ordem das páginas: a sequência do show (pedidos a seguir, depois setlist).
- Tamanho automático: a linha mais larga cabe na tela; pinça ajusta e o
  tamanho fica guardado no aparelho.
- Sem cifra colada: **Colar cifra** e, se houver link, **Abrir no site**.
- Pedal Bluetooth de virar página: setas e Page Up/Down do teclado.
- "Abrir cifra" no modo palco e na setlist abre o leitor naquela música.

Fora (para simplificar): arrastar para o lado, ajuste "só ler / avançar
marca", selo à parte, pedidos e cronômetro no leitor, rolagem automática,
botões de tamanho.

## Dados

- Cifra em texto separada do link: tabela nova `CifrasEmTexto` (artista,
  música e cantor normalizados como nos links), criada só se não existir.
- `GET /api/artista/cifras/consulta` passa a devolver também `texto`; a
  sequência do palco já consulta todas as músicas antes do show.
- `PUT /api/artista/cifras/texto` — `{ musica, artista, texto }`; texto vazio
  apaga. Só o artista dono; nada aparece em rota pública.

## Etapas

1. Cifra colada e leitor (este desenho).
2. Sem internet: guardar setlist, sequência e cifras no aparelho; aviso
   discreto; marcações em fila até a conexão voltar.
3. Depois: transpor tom, observações por música.
