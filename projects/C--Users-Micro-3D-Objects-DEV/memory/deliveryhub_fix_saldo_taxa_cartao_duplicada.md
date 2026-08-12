---
name: deliveryhub-fix-saldo-taxa-cartao-duplicada
description: "Bug critico de cobranca - total_pago nao contava a taxa de cartao ja cobrada, sistema pedia ela de novo no fechamento"
metadata: 
  node_type: memory
  type: project
  originSessionId: ce53651c-2bd0-46ad-9cf7-505577dd6605
  modified: 2026-07-26T21:27:38.763Z
---

Em 2026-07-26, achado e corrigido (MERGEADO EM MAIN + TESTADO PRODUÇÃO) um bug financeiro real em `saldoDevedor()` (`server_delivery/src/salao/salao.service.ts`): o campo `total` da comanda somava a taxa de cartão de todos os pagamentos (`totalTaxaCartao`), mas `total_pago` somava só `p.valor`, sem a taxa. Resultado: a taxa já cobrada num pagamento parcial em cartão continuava contando como "falta pagar", e o sistema pedia ela de novo no fechamento final — overcharge real do cliente.

**Fix:** `total_pago` passou a somar `p.valor + p.taxa_cartao_valor` de cada pagamento. Essa função é a fonte única usada por: modal do caixa (`ComandaModal`), portal do garçom, e página pública de acompanhamento (`mesa-acompanhar`) — o fix propagou pros 3 automaticamente.

**Why:** usuário percebeu a inconsistência comparando "Saldo devedor" exibido com a soma manual dos pagamentos já feitos (via captura de tela real de uma comanda com pagamento parcial em cartão débito).

**How to apply:** qualquer cálculo financeiro novo que envolva taxa de cartão em pagamentos parciais tem que somar `valor + taxa_cartao_valor` junto, nunca só `valor` — é fácil esquecer a taxa em um dos dois lados (total vs total_pago) e reintroduzir o bug.

Ver [[deliveryhub_fix_taxa_cartao_total]], [[deliveryhub_fix_taxa_cartao_resumo_caixa]] (bugs de taxa cartão anteriores, mesma categoria de erro recorrente).
