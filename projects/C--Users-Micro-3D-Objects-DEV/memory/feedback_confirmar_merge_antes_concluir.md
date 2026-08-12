---
name: feedback-confirmar-merge-antes-concluir
description: "Antes de considerar uma tarefa terminada, confirmar que o commit realmente chegou em main (git log main | grep), não só que foi commitado numa branch"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 078ad696-7b05-45b5-88a0-d9961bf703d9
  modified: 2026-08-10T22:15:44.313Z
---

Regra: não marcar/tratar uma tarefa como concluída só porque rodei `git commit` numa branch de tarefa. Preciso confirmar que ela foi de fato mergeada em `main` antes de seguir pra próxima tarefa ou reportar "feito".

**Why:** em 2026-08-10, o dark mode de `customer-profile`/`customer-account-order-history` (ver [[deliveryhub_plano_dark_mode_retrofit]]) foi commitado numa branch (`fix/dark-customer-profile`) mas o merge pra `main` nunca aconteceu — segui pra outras tarefas na mesma sessão achando que já tinha subido. O usuário só descobriu horas depois testando em produção ("subiu sem o dark"), tive que investigar do zero pra achar que a branch tinha ficado parada.

**How to apply:** depois de qualquer commit numa branch de tarefa, se a intenção era mergear/deployar na mesma sessão, checar explicitamente `git log --oneline main..<branch>` (deve ficar vazio depois do merge) ou `git log --oneline main | grep <hash-do-commit>` antes de dizer "commitado e pronto" ou seguir pra próxima tarefa. Se abrir várias branches na mesma sessão (comum quando o usuário pede várias coisas em sequência), manter uma lista mental/checagem de quais já foram mergeadas e quais ainda estão soltas — não confiar na memória de "acho que já fiz isso".
