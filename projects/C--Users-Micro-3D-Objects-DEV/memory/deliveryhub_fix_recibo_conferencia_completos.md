---
name: deliveryhub-fix-recibo-conferencia-completos
description: "Recibo de pagamento e conferencia da comanda saiam incompletos (sem taxa por pagamento, TOTAL zerado, sem garcom/pagamentos ja feitos)"
metadata: 
  node_type: memory
  type: project
  originSessionId: ce53651c-2bd0-46ad-9cf7-505577dd6605
  modified: 2026-07-26T21:27:51.123Z
---

Em 2026-07-26, corrigidos vários gaps nos comprovantes impressos do módulo Salão (MERGEADO EM MAIN + TESTADO PRODUÇÃO):

1. `pagar()` no backend não selecionava `taxa_cartao_valor` na query de pagamentos — o recibo impresso no momento do fechamento saía sem taxa por forma de pagamento.
2. TOTAL do recibo usava "quanto faltava cobrar agora" (podia ser R$0,00 se pagamentos parciais já cobriam tudo) em vez do valor geral da comanda inteira (produtos ± desconto/acréscimo + gorjeta + taxa). Corrigido pra sempre mostrar o total geral, com `pagar()`/`reimprimirRecibo()` retornando `total_geral`/`total` já com essa soma pronta.
3. Templates de impressão (`printComanda.js` navegador + `formatarReciboTexto`/`formatarConferenciaTexto` no agente térmico) não mostravam a taxa individual de cada pagamento no breakdown, só um total agregado.
4. Conferência (ticket "não é recibo fiscal") não mostrava nome do garçom nem a lista de pagamentos já feitos — só a forma de pagamento selecionada na tela no momento.
5. Modal da comanda já paga (`ComandaModal`) escondia o bloco inteiro de desconto/acréscimo/gorjeta/taxa/total geral fora do modo edição — sumia tudo depois de fechada.

**Why:** usuário testou uma comanda real com pagamento parcial em cartão e viu o recibo sem a taxa, sem o total, sem os detalhes.

**How to apply:** qualquer print/comprovante novo do módulo Salão precisa incluir: subtotal, desconto, acréscimo, gorjeta, taxa de cartão (total E por pagamento), forma de pagamento, e o total geral real — não "quanto falta" ou "quanto foi cobrado agora".

Ver [[deliveryhub_fix_saldo_taxa_cartao_duplicada]] (bug relacionado, mesma sessão).
