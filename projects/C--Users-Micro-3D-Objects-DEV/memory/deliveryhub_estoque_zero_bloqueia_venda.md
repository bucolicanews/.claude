---
name: deliveryhub-estoque-zero-bloqueia-venda
description: Produto com quantidade_estoque zero/nulo some das telas de venda (delivery, garçom, Salão dono) — MERGEADO EM MAIN
metadata:
  type: project
  originSessionId: current
  modified: 2026-07-25T15:36:02.922Z
---

Campo `products.quantidade_estoque` (migration `20260718000001_products_estoque.sql`) existia só como decorativo/relatório desde 2026-07-18 — comentário da própria migration dizia "sem decremento automático na venda". Usuário pediu pra passar a bloquear a venda de fato quando chega em zero.

**Decisão de regra (perguntei, usuário confirmou):** bloqueia sempre que `quantidade_estoque` for 0 **ou null**, sem exceção — mesmo sabendo que a coluna é `NOT NULL DEFAULT 0`, ou seja todo produto que o dono nunca setou estoque manualmente também some da venda até ele definir uma quantidade > 0. Não tem toggle "controla estoque" nem exceção por tipo de produto.

Implementado como filtro `quantidade_estoque > 0` (Postgres `.gt()` já exclui 0 e NULL) em todo lugar que lista produto **pra comprar**:
- Backend: `catalogo.controller.ts` (`todosOsProdutos`, `montarCardapio` — cardápio público delivery), `salao.service.ts` `produtos()` (picker garçom), `tags.service.ts` (carrosséis "mais pedidos" e tag manual).
- Frontend: `restaurante-salao/index.jsx`, filtro **client-side** nos dois pickers do dono (adicionar item na comanda + Venda balcão) — não dá pra filtrar no backend porque o endpoint (`meusProdutos()`/`GET /produtos`) é o mesmo usado pela tela de admin de Produtos e pelo relatório "Sem estoque", que **precisam** continuar mostrando os produtos zerados pro dono repor.

**Gotcha evitado:** quase filtrei `meusProdutos()` no backend também — teria quebrado o filtro "Sem estoque" da tela de Produtos e o relatório de reposição (ambos dependem desse mesmo endpoint trazendo os itens zerados). Corrigido antes de commitar: backend desse endpoint fica sem filtro, só o picker de venda filtra na tela.

Fora do escopo (não mexido): endpoint de admin da plataforma (`adminService.js`/`produtos.service.ts` `listarPorEmpresa`) e ferramenta MCP (`produtos.tools.ts`) — não são superfície de venda direta ao cliente.

Commits mergeados em `main` (2026-07-25), testado local antes do push:
- backend (`server_delivery`, submodule + standalone sincronizados): branch `feat/bloqueia-venda-estoque-zero`, commit `ee9561b`.
- frontend (`deliveryhub_white_label`): branch `feat/bloqueia-venda-estoque-zero`, commit `442f278`.

Push feito, dispara deploy EasyPanel. Teste em produção ainda pendente de confirmação do usuário.
