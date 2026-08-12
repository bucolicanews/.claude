---
name: deliveryhub-redis-cache-catalogo
description: "Cache Redis (cache-aside, TTL curto) nas rotas publicas /r/* do catalogo — MERGEADO+PUSHADO+TESTADO EM PRODUCAO (confirmado com MONITOR)"
metadata: 
  node_type: memory
  type: project
  originSessionId: 4e4fed69-10b0-42ab-9d2d-aab41161c9b5
  modified: 2026-07-31T16:21:18.531Z
---

Cache Redis no backend (`server_delivery`) cobrindo só `CatalogoController` (`src/restaurante/catalogo.controller.ts`, rotas públicas `/r/*`: home, filtros, produtos/combos marketplace, cardápio por slug/domínio). Cache-aside, TTL 15s (cardápio/produtos/combos/home) e 60s (filtros geográficos), **sem invalidação manual** — decisão do usuário, aceita defasagem curta de estoque/preço em troca de simplicidade.

Arquivos novos: `src/redis/redis.service.ts` (client `ioredis`, wrapper `getJSON`/`setJSON`) e `src/redis/redis.module.ts` (Global, mesmo padrão do `SupabaseModule`). **Best-effort de verdade**: `REDIS_URL` ausente usa `config.get` (não `getOrThrow`) — só desativa o cache, não derruba o boot do Nest. Isso foi um bug que corrigi durante a tarefa (primeira versão usava `getOrThrow` e quebraria o app inteiro em produção se a env var faltasse).

**Status: MERGEADO em `main` (submodule + standalone), PUSHADO, TESTADO E CONFIRMADO FUNCIONANDO EM PRODUÇÃO** (EasyPanel, projeto `app_desenvolvimento`) via `MONITOR` no redis-cli mostrando `GET` (miss) seguido de `SET ... EX 15` real. README do backend documentado com seção "Cache (Redis)".

**Gotchas caros aprendidos nessa tarefa (guardar bem):**
1. **Senha do Redis com caractere especial precisa URL-encode** (`@` → `%40`) na `REDIS_URL`, senão o parser corta a senha errado e dá `WRONGPASS`. Mais simples: pedir pro usuário trocar a senha do Redis pra algo só alfanumérico (foi o que resolveu de vez aqui — senha final ficou `Jota1979jota`, sem `@`).
2. **`KEYS chave*` pra testar cache é enganoso com TTL curto** — a call e o comando manual quase sempre têm mais de 15s de intervalo (troca de janela, digitação), dando falso negativo mesmo com tudo funcionando. Teste confiável: `MONITOR` no redis-cli (mostra os comandos em tempo real, sem corrida contra o TTL).
3. **Confirmar a URL de teste antes de cronometrar nada.** Perdi um bom tempo comparando tempo de resposta (`curl -w %{time_total}`) numa URL errada (`...delivery256235...`, sufixo que não existia mais) que só devolvia a página 404 padrão do EasyPanel — nunca chegava no backend. Sempre checar `%{http_code}` /corpo da resposta, não só o tempo.
4. **`ENOTFOUND`/erro de rede pode ser só timing de restart** — apareceu uma vez bem na janela em que o Redis (serviço separado) tava reiniciando; sumiu sozinho no boot seguinte do backend.
5. Backend (`app_desenvolvimento`) e Redis (`jota_empresas`) são **projetos diferentes no EasyPanel mas a rede alcança** — não é isolamento de projeto, contrário do que eu suspeitava inicialmente.
6. `.env_exemplo` do frontend tinha `SERVER_API` com URL errada há um tempo (sufixo `256235` a mais) — corrigido.

Dev local: Redis via Docker solto (`docker run -d --name deliveryhub-redis -p 6379:6379 redis:7-alpine`), `REDIS_URL=redis://127.0.0.1:6379` no `.env` do backend. Container não sobe/desce junto com o backend — comandos manuais (`docker start/stop deliveryhub-redis`).

Escopo desta fase é só o catálogo público (maior tráfego, sem auth). Ficou de fora (decisão consciente): produtos/categorias admin por empresa, estoque, caixa, pedidos.

Ver [[deliveryhub_vps_supabase_secrets]] pro padrão de como colar env no EasyPanel. Ver [[deliveryhub_dois_clones_server_delivery]] — sincronizado igual sempre (pull no standalone depois do push no submodule).
