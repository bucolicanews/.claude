---
name: deliveryhub-troco-pix-visual-mobile-comandas
description: Troco via Pix no pagamento em dinheiro + fonte maior nas comandas (garçom/PDV) + Dinheiro/Saldo Pix reais no caixa/dashboard
metadata: 
  node_type: memory
  type: project
  originSessionId: 3ad9965e-127d-4b5d-aa3a-c07276245050
  modified: 2026-08-09T21:28:54.001Z
---

Duas mudanças pedidas juntas em `/restaurante/salao` (comandas) e telas de caixa:

**1) Visual mobile maior**: fonte/botões maiores no card de item, header e saldo — portal garçom (`ComandaDetalhe`) e PDV Salão (`ComandaDetalheModal`). Cuidado tomado pra não quebrar layout (só bump de `text-*`/tamanho de botão, sem mexer em estrutura).

**2) Troco via Pix**: ao pagar em dinheiro com troco, checkbox opcional "Troco via Pix" — em vez de dar troco físico, registra que o troco foi devolvido por Pix (dono manda por fora, não é integração real de Pix). Não desfalca a espécie do caixa, sai como saída `meio:'pix'` no ledger do caixa. Coluna `troco_via_pix` em `comanda_pagamentos`. Dono pode corrigir depois um pagamento já lançado (botão "Troco Pix" na lista de pagamentos do PDV — endpoint dedicado `alterarTrocoPix`, faz estorno+relançamento no meio certo).

**Gotcha grande (múltiplas idas e vindas nessa sessão):** o app tinha VÁRIAS métricas parecidas de "Dinheiro"/"Pix" espalhadas (📵 "Vendas espécie" = valor da venda; "Espécie no Caixa" = fluxo real; "Vendas digital" = receita por forma; "Recebido por forma de pagamento" = idem com contagem) — nenhuma refletia o troco via Pix corretamente, causando MUITA confusão do usuário testando (relatou resultados "errados" repetidas vezes até isolar o problema certo). Fórmula final que bateu com o esperado do usuário:
- `Dinheiro exibido = valor_da_venda_em_dinheiro − pix_calculado` (pix_calculado é negativo quando saiu troco via pix, então isso SOMA o troco de volta)
- `Pix exibido = valor_da_venda_em_pix + pix_calculado` (subtrai o troco)
- **Importante**: só ajusta quando o troco foi via Pix. Troco físico (dinheiro) já deixava o valor da venda certo sozinho — não pode aplicar o ajuste nesse caso (bug que corrigimos: usar `cash_recebido` bruto inflava o Dinheiro mesmo em troco físico).
- Backend expõe `entradas_pix`/`saidas_pix`/`pix_calculado` em `calcularResumo` (`restaurante.service.ts`), consumido em `restaurante-dashboard/index.jsx` ("Recebido por forma de pagamento" + card novo "Troco pago via Pix") e `restaurante-financeiro/CaixaAtualPanel.jsx` ("Vendas por método" + "Digital (PagBank)").
- Card Pix mostra "Saldo Pix" (líquido) + sub-linha "Recebido: RX" (bruto, sem desconto do troco) — pedido explícito do usuário.

**Debug tool útil**: pra rastrear caixa local, `curl http://127.0.0.1:54331/rest/v1/caixas?status=eq.aberto&select=...` com a service_role key do `supabase status` — mais rápido que psql (não tinha instalado). Cuidado: `numero_comanda` (exibido "Comanda #N") ≠ `orders.id` (chave real) — não dá pra cruzar direto sem consultar a tabela `orders`.

Status: MERGEADO EM MAIN + PUSHADO (2026-08-09), ambos repos, migration `troco_via_pix` — testado pelo usuário, confirmado batendo certo. Ver [[deliveryhub-venda-balcao-nome-cliente-envio-fechamento]] (mesma área de código).
