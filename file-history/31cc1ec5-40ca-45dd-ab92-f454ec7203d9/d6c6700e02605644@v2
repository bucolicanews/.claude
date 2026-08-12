---
name: deliveryhub-fix-caixa-estorno-permissoes
description: "Estorno de dinheiro (pagamento corrigido/removido + comanda cancelada), gorjeta direto ao garçom, trava clique duplo, garçom não exclui comanda — MERGEADO+PUSHADO ambos repos"
metadata: 
  node_type: memory
  type: project
  originSessionId: 31cc1ec5-40ca-45dd-ab92-f454ec7203d9
  modified: 2026-07-31T00:14:49.076Z
---

Sessão 2026-07-30, sequência de bugs reais achados testando o caixa depois do fix de [[deliveryhub_fix_saldo_taxa_cartao_duplicada]]-like (dinheiro não somava no caixa físico).

**Bug 1 — dinheiro delivery não creditava:** pedido pago em dinheiro no checkout, motoboy confirma entrega (ou dono marca entrega própria), nunca credita `registrarEntradaCaixa` — só salão fazia isso. Corrigido em `pedidos.service.ts atualizarStatus()` e `motoboy.service.ts confirmarEntrega()`/`entregarProprio()`.

**Bug 2 — pagamento exato sem troco não creditava:** salão/balcão/garçom só credita se `valorRecebido !== undefined`; se o operador paga em dinheiro sem digitar "valor recebido" (não precisa de troco), campo fica vazio, nunca credita. Corrigido nos 4 pontos (pagar mesa, finalizar balcão, registrar parcial garçom, registrar parcial dono) mandando o próprio valor cobrado como fallback.

**Bug 3 — clique duplo duplicava lançamento:** botão "Pagar"/"Registrar" usa `disabled={salvando}` (state), que é assíncrono — clique muito rápido passa 2x antes do disable renderizar. Travado com `useRef` síncrono (`emAndamentoRef`) em pagar/finalizar/registrar parcial (ambos modais + garçom).

**Bug 4 — deletar/editar pagamento em dinheiro não estornava o caixa:** apagar um pagamento errado (pra corrigir) só deletava a linha em `comanda_pagamentos`, a entrada automática no caixa físico ficava — dinheiro fantasma. Pior: também não revertia o TROCO que tinha saído junto, então corrigir deixava o saldo errado pro lado contrário. `SalaoService.estornarPagamentoEmDinheiro()` novo reverte os dois (entrada + troco), usado em editar/remover pagamento (garçom e dono) E em cancelar/excluir a comanda inteira (`estornarPagamentosDaComanda()`, percorre todos os `comanda_pagamentos` da comanda). Tipos novos no ledger `estorno_pagamento`/`estorno_troco`, excluídos do cálculo de Saldo Líquido (mesma lógica que já existia pra `venda_dinheiro`/`troco`, senão conta 2x).

**Feature — gorjeta paga direto ao garçom:** select "Forma de pagamento da gorjeta" no fechamento da comanda de mesa ganhou 3 opções: "Na comanda" (padrão, cobra junto), "Pix direto", "Dinheiro direto" (cliente pagou a gorjeta na mão do garçom, por fora) — nesse caso não entra no valor cobrado da comanda nem em `orders.gorjeta_valor` (usado no relatório de repasse do garçom via [[deliveryhub_repasse_garcom_dinheiro_pix]], senão contaria a mesma gorjeta 2x). Passou por 2 iterações: 1ª tentativa criou um select duplicado (2 selects na tela), usuário pediu pra fundir em 1 só — reaproveita o `forma` existente como valor técnico interno (payment_method só aceita pix/credit_card/debit_card/cash no banco), removeu as opções de cartão do select visível.

**Feature — garçom não exclui mais comanda:** botão "Excluir comanda" removido do portal do garçom — rota `DELETE /garcom/comandas/:id` removida do backend também (não só escondido no front, Zero Trust). Só o estabelecimento cancela via PDV (`SalaoPdvService.cancelar`).

**Status: MERGEADO+PUSHADO main em ambos os repos 2026-07-30 (submodule `e65f9d3`, main `a242da2`). Sem migration nova nessa leva. EasyPanel/deploy do código ainda por confirmar.**

**How to apply:** se aparecer de novo "caixa não bate", suspeitar primeiro de: (a) pagamento em dinheiro sem `valorRecebido` sendo enviado, (b) pagamento deletado/editado sem passar por `estornarPagamentoEmDinheiro`, (c) comanda cancelada sem passar por `estornarPagamentosDaComanda`. Qualquer novo lugar que credite/debite dinheiro no ledger da comanda precisa decidir se o tipo entra ou não em `entradas_saldo`/`saidas_saldo` (`calcularResumo` em restaurante.service.ts) — regra: se é o "espelho automático" de uma venda já contada em `total_vendas`, exclui; se é lançamento manual real (sangria, adição), inclui.
