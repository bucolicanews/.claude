---
name: project-deliveryhub-white-label
description: Projeto deliveryhub_white_label - plataforma delivery white label (React front + NestJS-style backend)
metadata: 
  node_type: memory
  type: project
  originSessionId: 3eaea5f7-78bd-486d-86dd-4fe0868eb5c2
---

Projeto ativo em `C:\Users\Micro\3D Objects\DEV\deliveryhub_white_label`. Repo git próprio (não é o mesmo repo do my_memory), branch `main`, sincronizado com `origin/main`.

Stack real do projeto (README): React 18, Vite, Redux Toolkit, TailwindCSS, React Router v6, D3.js/Recharts, React Hook Form, Framer Motion, Jest. Backend em `backend/` (NestJS - dist compilado com auth guards: admin, cozinha, jwt, motoboy, restaurant-owner; módulos empresas, categorias, motoboy, mcp).

Domínio: delivery multi-restaurante com áreas admin, motoboy (entregador), cozinha, cliente. Features recentes (2026-07): frete cobrado por motoboy, troco, cancelamento com motivo, vínculo cliente-restaurante, checkout com resumo de pedido.

**Why:** projeto white label = precisa suportar múltiplos tenants/restaurantes com áreas separadas por papel (admin/cozinha/motoboy/cliente).

**How to apply:** aplicar [[security_policy_jhon]] (multi-tenant RLS, RBAC por papel) e [[design_system_delivery]] (visual Rappi-style) neste projeto. Seguir [[engineering_guidelines_jhon]] para qualquer código novo no backend NestJS e frontend React.

Repo GitHub: `jmoka/deliveryhub_white_label` (SSH). Identidade git local deste repo: `jmoka` / `jmokatavares@gmail.com`.

Setup local do Supabase (portas customizadas, fix de grants) registrado em [[deliveryhub_supabase_local_setup]].

Backend foi separado pro repo próprio `server_delivery` (`C:\Users\Micro\3D Objects\DEV\server_delivery`, GitHub `jmoka/serer_delivery`). Pendência técnica de deploy em produção (frontend usa `/api` relativo) registrada em [[deliveryhub_pendencia_api_url_producao]].

Ver vault completo em [[my_memory_vault]].
