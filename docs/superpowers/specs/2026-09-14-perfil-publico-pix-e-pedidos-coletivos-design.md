# Perfil público, apoio via Pix e pedidos coletivos

## Objetivo

Preparar a apresentação pública do TocaEssaApp para cantores de bares e eventos, permitindo que o público conheça e contate o artista, faça uma contribuição voluntária por Pix e perceba quando uma música tem apoio coletivo.

## Escopo deste incremento

- Ampliar o perfil geral do artista com biografia, Instagram, WhatsApp profissional e configuração de Pix.
- Permitir que o artista escolha individualmente quais contatos serão exibidos ao público.
- Exibir um resumo público do artista dentro da apresentação pública.
- Oferecer a ação **Apoiar o artista**, com valores sugeridos de R$ 5, R$ 10 e R$ 20 e valor personalizado.
- Gerar Pix Copia e Cola e QR Code estáticos, sem conta em intermediador e sem confirmação automática.
- Agrupar visualmente pedidos equivalentes de música e destacar grupos com mais de um pedido.
- Preservar cada pedido individual no banco para histórico, autoria, cancelamento, estatísticas e avaliações.

## Fora do escopo

- Cobrança por cartão, carteira digital ou assinatura.
- Confirmação automática de pagamento, webhook, estorno ou conciliação.
- Alteração automática da posição da fila por valor contribuído.
- Garantia de que uma contribuição fará a música ser tocada.
- Ranking público de valores ou identificação de quem contribuiu.

## Perfil geral do artista

O perfil artístico continuará sendo a fonte única da identidade usada em todas as apresentações. Ele receberá os campos opcionais:

- `instagram`: nome de usuário ou URL válida do Instagram;
- `whatsapp`: telefone profissional em formato internacional;
- `exibirInstagram` e `exibirWhatsapp`: controles independentes de visibilidade;
- `pixAtivo`: habilita o apoio nas apresentações públicas;
- `pixChave`: chave usada para montar o BR Code;
- `pixNomeBeneficiario` e `pixCidadeBeneficiario`: dados exigidos pelo padrão Pix;
- `pixMensagem`: texto curto opcional apresentado antes do QR Code.

A API nunca devolverá a chave Pix no perfil público. Para o público ela devolverá apenas se o apoio está disponível e um payload Pix já montado para o valor solicitado. A edição continuará protegida pela sessão do artista.

O artista será orientado a usar uma chave aleatória, pois chaves de CPF, telefone ou e-mail podem expor dados pessoais ao pagador.

## Experiência do público

Na apresentação pública, o cabeçalho do artista terá uma ação discreta para abrir o perfil. O painel público mostrará foto ampliável, nome, biografia e apenas os contatos autorizados. Instagram e WhatsApp abrirão links externos seguros.

Quando `pixAtivo` estiver habilitado, aparecerá **Apoiar o artista**. Um modal permitirá selecionar R$ 5, R$ 10, R$ 20 ou informar um valor entre R$ 1 e R$ 1.000. Após a escolha, o app solicitará à API o payload estático, exibirá o QR Code e permitirá copiar o código Pix.

O texto deixará explícito: “A contribuição é um apoio voluntário e não garante que um pedido seja aceito ou tocado.” Não haverá estado visual de “pago”, porque o MVP não confirma a transação.

## Pedidos repetidos e destaque coletivo

Dois pedidos serão equivalentes quando o nome da música e o artista coincidirem após remover espaços laterais, normalizar espaços internos e ignorar maiúsculas/minúsculas. O sistema não tentará corrigir grafias diferentes nesta etapa.

Enquanto a música ainda estiver ativa, o agrupamento independerá de o pedido estar aguardando, aceito ou tocando. O estado visível do grupo seguirá a precedência `TocandoAgora`, `Aceito` e `Aguardando`. Se uma nova pessoa pedir uma música que já está aceita ou tocando, o novo pedido herdará esse estado e entrará no mesmo grupo; uma música já finalizada não fará pedidos futuros pularem a análise do artista. No histórico, grupos serão separados por estado terminal para não misturar execuções e recusas.

A API produzirá uma visão agrupada para o artista e para o público, contendo:

- o pedido representativo, escolhido pelo mais antigo do grupo;
- `quantidadePedidos`;
- nomes distintos dos solicitantes;
- IDs dos pedidos que compõem o grupo.

Grupos com `quantidadePedidos > 1` receberão um selo como **3 pedidos** e tratamento visual de maior demanda. Um único cartão substituirá cartões duplicados.

As ações do artista sobre um grupo serão aplicadas a todos os pedidos ativos equivalentes: aceitar, marcar como não conhecida, marcar como ainda não sabe tocar, iniciar e finalizar. Ao entrar na fila, o grupo ocupará a posição do pedido aceito mais antigo. A reordenação será feita por grupos, evitando que pedidos equivalentes se separem.

O cancelamento do público continuará afetando somente o seu próprio pedido. Se ainda houver outros pedidos equivalentes, o grupo permanecerá e sua contagem será atualizada.

## Dados e API

O banco atual será ampliado de forma retrocompatível. Campos opcionais usarão valores nulos ou `false`, de modo que perfis existentes continuem funcionando sem apoio ou contatos públicos.

Responsabilidades propostas:

- `PerfilArtistico`: armazenar identidade, contatos, visibilidade e configuração Pix.
- `ServicoPix`: validar valor e dados do recebedor e gerar um BR Code Pix estático com CRC16.
- `GrupoDePedidosMusicais`: DTO de leitura e de ações coletivas; não será uma nova entidade persistida.
- endpoints de perfil: salvar dados privados e devolver uma projeção pública sem a chave Pix;
- endpoint de Pix: gerar o payload para uma apresentação pública e um valor válido;
- endpoints de fila: listar grupos e receber ações/reordenação por grupo.

Nenhum segredo bancário ou comprovante será armazenado. O payload gerado contém apenas os dados necessários para o Pix estático.

## Regras de erro

- Apoio desabilitado ou perfil sem dados Pix completos: responder como recurso indisponível e ocultar o botão.
- Valor fora do intervalo: retornar validação clara sem gerar payload.
- Instagram ou WhatsApp inválidos: impedir o salvamento e explicar o formato esperado.
- Grupo inexistente ou que mudou após atualização em tempo real: recarregar a fila e informar que ela foi atualizada.
- Falha ao copiar ou desenhar o QR Code: manter o Pix Copia e Cola disponível.

## Tempo real

Criação, cancelamento ou mudança de status de um pedido continuará usando o mecanismo atual de atualização. A cada evento, cliente e artista recalcularão a lista agrupada recebida da API; a contagem e os solicitantes mudarão sem recarregar a página inteira.

## Segurança e privacidade

- A chave Pix nunca aparecerá em respostas genéricas de perfil ou apresentação.
- Links externos serão formados pelo aplicativo, sem aceitar esquemas arbitrários.
- Campos terão limites de tamanho no cliente e no servidor.
- O perfil público mostrará apenas campos com visibilidade explicitamente ativada.
- O QR Code não será descrito como cobrança confirmada nem como compra de posição na fila.

## Testes e critérios de aceite

- Um perfil antigo continua sendo carregado após a evolução do banco.
- O artista salva contatos e controla separadamente a visibilidade de cada um.
- A projeção pública não contém a chave Pix.
- Payloads Pix gerados para valores válidos passam pela validação de CRC16; valores inválidos são rejeitados.
- A tela pública esconde apoio quando o Pix está incompleto ou desativado.
- Pedidos equivalentes aparecem em um cartão com contagem e solicitantes distintos.
- Pedidos de grafia diferente permanecem separados.
- Uma ação coletiva altera todos os pedidos ativos do grupo.
- Cancelar um pedido individual reduz a contagem sem remover pedidos alheios.
- Reordenar grupos mantém pedidos equivalentes juntos.
- Testes do servidor, testes Flutter, análise estática e build continuam passando.

## Evolução futura

Depois dos testes em apresentações reais, uma segunda especificação poderá integrar um provedor de pagamentos para Pix dinâmico e confirmação por webhook. Só então será seguro associar contribuição confirmada a um **pedido em destaque**, ainda sem retirar do artista o controle editorial da fila.
