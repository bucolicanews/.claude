---
name: feedback-rate-limiting-padrao
description: "Standing rule: every backend API in the ecosystem needs rate limiting (@nestjs/throttler) by default, plus a 3-layer cache/pagination target (backend throttling+cache, API pagination, frontend debounce/dedupe)"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 4dbe6920-8d21-41ad-bdda-8fe00a256e52
  modified: 2026-09-30T16:30:44.442Z
---

Toda API de qualquer projeto do ecossistema precisa de **rate limiting no backend por padrão** — não é algo a adicionar só se abuso for detectado depois. No [[project_deliveryhub]] já está implementado via `@nestjs/throttler`: `ThrottlerGuard` como `APP_GUARD` global em `src/app.module.ts` (limite-padrão 100 req/min/IP), com `@Throttle()` bem mais apertado sobreposto em endpoints sensíveis (login principal 20/min, 2FA 5–10/min, login de garçom 5/min, login de motoboy 10/hora, endpoint público de serviços 5/min).

**Why:** usuário descreveu em 2026-09-30 a combinação de proteção/performance que quer como padrão (Frontend debounce+cache → Backend rate limiting → API paginação+cache → Supabase) e confirmou que o throttling do backend já implementado no DeliveryHub é o padrão certo a generalizar. Formalizado como [[reference_may_memory_vault|ADR-006-RATE-LIMITING-E-CACHE]] no vault.

**How to apply:** ao criar um projeto novo ou módulo novo com API própria, registrar `ThrottlerModule.forRoot(...)` + `ThrottlerGuard` global desde o início (mesmo padrão do DeliveryHub), e aplicar `@Throttle()` próprio (mais apertado que o padrão global) em toda rota de autenticação, 2FA, recuperação de senha, ou qualquer ação de alto custo/abusável. Cache Redis (cache-aside, TTL curto) pra endpoint que recomputa a mesma consulta cara com frequência. Listagem que cresce sem limite (pedidos, clientes, produtos) nasce com paginação real (cursor/page), não `.limit()` fixo solto — isso hoje é inconsistente até no DeliveryHub (débito técnico reconhecido, não é motivo pra bloquear nada, mas corrigir conforme mexer na rota). Camada de frontend (debounce em busca/autocomplete, cache/dedupe de request tipo React Query/SWR) ainda **não existe em nenhum projeto do ecossistema** — é a lacuna mais óbvia se aparecer sintoma de volume (autocomplete disparando request a cada tecla).
