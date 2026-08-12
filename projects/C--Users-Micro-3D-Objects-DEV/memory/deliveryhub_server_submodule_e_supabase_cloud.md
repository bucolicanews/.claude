---
name: deliveryhub-server-submodule-e-supabase-cloud
description: server_delivery e git submodule dentro do deliveryhub_white_label; projeto pivotou de VPS self-hosted pra Supabase Cloud
metadata: 
  node_type: memory
  type: project
  originSessionId: 3fe4b1f0-07c7-4d4c-a1eb-375df490dc6f
---

Decisões de 2026-07-10 (commits `7c0c165`, `ef3f023` no branch `chore/setup-supabase-local-e-memoria`):

**Backend como submodule:** o usuário quer clonar só o `deliveryhub_white_label` e já ter o backend junto pra instalação local, mas continuar fazendo deploy do `server_delivery` separado (VPS/serviço próprio). Solução: `server_delivery/` dentro do front é um **git submodule** apontando pro repo `jmoka/serer_delivery` (não é cópia solta — evita divergência de código entre as duas cópias). `.env` do submodule não é versionado (mesma regra do repo standalone), precisa criar manualmente com `SUPABASE_URL`/`SUPABASE_SERVICE_ROLE_KEY` a cada clone novo. A pasta `backend/` antiga (embutida, pré-separação) foi removida do repo.

**Pivot de VPS self-hosted pra Supabase Cloud:** tentativa de self-host via EasyPanel (ver [[deliveryhub_vps_supabase_secrets]]) travou em problemas de deploy (env vars resetando no painel, compose quebrando com `DOCKER_SOCKET_LOCATION` vazio). Projeto migrou pra usar **Supabase Cloud** (`https://gkeolhhcptavftwloucj.supabase.co`) como banco de produção/teste em vez do self-host na VPS. As migrations desse projeto Cloud ainda não foram aplicadas (pendente — usar `supabase link --project-ref gkeolhhcptavftwloucj` + `supabase db push`).

**Bug de código corrigido:** `src/lib/supabase.js` sempre substituía `VITE_SUPABASE_URL` por `window.location.origin` em modo dev (pra funcionar o proxy do Vite com Supabase local) — isso quebrava qualquer front rodando em dev contra Supabase remoto (Cloud ou VPS), causando 500 em signup/login (proxy tentava falar com `127.0.0.1:54331` que não estava rodando). Corrigido pra só aplicar esse truque quando `VITE_SUPABASE_URL` for de fato local (127.0.0.1/localhost).

**Pendência ainda aberta:** `SUPABASE_SERVICE_ROLE_KEY` usado no `server_delivery/.env` (tanto no repo standalone quanto no submodule) está com o valor da chave `anon`/`publishable`, copiado errado — precisa pegar a chave `service_role` real em Settings → API do projeto Supabase Cloud.

Ver [[project_deliveryhub_white_label]], [[deliveryhub_pendencia_api_url_producao]].
