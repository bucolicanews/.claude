---
name: deliveryhub-aba-relatorios-plano
description: "IMPLEMENTADO E MERGEADO EM MAIN — aba Relatórios (Garçom/Financeiro/Produtos) no painel restaurante, depois estendida com custo/estoque mínimo/lucro"
metadata:
  node_type: memory
  type: project
  originSessionId: pending
  modified: 2026-07-23T15:13:49.455Z
---

**Atualizado 2026-07-23:** branch `feature/relatorios` mergeada em `main` nos dois repos (backend `e2b2234`, frontend `6e6a972`). Bug de payment_method único (parte 1 e 2, ver antiga [[deliveryhub_bug_forma_pagamento_comanda_dashboard]] — memória removida por estar resolvida) também corrigido dentro desse escopo, commit backend `5f082c0`. Depois estendida com custo/estoque mínimo do produto e relatórios de reposição/sem giro/lucro (branch `feat/produto-custo-estoque-relatorios`, também já mergeada — backend `fdca824`, frontend `1f830f4`).

Requisito pedido pelo usuário em 2026-07-18: nova aba **Relatórios** na barra de navegação superior do painel do restaurante, levando a uma página com **menu de relatórios** — cada relatório tem tela com filtro e opção de impressão (mesmo padrão do [[deliveryhub_modulo_restaurante_ideias]] ideia 6, mas agora com escopo fechado pelo usuário).

**Relatório 1 — Garçom:**
- Total de vendas por garçom
- Comissão por garçom
- Gorjeta por garçom
- Comandas abertas por garçom
- Mesas pendentes / comandas pendentes por garçom

**Relatório 2 — Financeiro:**
- Vendas do dia
- Comissão paga (aos garçons)
- Gorjetas pagas ao garçom
- Pagamentos por forma: dinheiro, PIX, cartão crédito, cartão débito
- Troco
- Fluxo de caixa detalhado: valores recebidos e formas pagas (discriminado)

**Relatório 3 — Produtos:**
- Lista de produtos
- Produtos sem estoque
- Produtos ativos e bloqueados

**Why:** consolida os relatórios do módulo Restaurante (ideia 6/6-refinada, já coletada antes) num único lugar navegável, em vez de ficar só dentro do RelatorioPanel colapsável do Dashboard (que hoje só cobre delivery, sem garçom/comissão/gorjeta/produtos). Ver também [[deliveryhub_bug_forma_pagamento_comanda_dashboard]] — o relatório Financeiro (fluxo de caixa detalhado por forma) esbarra no mesmo bug de payment_method único; corrigir junto faz parte do escopo (fluxo de caixa correto depende de decompor comanda_pagamentos).

**How to apply:** usuário pediu ordem: lista de tarefas → plano de implantação → registrar tudo → iniciar execução. Seguir [[feedback_branch_por_tarefa]] (branch nova nas duas repos — frontend e server_delivery submodule — não mexer direto na main).

**Decisões confirmadas com usuário 2026-07-18 (após exploração de código):**
1. **Nav** (achado: 15 páginas restaurante-* duplicam array LINKS/header, sem componente compartilhado) — usuário escolheu editar as 15 cópias diretamente, sem refatorar pra componente único. Escopo mínimo.
2. **Estoque de produto** (achado: `products` não tem coluna de estoque, só `is_active`) — usuário quer estoque real, nova coluna `quantidade_estoque` (migration), **ajuste manual** (sem decremento automático na venda, pra não mexer no fluxo crítico de pedido/comanda).

**Plano técnico (baseado em exploração real do código, ver detalhes por task no TaskList desta sessão):**

Backend (`server_delivery/src/restaurante/`):
- Migration `products.quantidade_estoque INTEGER NOT NULL DEFAULT 0`.
- `getRelatorioGarcom(restaurantId, de, ate)` — novo: total vendido/comissão/gorjeta por garçom no período (via `garcom_comissoes_lancamentos`, `orders.gorjeta_valor`), + comandas abertas/mesas pendentes por garçom (estado atual, não filtrado por período).
- `getRelatorio` existente estendido (ou novo `getRelatorioFinanceiro`) — comissão paga total, gorjetas pagas total, troco (`comanda_pagamentos.troco`), fluxo de caixa detalhado (já tem `buscarPagamentosPorComanda`/`calcularResumo` como base, reaproveitar).
- `getRelatorioProdutos(restaurantId, de, ate)` — novo: vendas por produto (agregação `order_items`) + lista completa/sem estoque/ativos-bloqueados (estado atual).
- Ajuste manual de estoque: estender `editarProduto` ou novo PATCH.

Frontend (`src/pages/restaurante-relatorios/` novo):
- `src/utils/relatorioPrint.js` novo — extrai `buildRange`/`printIframe`/`reportBaseStyle` hoje duplicados em `RelatorioPanel.jsx` e `restaurante-financeiro/index.jsx` (achado da exploração); refatora os dois pra usar o util, sem mudar comportamento.
- `restauranteService.js`: `getRelatorioGarcom`, `getRelatorioProdutos`, `ajustarEstoqueProduto`, extensão de `getRelatorio`.
- Rotas em `Routes.jsx`: `/restaurante/relatorios` (menu), `/relatorios/garcom`, `/relatorios/financeiro`, `/relatorios/produtos` — dentro de `RestauranteGuard`.
- Páginas novas: `restaurante-relatorios/index.jsx` (menu), `Garcom.jsx`, `Financeiro.jsx`, `Produtos.jsx` — cada uma com filtro (dia/mês/ano/período) + impressão, reaproveitando o util novo.
- Campo `quantidade_estoque` editável adicionado na tela `restaurante-produtos/index.jsx` já existente.
- Link "Relatórios" adicionado nas 15 páginas `restaurante-*` que duplicam nav.

Ver [[deliveryhub_bug_forma_pagamento_comanda_dashboard]] — resolvido de fato dentro desse plano, já que `buscarPagamentosPorComanda` já existe no backend (`restaurante.service.ts:805`) e será reaproveitado pro relatório Financeiro.

**IMPLEMENTADO 2026-07-18 — todas as 14 tasks concluídas, build frontend (`vite build`) e backend (`nest build`) passando limpo, commitado em `feature/relatorios` nas duas repos (frontend `ef29197`, backend `67ef98a`).** Mergeada em main em 2026-07-23 (ver atualização no topo do arquivo) — usuário testou/aprovou antes do merge.
