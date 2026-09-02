# Marketplace pago — vender posição nos carrosséis do marketplace

## Contexto

Hoje, `menu-catalog-product-browse/index.jsx` (a home pública do marketplace, `localhost:4028/`) já mistura produtos de **várias lojas diferentes** em 4 carrosséis: Combos, Mais Vendidos, Em Promoção, Lançamentos — cada card já mostra o nome da loja dona e linka pra ela (`ProdCarrosselCard`/`ComboCarrosselCard`). Isso é decisivo: a estrutura de "vitrine compartilhada entre lojas" já existe, não precisa ser inventada.

O que falta é **vender posição** nesses carrosséis: um restaurante paga pra ter X produtos seus aparecendo ali por um período, além do que já aparece organicamente (produto com `destaque=true`, tag `promo`, etc.).

Decisões de negócio já fechadas com o usuário:
- **Os 4 carrosséis entram no modelo pago** (Combos, Mais Vendidos, Em Promoção, Lançamentos).
- **Vagas limitadas por carrossel** (ex.: só 3 posições pagas em "Lançamentos" por vez) — cria escassez real, evita o carrossel virar 100% propaganda, e dá um estado claro de "sem vagas".
- **Pacotes fixos pré-definidos pelo admin** (ex.: "1 produto / 7 dias — R$29"), não um cálculo livre de N×dias.

**Risco que sinalizei e o usuário optou por assumir**: "Mais Vendidos" hoje não é baseado em venda real (é o `destaque` manual, ver `menu-catalog-product-browse/index.jsx` linhas 932-948) e "Em Promoção" depende de tag `promo`. Vender posição paga nesses dois sem deixar claro pro cliente final pode parecer enganoso. **Mitigação que vou incluir по padrão**: todo card patrocinado ganha uma etiqueta pequena "Patrocinado" — resolve a questão de transparência sem mudar a decisão de negócio do usuário.

## O que já existe e vou reaproveitar

- **Carrosséis e cards já cross-loja**: `ProdCarrossel`/`ComboCarrossel`/`ProdCarrosselCard`/`ComboCarrosselCard` em `menu-catalog-product-browse/index.jsx` (linhas ~345-517) — cada item já carrega `produto.restaurante`/`combo.restaurante`.
- **Fonte dos 4 carrosséis hoje**:
  - Combos: `GET /api/r/combos` → `catalogo.controller.ts todosOsCombos()` (linhas 237-282), `.in('restaurant_id', restIds)`, cache Redis 15s.
  - Produtos (Mais Vendidos/Promoção/Lançamentos): `GET /api/r/produtos` → `todosOsProdutos()` (linhas 194-232), mesmo padrão de cache; o frontend filtra client-side por tag (`tagsCatalogo`, `is_auto` cai pro fallback `destaque`, senão `tags.includes(tag.slug)`) nas linhas 932-948.
- **Pagamento do dono pra plataforma** (não é o cliente pagando pedido): `PlanosService.pagarFatura()` (`planos.service.ts` linhas 637-697) — `clientPlataforma()` (conta PagBank da própria plataforma, não do restaurante) → `criarOrdemPix`/`criarOrdemCartao`, grava `pix_code`/`pagbank_order_id` na linha, confirma via webhook dedicado (`planos-webhook.controller.ts`). É exatamente o formato de cobrança "avulsa" que uma compra de pacote de destaque precisa — vou replicar esse padrão pra uma tabela nova, não mexer nas tabelas de plano recorrente.
- **Padrão de config global**: `platform_settings.config` (JSONB, já usado pra `comissao_padrao_pct`) — vou guardar a capacidade de vagas por carrossel ali (`{ marketplace_slots: { combos: 3, mais_vendidos: 3, promocao: 3, lancamentos: 3 } }`), sem tabela nova só pra isso.
- **Padrão de modal "selecionar produtos" com contador**: `CardapioImpressoModal`/`GdoorMapeamentoModal` — mesmo formato pro dono escolher quais produtos entram no pacote comprado.
- **Padrão de admin CRUD de "produto vendável" com preço/período**: `admin-planos/index.jsx` + `planos.service.ts` (`criarPlano`/`atualizarPlano`) — mesmo espírito pros pacotes de destaque.

## Modelo de dados (2 tabelas novas)

```sql
-- Pacotes vendáveis, definidos pelo admin da plataforma (mesmo espírito de "planos").
CREATE TABLE public.marketplace_boost_pacotes (
  id            BIGSERIAL PRIMARY KEY,
  nome          TEXT NOT NULL,
  carrossel     TEXT NOT NULL CHECK (carrossel IN ('combos','mais_vendidos','promocao','lancamentos')),
  qtd_produtos  INT NOT NULL CHECK (qtd_produtos > 0),
  dias          INT NOT NULL CHECK (dias > 0),
  preco         NUMERIC(10,2) NOT NULL,
  ativo         BOOLEAN NOT NULL DEFAULT true,
  created_at    TIMESTAMPTZ DEFAULT NOW()
);

-- Campanhas compradas (histórico + ativas). "Ativo" é sempre calculado por data
-- (pago_em IS NOT NULL AND fim_em > now()) — sem job/cron pra virar status,
-- este projeto não tem infra de cron interno hoje.
CREATE TABLE public.marketplace_boosts (
  id              BIGSERIAL PRIMARY KEY,
  restaurant_id   BIGINT NOT NULL REFERENCES public.restaurants(id) ON DELETE CASCADE,
  pacote_id       BIGINT NOT NULL REFERENCES public.marketplace_boost_pacotes(id),
  carrossel       TEXT NOT NULL,              -- denormalizado do pacote, facilita a query de vagas
  item_ids        BIGINT[] NOT NULL,          -- product_id[] (ou combo_id[] quando carrossel='combos')
  valor_centavos  INT NOT NULL,
  pagbank_order_id TEXT,
  pix_code        TEXT,
  pix_qr_url      TEXT,
  pago_em         TIMESTAMPTZ,
  fim_em          TIMESTAMPTZ,                -- calculado no momento da confirmação: pago_em + pacote.dias
  created_at      TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX idx_marketplace_boosts_ativos ON public.marketplace_boosts (carrossel, fim_em) WHERE pago_em IS NOT NULL;
```

**Vaga ocupada = produto, não campanha**: comprar "3 produtos" consome 3 das vagas configuradas daquele carrossel (`SUM(array_length(item_ids,1))` sobre boosts ativos < capacidade configurada) — não 1 vaga por compra.

## Backend

- **`server_delivery/src/marketplace-boost/`** (módulo novo, mesmo padrão de `planos/`):
  - `marketplace-boost.service.ts`: `listarPacotes()` (com `vagas_disponiveis` calculado por carrossel), `criarBoost(restaurantId, pacoteId, itemIds)` (valida: itens pertencem ao restaurante, `itemIds.length === pacote.qtd_produtos`, vaga disponível — senão `ConflictException('Sem vagas nesse carrossel no momento')`), `pagarBoost(...)` (clona o padrão de `pagarFatura`, reaproveitando `clientPlataforma()`), `meusBoosts(restaurantId)`.
  - `marketplace-boost-admin.service.ts` (ou métodos no mesmo service, guardado por `AdminGuard`): CRUD de `marketplace_boost_pacotes`, editar `platform_settings.config.marketplace_slots`.
  - Webhook: reaproveitar `planos-webhook.controller.ts` (mesma conta PagBank da plataforma) ou duplicar o padrão num `marketplace-boost-webhook.controller.ts` dedicado — decidir na hora, olhando como o `reference_id` já é usado pra rotear entre os dois webhooks de pagamento existentes no projeto (`pagamentos` vs `planos`) antes de criar um terceiro.
- **Rota pública nova**: `GET /api/r/patrocinados` em `catalogo.controller.ts`, cache Redis curto (mesmo padrão 15s) — retorna `{ combos: [ids...], mais_vendidos: [ids...], promocao: [ids...], lancamentos: [ids...] }` só com boosts `pago_em IS NOT NULL AND fim_em > now()`.
- **Rotas dono** (`RestaurantOwnerGuard`): `GET restaurante/boosts/pacotes`, `POST restaurante/boosts`, `GET restaurante/boosts`.
- **Rotas admin** (`AdminGuard`): CRUD de pacotes + config de vagas.

## Frontend

- **`menu-catalog-product-browse/index.jsx`**: busca `/api/r/patrocinados` junto dos outros fetches iniciais; pra cada carrossel, prepend os itens patrocinados (puxados do array já carregado de `produtos`/`combos` pelo id) antes de fatiar os 20 exibidos, e passa uma prop `patrocinado` pro card correspondente renderizar a etiqueta "Patrocinado".
- **Painel do dono** (novo, ex. `restaurante-marketplace-boost` ou seção em `restaurante-config`): lista pacotes disponíveis por carrossel com vagas restantes, modal de seleção de produtos (mesmo padrão do `CardapioImpressoModal`: checkbox + contador, trava em `pacote.qtd_produtos` selecionados), tela de pagamento PIX/cartão reaproveitando o componente já usado no pagamento de fatura de plano (`restaurante-financeiro` ou onde `pagarFatura` já é chamado no frontend — localizar antes de implementar).
- **Painel admin** (novo, mesmo padrão de `admin-planos/index.jsx`): CRUD de pacotes por carrossel + campo de vagas por carrossel.

## Recomendação de execução (não é escopo, é ordem)

Dado o tamanho (2 tabelas, pagamento avulso, 3 telas novas, mudança na home pública), sugiro implementar e testar **um carrossel só primeiro** (ex. Lançamentos — o de menor risco de reputação) ponta a ponta, confirmar que compra→pagamento→aparição no marketplace funciona de verdade, e só depois replicar pros outros 3 (o schema já suporta os 4 desde o início, é só questão de cadastrar pacotes pros outros carrosséis depois).

## Verificação

1. `npx tsc --noEmit` (backend) e `npx vite build` (frontend) limpos.
2. Migration aplicada local primeiro, depois produção (regra já combinada).
3. Fluxo manual completo: admin cria pacote + define vagas → dono compra (PIX sandbox ou cartão) → webhook confirma → produto aparece no carrossel certo do marketplace com etiqueta "Patrocinado" → comprar além da capacidade retorna erro de "sem vagas" → após `fim_em`, produto some sozinho do carrossel (sem precisar de job, só passagem de tempo/data mockada).
