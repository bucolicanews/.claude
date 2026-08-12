# Colaboradores por caixa (link + senha) + edição de caixa pelo dono

## Contexto

Depois de implementar múltiplos caixas simultâneos (Principal/Bar/Salão), o único jeito de "escolher qual caixa operar" é um seletor na tela que salva a escolha no `localStorage` do navegador (`src/utils/caixaSessao.js`) — funciona pro garçom/dono que já está logado, mas não dá um jeito de **uma pessoa do setor (ex: o bartender) logar direto naquele caixa**, sem depender de um login de garçom genérico. O usuário quer resolver isso com uma tabela de **colaboradores**: cada colaborador tem login próprio (link + senha) e um **setor** fixo (Bar, Salão...) — ao logar, cai direto operando o caixa daquele setor, sem escolher nada. Além disso, o dono precisa **ver e editar** os caixas abertos (hoje só abre/fecha, não edita nome/operador/valor nem reabre).

Referência direta: o sistema de **garçom** já resolve exatamente esse padrão (tabela própria, login via link com `login_key` na URL + senha, JWT custom, guard próprio) — `colaboradores` é uma tabela **separada** de `garcons` (não reaproveita), mas replica a mesma arquitetura.

## Decisões já validadas com o usuário

- `colaboradores` é tabela nova, independente de `garcons`.
- O link/senha é por **colaborador** (não por caixa) — colaborador tem um **setor** (texto livre, casa com o campo `nome` de `caixas`) e, ao logar, o backend resolve dinamicamente qual caixa está aberto com aquele nome. Isso importa porque `caixas` são efêmeras (fecha e abre uma linha nova todo turno) — colaborador não pode ficar preso a um `caixa_id` fixo de uma linha específica, senão quebra no dia seguinte quando o caixa daquele setor reabre como outra linha.
- Dono pode editar **tudo** de um caixa aberto: nome, nome_operador, valor_inicial, e também fechar/reabrir.

## Descobertas (mapeamento do garçom como blueprint)

- `garcons` (`supabase/migrations/20260714000004_garcons.sql`): id, restaurant_id, nome, telefone, `login_key` (UNIQUE **global**, não por restaurante), password_hash, ativo, permissoes jsonb, ultimo_acesso_em.
- Login: `garcom-auth.service.ts` — `login(loginKey, password)` busca por `login_key` global, `bcrypt.compare`, gera JWT `{ garcomId }` com `jwt.sign(..., { expiresIn: '12h' })` usando secret `GARCOM_JWT_SECRET`. Controller `garcom-auth.controller.ts` expõe `POST garcom/auth/login`.
- Guard: `garcom.guard.ts` lê header `x-garcom-token`, valida JWT, busca garçom (`ativo`, dados do restaurante), popula `request.garcomId/garcomNome/garcomRestaurantId/...`.
- CRUD pelo dono: `garcons.service.ts` (`criar` gera `login_key` com `crypto.randomBytes(4).toString('hex')`, retry até 5x por causa da unicidade global; `listar`/`atualizar`/`remover`/`garconsOnline`). Controller `restaurante-garcons.controller.ts` (`RestaurantOwnerGuard`).
- Tela do dono: `src/pages/restaurante-garcons/index.jsx` — form simples (nome, telefone, senha inicial) + card por garçom mostrando o link `${origin}/garcom/${login_key}` copiável.
- Tela de login do garçom: `src/pages/garcom-portal/index.jsx`, rota `/garcom/:loginKey` (`src/Routes.jsx`) — `loginKey` vem da **URL** via `useParams`, tela só pede a senha. Token salvo em `localStorage`, enviado via header `x-garcom-token` (`garcomService.js`).
- Rotas hoje exclusivas do dono que um colaborador de setor vai precisar chamar: `POST restaurante/salao/venda-direta`, `POST restaurante/salao/comandas/abrir`, e as rotas de caixa (`restaurante.controller.ts`: abrir/fechar/saida/entrada) — todas atrás de `RestaurantOwnerGuard` hoje. Vou **reusar os métodos de serviço já existentes** (`SalaoPdvService.vendaDireta/abrirComanda/pagar`, `RestauranteService.abrirCaixa/fecharCaixa`) por trás de um guard/controller novo — não duplica lógica de negócio, só adiciona uma porta de entrada scoped ao colaborador.

## Parte 1 — Tabela + auth de colaboradores (mirror do garçom)

### Banco (migration nova)
```sql
CREATE TABLE public.colaboradores (
  id SERIAL PRIMARY KEY,
  restaurant_id INT NOT NULL REFERENCES restaurants(id) ON DELETE CASCADE,
  nome TEXT NOT NULL,
  telefone TEXT,
  setor TEXT NOT NULL,           -- casa com caixas.nome (ex: "Bar", "Salão")
  login_key TEXT NOT NULL UNIQUE,
  password_hash TEXT NOT NULL,
  ativo BOOLEAN NOT NULL DEFAULT true,
  ultimo_acesso_em TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW()
);
-- RLS: owner do restaurante, igual garcons_owner
```

### Backend
- `server_delivery/src/auth/colaborador.guard.ts` — cópia adaptada de `garcom.guard.ts`: header `x-colaborador-token`, secret `COLABORADOR_JWT_SECRET`, payload `{ colaboradorId }`, popula `request.colaboradorId/colaboradorNome/colaboradorRestaurantId/colaboradorSetor`. Não depende de "restaurante aberto" (isso é regra do garçom/delivery, colaborador de caixa não precisa).
- `server_delivery/src/colaboradores/colaborador-auth.service.ts` — `login(loginKey, password)`, mesmo padrão bcrypt + JWT (`expiresIn: '12h'`, mesmo prazo do garçom).
- `server_delivery/src/colaboradores/colaboradores.service.ts` — CRUD pelo dono: `criar` (nome, telefone?, setor, senha — gera `login_key` com `crypto.randomBytes(4).toString('hex')` + retry de unicidade, igual `garcons.service.ts`), `listar`, `atualizar`, `remover`.
- `server_delivery/src/colaboradores/colaborador-auth.controller.ts` — `POST colaborador/auth/login` (público).
- `server_delivery/src/colaboradores/restaurante-colaboradores.controller.ts` — `@Controller('restaurante/colaboradores')`, `RestaurantOwnerGuard`: `GET /`, `POST /`, `PATCH /:id`, `DELETE /:id`.
- Registrar o novo módulo (`ColaboradoresModule`) no `app.module.ts` (mirror de como o módulo de garçom/salão está registrado).

### Frontend
- `src/services/colaboradorService.js` — mirror de `garcomService.js` (login, token em `localStorage` chave `colaborador_access_token`, header `x-colaborador-token`).
- `src/services/restauranteService.js` — `listColaboradores/criarColaborador/atualizarColaborador/removerColaborador`.
- `src/pages/restaurante-colaboradores/index.jsx` — mirror de `restaurante-garcons/index.jsx`: form (nome, telefone, **setor** — input texto livre ou datalist com os nomes de caixa já usados, senha inicial) + card com link `${origin}/colaborador/${login_key}` copiável, ativar/desativar/remover.
- Link no menu lateral do dashboard (mirror do item "Garçons").

## Parte 2 — Operar o caixa do setor (colaborador logado)

### Backend
- `server_delivery/src/colaboradores/colaborador.controller.ts` — `@Controller('colaborador')`, `@UseGuards(ColaboradorGuard)`:
  - `GET me` — retorna `{ nome, setor, caixaAberto }`, onde `caixaAberto` vem de resolver `caixas` com `restaurant_id + nome=setor + status=aberto` (mesma query já usada em vários lugares do `restaurante.service.ts`/`salao.service.ts`).
  - `POST caixa/abrir` — chama `RestauranteService.abrirCaixa(restaurantId, { nome_operador: colaboradorNome, nome: setor, valor_inicial, is_principal: false })`.
  - `POST caixa/fechar` — resolve o caixa do setor e chama `RestauranteService.fecharCaixa` com o `caixa_id` resolvido (aceita `permitir_pendencias` igual ao fluxo do dono).
  - `POST venda-direta` — chama `SalaoPdvService.vendaDireta(restaurantId, itens, forma_pagamento, valor_recebido, caixaId)` (caixaId resolvido do setor).
  - `GET comandas`, `POST comandas/abrir`, `POST comandas/:id/pagar` — reusa `SalaoPdvService` passando o `caixa_id` do setor (cobre o caso de um setor tipo "Bar" que também atende comanda/mesa, não só balcão).
- Nenhuma lógica de negócio nova aqui — só uma porta de entrada scoped por setor chamando os services que já existem.

### Frontend
- `src/pages/colaborador-portal/index.jsx` — rota `/colaborador/:loginKey` (`src/Routes.jsx`). Login (só senha, `loginKey` da URL) → tela simples "Caixa: {setor}":
  - Fechado: botão abrir (valor inicial).
  - Aberto: resumo (vendas, saldo), botão "Venda direta" (reusa o mesmo componente de carrinho já existente, adaptado), lista de comandas do setor (se houver), botão "Fechar caixa" (reusa o fluxo de conferência + opção "fechar mesmo assim/pendente" já existente no `FecharCaixaModal`, adaptado pro contexto do colaborador).

## Parte 3 — Dono ver/editar caixas

### Backend
- `RestauranteService.atualizarCaixa(restaurantId, caixaId, body: { nome?, nome_operador?, valor_inicial? })` — só permite em caixa `status='aberto'`.
- `RestauranteService.reabrirCaixa(restaurantId, caixaId)` — só o caixa fechado mais recente daquele "nome", volta `status='aberto'` (respeita os índices únicos parciais já existentes — falha com erro claro se já existe outro aberto com o mesmo nome).
- Rotas em `restaurante.controller.ts`: `PATCH caixa/:id`, `POST caixa/:id/reabrir`.

### Frontend
- `OutrosCaixasPanel.jsx` (já existe): cada card ganha modo de edição inline (nome, nome_operador, valor_inicial) e mostra o colaborador responsável (se houver um colaborador com `setor === caixa.nome`) com o link de acesso dele.
- Card do caixa Principal (`restaurante-dashboard/index.jsx`) ganha o mesmo botão de editar.
- Histórico (`HistoricoCaixasPanel.jsx`): botão "Reabrir" no caixa fechado mais recente de cada nome (quando não há outro aberto com esse nome).

## Ordem de implementação
1. Migration `colaboradores` + módulo backend completo (auth + CRUD) — testável isolado via curl/Postman antes de mexer em frontend.
2. Frontend de gestão (`restaurante-colaboradores`) — dono consegue criar colaborador e ver o link.
3. Backend Parte 2 (rotas scoped do colaborador) + `colaborador-portal` frontend — fluxo ponta a ponta de abrir/vender/fechar pelo link.
4. Parte 3 (editar/reabrir caixa) — independente das partes 1-2, pode vir em paralelo ou depois.

## Verificação
- `npx supabase db reset` local (nova migration).
- Criar colaborador setor "Bar" pelo dashboard, copiar link, abrir em aba anônima, logar só com senha.
- Abrir caixa Bar pelo colaborador → confirmar aparece em `GET restaurante/caixa/abertos` (visão do dono) com `nome_operador` = nome do colaborador.
- Fazer uma venda direta pelo colaborador → confirmar aparece no resumo do caixa Bar.
- Fechar caixa Bar pelo colaborador (com e sem pendência) → confirmar histórico mostra certo.
- Dono edita nome/valor_inicial do caixa Bar aberto, reabre um caixa fechado — conferir que os índices únicos (1 principal, nomes não duplicados entre abertos) continuam sendo respeitados.
- `npx tsc --noEmit` no `server_delivery` e `npx vite build` no repo principal.
