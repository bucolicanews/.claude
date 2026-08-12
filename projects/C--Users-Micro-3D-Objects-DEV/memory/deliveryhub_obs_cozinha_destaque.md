---
name: deliveryhub-obs-cozinha-destaque
description: "Observação do item na tela da cozinha ganhou destaque visual (fundo azul, letra branca, piscando) — MERGEADO EM MAIN"
metadata: 
  node_type: memory
  type: project
  originSessionId: 445f28c5-3670-4658-a749-e59c81fd1527
  modified: 2026-07-26T02:10:59.440Z
---

Tela da cozinha (`/restaurante/producao` ou equivalente, `src/pages/restaurante-cozinha/index.jsx`) mostrava a observação do item (`item.observacao`) em texto âmbar pequeno, fácil de passar despercebido. Trocado por `text-sm font-bold text-white bg-blue-600 rounded px-1.5 py-0.5 animate-pulse` — primeira tentativa foi vermelho (`text-red-500`), usuário achou ruim de ler e pediu fundo azul/letra branca.

**Mergeado em main em 2026-07-26:** branch `feat/obs-cozinha-destaque`, commits `2afd1b7` (chore: fix de drift no ponteiro do submodule deixado do merge anterior) + `351150d` (feat: a mudança visual em si). Push em main: `67d14a3`. Sem mudança de backend, não precisou sincronizar clone standalone.

**Gotcha confirmado:** merge de branch feature pode deixar o ponteiro do submodule apontando pro commit pré-merge do backend em vez do commit de merge em main, se a branch feature não foi rebasada/atualizada depois do backend já ter sido mergeado — reforça [[deliveryhub_dois_clones_server_delivery]]. Vale sempre conferir `git diff server_delivery` antes de commitar em tarefas subsequentes.

**Why:** cor âmbar pequena não chamava atenção o suficiente na cozinha; vermelho piscando foi tentado primeiro mas achado difícil de ler — azul com texto branco resolveu contraste + urgência.

**How to apply:** feature simples, mergeada e pushada, validada pelo usuário ("perfeito") antes do merge. Deploy real no EasyPanel não confirmado.
