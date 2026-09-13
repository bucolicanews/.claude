# Fase 6 — Contratos (financeiro) + Documentos Societários — jota_integrador + jota_fiscal_frontend

## Contexto

Usuário escolheu portar a "Fase 6" do roadmap original (Contratos/Documentos Societários), o maior módulo ainda não iniciado. Minerado (read-only) `jotaCaixa/src/{pages/{NovoContrato,PreencherContrato,Contratos,AssinarContrato,ContratoLinkPage,GerarDocumentoSocietario,GerenciarModelosSocietarios,GerenciarBlocosSocietarios,DocumentosSocietarios}.tsx, components/{contratos,documentos-societarios,formularios/FormDocumentoSocietarioModelo}.tsx, config/contrato-tags-padrao.ts, types/{contratos,documentos-societarios}.ts}`.

O jotaCaixa tem dois sistemas quase idênticos que compartilham a mesma engine de tags `{{TAG}}`:
- **Contratos** (financeiro): gera parcelas em Contas a Receber + lançamento contábil, tem fluxo de assinatura eletrônica público (link sem login, selfie via câmera, RPC pública bypassando RLS).
- **Documentos Societários**: sem vínculo financeiro, com "blocos" reutilizáveis (cláusulas de texto) e conteúdo editável por instância.

Decisões do usuário (via AskUserQuestion, já confirmadas):
1. **Dois módulos NestJS separados** (`contratos/` e `documentos-societarios/`), espelhando o jotaCaixa — não um módulo genérico único.
2. **Réplica completa do fluxo de assinatura eletrônica**: link público (sem login) + captura de selfie + endpoint público. Adaptado à arquitetura deste projeto: em vez de RPC Postgres pública bypassando RLS (como o jotaCaixa faz), será um **controller NestJS público** (sem `SupabaseAuthGuard`) com throttle mais restrito, e a selfie vai para **bucket privado** com leitura só via signed URL (nunca bucket público como no original — mesmo desvio já aplicado em Protocolos/Caixa Postal).
3. **Incluir Blocos societários e Aditivos contratuais** nesta rodada (não adiar).

**Simplificações deliberadas** (a documentar, não pedir de novo — mesmo padrão de reduzir escopo de UI/complexidade já usado a sessão inteira):
- Sem editor rich-text (Quill): usa `<textarea>` simples com toggle HTML/texto — nenhum outro lugar do jota_fiscal_frontend usa rich-text ainda, e a renderização de tags funciona igual com HTML digitado à mão.
- Sem captura de câmera ao vivo: `<input type="file" accept="image/*" capture="user">` (abre câmera frontal no mobile, fallback pra upload normal no desktop) — sem lib de câmera dedicada.
- Sem envio por WhatsApp/Email via backend: frontend monta um link `wa.me`/`mailto:` com o texto pronto (a URL pública de assinatura) — nenhuma tabela de template, nenhuma integração de mensageria nova.
- Modelos (`modelos_contrato`, `modelos_societarios`, `blocos_societarios`) são sempre de uma `empresa_id` (sem conceito de "modelo global" da plataforma nesta v1 — o jotaCaixa tinha `proprietario_id` nullable pra isso; pode virar melhoria futura).
- Aditivo contratual: **não** recalcula parcelas via um motor genérico novo — reaproveita 100% os primitivos já existentes do módulo Contas a Receber (`cancelar` a conta antiga + `criar` uma nova via `CriarContaReceberUseCase`) quando o aditivo muda valor/parcelamento, preservando o registro histórico do aditivo. Aditivo que só documenta uma mudança não-financeira (ex: prazo, cláusula) não mexe na conta a receber.

## Schema (migration nova, `202609XXXXXXXX_contratos_e_documentos_societarios.sql`)

Segue o padrão já usado (RLS via `pode_acessar_empresa`/`auth_contador_id`, trigger `set_atualizado_em`, catálogo de permissões no fim, bucket privado). Tabelas:

**Contratos:**
```sql
modelos_contrato (id, empresa_id not null, titulo, conteudo_template, tipo_conteudo check('html','texto') default 'html', criado_em, atualizado_em)

configuracao_contratos (empresa_id pk, conta_patrimonial_receber_id references plano_contas, conta_resultado_receita_id references plano_contas, url_base_assinatura, criado_em, atualizado_em)

contratos_gerados (
  id, empresa_id not null, modelo_id references modelos_contrato, cliente_id not null references clientes,
  titulo, status check('rascunho','pendente_assinatura','ativo','cancelado','concluido','bloqueado') default 'rascunho',
  valores_tags jsonb not null default '{}', conteudo_renderizado not null,
  valor_total numeric(14,2), conta_receber_id references contas_receber (nullable -- só existe se valor_total > 0),
  token_assinatura text not null unique default encode(gen_random_bytes(24),'hex'),  -- nunca expõe o UUID do contrato na URL pública
  assinatura_nome text, assinatura_selfie_ref text, assinado_em timestamptz,
  criado_por not null, criado_em, atualizado_em
)

contrato_tags (id, empresa_id not null, nome_tag not null, descricao, criado_em, unique(empresa_id, nome_tag))  -- tags customizadas da empresa

contrato_aditivos (id, contrato_id not null references contratos_gerados, descricao not null, valor_total_novo numeric, numero_parcelas_novo int, conta_receber_anterior_id, conta_receber_nova_id, criado_por not null, criado_em)
```

**Documentos Societários:**
```sql
modelos_societarios (id, empresa_id not null, titulo, conteudo_template, tipo_documento, tipo_conteudo check('html','texto') default 'html', criado_em, atualizado_em)

blocos_societarios (id, empresa_id not null, titulo, conteudo not null, tipo_bloco, criado_em)  -- delete real permitido (mesmo padrão de descricoes-extrato/identificadores-extrato)

documentos_societarios_gerados (
  id, empresa_id not null, modelo_id references modelos_societarios on delete set null, cliente_id references clientes (nullable),
  titulo not null, status check('rascunho','finalizado','arquivado') default 'rascunho',
  valores_tags jsonb not null default '{}', conteudo_renderizado not null, conteudo_principal_manual text,
  data_registro date, criado_por not null, criado_em, atualizado_em
)
```

RLS: mesmo padrão de `clientes`/`protocolos` (select = `pode_acessar_empresa`; insert/update/delete = `exigirPosseDeContador`-equivalente, `auth_contador_id() = contador da empresa`). `contratos_gerados`/`documentos_societarios_gerados` seguem a mesma regra de delete condicional já usada em Protocolos (`status in (...)` restritos via RLS como defesa em profundidade, regra fina fica na Application).

Bucket privado novo: `contratos-selfies` (mesmo padrão de `insert into storage.buckets (...) values (..., false)`).

Catálogo de permissões novo: `contratos:*`, `documentos_societarios:*`.

## Backend `jota_integrador`

### `src/contratos/` (Clean Architecture)

- `dominio/tags.ts` — `renderizarTags(template, valores): string` (replace simples, escapa regex), reaproveitado também por `documentos-societarios/` (função pura compartilhada, colocada em `src/common/tags/renderizar-tags.ts` — compartilhar uma função utilitária pura não contradiz "dois módulos separados", que se refere a schema/usecases de negócio).
- `dominio/contrato.ts` — catálogo estático `TAGS_SISTEMA` (CLIENTE_*, EMPRESA_*, financeiras calculadas), `transicaoValida()`.
- `aplicacao/portas/contratos-repositorio.port.ts` — CRUD de `modelos_contrato`, `contratos_gerados`, `contrato_tags`, `contrato_aditivos`, `configuracao_contratos`.
- Casos de uso principais:
  - CRUD de `ModelosContrato` (mesmo padrão de `historicos`/`clientes`).
  - `ObterCatalogoTagsUseCase` — `TAGS_SISTEMA` + `contrato_tags` da empresa.
  - `PreVisualizarContratoUseCase` — dado `clienteId` + `modeloId` + tags manuais + dados financeiros, resolve `CLIENTE_*`/`EMPRESA_*`/financeiras, chama `renderizarTags`, devolve preview (não persiste).
  - `CriarContratoUseCase` — resolve tags automáticas + manuais → renderiza (snapshot imutável em `conteudo_renderizado`) → se `valorTotal > 0`, injeta `ContasAReceberModule` e chama `CriarContaReceberUseCase.executar(...)` (reaproveita 100% a lógica já validada de partida dobrada + parcelamento — **precisa exportar `CriarContaReceberUseCase` no `ContasAReceberModule`, que hoje só exporta `CONTAS_RECEBER_REPOSITORIO`/`RegistrarRecebimentoUseCase`**) → grava `contratos_gerados` com `contaReceberId` + `tokenAssinatura` gerado no banco → `AuditoriaService.registrar`.
  - `AtualizarContratoUseCase` — só campos livres, bloqueado se status fora de `rascunho`/`pendente_assinatura`.
  - `RegistrarAditivoUseCase` — grava `contrato_aditivos`; se `valorTotalNovo`/`numeroParcelasNovo` informados, chama `CancelarContaReceberUseCase` na conta antiga + `CriarContaReceberUseCase` numa nova, linkando os dois IDs no aditivo (histórico preservado, nunca edita parcela já paga).
  - `ExcluirContratoUseCase` — só permite se a conta a receber vinculada não tem nenhum recebimento registrado (equivalente ao `delete_contract_if_no_payments` do jotaCaixa, reimplementado como checagem em `ContasReceberRepositorioPort.obterPorId(...).valorRecebido === 0`).
  - `BloquearContratoUseCase`/`DesbloquearContratoUseCase`.
  - `GerarLinkAssinaturaUseCase` — monta `${configuracao.urlBaseAssinatura}/assinar-contrato/${tokenAssinatura}` (não expõe UUID).
  - `ObterContratoPublicoUseCase` — busca por **token**, nunca por ID cru; devolve só os campos necessários pro preview público (título, conteúdo renderizado, nome do cliente, status).
  - `AssinarContratoPublicoUseCase` — valida `status === 'pendente_assinatura'`, recebe multipart (nome + selfie), chama `StorageContratosService.armazenar(...)`, marca `assinado_em`/`assinaturaNome`/`assinaturaSelfieRef`/`status='ativo'`, `AuditoriaService.registrar` com `usuarioId` especial (ex: constante `ORIGEM_PUBLICA`, já que não há usuário autenticado).
  - `ObterUrlSelfieUseCase` — signed URL sob demanda, autenticado (contador vê depois).
- `infraestrutura/`: `ContratosRepositorioSupabase`, `StorageContratosService` (mirror exato de `StorageProtocolosService`, bucket `contratos-selfies`, `armazenar`/`gerarUrlAssinada`).
- `apresentacao/`:
  - `ContratosController` (`empresas/:empresaId/contratos`, autenticado, mesmo padrão `exigirPosse`/`exigirPosseDeContador` de todo módulo já existente).
  - **`AssinaturaPublicaController`** (`@Controller('assinatura-publica')`, **SEM** `@UseGuards(SupabaseAuthGuard,...)` — rotas públicas de propósito) com `@Throttle({ default: { limit: 5, ttl: 60_000 } })` mais restrito que o default global (100/min), já que é superfície não-autenticada:
    - `GET /assinatura-publica/:token`
    - `POST /assinatura-publica/:token/assinar` (multipart, campo `selfie`)

### `src/documentos-societarios/`

Estrutura simétrica, sem financeiro/assinatura:
- CRUD `ModelosSocietarios` (igual padrão de `historicos`).
- CRUD `BlocosSocietarios` (delete real, igual `descricoes-extrato`/`identificadores-extrato` — reaproveita inclusive o mesmo componente frontend genérico `ListaPicklistExtrato.tsx`? Não: layout de bloco é um card com "copiar conteúdo", não uma lista inline-edit — vai ter componente próprio simples, mas o backend é idêntico em espírito).
- `CriarDocumentoSocietarioUseCase` — reaproveita `renderizarTags` de `src/common/tags/`; grava `conteudoRenderizado` + `conteudoPrincipalManual` (cópia inicial editável).
- CRUD `DocumentosSocietariosGerados` (Atualizar/ObterUrlListar/Excluir/Arquivar).

## Frontend `jota_fiscal_frontend`

- **Autenticado** (rotas globais dentro do shell):
  - `/contratos` (lista, abas Ativos/Pendentes/Inativos), `/contratos/novo` (grid de modelos), `/contratos/preencher/:modeloId` (form + preview ao vivo, reaproveita `listarClientes`), `/contratos/:id` (detalhe: aditivos, link de assinatura, selfie via signed URL).
  - `/contratos/modelos` (CRUD de `modelos_contrato`).
  - `/documentos-societarios` (lista), `/documentos-societarios/modelos`, `/documentos-societarios/blocos`, `/documentos-societarios/gerar/:modeloId`.
- **Pública** (fora de `<RotaProtegida>`, sem exigir login — nova entrada em `App.jsx`):
  - `/assinar-contrato/:token` — busca via `GET /assinatura-publica/:token`, formulário nome + `<input type="file" accept="image/*" capture="user">`, `POST .../assinar` (multipart).
- Editor de template: `<textarea>` + toggle "HTML"/"Texto simples" (sem Quill), painel lateral com botões de tag clicáveis (`{{TAG}}` insere na posição do cursor) — mesmo conceito do jotaCaixa, sem a dependência de rich-text.
- Blocos societários: grid de cards (`BlocoCard.tsx`) com botão "Copiar" (clipboard) e botão "Inserir" quando usado dentro do editor de modelo.
- Compartilhar link: botões que montam `https://wa.me/?text=...` e `mailto:?body=...` com a URL pública de assinatura — sem chamada de API.

## Verificação

1. `npx supabase db reset` — migration aplica limpo, bucket `contratos-selfies` criado, RLS ativa.
2. `npx nest build` limpo.
3. Exportar `CriarContaReceberUseCase`/`CancelarContaReceberUseCase` no `ContasAReceberModule` sem quebrar nada existente (`nest build` + smoke test de CP/CR ainda funcionando).
4. Testar via API real (porta de rascunho, nunca a 3002 do usuário): criar modelo → criar contrato com tags automáticas + parcelamento → confirma `contas_receber` criada com parcelas certas → gerar link → **sem token de autenticação**, `GET /assinatura-publica/:token` → `POST .../assinar` com selfie → confirma status `ativo` + signed URL da selfie funciona só pra usuário autenticado da empresa dona → tentar excluir contrato com recebimento registrado → 400 → registrar aditivo com novo valor → confirma conta antiga cancelada + nova criada → isolamento cross-tenant (empresa B não acessa token/contrato de empresa A, exceto pela rota pública que é por token opaco, não por ID).
5. Societário: modelo → bloco → gerar documento com conteúdo manual editável → listar/editar/arquivar/excluir.
6. `npx tsc --noEmit` e `npx vite build` limpos no frontend.
7. Deixar pro usuário clicar-testar no navegador depois (mesmo padrão da sessão inteira, [[feedback_browser_testing]]).
