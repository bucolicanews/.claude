---
name: deliveryhub-decrementar-estoque-venda
description: "Estoque decrementa automaticamente na venda (delivery e salão) e devolve no cancelamento — MERGEADO+PUSHADO ambos repos (main), TESTADO"
metadata: 
  node_type: memory
  type: project
  originSessionId: 31cc1ec5-40ca-45dd-ab92-f454ec7203d9
  modified: 2026-07-30T18:25:43.862Z
---

Pergunta do usuário 2026-07-30: estoque diminui de acordo com as vendas? Não diminuía — `quantidade_estoque` só bloqueava venda em 0/null (ver [[deliveryhub_estoque_zero_bloqueia_venda]]). Tarefa 1 de 2 combinadas nesta sessão.

**Regra confirmada pelo usuário (3 perguntas):** delivery decrementa na criação do pedido (não na confirmação); salão decrementa ao adicionar item na comanda (não só ao fechar); cancelamento sempre devolve o estoque.

**Implementado:**
- Migration `supabase/migrations/20260730000002_ajustar_estoque_function.sql`: função Postgres `ajustar_estoque(p_product_id, p_delta)` — update atômico de uma linha (não precisa transação explícita), `GREATEST(..., 0)` nunca deixa negativo.
- Novo `EstoqueService` (`server_delivery/src/estoque/estoque.service.ts`, módulo `@Global()` registrado em `app.module.ts`): `decrementarItens()`, `restaurarItens()`, `ajustarPorDelta()` (edição de quantidade), `restaurarItensDoPedido()` (busca todos os `order_items` não cancelados de um pedido/comanda e devolve).
- **Decrementa:** `pedidos.service.ts criar()` (pedido delivery), `salao.service.ts adicionarItens()` (garçom), `salao-pdv.service.ts adicionarItens()` (PDV do dono).
- **Restaura:** `pedidos.service.ts atualizarStatus()` (cobre `cancelar()` admin), `cancelarCliente()`; `restaurante.service.ts cancelarPedidoAdmin()` e `cancelarItem()` (KDS — cancelar item em Aguardando Preparo, precisou expandir o `select` pra trazer `product_id`/`quantity`); `motoboy.service.ts registrarOcorrencia()` tipo cancelada; `salao.service.ts removerItem()` e `excluirComanda()`; `salao-pdv.service.ts removerItem()` e `cancelar()` (comanda inteira).
- **Ajusta delta:** `salao.service.ts editarItem()` e `salao-pdv.service.ts editarItem()` quando a quantidade de um item já lançado muda (não pedido explicitamente, mas necessário pra não desalinhar).
- **Não mexido de propósito** (não é venda nova nem cancelamento — item só muda de dono): mover/juntar itens entre comandas (`salao-pdv.service.ts` transferir/juntar mesa), `dividirComanda` (garçom e PDV).

**Caveat:** `cancelarPedidoAdmin` não tem restrição de status (admin pode cancelar pedido já `delivered`) — com a regra "sempre devolve", cancelar um pedido já entregue devolve estoque de item que já saiu de fato. Comportamento pré-existente do endpoint, não redesenhado — só decidir se vira problema na prática.

**Status: MERGEADO+PUSHADO main em ambos os repos 2026-07-30 (submodule commit `c055612`, main commit `aef8813`). Migration aplicada local e Cloud. Testado pelo usuário (garçom + comanda de mesa + Venda balcão), deu certo.**

**Bug pego durante o teste e corrigido junto:** `restaurante-salao/index.jsx` — os pickers de produto do dono (comanda de mesa e Venda balcão) buscavam a lista de produtos **uma vez só** num `useEffect` separado, nunca reroda depois de incluir/editar/remover item (só a comanda recarregava). Resultado: backend decrementava certo, mas a quantidade em estoque exibida ficava desatualizada — parecia que não tinha acontecido nada. Fix: incluí `getMeusProdutos()` dentro do `carregar()` de cada modal (`Promise.all` junto com a comanda), removendo o fetch avulso.

**Também adicionado:** picker de produto (garçom, mesa do dono, Venda balcão) mostra "Em estoque: N" e trava o botão `+` no limite disponível nos dois QuickAdd modals — precisou expor `quantidade_estoque` no select de `salao.service.ts produtos()` (endpoint do garçom), que não trazia esse campo antes.

**How to apply:** se aparecer de novo sensação de "não decrementou" numa tela nova, suspeitar primeiro de picker com lista de produtos cacheada/não recarregada, antes de suspeitar do backend — já rolou uma vez.
