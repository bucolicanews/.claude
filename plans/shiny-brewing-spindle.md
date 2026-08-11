# Domínio customizado por estabelecimento

## Contexto

Cada estabelecimento hoje só é acessível pelo cardápio público em `.../r/:slug` (ex.: `app-dev.../r/restaurante-demo`). O dono quer poder cadastrar um domínio próprio (ex.: `restordemo.com`) que, depois de o DNS apontar pro servidor e o domínio ser adicionado manualmente na aba "Domínios" do EasyPanel (ação do usuário, fora do escopo deste código), sirva a mesma página do cardápio — mas na raiz do domínio, sem o prefixo `/r/slug` visível.

O frontend é hoje um SPA estático (`serve -s build`, sem nginx/host-routing) — todo domínio apontado pro EasyPanel cai no mesmo `index.html`, então a decisão de "que restaurante mostrar" só pode acontecer no client, lendo `window.location.hostname`.

## Desenho da solução

1. **DB**: nova coluna `custom_domain TEXT UNIQUE` (nullable) em `restaurants`.
2. **Backend**: novo endpoint público que resolve `hostname → payload do cardápio` (mesmo formato do `/r/:slug`), reaproveitando a lógica já existente. Novo endpoint autenticado pro dono salvar/limpar seu domínio.
3. **Frontend**: a rota raiz `"/"` passa a primeiro tentar resolver o hostname atual contra esse endpoint; se achar, renderiza o cardápio (mesmo componente de `/r/:slug`, sem navegação/redirect visível); se não achar (404 — inclui o próprio domínio principal do marketplace), cai no comportamento atual (`MenuCatalogProductBrowse`). Nenhuma outra rota muda (`/shopping-cart-checkout`, `/order-tracking-status`, `/restaurante/*` etc. já não dependem do slug estar na URL — usam `sessionStorage`/state).

### Por que essa abordagem (vs. alternativas)
- **Redirect pro `/r/slug`** foi descartado — trocaria a URL visível de volta pra `restordemo.com/r/restaurante-demo`, o oposto do que foi pedido.
- **Múltiplos domínios por estabelecimento** foi descartado (confirmado com o usuário) — 1 coluna única é suficiente pro caso de uso.

## Mudanças concretas

### Migration
`supabase/migrations/20260718000003_restaurants_custom_domain.sql`
```sql
ALTER TABLE public.restaurants
  ADD COLUMN IF NOT EXISTS custom_domain TEXT UNIQUE;
```

### Backend (`server_delivery`)

- **`src/common/dominio.util.ts`** (novo, ao lado de `common/geo.util.ts`): `normalizarDominio(host: string): string` — lowercase, remove protocolo/caminho se colado por engano, remove `www.` inicial, trim. Usado tanto ao salvar quanto ao resolver, pra tratar `restordemo.com` e `www.restordemo.com` como o mesmo domínio.

- **`src/restaurante/catalogo.controller.ts`**:
  - Extrair o corpo de `cardapio(slug)` (linhas 178-219, monta `{restaurante, cardapio, destaques, promos, combos}`) para um método privado `montarCardapio(restaurante)`, reaproveitado pelos dois endpoints.
  - Novo `@Get('by-domain/:host')` — **precisa ser declarado antes de `@Get(':slug')`** (mesma regra já documentada nas linhas 122-124 pra `filtros`/`produtos`). Normaliza o host recebido, busca `restaurants` por `.eq('custom_domain', hostNormalizado)`, 404 se não achar, senão chama `montarCardapio`.
  - Select do restaurante (linha 182) já inclui `slug` — necessário pro frontend saber o slug efetivo mesmo quando entrou via domínio (usado no checkout).

- **`src/restaurante/restaurante.service.ts`**:
  - `minhaEmpresa` (linha 20-25): incluir `custom_domain` no select, pra tela de aparência mostrar o valor atual.
  - Novo método `atualizarDominio(restaurantId, customDomain)`:
    - `customDomain` vazio/null → seta coluna pra `null` (remove domínio).
    - Caso contrário: normaliza via `normalizarDominio`; valida formato de hostname (regex simples, rejeita `/`, espaços, `http`); **bloqueia se o domínio normalizado terminar em `.easypanel.host` ou for `localhost`/`127.0.0.1`** — evita o dono acidentalmente "sequestrar" o próprio domínio da plataforma (isso tornaria o marketplace principal inacessível pra todo mundo, já que a raiz `"/"` passaria a resolver pra esse restaurante).
    - Trata violação de unicidade do Postgres (`error.code === '23505'`) devolvendo mensagem amigável "Este domínio já está em uso por outro estabelecimento."

- **`src/restaurante/restaurante.controller.ts`** (guard `RestaurantOwnerGuard` já aplicado no controller inteiro):
  - `@Patch('dominio')` → `service.atualizarDominio(req.restaurantId, body.custom_domain)`.

### Frontend

- **`src/services/restauranteService.js`**:
  - `getCardapioPorDominio(hostname)` — igual a `getCardapioPorSlug` (linha 213-222) mas contra `${apiPath('/api/r/by-domain')}/${hostname}`; em vez de lançar erro no 404, **retorna `null`** (simplifica a decisão no `HomeRouter`: qualquer falha = "não é domínio customizado, mostra marketplace").
  - `updateDominio(customDomain)` → `apiFetch('/dominio', { method: 'PATCH', body: JSON.stringify({ custom_domain: customDomain }) })`.

- **`src/pages/restaurante-catalogo/index.jsx`** (componente do cardápio, hoje só usado em `/r/:slug`):
  - Aceitar prop opcional `dadosPreCarregados`. Se vier preenchida: `useState` inicial de `data`/`loading` já resolvidos, e o `useEffect` de fetch (linha 205-214) não dispara.
  - Trocar os usos de `slug` (vindo hoje só de `useParams`, linhas 195, 239, 243) por um `slugEfetivo = slug ?? data?.restaurante?.slug` — necessário porque quando o cardápio é aberto via domínio customizado não existe `:slug` na URL, mas o checkout ainda precisa saber a qual restaurante o carrinho pertence.

- **`src/pages/home-router/index.jsx`** (novo): componente montado na rota `"/"`.
  - No mount, chama `getCardapioPorDominio(window.location.hostname)`.
  - Enquanto carrega: spinner simples (mesmo padrão visual usado em `restaurante-aparencia/index.jsx` linha 170-174).
  - Se resolveu → `<RestauranteCatalogo dadosPreCarregados={payload} />`.
  - Se não (null) → `<MenuCatalogProductBrowse />` (comportamento atual, sem mudança).

- **`src/Routes.jsx`**: linha 59, trocar `<Route path="/" element={<MenuCatalogProductBrowse />} />` por `<Route path="/" element={<HomeRouter />} />` (novo import).

- **`src/pages/restaurante-aparencia/index.jsx`**: nova seção "Domínio personalizado" logo após a seção "Link da sua página" (depois da linha 215) — campo texto (ex.: `restordemo.com`), botão salvar próprio (chama `updateDominio`, feedback de sucesso/erro isolado do form principal de aparência), texto de ajuda explicando o passo manual no EasyPanel. Estado inicial vem de `getMinhaEmpresa().empresa.custom_domain` (já incluído no select do backend).

## Verificação

- Rodar a migration local (Supabase).
- Com um restaurante de teste: setar `custom_domain` via tela de Designer, confirmar que salvou (`getMinhaEmpresa` retorna o valor).
- Simular acesso por domínio customizado sem precisar de DNS real: no browser, `http://localhost:4028/` normalmente cai no marketplace; testar a resolução chamando diretamente `GET /api/r/by-domain/<dominio-cadastrado>` (via curl/Postman) e confirmar que devolve o mesmo payload que `GET /api/r/<slug>`.
- Confirmar que `/api/r/by-domain/<qualquer-coisa-invalida>` devolve 404 (não quebra o `HomeRouter`).
- Confirmar que tentar salvar `custom_domain` igual a um domínio já usado por outro restaurante retorna erro amigável (unique violation).
- Confirmar que tentar salvar algo terminando em `.easypanel.host` é rejeitado.
- Rodar `npx tsc --noEmit` no `server_delivery` depois das mudanças.
