---
name: deliveryhub-impressora-sangria-acrescimo
description: "Feature: impressora dedicada em Config pra imprimir recibo de Sangria/Adição do caixa, mesmo mecanismo do recibo de venda"
metadata: 
  node_type: memory
  type: project
  originSessionId: 31478d17-6022-4d9f-8514-8d3a6dd52dd7
  modified: 2026-08-09T23:10:58.942Z
---

Nova config em Config > "Impressora de sangria/adição" (`restaurants.sangria_acrescimo_impressora_id`, migration `20260809000002_sangria_acrescimo_impressora.sql`). Toda Sangria/Adição registrada no caixa (`CaixaAtualPanel.jsx`) gera recibo: via agente local pareado (job em `impressao_jobs`) se configurada, senão fallback de impressão pelo navegador (`printReciboMovimentoCaixa` em `src/utils/printComanda.js`).

Backend: `server_delivery/src/restaurante/restaurante.service.ts` — `imprimirReciboMovimento()` privado, chamado em `adicionarSaida`/`adicionarEntrada`, mesmo padrão do `SalaoService.imprimirReciboSeConfigurado` (recibo de venda).

Recibo do fallback navegador refeito depois de reportado bug visual: rótulo (Descrição/Meio/Valor) em bloco separado do valor (antes ficava tudo grudado numa linha só quando descrição era longa) — funciona tanto A4 quanto térmica em rolo.

**Status:** MERGEADO+PUSHADO ambos repos (frontend+submodule) + MIGRATION CLOUD (`db push --linked`) + TESTADO PRODUÇÃO, EasyPanel confirmado 2026-08-09.

**Why:** dono quer comprovante físico de toda sangria/acréscimo pra auditoria/controle de caixa.

**How to apply:** referência de padrão pra qualquer novo tipo de recibo dedicado (config de impressora opcional + fallback navegador) — replicar a mesma estrutura: coluna nullable FK impressoras, `imprimirXSeConfigurado`/`imprimirX` que insere em `impressao_jobs` ou devolve `{via:'navegador'}`, função de print no `printComanda.js` como fallback.
