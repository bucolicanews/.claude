---
name: deliveryhub-filtro-fluxo-caixa-financeiro
description: "Filtro por forma de pagamento + colunas cliente/atendente/taxa no relatório financeiro, e botões Sangria/Adição na Análise por Período"
metadata: 
  node_type: memory
  type: project
  originSessionId: 768e8f2d-1fa6-44a3-a4fc-12a38bb5b441
  modified: 2026-08-02T22:25:37.022Z
---

Duas entregas na página `/restaurante/relatorios/financeiro` (`src/pages/restaurante-relatorios/Financeiro.jsx`) e em `/restaurante/financeiro` (`src/pages/restaurante-financeiro/index.jsx`), backend em `server_delivery/src/restaurante/restaurante.service.ts` método `getRelatorio`.

**Filtro por forma de pagamento (Financeiro.jsx — relatório analítico):**
Cards PIX/Dinheiro/Cartão/+Taxa cartão viram clicáveis, filtram a lista "Fluxo de Caixa Detalhado" (toggle, clica de novo limpa). Lista ganha colunas Cliente, Atendente (garçom ou "Balcão"/aberto_por_nome), Taxa Cartão e Valor Total (valor+taxa) — na tela e no relatório impresso. Backend: cada item de `fluxo_caixa` agora carrega `cliente_nome`, `atendente_nome`, `taxa_cartao_valor`.

**Botões Sangria/Adição (restaurante-financeiro/index.jsx — painel gerencial):**
Antes só "Saídas" (sangrias) tinha lista detalhada agregando todos os caixas sobrepostos ao período buscado; "Adições" (entradas) não existia agregado por período, só via `caixa.entradas` do caixa aberto atual (CaixaAtualPanel). Adicionei agregação de `entradas` por período no backend igual já fazia com `saidas` (cruza todos os caixas que se sobrepõem ao range `de`/`ate`, filtra cada lançamento pelo `criado_em`). Botões "Sangria (N)"/"Adição (N)" ao lado do título "Análise por Período" abrem a lista completa de lançamentos do período — não é só o caixa do dia.

**Why:** usuário queria auditar rapidamente todos os pagamentos de uma forma específica e todas as sangrias/adições de um período (não só sessão de caixa atual), sem precisar abrir caixa por caixa.

**How to apply:** ao mexer em relatório financeiro/caixa, lembrar que existem DUAS páginas parecidas — `restaurante-relatorios/Financeiro.jsx` (relatório analítico, print) e `restaurante-financeiro/index.jsx` (painel gerencial com caixa atual + histórico) — cada uma com seu próprio `buildPrintHtml`/`buildPrint` e sua própria cópia de `PAYMENT_LABELS`/`ORIGEM_LABELS`. `getRelatorio` no backend alimenta as duas.

MERGEADO+PUSHADO MAIN (ambos repos) + DEPLOY CONFIRMADO PELO USUÁRIO.
