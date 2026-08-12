---
name: feedback-branch-por-tarefa
description: Usuario quer branch novo (nunca main direto) toda vez que inicia uma tarefa
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 3fe4b1f0-07c7-4d4c-a1eb-375df490dc6f
---

Regra pedida explicitamente (2026-07-10): criar branch diferente de `main` sempre que iniciar uma tarefa nova em qualquer projeto DEV, em vez de commitar direto em `main`.

**Why:** manter `main` limpo e permitir revisão/reversão por tarefa isolada.

**How to apply:** no início de cada tarefa (antes do primeiro commit), rodar `git checkout -b <tipo>/<descricao-curta>` a partir de `main` atualizado. Nome de branch segue padrão conventional (`feat/`, `fix/`, `chore/`, `docs/`). Só voltar a commitar em `main` se o usuário pedir merge/PR explicitamente. Ver [[feedback_workflow_memory_commits]] pra regra de commit após ação bem-sucedida.

**Pegadinha (2026-07-18):** depois de um merge pra `main` (pedido explícito do usuário), o repo fica na `main` — se o usuário pedir uma tarefa NOVA logo em seguida na mesma sessão, é fácil esquecer e começar a editar já na `main` por inércia (aconteceu: editei 16 arquivos do menu lateral direto na main antes de perceber). Corrigido criando branch em cima do estado sujo (`git checkout -b` preserva as mudanças não commitadas) e seguindo o fluxo normal depois. **Sempre checar `git branch --show-current` antes do primeiro Edit de uma tarefa nova, não só no início da sessão.**
