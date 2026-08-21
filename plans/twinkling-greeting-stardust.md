# Migração do motoboy para Supabase Auth de verdade

## Contexto

Hoje motoboy é um sistema de autenticação paralelo: login por `password_hash` (bcrypt) + JWT próprio (`MOTOBOY_JWT_SECRET`), sessão única controlada manualmente (`active_session_id`/`session_expires_at`), guard lendo header `x-motoboy-token`, tudo isolado do Supabase Auth que cliente/dono de restaurante já usam. Isso já causou bug real (motoboy autocadastrado colidindo por e-mail com conta de cliente, ver memória do projeto) e não tem nenhum jeito de recuperar senha, editar perfil, ou tratar o motoboy como um "usuário" de verdade do sistema.

Pedido do usuário: motoboy deve ser um usuário real como cliente/dono — conta no Supabase Auth, recuperação de senha funcionando, perfil editável, `/motoboy` como painel autenticado de verdade (não um token solto no localStorage).

Decisões já confirmadas com o usuário:
1. **Manter a trava de sessão única** (só 1 dispositivo logado, com "forçar logout" pelo restaurante) — reimplementada por cima do Supabase Auth via um header próprio (`x-motoboy-session`) somado ao token Supabase, já que o JWT do Supabase não carrega esse controle nativamente.
2. **E-mail passa a ser obrigatório** para conta de motoboy daqui pra frente (autocadastro e cadastro pelo restaurante). Telefone continua existindo, só deixa de ser identificador de login.
3. **Restaurante continua podendo digitar a senha direto** ao cadastrar motoboy, E ganha a opção de gerar um link de definir/redefinir senha (pra copiar/mandar por WhatsApp) e também um botão de enviar esse link por e-mail (reaproveitando o mesmo mecanismo de "esqueci senha" que cliente já usa — sem mailer próprio).

Achados-chave da investigação que embasam o plano:
- `motoboys.user_id UUID REFERENCES auth.users(id)` **já existe** (nullable, migration `20260714000002_motoboys_user_id.sql`), só raramente populado hoje.
- O trigger `handle_new_user()` que cria `user_profiles` ao inserir em `auth.users` **já reconhece `role='motoboy'`** (enum `user_role` já tem esse valor) — só precisa que o `signUp()` do frontend passe `role: 'motoboy'` no metadata.
- `enable_confirmations = false` no `supabase/config.toml` local → `signUp()` já retorna sessão ativa na hora, sem esperar confirmação por e-mail. Não é um bloqueio.
- O trigger `sync_user_profile_email` (`20260813000003_sync_user_profile_email.sql`) já existe pra manter `user_profiles.email` sincronizado quando `auth.users.email` muda — só precisa ser estendido pra também atualizar `motoboys.email`.
- Não existe fluxo de "esqueci senha" funcionando pra **ninguém** hoje: `authService.resetPassword()` já chama `supabase.auth.resetPasswordForEmail` com `redirectTo: /reset-password`, mas essa rota não existe no `Routes.jsx` — precisa ser criada agora (beneficia cliente/dono também, de graça).
- Backend não tem framework de DTO — mass assignment é evitado com objetos `campos={}` explícitos (ver `impressoras.service.ts`, `produtos.service.ts`). Seguir esse padrão.
- Todo change de backend precisa ir pros dois checkouts sincronizados: `serer_delivery/` e `deliveryhub_white_label/server_delivery/` (submódulo), depois bump do ponteiro do submódulo no frontend.

## 1. Migração SQL (`deliveryhub_white_label/supabase/migrations/20260821000001_motoboys_supabase_auth.sql`)

- Não alterar a coluna `user_id` (já existe). Adicionar `CREATE UNIQUE INDEX IF NOT EXISTS motoboys_user_id_unique ON public.motoboys (user_id) WHERE user_id IS NOT NULL;` — hoje nada impede duas linhas de `motoboys` apontarem pro mesmo `auth.users.id`, e o novo guard depende de lookup único por `user_id`.
- Não dropar `password_hash`/`access_token`/`active_session_id`/`session_expires_at`/`precisa_completar_cadastro` — manter por segurança/rollback, só parar de ler/escrever nos novos fluxos. Adicionar `COMMENT ON COLUMN` marcando `password_hash`/`access_token` como legado.
- Estender `sync_user_profile_email()` (recriar a função com `CREATE OR REPLACE`) pra também rodar `UPDATE public.motoboys SET email = NEW.email WHERE user_id = NEW.id;` — mantém `motoboys.email` em sincronia quando o motoboy troca o e-mail via `authService.updateEmail`.
- Não tocar na política RLS `motoboys_owner` (ainda referencia a coluna legada `restaurant_id`) — está morta na prática (`SupabaseService` sempre usa a service-role key, que ignora RLS; nenhum código do frontend consulta `motoboys` com a anon key). Deixar um comentário na migration explicando isso, não é bloqueante.
- Não tornar `motoboys.email` `NOT NULL` no banco — obrigatoriedade fica só na camada de aplicação (igual outras regras hoje).
- Aplicar local: `npx supabase migration up` (rodado de `deliveryhub_white_label/`). Produção (`delivery_jota`, ref `gkeolhhcptavftwloucj`): só com `npx supabase db push --linked` depois de confirmação explícita do usuário, e só depois do backfill (seção 3) já ter rodado.

## 2. Backend (aplicar idêntico em `serer_delivery/` e `deliveryhub_white_label/server_delivery/`)

### 2.1 `src/motoboy/motoboy-auth.service.ts` — remover e substituir

Remover: `login()`, `completarCadastro()` (legado), `gerarToken()`, imports de `bcrypt`/`jsonwebtoken`, `exigirContaSemRestaurante`/`vincularContaCliente` (substituídos abaixo).

Manter: `EMAIL_RE`/`PHONE_RE` (ainda usados por `motoboy.service.ts`), `uploadDocumento()`, a lógica de sessão única (`abrirSessao`, `SESSION_TTL_MS`, `logout`) — o `UPDATE` condicional atômico continua igual, só passa a ser chamado a partir de um `motoboyId` resolvido via `user_id` verificado pelo Supabase, não mais de um payload de JWT próprio.

Novos métodos:
- `completarCadastro(userId: string, body)` — body só `{ name, phone, foto_perfil, documento_frente, documento_verso?, comprovante_endereco }`, sem `password`/`email` (e-mail vem do JWT do Supabase já verificado, não do body, pra não poder ser forjado). Fluxo: rejeita se `userId` já é dono de restaurante; rejeita se `userId` já tem linha em `motoboys` (idempotência); insere `motoboys` com `user_id`, `email` (do token), `name`, `phone`, `precisa_completar_cadastro: false`, `status_plataforma: 'pendente'`, sem `password_hash`; sobe os 4 documentos; promove `user_profiles.role = 'motoboy'`. Retorna `{ ok: true }` (sem token — sessão Supabase já existe no frontend).
- `abrirSessaoPortal(userId: string)` — busca `motoboys.id` por `user_id` (404 se não achar), checa `is_active`, chama o `abrirSessao()` existente, retorna `{ sessionId }`.
- `logout(motoboyId)` mantido, mas `motoboyId` agora vem do novo guard (via `req.motoboyId`), não de payload de JWT próprio.

### 2.2 `src/motoboy/motoboy-auth.controller.ts` — reescrito

- `POST motoboy/auth/completar-cadastro` — `@UseGuards(JwtGuard)`, chama `completarCadastro(req.userId, body)`.
- `POST motoboy/auth/abrir-sessao` — `@UseGuards(JwtGuard)`, `@Throttle` (ex. 10/min), chama `abrirSessaoPortal(req.userId)`.
- `POST motoboy/auth/logout` — `@UseGuards(MotoboyGuard)` (novo guard), chama `logout(req.motoboyId)`.
- Remover de vez as rotas antigas `POST cadastro` e `POST login`.

### 2.3 `src/auth/motoboy.guard.ts` — reescrito (mesmo arquivo/classe)

Composição igual `RestaurantOwnerGuard`: roda `JwtGuard.canActivate` primeiro (verifica o JWT real do Supabase via JWKS, seta `req.userId`), depois busca `motoboys` por `user_id = req.userId`, confere `is_active`, e **adicionalmente** confere o header `x-motoboy-session` contra `active_session_id`/`session_expires_at` no banco (isso é o que preserva a trava de sessão única e o "forçar logout"). Seta `req.motoboyId`/`req.motoboyName`. Remove de vez `jsonwebtoken`/`MOTOBOY_JWT_SECRET` e o fallback legado de `access_token`.

### 2.4 `src/motoboy/motoboy.service.ts` — `criarPeloRestaurante`/`editarPeloRestaurante`

- `criarPeloRestaurante`: `email` passa a ser obrigatório na validação. Trocar `bcrypt.hash(...)` por `supabase.auth.admin.createUser({ email, password: body.password, email_confirm: true, user_metadata: { name, role: 'motoboy' } })` (mesmo padrão de `scripts/seed-primeiro-boot.ts`/`usuarios.service.ts trocarCredenciais`). Se e-mail já existir no Auth (422/"already"), lançar `ConflictException` claro. Inserir `motoboys` com `user_id` do usuário criado, sem `password_hash`. Senha continua obrigatória no create (decisão do usuário).
- `editarPeloRestaurante`: se `body.password` vier, chamar `auth.admin.updateUserById(motoboy.user_id, { password })` em vez de hash local (precisa buscar `user_id` junto no select de `exigirMotoboyGerenciadoPeloRestaurante`). Se `body.email` mudar, `updateUserById(..., { email, email_confirm: true })` + atualizar `motoboys.email`.
- Novo `gerarLinkRedefinicaoSenha(motoboyId, restaurantId)`: valida posse, busca `email`/`user_id` (404 se motoboy nunca migrou), chama `supabase.auth.admin.generateLink({ type: 'recovery', email })`, retorna `{ link: data.properties.action_link }`.
- Novo `enviarLinkRedefinicaoSenhaPorEmail(motoboyId, restaurantId)`: valida posse, chama `supabase.auth.resetPasswordForEmail(email, { redirectTo: ... })` — mesmo mecanismo que cliente já usa, funciona com qualquer client Supabase (não é admin-only), sem precisar de mailer próprio.

### 2.5 `src/motoboy/restaurante-motoboys.controller.ts` — novos endpoints

`POST :motoboyId/gerar-link-senha` e `POST :motoboyId/enviar-link-senha-email`, ambos sob `RestaurantOwnerGuard` já existente no controller, chamando os métodos novos acima.

### 2.6 Perfil do motoboy — novo PATCH em `src/motoboy/motoboy-portal.controller.ts`

`PATCH me` (guard `MotoboyGuard`) → novo `MotoboyService.atualizarPerfilMotoboy(motoboyId, body)` com allowlist explícita (`name`, `phone`, re-upload de `foto_perfil` se enviado), seguindo o padrão `campos={}` do resto do código. E-mail **não** é editável por aqui — troca de e-mail passa por `authService.updateEmail` do próprio motoboy (fluxo já existente pra cliente), e o trigger da seção 1 mantém `motoboys.email` sincronizado.

### 2.7 Limpeza

`MOTOBOY_JWT_SECRET`: parar de usar nos itens acima; remover do `.env.example` só no commit final de limpeza (não no mesmo deploy, por segurança de rollback). Fallback legado de `access_token` no guard: removido de vez (não é compromisso dual-sistema — é corte real), condicionado a confirmar que o backfill (seção 3) cobriu 100% dos motoboys existentes antes de subir essa remoção.

## 3. Script de backfill (rodar uma vez, local depois produção)

Novo `scripts/backfill-motoboys-supabase-auth.ts` (nos dois checkouts), no estilo de `scripts/seed-primeiro-boot.ts`:

1. Carrega `SUPABASE_URL`/`SUPABASE_SERVICE_ROLE_KEY` do `.env`.
2. `SELECT id, name, email, phone, user_id FROM motoboys WHERE user_id IS NULL`.
3. Linha sem e-mail → loga e pula (some no resumo final pra contato manual — telefone-only não dá pra migrar sozinho).
4. Linha com e-mail → `auth.admin.createUser({ email, password: <random 16 chars>, email_confirm: true, user_metadata: { name, role: 'motoboy' } })` (fallback pra e-mail já existente igual ao `seed-primeiro-boot.ts`), depois `UPDATE motoboys SET user_id = ...`, depois `auth.admin.generateLink({ type: 'recovery', email })` e imprime o link no console (senha aleatória é inútil sem isso — motoboy PRECISA resetar antes do primeiro login).
5. Idempotente (só processa `WHERE user_id IS NULL` de novo).

Rodar local primeiro contra os 2 motoboys de teste (`dd@delivery.com` id 1, `tati@delivery.com` id 2 — ambos têm e-mail, migram limpo). **Antes de rodar em produção**: `SELECT count(*), count(email) FROM motoboys WHERE user_id IS NULL` no banco de produção real, reportar pro usuário, e só rodar o backfill lá com confirmação explícita dele (cria `auth.users` de verdade e não manda e-mail sozinho — quem rodar o script entrega o link manualmente).

## 4. Frontend (`deliveryhub_white_label`)

- **Novo `src/pages/reset-password/index.jsx` + rota `/reset-password`** em `Routes.jsx` (pública, sem guard). Supabase SDK já captura o token da URL sozinho (`detectSessionInUrl`) e dispara `onAuthStateChange` com `PASSWORD_RECOVERY`; a página mostra formulário de nova senha, chama `authService.updatePassword()`, redireciona pro painel certo (`isMotoboy() ? '/motoboy' : isRestaurantOwner() ? '/restaurante' : '/'`). Infra compartilhada — vale a pena subir num commit isolado, antes do resto, já que beneficia cliente/dono também e não depende de nada do motoboy.
- **`src/components/MotoboyGuard.jsx`** — reescrito no padrão de `RestauranteGuard.jsx`: usa `useAuth()` (`isAuthenticated()`, `isMotoboy()`), sem mais checagem de localStorage/`?token=` na URL.
- **`src/services/motoboyAuthService.js`**: remove `TOKEN_KEY`/localStorage do token antigo e `login`/`cadastro`/`completarCadastro` antigos. Adiciona `SESSION_KEY='motoboy_session_id'` (localStorage) + getters/setters, `abrirSessaoMotoboy()` (pega `supabase.auth.getSession()`, chama `POST /motoboy/auth/abrir-sessao` com `Authorization: Bearer`, guarda o `sessionId` retornado), `completarCadastroMotoboy(dados)` (chama `POST /motoboy/auth/completar-cadastro` com `Authorization: Bearer` da sessão recém-criada pelo `signUp()`).
- **`src/services/motoboyService.js`**: `motoboyFetch()` passa a mandar `Authorization: Bearer <supabase access_token>` **e** `x-motoboy-session: <sessionId>` em toda chamada, no lugar do único `x-motoboy-token`. Em 401, limpa o `sessionId` e redireciona pro login.
- **`src/pages/motoboy-cadastro/index.jsx`**: troca o fluxo por `signUp(email, password, { name, role: 'motoboy', phone })` (via `useAuth()`, igual cliente) → `completarCadastroMotoboy(...)` (docs) → `abrirSessaoMotoboy()` → `refreshUserProfile()` → `navigate('/motoboy')`. Corrigir `minLength` da senha de 6 pra 8 (já era inconsistente com a regra do backend).
- **`src/pages/customer-registration-login/index.jsx`**: adicionar `if (isMotoboy()) return '/motoboy';` na lógica de redirect pós-login (`getRedirectUrl`, hoje só trata admin/dono). Remover o fallback antigo `motoboyLogin` (bloco `try/catch` do login customizado) — motoboy autentica só pelo `signIn` normal do Supabase daqui pra frente.
- **`src/pages/restaurante-motoboys/index.jsx`** (`MotoboyFormModal`): campo `email` vira `required`. No modo edição, adicionar 3 botões: "Copiar link" (chama `gerarLinkSenhaMotoboy`, copia pra clipboard), "Enviar por WhatsApp" (mesmo link, abre `https://wa.me/<telefone>?text=<link>`, seguindo o padrão já usado em `PedidoDetalhe.jsx`), "Enviar por e-mail" (chama `enviarLinkSenhaMotoboyPorEmail`, mostra toast de sucesso).
- **`src/services/restauranteService.js`**: adicionar `gerarLinkSenhaMotoboy`/`enviarLinkSenhaMotoboyPorEmail` perto de `criarMotoboy`/`editarMotoboy`.
- **Perfil do motoboy**: nova seção "Meu perfil" dentro de `src/pages/motoboy-portal/index.jsx` (aba/seção na mesma página, não rota nova) — lê de `GET /motoboy/me` (já buscado hoje), edita via o novo `PATCH /motoboy/me`. Troca de senha reaproveita o "esqueci minha senha" já existente (sem UI nova de "trocar senha logado" — evita abstração especulativa).

## 5. Ordem de deploy

Sem CI/CD, sem feature flag, deploy = push no main. Sequência:

1. **Commit isolado, pode subir já**: página `/reset-password` (item 4, primeiro bullet) — puramente aditivo, beneficia todo mundo, zero dependência do resto.
2. **Migration + backend** (itens 1 e 2), aplicados juntos: migration primeiro (`supabase migration up` local / `db push --linked` em prod, com confirmação), depois deploy do backend nos dois checkouts + bump do ponteiro do submódulo. **Rodar o backfill (item 3) imediatamente antes desse deploy**, na mesma janela — sem `user_id` setado, motoboy não consegue logar de jeito nenhum depois que o guard antigo sair do ar.
3. **Frontend** (item 4, resto), logo em seguida — a troca do guard/rotas no backend já quebra o app antigo pra motoboy nesse meio-tempo, então não dá pra esperar.
4. **Commit de limpeza final** (sem pressa): remover `MOTOBOY_JWT_SECRET` do `.env.example`, conferir que não sobrou referência a `password_hash`/`access_token` no código (colunas do banco continuam, só não são mais usadas).

**Aviso explícito**: motoboys logados no sistema antigo no momento do deploy do passo 2 vão cair (401) e precisar logar de novo pelo fluxo novo — não tem como evitar sem manter os dois sistemas em paralelo, o que fugiria do pedido de "migração de verdade".

## Verificação (sem suite de testes automatizada no projeto — teste manual ponta a ponta é o critério)

1. Autocadastro (`/motoboy/cadastro`, e-mail+senha 8+ caracteres+4 docs) → confere no banco: `auth.users` criado, `user_profiles.role='motoboy'`, `motoboys.user_id` setado, sem `password_hash`, `active_session_id` setado.
2. Login normal (`/customer-registration-login`) com esse e-mail/senha → cai em `/motoboy`.
3. Sessão única: logar em 2 navegadores com a mesma conta → segundo recebe erro de sessão já ativa; "Forçar logout" pelo restaurante (em motoboy `criado_por_restaurant_id`) → primeiro dispositivo cai no próximo request.
4. Recuperação de senha: "Esqueci minha senha" com e-mail do motoboy → clicar no link do e-mail (Inbucket local) → cai em `/reset-password` → define senha nova → loga com ela.
5. Perfil: editar nome/telefone na nova seção do painel → recarregar → confirma persistência.
6. Motoboy criado pelo restaurante: preencher nome/telefone/e-mail/senha → confere `auth.users` criado via admin API, `motoboys.user_id`/`criado_por_restaurant_id` setados, afiliação aceita.
7. Convite: no motoboy acima, "Copiar link" → válido em janela anônima → define senha → loga. "Enviar por e-mail" → mesmo teste via e-mail.
8. Rotas antigas (`POST /motoboy/auth/login`) devem sumir (404/rota não existe).
9. `diff` entre os dois checkouts de backend (excluindo `node_modules`/`.git`/`.env`) deve dar vazio antes de considerar o backend pronto.

### Arquivos-chave
- `serer_delivery/src/motoboy/motoboy-auth.service.ts` (+ cópia idêntica no submódulo)
- `serer_delivery/src/auth/motoboy.guard.ts`
- `serer_delivery/src/motoboy/motoboy.service.ts`
- `serer_delivery/scripts/backfill-motoboys-supabase-auth.ts` (novo)
- `deliveryhub_white_label/supabase/migrations/20260821000001_motoboys_supabase_auth.sql` (novo)
- `deliveryhub_white_label/src/services/motoboyAuthService.js`, `motoboyService.js`
- `deliveryhub_white_label/src/components/MotoboyGuard.jsx`
- `deliveryhub_white_label/src/pages/motoboy-cadastro/index.jsx`, `restaurante-motoboys/index.jsx`, `motoboy-portal/index.jsx`
- `deliveryhub_white_label/src/pages/reset-password/index.jsx` (novo)
