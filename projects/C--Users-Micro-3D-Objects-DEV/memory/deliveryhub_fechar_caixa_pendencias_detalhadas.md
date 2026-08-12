---
name: deliveryhub-fechar-caixa-pendencias-detalhadas
description: Fechar caixa com pendencia (409) mostra lista detalhada de pedidos/comandas/mesas abertos em vez de alerta generico
metadata: 
  node_type: memory
  type: project
  originSessionId: a3b8cc80-dd93-409c-8298-ab3f1d5bc4af
  modified: 2026-07-28T20:50:56.321Z
---

Fechar Caixa: quando backend retorna 409 (pendencias em aberto), front agora guarda `pedidos`/`comandas`/`mesas` do `e.data` em state (`pendencias`) e passa pro `FecharCaixaModal` renderizar lista detalhada, em vez de so `alert()` generico.

**Why:** backend (`restaurante.service.ts` `fecharCaixa`) ja retornava os arrays completos no `ConflictException`, e `FecharCaixaModal.jsx`/`PedidosAbertosView` ja tinham as props `comandasAbertas`/`mesasAbertas` prontas — so faltava `CaixaAtualPanel.jsx` conectar os dois lados.

**Estado:** MERGEADO+PUSHADO EM MAIN (commit e2bfec6, 2026-07-28), EasyPanel deploy não confirmado manualmente. Testar fluxo real: deixar pedido/comanda/mesa aberta, tentar fechar caixa, conferir se modal lista os itens certos.

Próximo: retomar [[deliveryhub_plano_dark_mode_retrofit]].
