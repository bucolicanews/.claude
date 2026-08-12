---
name: deliveryhub-dois-clones-server-delivery
description: existem 2 clones locais do repo server_delivery (mesmo remoto) — precisa manter os dois sincronizados manualmente
metadata: 
  node_type: memory
  type: project
  originSessionId: 61bd9ff7-dd86-42e2-98a3-bd0208787756
---

Duas cópias locais do mesmo repositório `jmoka/serer_delivery`, sem relação de submodule entre elas:

- `C:\Users\Micro\3D Objects\DEV\server_delivery` — **clone principal**, standalone. É o que o usuário sobe/testa pra **VPS/produção** (EasyPanel) — confirmado explicitamente pelo usuário em 2026-07-14 e novamente 2026-07-15.
- `C:\Users\Micro\3D Objects\DEV\deliveryhub_white_label\server_delivery` — git submodule dentro do repo frontend, é onde o trabalho de desenvolvimento (eu) acontece. **Sempre manter atualizado** em relação ao principal (mesma branch, mesmo commit).

**Why:** setup histórico — o backend foi separado do frontend virando submodule, mas o usuário já tinha (ou criou depois) um clone solto pra testar localmente antes de deployar, sem perceber que agora existem duas cópias divergentes do mesmo código. Confirmado 2026-07-15: standalone é literalmente "o que está rodando na VPS" — sempre tratar como espelho do que está em produção.

**How to apply:** depois de qualquer commit/push meu no submodule (`deliveryhub_white_label/server_delivery`), rodar `git pull origin main` na standalone (`DEV/server_delivery`) antes do usuário testar local ou subir pra VPS — os dois devem ficar sempre no mesmo commit de `main`. Se o usuário reportar bug/comportamento estranho testando local, primeiro checar `git log --oneline -1` nos dois clones pra confirmar que não estão dessincronizados (foi a causa raiz de um bug de "imagem não aparece" em 2026-07-14 — standalone estava ~15 commits atrasado, sem o módulo Salão inteiro). Verificado em 2026-07-15: `git fetch` + `git status` + `git log --oneline -5` nos dois é suficiente pra confirmar mesmo commit.

**Cuidado extra:** standalone tem `.env.example` (arquivo versionado) com risco de segredo real colado por engano (achado em 2026-07-15: linha com `GARCOM_JWT_SECRET=` valor real, não placeholder). Sempre checar `git diff` antes de comitar mudanças nesse repo — nunca deixar segredo real em arquivo `.example`.
