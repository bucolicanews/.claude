# Módulo "Serviços" (prestação sob orçamento)

## Contexto

O DeliveryHub hoje vende dois tipos de plano/módulo: `modulo_delivery` (carrinho/checkout) e `modulo_salao` (comandas/mesas). O usuário quer um terceiro módulo, **Serviços**, para estabelecimentos que prestam serviço em vez de vender produto — não há preço fixo nem checkout dentro do app. O fluxo é: o estabelecimento cadastra os serviços que presta; o cliente, na vitrine pública da loja, pede um orçamento (nome + telefone + mensagem, sem precisar login); o estabelecimento recebe essa solicitação no painel — novo item **Serviços** no menu lateral, com aviso de nova solicitação pendente — e entra em contato por fora do app (ligação/WhatsApp). Sem chat nem pagamento dentro do app nessa primeira versão.

Escopo confirmado com o usuário: implementar o fluxo completo agora (painel + vitrine do cliente), como módulo de plano com flag própria (`modulo_servicos`, mesmo padrão de `modulo_delivery`/`modulo_salao`), com cadastro de serviço contendo nome, descrição, foto, categoria e faixa de preço estimada.

Decisões de implementação (recomendações já validadas contra o código existente, não é preciso confirmar de novo):
- **Status da solicitação:** só dois estados, `'pendente' | 'contatado'` — não há aprovação/recusa de valor aqui como no repasse de motoboy, só marcar "já liguei".
- **Foto do serviço:** reusa o upload real já existente (Supabase Storage via `POST /restaurante/storage/upload`, componente `ImageUpload`), só com `folder="servicos"`. Nenhuma mudança de backend de upload.
- **Faixa de preço:** dois campos nullable `preco_min`/`preco_max` (`NUMERIC(10,2)`, mesmo tipo de `products.price`), não texto livre — mantém dado estruturado e cobre os 3 casos de exibição (`"R$ X – R$ Y"` / `"A partir de R$ X"` / `"Sob consulta"`).
- **Categoria:** coluna `categoria TEXT` livre na própria tabela `services`, não reaproveita `categories` (essa é escopada pra cardápio/produto — misturar semânticas complicaria `getMinhasCategorias`).
- **Guard de módulo desativado:** confirmado no código (`Routes.jsx`) que módulos hoje NÃO têm redirecionamento de rota próprio — `/restaurante/salao` só usa `RestauranteGuard` (role), a visibilidade é só no menu lateral. Seguir o mesmo padrão pra `/restaurante/servicos` — sem guard extra a inventar.

## 1. Migrations SQL (`deliveryhub_white_label/supabase/migrations/`, só nesse repo)

**`20260903000001_modulo_servicos.sql`** — terceiro módulo de plano, mesmo padrão de `20260727000001_modulos_delivery_salao.sql`:
```sql
ALTER TABLE public.restaurants
    ADD COLUMN IF NOT EXISTS modulo_servicos BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE public.planos
    ADD COLUMN inclui_servicos BOOLEAN NOT NULL DEFAULT false;
```
Sem backfill — módulo novo, ninguém deve ganhar acesso automático.

**`20260903000002_services.sql`**:
```sql
CREATE TABLE public.services (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  restaurant_id BIGINT NOT NULL REFERENCES public.restaurants(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  description TEXT,
  image_url TEXT,
  categoria TEXT,
  preco_min NUMERIC(10,2),
  preco_max NUMERIC(10,2),
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_services_restaurant_active ON public.services(restaurant_id, is_active);
ALTER TABLE public.services ENABLE ROW LEVEL SECURITY;
-- Sem policy pública — CRUD só via RestaurantOwnerGuard (service role), leitura
-- pública passa pelo backend (CatalogoController), nunca client Supabase no browser.
```

**`20260903000003_solicitacoes_orcamento_servico.sql`**:
```sql
CREATE TABLE public.solicitacoes_orcamento_servico (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  service_id BIGINT NOT NULL REFERENCES public.services(id) ON DELETE CASCADE,
  restaurant_id BIGINT NOT NULL REFERENCES public.restaurants(id) ON DELETE CASCADE,
  nome_cliente TEXT NOT NULL,
  telefone_cliente TEXT NOT NULL,
  mensagem TEXT,
  status TEXT NOT NULL DEFAULT 'pendente' CHECK (status IN ('pendente', 'contatado')),
  criado_em TIMESTAMPTZ NOT NULL DEFAULT now(),
  contatado_em TIMESTAMPTZ
);
CREATE INDEX idx_solic_orcamento_restaurant_status ON public.solicitacoes_orcamento_servico(restaurant_id, status);
CREATE INDEX idx_solic_orcamento_service ON public.solicitacoes_orcamento_servico(service_id);
ALTER TABLE public.solicitacoes_orcamento_servico ENABLE ROW LEVEL SECURITY;
-- RLS sem policy — mesmo padrão restritivo de motoboy_repasse_solicitacoes: o INSERT
-- público vem de endpoint dedicado no backend (service role), nunca client no browser.
```
`restaurant_id` redundante com `service_id.restaurant_id` de propósito (mesmo padrão de `motoboy_repasse_solicitacoes`) — evita join extra em toda listagem/contagem do painel.

## 2. Backend — replicar em `serer_delivery/` **e** `deliveryhub_white_label/server_delivery/`

- **DTOs de plano** (`src/planos/dto/criar-plano.dto.ts`, `atualizar-plano.dto.ts`): adicionar `inclui_servicos?: boolean` ao lado de `inclui_gdoor`.
- **Sincronização plano→restaurante** (`src/planos/planos.service.ts`, `atribuirAssinatura()` ~linha 265): adicionar `modulo_servicos: plano.inclui_servicos,` no `.update({...})` existente. `aplicarTrocaSeNecessario()` já chama esse método, nenhuma outra mudança necessária.
- **Módulo Nest novo `src/servicos/`** (padrão de `src/motoboy/restaurante-motoboys.controller.ts` — controller dedicado, não embutir em `RestauranteController`):
  - `servicos.service.ts` — `ServicosService` com `listarMeusServicos`, `criarServico` (valida `preco_min <= preco_max` se ambos vierem, insere com `restaurant_id` explícito — nunca `...body` cru), `editarServico`/`deletarServico`/`toggleServico` (todos checam posse: busca o registro, compara `restaurant_id`, `NotFoundException` se não bater — padrão IDOR já auditado no projeto), `listarServicosAtivos(restaurantId)` (só `is_active=true`, usado pelo catálogo público), `criarSolicitacaoOrcamento` (valida que o serviço pertence ao restaurante do slug antes de inserir), `listarSolicitacoes`, `contarSolicitacoesPendentes` (`.select('id', { count: 'exact', head: true }).eq('status','pendente')` — mesmo padrão leve de `contarSolicitacoesRepassePendentes`), `marcarComoContatado`.
  - `restaurante-servicos.controller.ts` — `@Controller('restaurante/servicos') @UseGuards(RestaurantOwnerGuard)`: `GET /`, `POST /`, `PATCH /:id`, `DELETE /:id`, `PATCH /:id/toggle`, `GET /solicitacoes/count`, `GET /solicitacoes`, `PATCH /solicitacoes/:id/contatado`.
  - `servicos-publico.controller.ts` — `@Controller('r/:slug/servicos')`, sem guard: `POST /solicitar-orcamento` com `@Throttle({ default: { limit: 5, ttl: 60_000 } })` (mesma ordem de grandeza do rate-limit de login de garçom).
  - `servicos.module.ts` — `imports: [AuthModule, SupabaseModule]`, registra os dois controllers + service, `exports: [ServicosService]`. Registrar em `app.module.ts`.
  - DTOs (`src/servicos/dto/`): `CriarServicoDto`, `EditarServicoDto` (mesmos campos, opcionais), `SolicitarOrcamentoDto` (`nome_cliente`, `telefone_cliente`, `mensagem?`) — estilo `class-validator` de `criar-plano.dto.ts`.
- **`catalogo.controller.ts`** (`montarCardapio()` ~linha 356): injetar `ServicosService` (precisa `RestauranteModule` importar `ServicosModule`, igual já faz com `MotoboyModule`); incluir `modulo_servicos` no `.select(...)` de restaurante nas duas queries (`cardapio()`/`cardapioPorDominio()`); adicionar ao payload final:
  ```ts
  const servicos = restaurante.modulo_servicos
    ? await this.servicosService.listarServicosAtivos(restaurante.id)
    : [];
  return { restaurante, cardapio, destaques, promos, combos, servicos };
  ```
- **`restaurante.module.ts`**: adicionar `ServicosModule` a `imports`.

## 3. Frontend (`deliveryhub_white_label/`)

- **`src/hooks/useModulosEmpresa.js`**: adicionar `moduloServicos: !!data?.empresa?.modulo_servicos`.
- **`src/config/restauranteNavLinks.js`**: novo bloco `SERVICOS_LINKS = [{ label: 'Serviços', path: '/restaurante/servicos', icon: 'Wrench' }]`; assinatura de `getRestauranteNavLinks` ganha `moduloServicos`, inclui `...(moduloServicos ? SERVICOS_LINKS : [])`.
- **Badge do menu — generalizar de path único pra mapa**: hoje `RestauranteSidebar.jsx` (~linha 41) e `RestauranteHeader.jsx` (~linha 113) têm `l.path === '/restaurante/motoboys' && pendentesMotoboy > 0` fixo. Trocar a prop por `pendentesPorPath` (objeto `{ [path]: count }`):
  ```jsx
  {pendentesPorPath[l.path] > 0 && <span className="...">{pendentesPorPath[l.path]}</span>}
  ```
  Em `RestauranteHeader.jsx`, montar `{ '/restaurante/motoboys': pendentesMotoboy, '/restaurante/servicos': pendentesServicos }` e passar adiante.
- **`src/hooks/useSolicitacoesServicoCount.js`** (novo, mesmo modelo de `useSolicitacoesMotoboyCount.js` mas uma fonte só): polling `setInterval` 30s chamando `contarSolicitacoesServicoPendentes()`.
- **`src/services/restauranteService.js`**: `getMeusServicos`, `criarServico`, `editarServico`, `deletarServico`, `toggleServico`, `getSolicitacoesServico`, `contarSolicitacoesServicoPendentes`, `marcarSolicitacaoContatada` (todas via `apiFetch` autenticado, base `/api/restaurante`); `solicitarOrcamentoServico(slug, serviceId, data)` pública, seguindo exatamente o padrão de `getCardapioPorSlug` (`fetch(apiPath('/api/r/${slug}/servicos/${serviceId}/solicitar-orcamento'))`, sem `apiFetch` autenticado).
- **Página nova `src/pages/restaurante-servicos/index.jsx`** (padrão single-file de `restaurante-produtos/index.jsx`): `<RestauranteHeader active="/restaurante/servicos" title="Serviços" />`; duas abas — "Meus Serviços" (cards + modal criar/editar com overlay `fixed inset-0 bg-black/50 flex items-center justify-center z-50 p-4` e card `bg-white dark:bg-[#27272A] rounded-2xl p-6 w-full max-w-md md:max-w-[85%] max-h-[90vh] overflow-y-auto` — convenção de modal do projeto; campos nome, descrição, `ImageUpload folder="servicos"`, categoria, preço min/max) e "Solicitações" (lista com nome/telefone/mensagem/serviço/status, link `tel:`/`wa.me`, botão "Marcar como contatado").
- **Rota**: registrar `<Route path="/restaurante/servicos" element={<RestauranteGuard><RestauranteServicos /></RestauranteGuard>} />` em `src/Routes.jsx`, junto dos outros `/restaurante/*` (linha ~117-143) — sem guard de módulo extra (confirmado que nenhuma rota de módulo tem isso hoje, só o menu esconde).
- **`src/pages/restaurante-catalogo/index.jsx`**: desestruturar `servicos` do payload (~linha 349); `temServicos = restaurante.modulo_servicos === true` (atenção: default `false`, diferente de `temDelivery` que usa `!== false`); nova tab `...(temServicos && servicos?.length ? [{ id: 'servicos', label: 'Serviços' }] : [])`; `produtosDaTab()` retorna `servicos` quando `catAtiva === 'servicos'`; novo componente `ServicoCard` (mesma estrutura visual de `ProdutoCard`, sem stepper de quantidade — botão "Solicitar orçamento" no lugar); novo modal "Solicitar orçamento" (nome, telefone, mensagem opcional; primeiro modal desse tipo na vitrine, mesma convenção de overlay/card) chamando `solicitarOrcamentoServico`.
- **`src/pages/admin-planos/index.jsx`** (necessário — sem isso não dá pra ligar o módulo pra nenhum plano pela UI): `EMPTY`/estado de edição/payload de salvar ganham `inclui_servicos`; novo checkbox "Serviços (orçamento)" no bloco de módulos (~linha 198-222); novo badge condicional na listagem de planos (~linha 391-415).

## 4. Ordem de execução

1. As 3 migrations em `deliveryhub_white_label/supabase/migrations/` (só nesse repo) → `npx supabase migration up` local (rodado de `deliveryhub_white_label/`).
2. Backend em `serer_delivery/` (DTOs, `planos.service.ts`, `src/servicos/*`, `catalogo.controller.ts`, `restaurante.module.ts`, `app.module.ts`).
3. Replicar exatamente as mesmas mudanças de código (checkout separado, não `git pull`) em `deliveryhub_white_label/server_delivery/`. Nenhuma env var nova.
4. `npm run build`/`tsc --noEmit` nos dois backends.
5. Frontend: hook de módulo → nav links → generalização do badge → hook de contador → `restauranteService.js` → página `restaurante-servicos` + rota → `restaurante-catalogo/index.jsx`.
6. `admin-planos/index.jsx`.
7. Teste local ponta a ponta (seção 5).
8. Só depois de validado local, e com confirmação do usuário: `npx supabase db push --linked` (produção) + deploy dos backends.

## 5. Teste ponta a ponta local

1. `npx supabase migration up` (ou `db reset` completo).
2. Subir backend (`serer_delivery`) e frontend local.
3. `/admin/planos`: marcar "Serviços" num plano, salvar → confirmar `planos.inclui_servicos=true` no banco.
4. Atribuir o plano a um restaurante seed (fluxo já usado pra testar `modulo_delivery`/`modulo_salao`) → confirmar `restaurants.modulo_servicos=true`.
5. Login no painel → confirmar item "Serviços" no menu (desktop + mobile).
6. `/restaurante/servicos`: cadastrar serviço com foto real, categoria, testando os 3 casos de preço (min+max, só min, nenhum).
7. `/r/:slug` em aba anônima: tab "Serviços" aparece, faixa de preço formatada certa nos 3 casos.
8. "Solicitar orçamento" → preencher e enviar → confirmar `solicitacoes_orcamento_servico` com `status='pendente'`.
9. Painel: badge aparece no menu (contagem 1), reflete via polling 30s sem reload manual.
10. Aba "Solicitações": ver a solicitação, "Marcar como contatado" → badge zera, `status='contatado'`/`contatado_em` preenchido.
11. IDOR: editar/deletar serviço de outro `restaurant_id` via chamada direta com token de restaurante diferente → deve dar 404/403.
12. Throttle: 6+ requests em <1min pro `solicitar-orcamento` → 429 a partir do 6º.
13. Restaurante sem `modulo_servicos`: menu e tab somem, sem erro 500.

### Arquivos-chave
- `deliveryhub_white_label/supabase/migrations/20260903000001_modulo_servicos.sql` (+ as duas seguintes)
- `serer_delivery/src/planos/planos.service.ts` (`atribuirAssinatura`, ~linha 256-280)
- `serer_delivery/src/motoboy/restaurante-motoboys.controller.ts` (template a replicar)
- `serer_delivery/src/restaurante/catalogo.controller.ts` (`montarCardapio`, ~linha 356-388)
- `deliveryhub_white_label/src/config/restauranteNavLinks.js`, `deliveryhub_white_label/src/components/restaurante/RestauranteSidebar.jsx` (generalização do badge)
- `deliveryhub_white_label/src/pages/restaurante-catalogo/index.jsx` (tabs, `ProdutoCard`, destructuring de `data`, ~linha 349-368)
- `deliveryhub_white_label/src/Routes.jsx` (~linha 117-143, registro da rota)
