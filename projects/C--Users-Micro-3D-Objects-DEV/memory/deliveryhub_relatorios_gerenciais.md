---
name: deliveryhub-relatorios-gerenciais
description: "Rankings gerenciais nos relatorios (produto mais vendido/menos vendido/lucro, maiores vendas, ranking garcom com produto favorito)"
metadata: 
  node_type: memory
  type: project
  originSessionId: bdb43667-7429-48fe-b9b0-d932e62bf0b2
  modified: 2026-07-29T19:37:40.546Z
---

Implementado 2026-07-29, branch `feat/relatorios-gerenciais` (frontend + submodule `server_delivery`). **MERGEADO EM MAIN E PUSHADO** nos dois repos (backend `0c98b74`, frontend `e139db8`). Ainda precisa reiniciar o backend local pra ver o campo novo, e o EasyPanel puxar o `server_delivery` main pra refletir no deploy real.

**O que foi pedido:** produto mais vendido, maior venda em um período, produto que menos vendeu, produto com maior lucratividade, ranking de garçons (quem vendeu mais, quem ganhou mais gorjeta, produto favorito por garçom, filtro por período).

**Decisões tomadas com o usuário (plano aprovado antes de codar):** lucratividade = R$ absoluto (não margem %); "qual período vendeu mais" = usuário escolhe o período no filtro já existente, sem comparativo automático entre sub-períodos; rankings entram dentro das abas já existentes de `Produtos.jsx`/`Garcom.jsx`/`Financeiro.jsx`, não página nova.

**O que mudou:**
- Backend (`server_delivery/src/restaurante/restaurante.service.ts`, `getRelatorioGarcom`): novo campo `produtos` (top-5) por garçom, agregado de `order_items` das comandas pagas do período.
- `Produtos.jsx`: cards Mais Vendido/Menos Vendido/Mais Lucrativo (clicáveis, levam pra aba certa já ordenada) + toggle de ordenação nas abas Vendas/Lucro (antes não ordenavam pelo que interessava).
- `Garcom.jsx`: cards Quem Vendeu Mais/Quem Ganhou Mais Gorjeta, campo de busca por nome (complementa o select que já existia), toggle de ordenação (venda/gorjeta/comissão), coluna "Produto Favorito" com expansão pro top-5.
- `Financeiro.jsx`: nova seção "Maiores Vendas do Período" (top 10 pedidos/comandas por valor, direto de `dados.pedidos` que já vinha do backend — sem mudança de endpoint aqui).

**Pendências antes de mergear:** usuário precisa reiniciar o backend local (mudança em `.ts` não recarrega sozinha, ver [[feedback_backend_restart_apos_pull]]) e testar as 3 telas com dados reais. Ver [[feedback_banco_local_nunca_mudar_cloud]] e [[feedback_sempre_local_sem_permissao_web]] — não fazer merge/push main sem pedir de novo.

**Gotcha do submodule:** commitei dentro de `server_delivery` (branch `feat/relatorios-gerenciais` lá também) e depois no repo pai — pai só rastreia o ponteiro do submodule, os dois precisam de commit separado. Ver [[deliveryhub_dois_clones_server_delivery]] se for sincronizar com o clone standalone da VPS depois.
