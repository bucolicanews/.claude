---
name: deliveryhub-cancelar-item-producao
description: "botao Cancelar em item Aguardando Preparo na tela Producao — some tambem da Cozinha — MERGEADO+PUSHADO+MIGRATION CLOUD, TESTADO"
metadata: 
  node_type: memory
  type: project
  originSessionId: 9e881dd1-4b9e-4669-9856-ee5151393956
  modified: 2026-07-27T17:12:48.917Z
---

Pedido em 2026-07-27: em `/restaurante/producao`, item na coluna "Aguardando Preparo" ganhou botão vermelho "Cancelar" ao lado de "Iniciar Preparo". Cancelar exige confirmação (`confirm()`), só permitido enquanto `order_items.status = 'enviado'` (validado no backend também, não só escondido no front).

**O que mudou:**
- Migration `20260727000002_cancelar_item_kds.sql`: `order_items_status_check` ganha valor `'cancelado'` + coluna `cancelado_em`.
- Backend `restaurante.service.ts` `cancelarItem()` + rota `PATCH /kds/itens/:id/cancelar` (`restaurante.controller.ts`) — só aceita se status atual for `'enviado'`, senão 400.
- Frontend: `cancelarItemRestaurante()` em `restauranteService.js`, botão só no `ItemCard` quando `item.status === 'enviado'`.
- Item cancelado some automaticamente de Produção **e** Cozinha sem precisar mexer na tela de Cozinha — as duas leem o mesmo `GET /kds` cujo filtro de status (`enviado`,`preparando`,`pronto` de hoje) já exclui `cancelado`.

**Why:** dono queria descartar item lançado errado antes de começar o preparo, sem precisar cancelar a comanda/pedido inteiro.

**Status:** testado, mergeado em main (frontend+backend submodule+standalone VPS todos sincronizados), migration aplicada em produção (Supabase Cloud) em 2026-07-27.
