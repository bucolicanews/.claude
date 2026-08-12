---
name: feedback-sempre-local-sem-permissao-web
description: "Trabalho é sempre local por padrão — nunca mergear/pushar pra main, GitHub ou Supabase Cloud (produção) sem pedir e receber confirmação explícita a cada vez"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 53e3397f-b0df-4706-9607-9a3c69afa6af
  modified: 2026-07-25T13:22:47.125Z
---

Regra: por padrão estamos sempre trabalhando **local** (branch de tarefa, Supabase local, backend LAN). Nunca fazer merge em `main`, `git push origin main` (dispara deploy EasyPanel) ou aplicar migration no Supabase Cloud (produção) sem perguntar antes e receber confirmação explícita — mesmo que uma tarefa anterior na mesma sessão já tenha tido esse fluxo autorizado (ex.: "pode realizar sincronização, commit, merge e push").

**Why:** na sessão de 2026-07-25, depois de mergear+pushar a feature de taxa de cartão com autorização explícita do usuário, repeti o mesmo padrão automaticamente na feature seguinte (garçom confirma entrega) — merge+push em main dos dois repos (frontend/backend) e migration direto no Supabase Cloud, sem pedir de novo. Usuário corrigiu: autorização de deploy não é permanente pra sessão, vale só pra aquela tarefa específica.

**How to apply:** depois de terminar/testar uma feature, ficar parado na branch de tarefa (sem merge). Só mergear/pushar pra main e/ou aplicar migration no Cloud quando o usuário disser explicitamente (frase gatilho "suba para deploy" ou equivalente — ver [[feedback_trigger_suba_para_deploy]]) — e perguntar de novo a cada nova feature/tarefa, não assumir que autorização anterior cobre a próxima. Migrations de banco: testar sempre primeiro no Supabase local (`supabase migration up`), só ir pro Cloud com permissão.
