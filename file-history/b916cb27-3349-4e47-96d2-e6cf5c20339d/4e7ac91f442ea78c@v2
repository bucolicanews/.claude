---
name: feedback-trigger-suba-para-deploy
description: "frase gatilho \"suba para deploy\" tem workflow fixo definido pelo usuário — sincronizar, atualizar memória, registrar, commitar, push"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: b916cb27-3349-4e47-96d2-e6cf5c20339d
  modified: 2026-07-23T19:32:31.292Z
---

Quando o usuário disser **"suba para deploy"** (ou variação equivalente), executar nesta ordem:

1. Sincronizar clones relevantes (ver [[deliveryhub-dois-clones-server-delivery]] — só faz sentido sincronizar standalone depois que a branch em questão já estiver em `main`, não antes).
2. Atualizar memória (registrar o que foi feito, decisões, estado da branch).
3. Commitar tudo que estiver pendente (frontend + backend submodule, arquivos certos por nome, nunca `-A`).
4. Push das branches pro remoto.

**Why:** usuário definiu explicitamente essa frase como atalho pro fluxo completo de fim-de-tarefa, em vez de pedir cada passo separado toda vez (2026-07-23).

**How to apply:** "commit e push" sozinho, sem a frase "suba pra deploy", não implica os passos 1-2 automaticamente — só executa quando a frase exata (ou equivalente clara) for usada. Importante: push de branch feature (`feat/...`) pro GitHub **não é deploy real** — só main mergeada chega no servidor (VPS via standalone, ver [[deliveryhub-dois-clones-server-delivery]]). Sempre deixar claro pro usuário que o push da branch não colocou nada em produção ainda, a menos que a tarefa já tenha sido explicitamente mergeada em main.
