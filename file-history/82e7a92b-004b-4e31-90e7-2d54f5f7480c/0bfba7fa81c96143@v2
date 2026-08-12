# Sistema de Planos de Assinatura da Plataforma

## Contexto

Hoje cada loja paga só uma comissão % por venda (`restaurants.comissao_pct`, configurada pelo admin, fallback hardcoded `5` espalhado em 3 lugares do backend). O usuário quer um segundo mecanismo de monetização, parecido com planos de app tipo iFood: mensalidade paga direto da loja pra plataforma, com regras de limite de produtos e piso de faturamento pra começar a cobrar. Além disso, a comissão por venda precisa ganhar um valor padrão global configurável pelo admin, com cada loja podendo ter override individual ou "voltar ao padrão".

Decisões já fechadas com o usuário (não reabrir):
1. Comissão: mantém override por loja, mas adiciona padrão global. `comissao_pct = NULL` na loja = usa padrão global.
2. Um único modelo de "plano" flexível: nome, valor, periodicidade (mensal/trimestral/anual), limite_produtos (opcional), piso_faturamento (opcional), trial_dias (opcional).
3. Pagamento real via PagBank Pix, cobrança direta loja→plataforma (sem split), webhook confirma automático.
4. Fatura vencida + X dias de tolerância (configurável) → bloqueia acesso do dono ao painel `/restaurante` (exceto a própria tela do plano, pra ele pagar). Admin nunca é bloqueado.
5. Estourar limite de produtos do plano → bloqueia cadastro de novo produto, erro claro.

## Achados críticos da exploração (reaproveitar, não recriar)

- **Trigger SQL `registrar_comissao()`** (`supabase/migrations/20250825103853_setup_rls_policies.sql:137-147`) roda `AFTER UPDATE OF status ON orders` quando vira `delivered`, lê `comissao_pct` direto de `restaurants` sem fallback. Precisa `CREATE OR REPLACE FUNCTION` pra cair no padrão global quando `NULL`, senão comissão de loja em "padrão global" quebra silenciosamente.
- 3 lugares no backend fazem fallback hardcoded `?? 5` que também precisam do padrão global: `pagamentos/pagamentos.service.ts:56` (`getPagBankClient`), `restaurante/onboarding.controller.ts:56` (grava `comissao_pct: 5.0` explícito no self-registro — trocar pra não enviar o campo), e exibição no frontend `admin-empresas/index.jsx:409` (`e.comissao_pct ?? 5`).
- `restaurants.comissao_pct` já é `NUMERIC(5,2) DEFAULT 5.00` **sem** `NOT NULL` — já aceita NULL hoje, só trocar o `DEFAULT`.
- Guard do dono: `server_delivery/src/auth/restaurant-owner.guard.ts` — `RestaurantOwnerGuard`, decodifica JWT via `JwtGuard`, resolve `request.restaurantId` de `restaurants.user_id`. Padrão: `@Controller('restaurante')` + `@UseGuards(RestaurantOwnerGuard)` na classe inteira, métodos usam `@Req() req` → `req.restaurantId`.
- Criação de produto pelo dono: `POST /restaurante/produtos` → `restaurante.controller.ts` → `RestauranteService.criarProduto()` em `restaurante/restaurante.service.ts:187-225`, insert em `products` (coluna `is_active` controla ativo/inativo). É aqui que entra o check de limite.
- PagBank: `pagamentos/pagbank.client.ts::criarOrdemPix()` — client HTTP puro, reutilizável direto (recebe `reference_id`, `valor_centavos`, `customer:{name,email,tax_id}`, `itens`, `webhook_url`, `splits` opcional — **não usar splits** pra cobrança de assinatura). Token/conta da plataforma já ficam em `platform_settings.config` (jsonb, `id=1`), geridos por `plataforma/plataforma.service.ts`.
- Webhook de pedido (`POST /pagamentos/webhook`) é acoplado à tabela `orders` — **não reaproveitar**, criar webhook novo e separado `POST /planos/webhook` casando por `reference_id` prefixado `PLANO_{fatura_id}_...`.
- **Não existe `@nestjs/schedule`** nem cron no projeto — geração de fatura será lazy (on-read) + gatilho manual do admin, não scheduler (ver seção Backend).
- CRUD admin a replicar: `src/pages/admin-tags/index.jsx` (Modal interno controlado por state, `AdminNav` inline, dark mode zinc-800/900/700, chamadas via service em `src/services/`).
- Guard do dono no frontend: `src/components/RestauranteGuard.jsx` envolve **cada rota individualmente** em `src/Routes.jsx` (não é layout único) — bloqueio por inadimplência precisa vir de um estado carregado 1x no `AuthContext` (mesmo padrão de `userProfile`), não um fetch por troca de rota.
- Pagamento de pedido hoje pede `customer:{name,email,tax_id}` **do frontend a cada compra** (não fica salvo em tabela) — pra cobrança de assinatura, seguir o mesmo padrão: o dono preenche nome/e-mail/CPF-CNPJ na primeira vez que clicar em "Pagar" a fatura, sem precisar de coluna nova no banco.

## 1. Migration SQL

Novo arquivo `supabase/migrations/20260806000002_planos_assinatura.sql`:

```sql
CREATE TABLE public.planos (
    id BIGSERIAL PRIMARY KEY,
    nome TEXT NOT NULL,
    valor NUMERIC(10,2) NOT NULL CHECK (valor >= 0),
    periodicidade TEXT NOT NULL CHECK (periodicidade IN ('mensal', 'trimestral', 'anual')),
    limite_produtos INTEGER,                -- NULL = ilimitado
    piso_faturamento NUMERIC(10,2),         -- NULL = sempre cobra
    trial_dias INTEGER NOT NULL DEFAULT 0,
    ativo BOOLEAN NOT NULL DEFAULT true,    -- soft-disable, preserva histórico
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE public.assinaturas (
    id BIGSERIAL PRIMARY KEY,
    restaurant_id BIGINT NOT NULL UNIQUE REFERENCES public.restaurants(id) ON DELETE CASCADE,
    plano_id BIGINT NOT NULL REFERENCES public.planos(id) ON DELETE RESTRICT,
    status TEXT NOT NULL DEFAULT 'trial' CHECK (status IN ('trial', 'ativa', 'cancelada')),
    data_inicio TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    trial_fim TIMESTAMPTZ,
    ultimo_periodo_faturado_fim TIMESTAMPTZ,  -- controla a geração lazy de fatura
    data_cancelamento TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE public.plano_faturas (
    id BIGSERIAL PRIMARY KEY,
    assinatura_id BIGINT NOT NULL REFERENCES public.assinaturas(id) ON DELETE CASCADE,
    restaurant_id BIGINT NOT NULL REFERENCES public.restaurants(id) ON DELETE CASCADE,
    periodo_inicio TIMESTAMPTZ NOT NULL,
    periodo_fim TIMESTAMPTZ NOT NULL,
    valor NUMERIC(10,2) NOT NULL,
    status TEXT NOT NULL DEFAULT 'pendente' CHECK (status IN ('pendente', 'paga', 'vencida', 'isenta', 'cancelada')),
    vencimento TIMESTAMPTZ NOT NULL,
    pago_em TIMESTAMPTZ,
    pagbank_order_id TEXT,
    pix_code TEXT,
    pix_qr_url TEXT,
    reference_id TEXT UNIQUE,
    criado_em TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    atualizado_em TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (assinatura_id, periodo_inicio)
);

CREATE INDEX idx_plano_faturas_restaurant ON public.plano_faturas(restaurant_id);
CREATE INDEX idx_plano_faturas_status ON public.plano_faturas(status);
CREATE INDEX idx_assinaturas_restaurant ON public.assinaturas(restaurant_id);

ALTER TABLE public.restaurants ALTER COLUMN comissao_pct DROP DEFAULT;

CREATE OR REPLACE FUNCTION public.registrar_comissao()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
    pct NUMERIC(5,2);
BEGIN
    IF NEW.status = 'delivered' AND OLD.status <> 'delivered' THEN
        SELECT comissao_pct INTO pct FROM public.restaurants WHERE id = NEW.restaurant_id;
        IF pct IS NULL THEN
            SELECT COALESCE((config->>'comissao_padrao_pct')::numeric, 5.00)
            INTO pct FROM public.platform_settings WHERE id = 1;
        END IF;
        INSERT INTO public.plataforma_comissoes (empresa_id, pedido_id, valor_venda, comissao_pct, comissao_valor)
        VALUES (NEW.restaurant_id, NEW.id, NEW.total, pct, ROUND(NEW.total * pct / 100, 2));
    END IF;
    RETURN NEW;
END;
$$;
```

`comissao_padrao_pct` e `plano_dias_tolerancia` **não precisam de migration** — são chaves novas dentro do `platform_settings.config` jsonb existente (mesmo padrão usado pra `modo_individual`).

## 2. Backend — módulo novo `planos`

Pasta `server_delivery/src/planos/`: `planos.module.ts`, `planos.service.ts`, `dto/` (criar-plano, atualizar-plano, atribuir-assinatura — com `class-validator`, seguindo `plataforma/update-config.dto.ts` de referência), e 3 controllers.

**`PlanosAdminController`** (`@Controller('planos')`, `@UseGuards(AdminGuard)` na classe):
- `GET /planos` — lista planos (inclui inativos)
- `POST /planos`, `PATCH /planos/:id`, `DELETE /planos/:id` (delete só se nenhuma assinatura referenciar, senão `ConflictException` orientando usar `ativo:false`)
- `GET /planos/assinaturas` — todas as lojas + plano + status (join `restaurants.name`)
- `PUT /planos/assinaturas/:restaurantId` — atribui/troca plano (upsert)
- `PATCH /planos/assinaturas/:restaurantId/cancelar`
- `POST /planos/assinaturas/:restaurantId/gerar-fatura` — trigger manual da geração lazy
- `GET /planos/faturas` — todas as faturas, filtros `?restaurant_id=&status=`
- `PATCH /planos/faturas/:id/marcar-paga` — fallback pra pagamento combinado fora do Pix

**`PlanosRestauranteController`** (`@Controller('restaurante/plano')`, `@UseGuards(RestaurantOwnerGuard)` na classe):
- `GET /restaurante/plano/status` — leve, roda a sincronização lazy, devolve `{bloqueado, dias_atraso, fatura_pendente_id, plano_nome}` (chamado 1x por sessão pelo `AuthContext`)
- `GET /restaurante/plano` — detalhe completo (plano, assinatura, faturas recentes, produtos_ativos/limite)
- `GET /restaurante/plano/faturas`, `GET /restaurante/plano/faturas/:id`
- `POST /restaurante/plano/faturas/:id/pagar` — body `{nome, email, cpf_cnpj}`, gera QR Pix via `PagBankClient.criarOrdemPix` (token da plataforma, sem splits)

**`PlanosWebhookController`** (`@Controller('planos')`, sem guard, igual ao de pagamentos):
- `POST /planos/webhook` — casa por `reference_id` prefixado `PLANO_`, atualiza `plano_faturas.status='paga'`

**Wiring do limite de produtos**: `restaurante.module.ts` importa `PlanosModule`; `restaurante.service.ts::criarProduto()` (linha 187) chama `this.planos.verificarLimiteProdutos(restaurantId)` como primeira linha, antes da validação de categoria. `verificarLimiteProdutos`: sem assinatura ou cancelada → não bloqueia (loja legada sem plano); `limite_produtos IS NULL` → ilimitado; senão conta `products` `is_active=true` do restaurante e lança `ForbiddenException` se `count >= limite`.

**Geração de fatura — lazy on-read, sem `@nestjs/schedule`**: método `PlanosService.sincronizarPeriodo(restaurantId)`, chamado por `GET /restaurante/plano/status`, `GET /restaurante/plano` e pelo botão manual do admin. Justificativa de não usar cron: projeto não tem scheduler hoje, dono só precisa faturar quando efetivamente usa o sistema, admin tem botão manual pra forçar. Reversível — dá pra adicionar cron depois sem redesenhar schema.

Mecânica: marca `pendente`+vencida como `vencida`; calcula períodos fechados desde `ultimo_periodo_faturado_fim` até agora (loop, cobre meses sem login de uma vez); por período, soma `orders.total` (`status='delivered'`, dentro do período) da loja; se `piso_faturamento` setado e faturamento abaixo → fatura `isenta`/valor 0; senão `pendente`/valor do plano, vencimento = fim do período + 5 dias. `bloqueado` = existe fatura `pendente`/`vencida` com `vencimento + plano_dias_tolerancia < now()`.

**Bloqueio de inadimplência fica só no frontend** (guard de rota) — backend só expõe o status via `/restaurante/plano/status`, não trava endpoints de negócio individualmente (evitaria acoplar `PlanosService` em guards genéricos e criar exceções pra cada rota).

## 3. Config global (reaproveita `/plataforma/config`)

- `plataforma/update-config.dto.ts`: `comissao_padrao_pct?: number`, `plano_dias_tolerancia?: number` (`@IsOptional`).
- `plataforma/plataforma.service.ts`: `getConfig()` inclui os dois com default (`5`, `3`); `updateConfig()` grava se `!== undefined` (mesmo padrão do `modo_individual`).
- `pagamentos/pagamentos.service.ts:56` — trocar `?? 5` por `?? (platCfg.comissao_padrao_pct ?? 5)`.
- `restaurante/onboarding.controller.ts:56` — não enviar mais `comissao_pct: 5.0` no insert (deixa NULL = padrão global).

## 4. Frontend

**Novos:**
- `src/pages/admin-planos/index.jsx` — CRUD de planos, padrão `admin-tags` (Modal interno, `AdminNav` com link "Planos", dark mode zinc). Campos: nome, valor, periodicidade (select), limite_produtos (vazio=ilimitado), piso_faturamento (vazio=sempre cobra), trial_dias, ativo.
- Seção/aba na mesma página ou arquivo próprio pra **assinaturas por loja** (trocar plano, cancelar, gerar fatura manual) e **faturas globais** (filtro loja/status, marcar paga).
- `src/pages/restaurante-plano/index.jsx` — plano atual, status assinatura, faturas, botão "Pagar" (QR Pix + código copia-cola, polling via `GET /restaurante/plano/faturas/:id` até `paga`, mesmo padrão visual de `shopping-cart-checkout`).
- `src/services/planosService.js` — funções admin (getPlanos/criarPlano/atualizarPlano/removerPlano/getAssinaturas/atribuirAssinatura/cancelarAssinatura/gerarFaturaManual/getFaturas/marcarFaturaPaga), usando `apiPath('/api')`.
- Novas funções em `src/services/restauranteService.js`: `getMeuPlanoStatus`, `getMeuPlano`, `getMinhasFaturas`, `getFaturaDetalhe`, `pagarFatura`.

**Modificados:**
- `src/Routes.jsx` — rota `/restaurante/plano` (dentro de `<RestauranteGuard>`) e `/admin/planos`.
- `src/contexts/AuthContext.jsx` — novo state `planoStatus`; `useEffect` quando `userProfile?.role === 'restaurant_owner'` chama `getMeuPlanoStatus()`; expõe `planoStatus` no `value`.
- `src/components/RestauranteGuard.jsx` — após checks existentes: `if (planoStatus?.bloqueado && location.pathname !== '/restaurante/plano') return <Navigate to="/restaurante/plano" replace />`.
- `src/pages/admin-empresas/index.jsx` — Modal: `comissao_pct` vira input + checkbox "Usar padrão global" (marcado ⇒ desabilita input, manda `null`; desmarcado ⇒ sugere valor do padrão global buscado de `getPlataformaConfig()`). Linha 409 (exibição na lista) usa `e.comissao_pct ?? config_global` em vez de `?? 5` hardcoded.
- `src/pages/admin-configuracoes/index.jsx` — nova seção "Comissão e Inadimplência" (mesmo padrão visual das seções existentes) com `comissao_padrao_pct` e `plano_dias_tolerancia`, via `updatePlataformaConfig`.

## 5. Ordem de implementação (testável incrementalmente)

1. Migration SQL — validar local que o trigger de comissão continua funcionando com `comissao_pct NULL`.
2. `PlanosService` + `PlanosAdminController` (CRUD de planos) — testável via curl isolado.
3. `admin-planos` frontend (CRUD) — valida passo 2 visualmente.
4. Atribuição de assinatura por loja (`PUT/GET /planos/assinaturas`) + UI admin.
5. Check de limite de produtos em `criarProduto` — testa cadastrando até estourar.
6. Geração lazy de fatura + `GET /restaurante/plano/status` e `/restaurante/plano` (sem pagamento ainda).
7. Tela `restaurante-plano` (sem botão pagar funcional) + bloqueio em `AuthContext`/`RestauranteGuard` — testa fim a fim: fatura vencida → painel bloqueado → redireciona.
8. Integração PagBank (`/restaurante/plano/faturas/:id/pagar` + `/planos/webhook`) — por último, precisa de sandbox configurado.
9. Comissão global (DTO/service `plataforma`, seção `admin-configuracoes`, checkbox `admin-empresas`, fallback `pagamentos.service.ts`) — independente do resto, pode entrar em paralelo, mas feito por último pra não misturar escopos no mesmo ciclo de teste.

## Verificação

- Backend: `npx tsc --noEmit` em `server_delivery/` sem erros a cada etapa.
- Frontend: `npx vite build` sem erros a cada etapa.
- Migration: aplicar local (`supabase db reset` ou `db push` local), conferir `\d planos`, `\d assinaturas`, `\d plano_faturas`, e testar o trigger marcando um pedido como `delivered` pra uma loja com `comissao_pct NULL` (deve gravar `plataforma_comissoes` com o valor do padrão global).
- Fluxo fim a fim manual: criar plano de teste com `trial_dias=0`, periodicidade mensal, `limite_produtos=2`, atribuir a uma loja, cadastrar 2 produtos (ok) + 3º (bloqueado), forçar geração de fatura via botão admin, pagar via Pix sandbox, confirmar webhook marca `paga` e desbloqueia.
