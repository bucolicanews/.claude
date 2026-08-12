---
name: deliveryhub-fix-fechar-caixa-libera-mesa
description: "fechar caixa com mesa ocupada agora libera a mesa automaticamente, comanda vira pendência/fiado — MERGEADO EM MAIN e deployado"
metadata: 
  node_type: memory
  type: project
  originSessionId: 9a4ccde3-452c-4ec0-b92c-406f98a8e50e
  modified: 2026-07-24T02:00:31.105Z
---

Fechar caixa (Salão) com mesa ocupada travava o fluxo: mesa sem comanda vinculada (ex: bloqueada manualmente) bloqueava o fechamento sem opção de forçar, e mesmo com `permitir_pendencias`, a tabela `mesas` nunca era liberada — mesa ficava "empatada" pro próximo cliente.

Correção: `fecharCaixa` (`server_delivery/src/restaurante/restaurante.service.ts`, dentro do bloco pós-check de `permitir_pendencias`) agora libera (`status → 'livre'`) todas as mesas em aberto ao fechar o caixa. Comanda vinculada continua pendente (fiado), cobrada no caixa aberto quando o pagamento acontecer (lógica de realocação já existia, ver [[deliveryhub_caixa_fiado_multi_caixa]]). Front (`FecharCaixaModal.jsx`) agora conta mesa sozinha como pendência forçável e avisa que a mesa é liberada.

**Why:** pedido direto do usuário (2026-07-23) — "mesa deve ser fechada, caso fique fiado ou sem fechar vira comanda pra não empatar a mesa, e o caixa fecha".

**How to apply:** branch `fix/fechar-caixa-libera-mesa` — mergeada em `main` e pushed em ambos repos (frontend `deliveryhub_white_label` e backend `server_delivery`), clone standalone (`DEV/server_delivery`, o que roda na VPS) sincronizado via `git pull`. Testado pelo usuário antes do merge. Ver [[deliveryhub_dois_clones_server_delivery]] pro fluxo de sync, e [[feedback_nao_mudar_sem_permissao]] pra regra vigente daqui pra frente.
