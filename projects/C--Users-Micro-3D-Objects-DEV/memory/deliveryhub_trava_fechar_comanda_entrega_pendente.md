---
name: deliveryhub-trava-fechar-comanda-entrega-pendente
description: Garçom não fecha comanda com item pronto/preparando sem confirmar entrega — MERGEADO+PUSHADO
metadata: 
  node_type: memory
  type: project
  originSessionId: 009dc941-0da7-4d3e-8fce-f76f4c029d8d
  modified: 2026-07-29T21:30:02.481Z
---

Pedido do usuário 2026-07-29: garçom só pode fechar a comanda se tiver confirmado a entrega de todo item já pronto (mesma confirmação de [[deliveryhub_garcom_confirma_entrega_item]], que só cobria a sincronização com o Painel Bar — faltava travar o fechamento em si).

**Implementado:**
- Front (`src/pages/garcom-portal/index.jsx`): `temEntregaPendente` = algum item com `status` `preparando`/`pronto` e `entregue_garcom` false. Botão "Fechar comanda" desabilitado + aviso amber "Tem item pronto sem confirmar entrega".
- Backend (submodule `server_delivery/src/salao/salao.service.ts`, método `fecharComanda`): mesma checagem antes do update de status, `BadRequestException` se achar item pendente — não confia só no front (Zero Trust, ver [[security_policy_jhon]]).

**Status:** MERGEADO+PUSHADO em ambos os repos (submodule commit `6f89e79`, main commit `ce3f581`, 2026-07-29). EasyPanel/deploy não confirmado ainda.

**How to apply:** se aparecer bug de comanda fechando com item sem entregar, checar se `entregue_garcom` está sendo setado certo por [[deliveryhub_garcom_confirma_entrega_item]] antes de mexer aqui.
