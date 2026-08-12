---
name: deliveryhub-resumo-dinheiro-troco-comanda
description: "Resumo financeiro da comanda (garçom + dono) passou a mostrar dinheiro recebido e troco agregados, não só no recibo"
metadata: 
  node_type: memory
  type: project
  originSessionId: a521afbd-755c-4d62-a7bd-922e4503b67f
  modified: 2026-07-31T20:26:34.866Z
---

Resumo financeiro da tela de comanda (garcom-portal/index.jsx e restaurante-salao/index.jsx,
componente `ComandaModal`) agora soma pagamentos em dinheiro (`forma_pagamento === 'cash'`
com `valor_recebido`) e mostra linhas "Dinheiro recebido" e "Troco" junto de valor da
comanda/gorjeta/já pago/falta pagar — só aparece quando existe pagamento em dinheiro.

**Why:** já existia essa info por pagamento individual (linha "Dinheiro: X · Troco: Y · Venda: Z"
dentro da lista de pagamentos), e também no recibo impresso — mas não no resumo agregado da
comanda, que é o que fica visível de cara pro garçom/dono sem precisar rolar a lista de pagamentos.

**How to apply:** MERGEADO+PUSHADO em main nos dois repos (submodule `788bdaa`, principal
`be37cd5`), TESTADO no navegador local antes do merge, DEPLOY EASYPANEL CONFIRMADO OK
(sem erros). Sem migration — só mudança de código (select do backend + JSX). Relacionado a
[[deliveryhub_white_label]].

Gotcha real encontrado: o resumo agregado só funcionou depois de descobrir que o backend
(`obterComanda` em salao.service.ts e `comandaDetalhe` em salao-pdv.service.ts) nunca
selecionava `valor_recebido`/`troco` da tabela `comanda_pagamentos` — só o recibo impresso
tinha esses dados (passados direto na hora do pagamento, sem vir do banco). Se um resumo de
comanda em dinheiro/troco "não aparecer" de novo, checar primeiro se o SELECT do endpoint
inclui essas colunas antes de mexer no frontend.
