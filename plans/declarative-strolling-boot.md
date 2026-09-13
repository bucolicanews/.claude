# Portar jotaCaixa inteiro para jota_integrador + jota_fiscal_frontend

## Contexto

O pedido real (esclarecido depois que eu já tinha entregue uma "Conciliação Bancária" reduzida demais) é: pegar o **jotaCaixa inteiro** — um monolito legado (React+Vite falando direto com Supabase, sem backend separado, ~64 telas) — e portá-lo pra dentro do jota_integrador/jota_fiscal_frontend (arquitetura já separada: NestJS+Clean Architecture no backend, RLS, hierarquia real de 3 níveis), corrigindo os problemas de segurança/arquitetura que o jotaCaixa tem, mas **mantendo as mesmas telas** (mesmo conjunto de funcionalidades, mesma experiência).

Três agentes de exploração mapearam: (1) a hierarquia e o modelo de permissão reais do jotaCaixa, (2) o que já existe hoje no jota_integrador (schema, módulos, RBAC), (3) a estrutura do jota_fiscal_frontend + o quadro completo da família de telas "Conciliação Bancária" (que eu portei incompleta da primeira vez — faltou ~80% dela).

**Escala real**: isso é um roadmap de várias sessões, não uma tarefa única. Este plano cobre a correção de rumo imediata (RBAC + Conciliação Bancária completa) e o roadmap das fases seguintes, sem especificar cada tela em detalhe agora — cada fase futura recebe o mesmo tratamento (explorar → planejar → aprovar) quando chegar a vez.

## Descoberta 1 — a hierarquia de 3 níveis já bate, só falta uma peça

jotaCaixa tem `Admin (firma) → Cliente (empresa cliente) → Usuario (funcionário de qualquer um dos dois)`. Isso é exatamente o nível "Contador → Empresa → funcionário" do jota_integrador — **jotaCaixa nunca teve o nível "Admin de plataforma" acima disso** (não existe super-admin sobre múltiplos Admins lá). O jota_integrador já modela os 3 níveis certos (papéis com `escopo`: `plataforma`/`contador`/`empresa`) — **não precisa mudar o modelo, só popular as telas que faltam dentro dele.**

Padrão de dado a manter (já correto no jota_integrador, diferente do jotaCaixa): toda tabela nova ganha `empresa_id`/`contador_id` como FK de verdade — nunca repetir o anti-padrão do jotaCaixa de duplicar tabela (`admin_descricao_extrato` vs `descricao_extrato`) pra separar visão do Admin da visão do Cliente. Isso já é seguido em `plano_contas`/`lancamentos_contabeis`/conciliação — continuar assim em tudo que for portado.

## Descoberta 2 — RBAC granular existe no schema mas nunca foi ligado (é a "correção de segurança" mais importante)

- `permissoes`/`papel_permissoes` (tabelas N:N papel↔permissão) existem desde a migration 0002 mas **zero referência no código** — nunca foram usadas.
- Hoje a autorização real é só: (a) `@Papeis(Papel.X, Papel.Y)` grosseiro por rota, (b) checagem manual de posse (`exigirPosseDeContador`) por `contador_id`/`empresa_id`. Não existe "funcionário com permissão restrita" de verdade — `OPERADOR_CONTADOR`/`OPERADOR_EMPRESA` são tudo-ou-nada.
- No jotaCaixa, o mecanismo real é per-**usuário** (`permissoes: Record<string,bool>` num JSON solto na linha do funcionário, só aplicado a funcionário de Cliente — nem o funcionário do próprio Admin é checado). Isso é frágil (string solta, sem catálogo) e inconsistente (só um dos 3 níveis é checado de verdade).
- **Correção proposta**: usar as tabelas relacionais que já existem em vez de reinventar um JSON. Adiciona uma tabela nova `usuario_permissoes` (usuario_id, permissao_id) = concessão explícita por usuário, evolução do `papel_permissoes` (papel define o catálogo disponível pro escopo, `usuario_permissoes` é o que o dono de fato concedeu pra aquele funcionário). Papéis "_DONO" (CONTADOR_DONO, EMPRESARIO_DONO) e papéis de plataforma continuam sem restrição (dono não se autolimita). Só papéis "funcionário" (OPERADOR_CONTADOR, OPERADOR_EMPRESA, e futuro funcionário de plataforma se vier a existir) passam pela checagem granular.
- Mecanismo: `PermissoesService` (resolve o efetivo de um usuário) + `PermissoesGuard`/`@ExigirPermissao('recurso:acao')` (mesmo padrão de `PapeisGuard`/`@Papeis`, arquivo em `src/auth/apresentacao/guards/`), bypassado pra papéis-dono/plataforma. Endpoint `GET/PATCH /usuarios/:id/permissoes` pro dono (contador, empresa, ou plataforma) gerenciar as concessões do próprio funcionário.
- Escopo desta fase: construir o **mecanismo genérico** + aplicar num primeiro módulo real (conciliação bancária, já que vamos mexer nela mesmo). Aplicar em todo o resto das rotas existentes é trabalho incremental de cada fase futura, não migration em massa agora.

## Descoberta 3 — Conciliação Bancária é uma família de ~9 telas, não 1

O que portei antes (`useConciliacaoLogic.ts`+`MapearExtratoDialog.tsx`) cobria só a lógica de salvar um lote — faltou a página-hub com abas, o histórico, o extrato/ledger, a triagem pós-import, o caminho de categorização direta, e a tela de config standalone. Mapeamento real (jotaCaixa → jota_integrador):

| jotaCaixa | O que faz | Adaptação no jota_integrador |
|---|---|---|
| `Conciliacao.tsx` | Hub principal, 3 abas: Nova Conciliação (wizard conta→config→CSV→tabela) / Histórico / Pendências | Reescrever `contabil-empresa-conciliacao-bancaria/index.jsx` como esse hub de 3 abas |
| `GerenciarConfiguracoesExtrato.tsx` | CRUD standalone das configs de mapeamento de coluna | Nova rota `/contabil/empresas/:id/conciliacao-bancaria/configuracoes`, reusa os endpoints que já existem |
| `Extratos.tsx` | Ledger/auditoria de tudo que foi conciliado | Nova tela + endpoint `GET .../conciliacao-bancaria/lancamentos` (filtra `lancamentos_contabeis` por `origem='conciliacao_bancaria'`, já dá pra fazer sem tabela nova) |
| `HistoricoConciliacaoDialog.tsx` | Detalhe de um lote de importação passado | Preciso persistir TODAS as transações extraídas (não só as confirmadas) — ver tabela nova abaixo |
| `Mapeamento.tsx` | Triagem pós-import: transações pendentes de vínculo | Mesma tabela nova resolve isso — pendentes ficam com `status='pendente'`, tela lista e resolve depois |
| `useConciliacaoDireta.ts` | Categorização direta sem parcela (double-entry direto) | Já é essencialmente o que meu `ConfirmarConciliacaoUseCase` faz — manter |
| `ModalMapeamentoParcela` (matching CR/CP) | Vincula transação a uma parcela de contas a pagar/receber | **Fica de fora** — depende do módulo Contas a Pagar/Receber (Fase 2, ainda não existe). Não bloqueia o resto. |
| `GerenciarDescricoesExtrato.tsx`/`GerenciarIdentificadoresExtrato.tsx` | Picklists de apoio pra lançamento MANUAL (não é conciliação) | Fora desta fase — entra junto da tela de Lançamentos manual (Fase 4) |

**Mudança de schema necessária**: hoje meu módulo só persiste o que foi CONFIRMADO (preview é efêmero, nunca salvo). Pra ter Histórico real e a tela de Pendências (Mapeamento.tsx), preciso persistir toda transação extraída do CSV, com status. Nova tabela `conciliacao_transacoes` (empresa_id, conta_contabil_id, importacao_id, data_competencia, descricao, valor, tipo, identificacao, chave_dedupe, status: `pendente`|`conciliada`|`duplicada`|`ignorada`, lancamento_id nullable). `conciliacao_importacoes` (já existe) vira o cabeçalho do lote; `preview` passa a INSERIR essas linhas (status pendente/duplicada) em vez de só devolver JSON efêmero; `confirmar` passa a UPDATE das linhas pendentes escolhidas (cria o lançamento, seta `lancamento_id` + `status='conciliada'`) em vez de receber tudo de novo do frontend.

Arquivos a mexer no backend (`jota_integrador`):
- Nova migration: `usuario_permissoes` (RBAC) + `conciliacao_transacoes` + `importacao_id` em nada extra (já cabe: `conciliacao_transacoes.importacao_id` referencia `conciliacao_importacoes`).
- `src/auth/`: novo `PermissoesService`, `PermissoesGuard`, decorator `@ExigirPermissao`, controller de gestão (`GET/PATCH /usuarios/:id/permissoes`).
- `src/conciliacao-bancaria/`: reescrever `pre-visualizar-extrato.usecase.ts` (persiste em vez de só devolver), `confirmar-conciliacao.usecase.ts` (update em vez de criar do zero), novos casos de uso `listar-pendentes.usecase.ts`, `listar-historico-importacao.usecase.ts` (detalhe de 1 lote), `listar-lancamentos-conciliados.usecase.ts` (ledger). Controller ganha as rotas novas.

Frontend (`jota_fiscal_frontend`):
- Reescrever `paginas/contabil-empresa-conciliacao-bancaria/index.jsx` como hub de 3 abas (Nova Conciliação / Histórico / Pendências), reaproveitando o wizard que já existe pra aba 1.
- Nova página `paginas/contabil-empresa-conciliacao-configuracoes/` (CRUD standalone).
- Nova página `paginas/contabil-empresa-extratos/` (ledger).
- Ajustar `servicos/conciliacaoBancaria.js` pros endpoints novos.

## Roadmap das fases seguintes (ordem sugerida, sem detalhar agora — cada uma ganha exploração+plano próprio quando chegar a vez)

1. ~~**Fase 2 — Contas a Pagar / Contas a Receber**~~ **CONCLUÍDA (2026-09-11)**, testada ponta a ponta com API real. Ver detalhes na memória `project_jota_integrador.md`. `fornecedor`/`cliente_nome` ficaram texto livre (decisão explícita) -- Fase 3 troca por FK real.
2. ~~**Fase 3 — Clientes/Fornecedores**~~ **CONCLUÍDA (2026-09-11)**, testada ponta a ponta. `Bancos.tsx`/`ContasPatrimoniais.tsx` (views só-leitura sobre plano_contas) ficaram de fora -- dobram com a tela de Plano de Contas já existente, avaliar se cabem na Fase 5 (Relatórios) em vez de módulo próprio.
3. ~~**Fase 4 — Lançamentos manual + Históricos**~~ **CONCLUÍDA (2026-09-11)**, testada ponta a ponta. `Lancamentos.tsx` já existia pronto (mais flexível que o jotaCaixa -- N partidas, não só débito/crédito fixo), só faltava o picklist `GerenciarHistoricos.tsx` (tabela nova `historicos`, sugestão via `<datalist>` no campo histórico, mantido texto livre -- não virou FK). `GerenciarDescricoesExtrato.tsx`/`GerenciarIdentificadoresExtrato.tsx` **remapeados**: pertencem à Conciliação Bancária (usados só em `useConciliacao`/`FormExtratoDireto` no jotaCaixa), não a Lançamentos -- meta corrigida no plano original, ficam de fora desta fase.
4. ~~**Fase 5 — Relatórios**~~ **CONCLUÍDA (2026-09-11)** -- backend (`src/relatorios/`, 5 endpoints) + frontend (`pages/{Balancete,BalancoPatrimonial,DRE,Razao,FluxoCaixa}.tsx`, rotas globais `/relatorios/*`), testado via curl cruzando os 5 relatórios entre si com os mesmos dados. Dois bugs reais achados e corrigidos: `RelatoriosModule` nunca tinha sido registrado (esquecido no meio do PIVÔ), e a função SQL `relatorio_saldos_periodo` contava tudo em dobro quando `p_data_inicio` era null (usado pelo Balanço Patrimonial) -- ver memória `project_jota_integrador.md`.

## PIVÔ GRANDE (2026-09-11): jotaCaixa deixa de ser só referência de leitura e vira o front-end real

Usuário corrigiu o rumo: o front-end do jota_fiscal_frontend que eu vinha construindo (Tailwind puro, nav row de links dentro da página da empresa) tem um layout estruturalmente diferente do jotaCaixa (que usa rotas globais + shadcn/ui + Radix). Decisão: **copiar o código-fonte do jotaCaixa pro jota_fiscal_frontend** (páginas, componentes, hooks, layout) e trocar módulo por módulo a camada de dados (Supabase direto → API do jota_integrador), aplicando as correções de segurança/arquitetura já desenhadas ao longo do caminho. jota_fiscal_frontend deixa de ser Tailwind-puro-JS e vira TypeScript+shadcn/ui igual ao jotaCaixa. Detalhe completo na memória `project_jota_integrador.md`, seção "PIVÔ GRANDE".

Isso **invalida as telas Tailwind-puro das Fases 1-4** (contas a pagar/receber, clientes, fornecedores, históricos, conciliação) -- serão substituídas pela versão real do jotaCaixa, não mantidas. Os `servicos/*.js` (camada de API) continuam válidos como referência.

**Fundação já trazida e testada**: TypeScript + shadcn/ui + Radix + tokens de design do jotaCaixa, coexistindo com o JS existente (`tsc`/`vite build` limpos).

**Próximo passo**: portar Plano de Contas + Lançamentos como módulo-prova-de-conceito (backend 100% pronto), resolvendo antes a questão de "empresa ativa" (jotaCaixa sempre tem exatamente 1 owner por login; jota_integrador tem contador com N empresas -- precisa de um seletor persistente que o jotaCaixa nunca teve).
5. **Fase 6 — Contratos + Documentos Societários** (`Contratos.tsx`, `NovoContrato.tsx`, `PreencherContrato.tsx`, `AssinarContrato.tsx` público, `GerenciarModelos.tsx`, `GerenciarTags.tsx`, `DocumentosSocietarios.tsx`, `GerarDocumentoSocietario.tsx`, `GerenciarModelosSocietarios.tsx`, `GerenciarBlocosSocietarios.tsx`, `Protocolos.tsx`): domínio grande e autocontido.
6. **Fase 7 — Config/Admin + correção completa de gestão de usuários** (`Configuracoes.tsx` hub, `GerenciarUsuarios.tsx` com a tela de permissões granulares pros 3 níveis, `Suporte.tsx`/`AdminSuporte.tsx` tickets).
7. **Fase 8 — Ponto Eletrônico** (`PontoEletronico.tsx`, `AcompanharPonto.tsx`, `FolhaPonto.tsx`): confirmado pelo usuário (2026-09-11) que entra no roadmap, como fase própria ao final -- não é módulo à parte.

**Adiado por decisão de arquitetura já tomada antes** (não é esquecimento): `EmissaoNotas.tsx`/`ConfiguracaoEmissaoNF.tsx` — depende de escolher integração direta SEFAZ/prefeitura vs. provedor terceirizado (mesma pendência documentada na sessão de 09-09).

**Minha sugestão de FORA de escopo — confirma ou corrige**:
- Marketing/onboarding público do jotaCaixa (`LandingPage.tsx`, `Vendas.tsx`, `TesteGratis.tsx`, `Index.tsx`) — é o funil comercial do jotaCaixa como produto próprio; o JOTA FISCAL/CONTÁBIL já tem seu próprio cadastro+assinatura Stripe.
- Billing da própria firma (`MinhaAssinatura.tsx`, `SelecaoPagamentoRenovacao.tsx`, `PagamentoPix.tsx`, `ConfirmarRecebimento.tsx`, `GerenciarPlanos.tsx`) — já coberto pelo módulo `assinaturas` (Stripe) do jota_integrador, de forma diferente.
- `ConfiguracoesPagBank.tsx` — jota_integrador usa Stripe, não PagBank; não se aplica.

Ponto Eletrônico **confirmado dentro do escopo** (Fase 8, ver acima) -- não fica de fora.

## Verificação

Cada fase segue a disciplina já usada no projeto (ver memória `project_jota_integrador`): testar ponta a ponta com API real (usuários de teste existentes: `admin@teste.com`, `contadora@teste.com`, `contadorb@teste.com`, `empresa@teste.com`, senha `SenhaForte123!`), `tsc --noEmit` + `nest build` + boot real (`node dist/main.js`, checar "Nest application successfully started" sem `UnknownDependenciesException`) antes de considerar qualquer módulo pronto, `vite build` limpo no frontend. Migration sempre local primeiro (`supabase migration up`), produção só quando/se existir um projeto Supabase linkado (hoje não existe pra este projeto).
