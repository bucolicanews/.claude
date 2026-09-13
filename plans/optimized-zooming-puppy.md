# Licenciamento de Módulos por Pacote + Contabilidade própria de Contador/Plataforma

## Contexto

Hoje só a **empresa-cliente** tem contabilidade própria (plano de contas, lançamentos, contas a pagar/receber, contratos etc.) — contador e a própria Jota não têm nada disso pra controlar o próprio negócio. E não existe nenhum controle de "quais telas essa empresa pode ver" — todo módulo já implementado (Conciliação, CP/CR, Contratos, Documentos Societários, Protocolos, Bancos, Relatórios...) está liberado pra qualquer empresa cadastrada, sem depender de nenhum plano.

O usuário quer um modelo de negócio de duas camadas:
1. **Atacado (Admin↔Contador):** Jota vende **pacotes de módulos** (ex: "Integrador + Fluxo de Caixa") pro contador. Comprar gera uma **licença interna** (sem código visível) que o contador pode **ativar em qualquer empresa da própria carteira**, liberando ali os módulos daquele pacote.
2. **Varejo (Contador↔Empresa-cliente):** ao ativar a licença numa empresa, o contador **gera um contrato** (o módulo Contratos que já existe) cobrando o valor que ele mesmo decide da empresa. Isso precisa criar automaticamente uma **conta a receber** nos livros do próprio contador e uma **conta a pagar espelhada** nos livros da empresa — o mesmo mecanismo vale um nível acima (admin cobra o contador pelo pacote → conta a receber no admin / conta a pagar no contador).

Isso exige contador e a própria Jota terem sua própria "empresa" (reaproveitando 100% o schema/módulos já existentes de plano de contas/lançamentos/CP-CR), e um jeito de uma cobrança criada por um lado do sistema aparecer automaticamente do outro lado, em outra tenant, sem duplicar lançamento manual.

Decisões já fechadas com o usuário (via conversa, não todas por AskUserQuestion — usuário prefere responder direto):
- `planos`/`assinaturas` de crédito SERPRO **continuam intocados**, sistema completamente separado.
- Contador (e a Jota) viram uma linha na tabela `empresas` existente — sem tabela paralela.
- "Token"/licença é só um registro interno; contador clica "ativar nesta empresa", sem código pra copiar.
- Espelho financeiro sempre sincroniza no cancelamento/estorno (nunca fica dessincronizado).
- O mecanismo que gera a conta a pagar na empresa quando o contador cobra ela é o **módulo Contratos que já existe** — não um fluxo novo do zero.

**Assunções que fiz e não foram confirmadas explicitamente** (documentando aqui pra revisão, não vou perguntar de novo antes de implementar — corrija se algo estiver errado):
- Núcleo contábil (Lançamentos, Plano de Contas, Contas a Pagar/Receber, Clientes, Fornecedores, Históricos) fica **sempre liberado** pra qualquer empresa cadastrada, sem depender de pacote. Só os módulos "extras" (Contratos, Documentos Societários, Conciliação Bancária + picklists/Mapeamento, Protocolos, Bancos, Relatórios) entram no controle de licenciamento.
- A compra do pacote pelo contador (atacado) passa pelo **Stripe Checkout de verdade**, no mesmo padrão já usado por `AssinaturasModule` (créditos SERPRO) — não é registro manual.
- "Pacote" e "plano" viram uma coisa só (`pacotes_modulos`: nome + lista de módulos + preço + periodicidade) — não crio uma camada extra separando "pacote" (bundle de módulos) de "plano" (preço). Simplifica o v1; dá pra separar depois se precisar reusar o mesmo pacote em vários planos de preço.

## Descobertas da exploração (pontos que mudam o desenho)

- `empresas.contador_id` é `NOT NULL` — toda empresa já pertence a um contador, então a "empresa própria do contador" só precisa de `contador_id = ele mesmo`, sem mudar essa FK. Falta um discriminador de **tipo** (`cliente` vs "essa é a contabilidade do próprio contador/da própria Jota"), que não existe hoje.
- `contadores.tipo='interno_jota'` já existe no schema mas **nunca foi de fato criado** (zero seed, zero uso real) — hoje é só um fallback teórico documentado. Vou criar esse singleton de verdade e reaproveitá-lo tanto pra empresa-sem-contador-humano (uso original) quanto pra ser o contador dono da "empresa da própria Jota".
- `contas_pagar.fornecedor`/`contas_receber.cliente_nome` são **texto livre, sem FK** (decisão de design já documentada no schema) — ótimo pra este caso: a cobrança espelhada não precisa de FK pro tenant do outro lado, só grava o nome de exibição.
- `contas_pagar.criado_por`/`contas_receber.*.criado_por`/`lancamentos_contabeis.criado_por` são `NOT NULL references usuarios(id)` — uma cobrança gerada pelo sistema (sem usuário humano agindo) precisa de um `usuarios.id` válido. Resolvo com um **usuário-sistema** seedado (conta real no Supabase Auth, bloqueada pra login), em vez de mudar a constraint em várias tabelas.
- `criar_lancamento_contabil`/`criar_conta_receber_com_parcelas`/`criar_conta_pagar_com_parcelas` operam **numa empresa só** — não existe conceito de lançamento cross-empresa. O espelho financeiro precisa ser uma função Postgres nova que chama as duas (receber numa empresa + pagar na outra) dentro da **mesma transação**, senão um lado pode gravar e o outro falhar.
- `MenuLateral.tsx` hoje não tem NENHUM gate condicional — todo item aparece sempre. Vai precisar de um campo `modulo` opcional por item + um hook novo que busca quais módulos a empresa ativa tem liberado.
- `contratos_gerados.cliente_id` só aceita um `clientes` (cadastro interno da própria empresa) — pra "contador gera contrato contra uma empresa da carteira dele", a contraparte precisa poder ser uma `empresas`, não um `clientes`. Isso muda o schema de `contratos_gerados` (contraparte vira `cliente_id` OU `empresa_contraparte_id`, exatamente um dos dois).

## Schema (migration nova)

```sql
-- Discrimina empresas "de verdade" das de uso interno (contador/plataforma controlando o próprio negócio)
alter table empresas add column tipo text not null default 'cliente'
  check (tipo in ('cliente', 'interna_contador', 'interna_plataforma'));
create unique index idx_empresas_interna_contador on empresas(contador_id) where tipo = 'interna_contador';

-- Seed: contador interno da Jota (singleton) + a empresa própria da Jota
insert into contadores (tipo, nome, cnpj_cpf, email) values ('interno_jota', 'Jota Contabilidade', ..., ...)
  on conflict do nothing; -- ou checagem por tipo, já que não há unique em tipo hoje -- avaliar na implementação
insert into empresas (contador_id, tipo, razao_social, cnpj, modo_acesso_serpro) values (<id acima>, 'interna_plataforma', 'Jota Contabilidade', ..., 'procuracao');

-- Usuário-sistema (criado_por de lançamentos automáticos) -- conta real no Supabase Auth via Admin API,
-- feita na aplicação (não dá pra criar auth.users só de SQL), referenciada aqui como constante de config.

-- Catálogo de pacotes vendáveis pelo admin
create table pacotes_modulos (
  id uuid primary key default gen_random_uuid(),
  nome text not null,
  modulos text[] not null,              -- ex: '{contratos,conciliacao_bancaria}'
  preco numeric(12,2) not null check (preco >= 0),
  periodicidade text not null check (periodicidade in ('mensal', 'anual')),
  ativo boolean not null default true,
  criado_em timestamptz not null default now(),
  atualizado_em timestamptz not null default now()
);

-- Uma linha por "assento" comprado pelo contador -- o "token" interno, sem código visível
create table licencas_modulo (
  id uuid primary key default gen_random_uuid(),
  contador_id uuid not null references contadores(id),
  pacote_id uuid not null references pacotes_modulos(id),
  empresa_id uuid references empresas(id),  -- null = comprada mas ainda não ativada em nenhuma empresa
  status text not null default 'disponivel' check (status in ('disponivel', 'ativa', 'cancelada')),
  stripe_subscription_id text,
  ativado_em timestamptz,
  criado_em timestamptz not null default now()
);
create unique index idx_licencas_modulo_empresa_ativa on licencas_modulo(empresa_id) where status = 'ativa';
-- (uma empresa só tem 1 licença ativa por vez nesta v1 -- pacote define o conjunto de módulos daquela licença)

-- Rastreia o par receber/pagar de uma cobrança interna, pra cancelar/estornar os dois lados juntos
create table vinculos_financeiros_espelho (
  id uuid primary key default gen_random_uuid(),
  contrato_id uuid references contratos_gerados(id),
  conta_receber_id uuid not null references contas_receber(id),
  conta_pagar_id uuid not null references contas_pagar(id),
  estornado boolean not null default false,
  criado_em timestamptz not null default now()
);

-- Contraparte de um contrato pode ser um cliente OU uma empresa da carteira do contador -- exatamente um dos dois
alter table contratos_gerados alter column cliente_id drop not null;
alter table contratos_gerados add column empresa_contraparte_id uuid references empresas(id);
alter table contratos_gerados add constraint contratos_gerados_contraparte_check
  check ((cliente_id is not null) <> (empresa_contraparte_id is not null));

-- RLS novas (mesmo padrão pode_acessar_empresa/eh_plataforma já usado em todo lugar) +
-- catálogo de permissões pacotes_modulos:*/licencas_modulo:* pra SUPER_ADMIN/CONTADOR_DONO.

-- Checagem de módulo liberado -- mesmo padrão SECURITY DEFINER de pode_acessar_empresa
create or replace function empresa_tem_modulo(p_empresa_id uuid, p_modulo text)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from licencas_modulo lm
    join pacotes_modulos pm on pm.id = lm.pacote_id
    where lm.empresa_id = p_empresa_id and lm.status = 'ativa' and p_modulo = any(pm.modulos)
  )
$$;

-- Emite a cobrança dos dois lados numa transação só -- nunca um lado grava sem o outro
create or replace function emitir_cobranca_interna(
  p_empresa_credora_id uuid, p_nome_devedor text,
  p_empresa_devedora_id uuid, p_nome_credor text,
  p_descricao text, p_conta_patrimonial_credora_id uuid, p_conta_resultado_credora_id uuid,
  p_conta_patrimonial_devedora_id uuid, p_conta_resultado_devedora_id uuid,
  p_data_emissao date, p_criado_por uuid, p_parcelas jsonb, p_contrato_id uuid
) returns table(conta_receber_id uuid, conta_pagar_id uuid)
language plpgsql security definer set search_path = public as $$ ... $$;
-- chama criar_conta_receber_com_parcelas (lado credor) + criar_conta_pagar_com_parcelas (lado devedor)
-- dentro da mesma função (mesma transação implícita), grava vinculos_financeiros_espelho, retorna os 2 ids.

-- Estorna os dois lados juntos
create or replace function estornar_cobranca_interna(p_vinculo_id uuid, p_motivo text, p_executado_por uuid)
returns void language plpgsql security definer set search_path = public as $$ ... $$;
```

## Backend (`jota_integrador`)

- **`src/pacotes-modulos/`** (Clean Architecture igual todo módulo existente) — CRUD simples pro admin (`@Papeis(Papel.SUPER_ADMIN)`, mesmo padrão de `contadores.module.ts`). `Criar/Listar/Atualizar/DesativarPacoteUseCase`.
- **`src/licencas-modulo/`**:
  - `ComprarLicencaUseCase` — Stripe Checkout Session (reaproveita o padrão de `src/assinaturas/` — `price_data` inline, não Price pré-criado, mesma lição já documentada). Webhook de sucesso cria a `licenca_modulo` com `status='disponivel'`.
  - `AtivarLicencaUseCase` — recebe `licencaId` + `empresaId` (da carteira do contador) + `valorCobrado`/parcelamento. Seta `empresa_id`/`status='ativa'` na licença, e dispara `CriarContratoUseCase` (do módulo `contratos/`, estendido — ver abaixo) com `empresaContraparteId = empresaId`, `empresaId (issuer) = empresa interna do contador`.
  - `ListarLicencasUseCase`, `DesativarLicencaUseCase` (libera a empresa pra reativar outra licença depois).
- **`src/contratos/`** (existente, Fase 6) — extensão, não módulo novo:
  - `CriarContratoUseCase`: aceita `clienteId` OU `empresaContraparteId` (exatamente um). Quando é `empresaContraparteId`: `resolverTagsAutomaticas` usa a razão social/CNPJ da empresa contraparte no lugar dos campos de `cliente`; e a criação financeira passa a chamar **`emitir_cobranca_interna`** (empresa emissora = credora, empresa contraparte = devedora) em vez do atual `CriarContaReceberUseCase` isolado.
  - `ExcluirContratoUseCase`/`RegistrarAditivoUseCase`: mesma checagem de recebimento, mas cancelamento agora passa por `estornar_cobranca_interna` quando o contrato tem `empresaContraparteId` (precisa cancelar os dois lados).
- **Módulo de gating** — `src/common/modulos/` novo: decorator `@ExigirModulo('contratos')` + `ModulosGuard` (chama `empresa_tem_modulo` via RPC, resolve `empresaId` do param de rota igual `PermissoesGuard` resolve usuário). Aplicado em `ContratosController`, `DocumentosSocietariosController`, `ConciliacaoBancariaController`, `ProtocolosController`, `BancosController`, `RelatoriosController`, `DescricoesExtratoController`/`IdentificadoresExtratoController` — mesmo padrão de `@UseGuards()` em cadeia já usado (`SupabaseAuthGuard, PapeisGuard, PermissoesGuard, ModulosGuard`). CP/CR, Lançamentos, Plano de Contas, Clientes, Fornecedores, Históricos **não** recebem esse guard (núcleo sempre liberado). `eh_plataforma()`/empresas `tipo != 'cliente'` sempre passam, sem checar licença.
- **`CriarContadorUseCase`** (`src/contadores/`): passa a também criar a `empresa` interna do contador (`tipo='interna_contador'`, `contador_id` = o próprio, CNPJ = o mesmo do contador) e semear um plano de contas mínimo nela (Ativo>Contas a Receber, Passivo>Contas a Pagar, Receita>Serviços, Despesa>Licenças/Honorários) — mesmo padrão de seed simples já usado no primeiro boot do projeto.
- **Endpoint novo** `GET /empresas/:id/modulos` — lista módulos liberados (usado pelo frontend pra montar o menu).

## Frontend (`jota_fiscal_frontend`)

- **`useModulosLicenciados` hook** novo — busca `GET /empresas/:id/modulos` pra empresa ativa (`useEmpresaAtiva`), cacheia em memória do componente (sem localStorage, evita o problema de cache obsoleto já identificado na exploração).
- **`MenuLateral.tsx`** — cada `ItemMenu` ganha `modulo?: string`; itens sem `modulo` sempre aparecem (núcleo); itens com `modulo` só aparecem se `useModulosLicenciados` incluir aquela chave.
- **`/admin/pacotes`** — CRUD de pacotes (grid de módulos com checkbox, preço, periodicidade) — reaproveita o padrão de tabela+dialog já usado em `Clientes.tsx`/`ContratoModelos.tsx`.
- **`/minhas-licencas`** (contador) — lista licenças disponíveis/ativas, botão "Comprar mais" (Stripe Checkout redirect) e "Ativar nesta empresa" (picker de empresa da carteira + campo de valor a cobrar), reaproveitando `FormNovaContaReceber`-like inputs de parcelamento.
- **`ContratoPreencher.tsx`/`ContratoNovo.tsx`** (Fase 6, existente) — quando o fluxo é "ativar licença", pula a etapa de escolher modelo/cliente manualmente (a `AtivarLicencaUseCase` já monta o contrato no backend); essas telas continuam servindo o caso já existente (empresa contrata com o próprio `cliente`).
- **Admin: painel de vendas** — nova aba/página listando `licencas_modulo` + `assinaturas` (SERPRO) num só painel de receita, conforme pedido ("admin controla principalmente as vendas feitas para os contadores").

## Ordem de execução sugerida

1. Migration completa (schema acima) + seed do contador/empresa interna da Jota + usuário-sistema.
2. `CriarContadorUseCase` passa a auto-criar a empresa interna de cada contador novo (rodar uma vez pros contadores já existentes via script/migration de dados).
3. `emitir_cobranca_interna`/`estornar_cobranca_interna` + `empresa_tem_modulo`, testados isolado via `psql` antes de qualquer código NestJS (mesmo padrão já usado nas funções de crédito).
4. `pacotes-modulos/` + `licencas-modulo/` (sem ainda gerar contrato — só CRUD e ativação simples).
5. Estender `contratos/` pra aceitar `empresaContraparteId` + `emitir_cobranca_interna`.
6. Ligar `AtivarLicencaUseCase` → `CriarContratoUseCase` (fecha o fluxo ponta a ponta do lado contador↔empresa).
7. `ModulosGuard` + aplicar nos controllers gated.
8. Repetir o mesmo fluxo um nível acima (admin↔contador) reaproveitando as mesmas funções/usecases, só trocando quem é credor/devedor.
9. Frontend: hook de módulos + menu condicional + telas de pacotes (admin) e licenças (contador).

## Verificação

1. `npx supabase db reset` limpo com a migration nova.
2. `nest build` + boot real (`node dist/main.js`, checar "Nest application successfully started").
3. Via API real: admin cria pacote → contador "compra" (Stripe modo teste/local) → licença aparece `disponivel` → contador ativa numa empresa da carteira, informando o valor → confirma: contrato criado com `empresaContraparteId`, `contas_receber` na empresa interna do contador batendo o valor, `contas_pagar` na empresa-cliente batendo o mesmo valor/parcelas, `vinculos_financeiros_espelho` linkando os dois.
4. Cancelar/excluir esse contrato → confirma que os dois lados (receber do contador + pagar da empresa) saem juntos.
5. Empresa sem licença ativa tentando acessar `/empresas/:id/contratos` → 403 do `ModulosGuard`. Empresa com licença → 200.
6. Repetir os passos 3-5 um nível acima (admin cobra contador).
7. Frontend: `tsc --noEmit` + `vite build` limpos; menu lateral mostra só os módulos licenciados pra uma empresa de teste sem pacote nenhum vs. uma com pacote completo.
