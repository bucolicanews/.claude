---
name: deliveryhub-garcom-nao-entreguei-item
description: Botão "Não entreguei" no portal garçom, ao lado de Entregar — volta item pra fila com aviso vermelho — MERGEADO EM MAIN, testado. Layout/Indo buscar/Já entreguei evoluíram em [[deliveryhub_auto_atendimento_mesa]]
metadata:
  type: project
  originSessionId: current
  modified: 2026-08-04T00:28:02.392Z
---

Pedido do usuário 2026-08-03: em `/garcom/:id`, quando item vai `pronto` e mostra botão **Entregar**, precisa de botão **Não entreguei** do lado. Clicar reverte status pra `enviado` (volta pra fila de preparo) e destaca em Cozinha/Bar/Produção com borda vermelha + observação fixa.

**Decisões confirmadas com usuário:**
- Destaque (borda vermelha + aviso) aparece em Produção + Cozinha + Bar (todas telas KDS, não só Produção).
- Aviso NÃO some quando cozinha/bar reenviar e marcar pronto de novo — só some quando o garçom confirmar a entrega de verdade depois (botão Entregar).

**Implementado:**
- Migration `20260803000001_item_garcom_nao_entregou.sql`: `order_items.garcom_nao_entregou BOOLEAN DEFAULT false` — aplicada no Supabase **local**, falta `db push --linked` no Cloud (ver [[feedback_migration_precisa_push_cloud_apos_deploy]]).
- Backend (`salao.service.ts`): `naoEntregarItem` (exige item `pronto`, seta `status: 'enviado', entregue_garcom: false, entregue_em: null, garcom_nao_entregou: true`). `confirmarEntregaItem` agora também zera `garcom_nao_entregou: false` ao confirmar entrega de verdade. Rota nova `PATCH garcom/comandas/:id/itens/:itemId/nao-entregar` (`salao.controller.ts`).
- `restaurante.service.ts` `getKdsSetor` retorna `garcom_nao_entregou` por item (fonte única usada por Produção/Bar/Cozinha/KDS-token).
- Frontend: botão "Não entreguei" só aparece quando `item.status === 'pronto'` (não em `preparando` — só faz sentido reverter algo que realmente chegou a ficar pronto), com `window.confirm` antes. Telas `restaurante-producao`, `restaurante-bar`, `restaurante-cozinha` (seção salão), `restaurante-kds-setor` (tablet token) ganharam borda vermelha (`border-red-500 ring-1 ring-red-500/40`, prioridade sobre a borda amarela de "próximo da fila") + faixa fixa "Esse pedido não foi entregue — garçom não entregou" (mesmo padrão visual da observação azul existente, cor vermelha).

**Status:** MERGEADO EM MAIN (frontend `f04598d`, backend `19eb4d1`), migration aplicada no Cloud via `db push --linked`, testado ao vivo pelo usuário. Evoluções posteriores (banner "Indo buscar"/"Já entregue pelo garçom", fix de layout dos botões) foram feitas em cima disso na branch `feat/auto-atendimento` — ver [[deliveryhub_auto_atendimento_mesa]].
