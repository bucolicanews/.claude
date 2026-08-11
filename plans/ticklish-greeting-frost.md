# Cache Redis no CatalogoController (rotas públicas `/r/*`)

## Contexto

Backend (`server_delivery`, NestJS + supabase-js puro, sem ORM) não tem camada de cache. Rotas mais acessadas do sistema são as públicas do marketplace/cardápio em `src/restaurante/catalogo.controller.ts` — sem autenticação, batidas por todo visitante/cliente, e algumas (`cardapio`) encadeiam 3 queries no Supabase por request. Usuário já tem instância Redis rodando na VPS (`jota_empresas_redis`). Objetivo: reduzir carga no Supabase e latência dessas rotas com cache-aside, TTL curto, sem invalidação manual (decisão do usuário: aceita alguns segundos de defasagem de estoque, igual iFood/Rappi).

Escopo desta fase: **só `CatalogoController`**. Não mexe em produtos/categorias admin, estoque, caixa, pedidos.

## Arquivos novos

**`server_delivery/src/redis/redis.service.ts`**
Mesma forma do `SupabaseService` (`src/supabase/supabase.service.ts`): client singleton criado no construtor via `ConfigService.getOrThrow('REDIS_URL')`, usando `ioredis`. Métodos:
- `async getJSON<T>(key: string): Promise<T | null>` — get + `JSON.parse`, retorna `null` se não existir.
- `async setJSON(key: string, value: unknown, ttlSeconds: number): Promise<void>` — `JSON.stringify` + `set(key, val, 'EX', ttlSeconds)`.

Ambos os métodos envolvidos em `try/catch` que loga warning e retorna `null`/não lança — cache é best-effort, se Redis cair o catálogo continua funcionando direto no Supabase.

**`server_delivery/src/redis/redis.module.ts`**
Mesma forma do `SupabaseModule`: `@Global()`, `providers: [RedisService]`, `exports: [RedisService]`.

## Arquivos alterados

**`server_delivery/package.json`** — adicionar dependência `ioredis`.

**`server_delivery/src/app.module.ts`** — importar `RedisModule` (junto de `SupabaseModule`).

**`server_delivery/src/restaurante/catalogo.controller.ts`** — injetar `RedisService`, envolver cada handler com padrão cache-aside (bater Redis antes do Supabase, gravar no fim). Chaves e TTL:

| Rota | Chave | TTL | Observação |
|---|---|---|---|
| `GET /r/filtros` | `catalogo:filtros` | 60s | Só muda quando cadastra restaurante novo |
| `GET /r/produtos` | `catalogo:produtos:marketplace` | 15s | Lista pesada (limit 200) |
| `GET /r/combos` | `catalogo:combos:marketplace` | 15s | |
| `GET /r/:slug` | `catalogo:cardapio:{slug}` | 15s | Rota mais quente — cardápio aberto por todo cliente |
| `GET /r/by-domain/:host` | `catalogo:cardapio:dominio:{dominio_normalizado}` | 15s | |
| `GET /r` (`listarRestaurantes`) | `catalogo:home:{querystring ordenada}` | 15s | **Só cacheia se não vier header `Authorization`** — quando vem token, resultado pode depender do endereço salvo do cliente (personalizado), então nesse caso pula cache e vai direto no Supabase, igual já faz hoje |

`montarCardapio` (método privado usado por `cardapio` e `cardapioPorDominio`) é o que efetivamente busca categorias/produtos/combos — o cache-aside entra nos handlers públicos (`cardapio`, `cardapioPorDominio`), guardando o resultado final já montado, não a query interna.

## Env vars

**`server_delivery/.env.example`** — adicionar `REDIS_URL=redis://default:senha@host:6379` (placeholder, sem credencial real).

**`server_delivery/.env`** (local, gitignored) — `REDIS_URL` real apontando pra VPS, com senha URL-encoded (`%40` no lugar de `@` literal):
```
REDIS_URL=redis://default:Jota1%40jota79@jota_empresas_redis:6379
```
Nota: como é só cache (TTL 15-60s, sem dado sensível persistido), é seguro dev local apontar direto pra mesma instância Redis da VPS — diferente do banco (Supabase), que você mantém local vs Cloud separados.

Produção (EasyPanel) recebe `REDIS_URL` na hora do deploy, fora desta tarefa (mesmo fluxo que vocês já usam pras outras env vars).

## Verificação

1. Rodar backend local com `REDIS_URL` setado.
2. `GET /r/:slug` de um restaurante existente duas vezes seguidas — segunda deve vir do Redis (mais rápida, sem novas queries no Supabase).
3. Confirmar chave no Redis (`redis-cli GET catalogo:cardapio:<slug>` ou painel EasyPanel) com TTL ativo (`TTL catalogo:cardapio:<slug>`).
4. Editar preço/estoque de um produto desse restaurante, chamar `GET /r/:slug` de novo antes do TTL expirar — deve mostrar valor antigo (esperado); esperar 15-20s, chamar de novo — deve mostrar valor atualizado.
5. Derrubar Redis (ou usar `REDIS_URL` inválida) e confirmar que `/r/*` continua respondendo normal (fallback direto Supabase, sem 500).
