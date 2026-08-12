---
name: deliveryhub-taxa-cartao-garcom-portal
description: Taxa de cartão no portal garçom (comanda + prévia antes de pagar) — mesma metodologia do Salão, MERGEADO EM MAIN E TESTADO EM PRODUÇÃO
metadata:
  type: project
  originSessionId: current
  modified: 2026-07-25T12:35:53.584Z
---

Continuação de [[deliveryhub_fix_taxa_cartao_total]] e [[deliveryhub_fix_taxa_cartao_resumo_caixa]] (essas duas eram Salão). Usuário pediu a mesma metodologia no **portal garçom** (`src/pages/garcom-portal/index.jsx`).

Duas partes:
1. **Listagem de pagamentos da comanda**: já mostrava "+ taxa" no label mas o valor exibido era só `p.valor` (sem somar taxa). Fix: `+ taxa` em laranja (`text-[#FF441F]`) e valor = `fmt(p.valor + (p.taxa_cartao_valor || 0))` — igual ao padrão já usado em `restaurante-salao/index.jsx`.
2. **Prévia antes de confirmar pagamento** (pedido em seguida na mesma sessão): ao digitar valor e escolher crédito/débito, mostra "+ taxa cartão (X%): RY — cobrar RZ" antes do garçom clicar "Pagar". Só visual, não altera nada até confirmar.

Backend: portal garçom usa endpoint próprio (`salao.service.ts` → `obterComanda`, rota `GET comandas/:id` do `salao.controller.ts`), diferente do endpoint do Salão/caixa. Não tinha `taxa_cartao_percentual` na resposta — adicionado no mesmo select que já buscava `gorjeta_percentual` de `restaurants`, retornado como `comanda.taxa_cartao_percentual`.

**Why:** garçom lança pagamento parcial em cartão direto na mesa, precisa ver taxa antes de cobrar do cliente (evita cobrar errado ou surpresa no fechamento).

**Gotcha:** portal garçom (`garcomService.js`/`salao.controller.ts`, auth por `garcomId`) é um caminho de backend separado do Salão/caixa (`restauranteService`/auth de dono) mesmo operando na mesma tabela `orders`/`comanda_pagamentos` — ao replicar fix de um pro outro, sempre checar se o endpoint usado por cada tela já expõe o campo necessário (aqui faltava `taxa_cartao_percentual` na resposta do garçom).

Commits mergeados em `main` (2026-07-25):
- backend (`server_delivery`, submodule + standalone sincronizados): branch `fix/taxa-cartao-preview-garcom`, commit `05bc17a`.
- frontend (`deliveryhub_white_label`): branch `fix/taxa-cartao-garcom-comanda`, commit `95102bd` (inclui o ponteiro do submodule).

Push feito pro GitHub (dispara deploy EasyPanel). Testado e confirmado pelo usuário em produção 2026-07-25.
