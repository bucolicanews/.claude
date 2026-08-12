---
name: deliveryhub-supabase-local-setup
description: "Como o Supabase local do deliveryhub_white_label foi configurado corretamente (portas, grants, .env)"
metadata: 
  node_type: memory
  type: project
  originSessionId: 3fe4b1f0-07c7-4d4c-a1eb-375df490dc6f
---

Setup local do Supabase pra [[project_deliveryhub_white_label]], commit `cbf7b17` no branch `chore/setup-supabase-local-e-memoria` (2026-07-10).

**Portas customizadas** (`supabase/config.toml`): API 54331, DB 54332, shadow 54330, Studio 54333, Inbucket 54334/54335/54336, analytics 54337. Motivo no comment do arquivo: "delivery-base — portas 5433x para não conflitar com outros projetos" (roda supabase local de outros projetos ao mesmo tempo).

`.env` aponta pro local em vez do projeto remoto:
- `VITE_SUPABASE_URL` / `SUPABASE_URL` = `http://127.0.0.1:54331`
- chaves anon/service_role trocadas pras chaves demo do `supabase start` local.

**Bug corrigido — migration `20260709000001_grants_schema_public.sql`:** GRANT padrão do Supabase nunca foi aplicado ao schema `public` no local. RLS restringe linhas mas não substitui o GRANT base — sem ele toda query falha com erro `42501` (permission denied), mesmo usando `service_role` (que bypassa RLS mas ainda depende do GRANT). Migration dá GRANT USAGE/ALL em tables/routines/sequences pra postgres/anon/authenticated/service_role + ALTER DEFAULT PRIVILEGES pra futuras tabelas.

`.gitignore` ganhou `supabase/.branches/` e `supabase/.temp/` (artefatos do CLI, não devem ir pro git).

**Why:** sem isso, `supabase start` local não fica utilizável — app quebra em toda query com 42501 mesmo com chaves certas.

**How to apply:** se `supabase start` for rodado em outro projeto/máquina e aparecer 42501 mesmo com service_role correto, aplicar essa migration de GRANT primeiro. Confirmar portas no `config.toml` antes de subir se houver outro Supabase local rodando.
