# Controle central de Clientes SaaS + Instalações Locais (licenciamento)

## Contexto

Hoje o sistema de planos/assinaturas/faturas (`planos`, `assinaturas`, `plano_faturas` — ver `server_delivery/src/planos/planos.service.ts`) só sabe cobrar **lojas do SaaS multi-tenant** (linha `assinaturas.restaurant_id NOT NULL REFERENCES restaurants(id)`). Ele já tem: geração lazy de fatura por período, cobrança PIX/cartão via PagBank, webhook, bloqueio por atraso, upgrade de plano — tudo testado e funcionando (confirmado nesta sessão).

Existe hoje um segundo tipo de cliente: quem **compra a instalação individual/local** do DeliveryHub (roda o mesmo código, mas standalone, com seu próprio banco Supabase separado — não é uma linha na tabela `restaurants` central). Confirmado por investigação: o flag `modo_individual` (`server_delivery/src/plataforma/plataforma.service.ts:104-105`, `src/contexts/LocalModeContext.jsx`) é hoje **só um filtro visual** — nenhum guard, nenhuma cobrança, nenhum controle central liga a essa instalação. Não existe nenhum conceito de serial/token/licença no código (grep confirmado: zero resultados reais).

Objetivo: o admin central (mothership, este mesmo painel) passa a **gerar um serial/token pra cada instalação local vendida**, acompanha o plano e os pagamentos dela do mesmo jeito que já acompanha uma loja SaaS — reaproveitando ao máximo o motor de cobrança que já existe (evita duplicar ~600 linhas de `planos.service.ts`).

Decisões já confirmadas com o usuário:
- **Validação automática**: a instalação local consulta o servidor central periodicamente com o serial; se vencida além da tolerância, mostra bloqueio local (mesmo padrão que já existe pro SaaS).
- **UI**: nova aba "Instalações Locais" dentro de `Admin → Planos` (reaproveita layout de tabs/tabela que já existe em `src/pages/admin-planos/index.jsx`).
- **Pagamento v1**: admin marca fatura como paga manualmente (reaproveita `marcarFaturaPaga`, que já é agnóstico ao tipo de titular por ser só um ID). Self-service PIX/cartão pra dono de instalação local fica pra depois (fora de escopo agora).

## Decisão de arquitetura: titular polimórfico

Em vez de duplicar `plano_faturas`/`assinaturas` numa tabela paralela (`instalacao_faturas` etc.), generalizar as duas tabelas existentes pra aceitarem **ou** `restaurant_id` **ou** `instalacao_id` (exatamente um dos dois, nunca os dois nem nenhum). Isso faz `sincronizarPeriodo`, `pagarFatura`, `pagarFaturaCartao`, `buscarChavePublicaCartao`, `marcarFaturaPaga`, `listarFaturas`, `renovarAgora` (com o fix de fatura duplicada já feito) funcionarem para os dois tipos de cliente quase sem duplicar lógica — só uma ramificação onde hoje a isenção por faturamento consulta a tabela `orders` (isso não existe/não faz sentido pra uma instalação local, que tem seu próprio banco separado — pra ela a fatura é sempre o valor cheio do plano, sem isenção por piso de faturamento).

## Modelo de dados (nova migration)

1. **`planos`**: adicionar `tipo TEXT NOT NULL DEFAULT 'saas' CHECK (tipo IN ('saas','local'))`. Campos como `limite_produtos`/`inclui_delivery`/`inclui_salao` continuam existindo mas ficam irrelevantes pra `tipo='local'` (não usados nesse fluxo). Admin cria planos "local" com nome/valor/periodicidade/trial, igual já faz hoje pra 'saas'.

2. **`instalacoes_locais`** (nova tabela):
   - `id BIGSERIAL PK`
   - `nome_cliente TEXT NOT NULL` (quem comprou)
   - `contato TEXT` (whatsapp/email — informativo)
   - `serial TEXT NOT NULL UNIQUE` (gerado no backend, formato tipo `DHUB-XXXX-XXXX-XXXX`, `crypto.randomBytes`)
   - `dominio_ou_ip TEXT` (opcional, onde tá hospedada — informativo)
   - `ultimo_check_em TIMESTAMPTZ` (última vez que a instalação bateu no checkin — "visto por último")
   - `ativo BOOLEAN NOT NULL DEFAULT true` (soft-disable, admin pode revogar serial sem deletar histórico)
   - `created_at`/`updated_at`

3. **`assinaturas`**: `restaurant_id` vira nullable, adicionar `instalacao_id BIGINT NULL REFERENCES instalacoes_locais(id) ON DELETE CASCADE`. Trocar a `UNIQUE` atual em `restaurant_id` por dois índices únicos parciais (`WHERE restaurant_id IS NOT NULL` / `WHERE instalacao_id IS NOT NULL`) + `CHECK` garantindo exatamente um dos dois preenchido.

4. **`plano_faturas`**: mesma coisa — `restaurant_id` nullable, `instalacao_id BIGINT NULL REFERENCES instalacoes_locais(id) ON DELETE CASCADE`, mesmo `CHECK`.

## Backend central (`server_delivery/src/planos/`)

- Refatorar os pontos que hoje recebem só `restaurantId: number` pra aceitarem um "titular" (`{ restaurantId }` ou `{ instalacaoId }`), mantendo as assinaturas públicas atuais dos controllers de restaurante intactas (não quebra nada do que já roda em produção).
- Em `sincronizarPeriodo`: quando o titular é `instalacaoId`, pular a consulta em `orders`/isenção por piso — fatura sempre no valor cheio do plano.
- Novo módulo `server_delivery/src/instalacoes/`:
  - `instalacoes.service.ts`: CRUD de `instalacoes_locais` (criar gera serial único), `atribuirPlano(instalacaoId, planoId)` (reaproveita a mesma lógica de `atribuirAssinatura`, generalizada), `checkin(serial)` → acha instalação pelo serial, atualiza `ultimo_check_em`, roda `sincronizarPeriodo({instalacaoId})`, devolve `{ bloqueado, dias_atraso, plano_nome, proxima_cobranca }`.
  - `instalacoes-admin.controller.ts` (`@UseGuards(AdminGuard)`): `GET/POST /instalacoes`, `PATCH /instalacoes/:id`, `POST /instalacoes/:id/plano` (atribuir/trocar plano), `POST /instalacoes/:id/gerar-fatura`.
  - `instalacoes-checkin.controller.ts` (**sem guard** — autenticado só pelo serial em si, igual o webhook do PagBank não tem guard): `POST /instalacoes/checkin { serial }`.
  - `planos-admin.controller.ts` (`listarFaturas`/`marcarFaturaPaga` já existentes): adicionar filtro opcional `tipo` (`saas`/`local`) no `GET /planos/faturas`, e no `select` incluir `instalacoes_locais(nome_cliente, serial)` junto com `restaurants(name)` pra a tabela do admin mostrar o nome certo dos dois tipos.

## Backend da instalação standalone (mesmo código, `server_delivery`)

- Novo `server_delivery/src/licenca/licenca-checkin.service.ts`: só ativa se a env var `LICENCA_SERIAL` estiver setada (instalação central multi-tenant nunca seta isso — no-op lá). No boot e a cada N horas (`@nestjs/schedule` ou `setInterval`), faz `POST` pra `LICENCA_CENTRAL_URL` (default aponta pro domínio de produção do mothership) com o serial, guarda o resultado (`bloqueado`, `dias_atraso`) em memória.
- `GET /licenca/status` (sem guard, local): frontend da instalação standalone lê esse endpoint pra saber se mostra bloqueio.
- Se o checkin falhar (sem internet, servidor central fora): não bloquear na hora — usar o último resultado conhecido + tolerância extra (não travar cliente por instabilidade de rede).

## Frontend central — Admin (`src/pages/admin-planos/index.jsx`)

- Adicionar aba `"Instalações Locais"` no array `TABS` (reaproveita o mesmo padrão visual das abas Lojas/Faturas: `Badge`, tabela, modal de formulário).
- Tab nova: tabela com nome do cliente, serial (com botão copiar), plano atual, status, último check-in ("visto há X dias"), próxima cobrança, botão "Nova instalação" (form: nome, contato, plano) que ao salvar mostra o serial gerado uma vez em destaque (pra admin copiar e mandar pro cliente).
- Aba "Faturas" existente ganha filtro por tipo (SaaS/Local) e mostra nome certo pros dois casos (já vem pronto do backend generalizado).
- Novo service `src/services/instalacoesService.js` espelhando `planosService.js` (mesmo padrão `apiFetch`).

## Frontend da instalação standalone

- `src/contexts/LocalModeContext.jsx` (já existe, já detecta `modo_individual`): estender pra também chamar `GET /licenca/status` quando em modo individual, expor `licencaBloqueada`/`diasAtraso` no contexto.
- Reaproveitar o componente de banner que já existe lá (`LocalModeBanner`) — variante de bloqueio total (mesmo espírito do banner "Painel bloqueado por atraso" que já existe em `src/pages/restaurante-plano/index.jsx:264-271`).

## Fora de escopo agora (registrar mas não implementar)

- Pagamento self-service (PIX/cartão) pro dono da instalação local — v1 é admin marcando pago manualmente.
- Rate limiting dedicado no endpoint de checkin.
- Tolerância de dias separada entre SaaS e Local (v1 reaproveita o mesmo `plano_dias_tolerancia` global já existente em `platform_settings`).

## Verificação

1. Migration aplica limpo local (`supabase db push` local) sem quebrar dados existentes de `assinaturas`/`plano_faturas` (todas as linhas atuais têm `restaurant_id` preenchido, `instalacao_id` fica NULL — CHECK passa).
2. Criar plano `tipo='local'` no admin, criar instalação, confirmar serial gerado é único e copiável.
3. Rodar `POST /instalacoes/checkin` manualmente (curl/Postman) com o serial — confirma fatura sendo gerada no primeiro checkin (trial ou cobrança conforme plano) e resposta de bloqueio correta.
4. Confirmar que o fluxo SaaS existente (loja normal pagando fatura, upgrade de plano, renovar agora) continua funcionando sem regressão após o refactor pro titular polimórfico — reteste manual dos 3 fluxos já validados nesta sessão (Pix, cartão, upgrade).
5. Simular instalação local com `LICENCA_SERIAL` setado no `.env`, confirmar checkin automático roda e `GET /licenca/status` reflete bloqueio corretamente.
