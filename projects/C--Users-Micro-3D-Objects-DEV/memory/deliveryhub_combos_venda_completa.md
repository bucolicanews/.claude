---
name: deliveryhub-combos-venda-completa
description: "Combo ligado na venda (delivery+salão+marketplace) + cadastro com preço por produto e ativar/desativar — MERGEADO+PUSHADO ambos repos, migrations na Cloud, TESTADO"
metadata: 
  node_type: memory
  type: project
  originSessionId: 31cc1ec5-40ca-45dd-ab92-f454ec7203d9
  modified: 2026-07-30T21:32:52.452Z
---

Sessão 2026-07-30: usuário perguntou "os combos tão aparecendo pro salão, verifique se aparece no delivery também" — achado que combo **não vendia em lugar nenhum**, só existia na tela de gestão (CRUD). Virou feature grande em várias rodadas.

**Modelo de venda:** combo explode nas linhas dos produtos reais que o compõem (`order_items` continua só sabendo de `products` — estoque/KDS/impressão por setor funcionam sem mudar schema). `CombosService.expandir()` (`server_delivery/src/combos/combos.service.ts`) é o núcleo, usado por `pedidos.service.ts` (delivery), `salao.service.ts` (garçom) e `salao-pdv.service.ts` (dono/PDV).

**Preço por produto (não fator único):** `combo_items.preco_no_combo` guarda quanto o dono decide cobrar por CADA produto dentro do combo. `combos.price`/`combos.preco_promo` são calculados no backend (Zero Trust, não confia no client) a partir disso: `price` = soma do preço real de tabela, `preco_promo` = soma do `preco_no_combo`. Cadastro (`restaurante-combos/index.jsx`) mostra os dois como texto read-only calculado ao vivo conforme o dono ajusta produto/quantidade/preço.

**Disponibilidade:** `CombosService.listarComDisponibilidade()` — combo some da venda se ele mesmo tiver `is_active=false` OU qualquer produto que o compõe tiver `quantidade_estoque<=0`/inativo (mesma regra de [[deliveryhub_estoque_zero_bloqueia_venda]]). Endpoints de venda filtram fora; endpoint de gestão (`meusCombos`) mostra tudo com o campo `disponivel` pro dono corrigir. `expandir()` revalida de novo na hora da compra (corrida entre 2 vendas).

**Exibição agrupada:** `order_items` ganhou `combo_nome` (nome pra mostrar) e `combo_quantidade` (quantas unidades do combo aquela linha representa, mesmo valor repetido em cada linha do lote de compra — usado pra somar certo mesmo se juntar lotes de compra diferentes do mesmo combo ao reagrupar). Util `src/utils/agruparItensComanda.js` reagrupa as linhas soltas de volta num card "Nx Nome do Combo" nas 3 telas (garçom, comanda do dono, Venda balcão).

**Onde aparece agora:**
- `/r/:slug` (loja): aba "🍱 Combos" no filtro de categoria + carrossel "Combos em destaque" no topo.
- `/` marketplace (`menu-catalog-product-browse`): chip "🍱 Combos" (troca a seção "Compare preços" pra grid de combos de todos os restaurantes) + carrossel — endpoint novo `GET /api/r/combos` (cross-restaurante).
- Garçom (`garcom-portal`) e dono (`restaurante-salao`, comanda de mesa + Venda balcão): combo aparece junto do picker de produto numa categoria "Combos", com badge preço promo riscado.
- Gestão (`restaurante-combos`): ativar/desativar (já existia no backend, só faltava botão), preço automático, campo "Cobrar no combo" por produto.

**Status: MERGEADO+PUSHADO main em ambos os repos 2026-07-30 (submodule `bd469e4`, main `4f26557`). Migrations 20260730000003/4/5 aplicadas local + Cloud via `db push --linked`. Testado pelo usuário em cada etapa. EasyPanel/deploy do código ainda por confirmar.**

**How to apply:** se aparecer combo com preço estranho, checar `combo_items.preco_no_combo` de cada item — não é mais fator proporcional, é direto por produto. Se disponibilidade parecer errada, checar `CombosService.listarComDisponibilidade` (produto inativo ou zerado em qualquer item do combo já esconde ele inteiro).
