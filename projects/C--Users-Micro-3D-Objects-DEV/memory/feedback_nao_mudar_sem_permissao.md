---
name: feedback-nao-mudar-sem-permissao
description: usuário exigiu nunca mudar/alterar código sem permissão explícita antes de agir
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 9a4ccde3-452c-4ec0-b92c-406f98a8e50e
  modified: 2026-07-24T02:00:21.009Z
---

Nunca alterar código, arquivos ou comportamento do projeto sem autorização explícita do usuário antes de agir. Perguntar/confirmar plano antes de implementar, não só antes de fazer merge/push.

**Why:** usuário pediu explicitamente "sempre obedeça em não mudar nada sem minha permissão" (2026-07-23), junto com pedido de deploy da feature [[deliveryhub_fix_fechar_caixa_libera_mesa]]. Reforça o padrão já visto em [[feedback_branch_por_tarefa]] e [[feedback_trigger_suba_para_deploy]] de sempre confirmar antes de agir.

**How to apply:** antes de editar código (não só antes de commitar/mergear/dar push), garantir que o usuário já autorizou aquela mudança específica — via pedido direto ou aprovação de um plano proposto. Não expandir escopo, não "aproveitar e já arrumar" outra coisa, não mudar nada além do combinado sem perguntar primeiro.
