---
name: deliveryhub-multi-tipo-estabelecimento
description: "Pivot do deliveryhub_white_label de \"só restaurante\" pra suportar qualquer tipo de estabelecimento com delivery (farmácia, mat. construção etc)"
metadata: 
  node_type: memory
  type: project
  originSessionId: 61bd9ff7-dd86-42e2-98a3-bd0208787756
  modified: 2026-07-23T15:12:16.526Z
---

Decisão de 2026-07-13: o projeto [[project_deliveryhub_white_label]] deixa de ser exclusivo pra restaurantes — a ideia é permitir cadastro de qualquer estabelecimento que faça delivery (farmácia, material de construção, etc — restaurante é só mais um tipo entre outros).

**Why:** ampliar o mercado do white label além de comida.

**Como foi implementado (fase 1, escopo combinado com o usuário):**
1. Nova tabela `establishment_types` (migration em `supabase/migrations/`) com seed dos tipos (Restaurante, Farmácia, Material de Construção etc) — populada só pelo dev via SQL, sem tela de CRUD ainda.
2. Coluna `type_id` adicionada em `restaurants` (nullable/default apontando pro tipo Restaurante), aditiva — não alterou nada existente.
3. Textos trocados (sem mexer em layout/estrutura): "Cadastrar meu restaurante" → "Cadastrar meu estabelecimento" e variações, em `customer-registration-login/index.jsx` e `menu-catalog-product-browse/index.jsx`.
4. Removido bloco de credenciais dev exposto na tela de login (`admin@test.com` / `Test@1234`) — não deve vazar credencial de teste em produção.

Branch da fase 1: `feat/tipo-estabelecimento` (front e submodule `server_delivery`), já merged na main dos dois em 2026-07-13.

**Atualizado 2026-07-23, verificado no código atual:** fases seguintes já implementadas e mergeadas em main:
- CRUD admin de tipos de estabelecimento (commit `50b0c10` no backend, "feat: CRUD admin de tipos de estabelecimento").
- Seletor de tipo de estabelecimento no formulário `restaurant-registration-setup` (`type_id`/`establishment_types` presentes em `src/pages/restaurant-registration-setup/index.jsx`).

Não confirmado se a renomeação `restaurants` → `establishments` genérico chegou a acontecer (não verificado nesta rodada) — tratar como possivelmente ainda pendente se for relevante pra alguma tarefa nova.
