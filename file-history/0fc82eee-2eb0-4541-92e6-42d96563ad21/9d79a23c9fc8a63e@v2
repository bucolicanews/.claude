# Corrigir vínculo dono↔restaurante + gestão de usuários pelo admin

## Contexto

Um restaurante em produção ("Resto Recanto do Farol") está com assinatura ativa e o dono corretamente configurado em `restaurants.user_id`, mas o botão do painel não aparece pra ele — o painel usa uma checagem separada (`user_profiles.role === 'restaurant_owner'`) que nunca foi atualizada pra esse usuário.

Causa raiz: o sistema usa **dois sinais de "dono" desacoplados**:
- `restaurants.user_id` — o vínculo real, usado pelo backend (`RestaurantOwnerGuard`) pra liberar os dados do painel.
- `user_profiles.role` — usado só pelo **frontend** (`AuthContext.isRestaurantOwner()` → `RestauranteGuard`) pra decidir se mostra/libera a navegação pro painel.

Eles só são sincronizados no último passo (5/5) da wizard de cadastro (`POST /restaurante/finalizar`, em `onboarding.controller.ts:162-166`), e esse `update` não checa erro. Se o dono fecha o navegador/perde conexão depois de pagar mas antes de clicar "Finalizar Cadastro", ou se o update falhar silenciosamente, `user_id` fica certo mas `role` fica `'customer'` pra sempre — reproduzindo exatamente o bug relatado. O mesmo buraco existe no admin: o campo "UUID do dono" em `admin-empresas` só mexe em `user_id`, nunca em `role`.

A partir disso, o usuário pediu para também resolver a lacuna maior: hoje não existe nenhuma tela admin pra listar usuários, vincular/desvincular donos de restaurante, ou trocar email/senha de qualquer usuário (suporte manual) — e nenhum usuário (admin, dono, cliente) tem uma tela própria pra trocar sua senha/email.

## Abordagem

### 1. Corrigir a causa raiz (backend + frontend, baixo risco)

Criar `server_delivery/src/usuarios/` (module + service) com um único método `sincronizarVinculoDono(restaurantId, novoUserId)` que vira a **fonte única** da regra "vínculo restaurante ↔ role":
- Atualiza `restaurants.user_id`, propagando erro (nunca engole).
- Eleva o novo dono pra `role='restaurant_owner'` — só se ele não for já `admin` (nunca rebaixa admin).
- Se havia um dono anterior diferente e ele não tem mais nenhum outro restaurante, rebaixa-o pra `'customer'` (mantém `role` como reflexo fiel do vínculo real).

Consumido em dois pontos que hoje fazem essa lógica errado/incompleta:
- `onboarding.controller.ts` `/finalizar` (linhas 162-166) — troca o `update` solto por `usuarios.sincronizarVinculoDono(restaurantId, userId)`. Isso faz falhas virarem erro real (500) em vez de sucesso falso, e o front cai no `catch` já existente do wizard.
- `empresas.service.ts` `atualizar()` (linhas 83-107) — quando o body tem `user_id`, delega pra `sincronizarVinculoDono()` em vez de só dar `update` cru. Isso corrige o campo "UUID do dono" do admin pra já fazer a coisa certa.

No frontend, `restaurant-registration-setup/index.jsx` `handleCompleteSetup` (~linha 305) passa a chamar `refreshUserProfile()` (já existe em `AuthContext`) logo após o `/finalizar` ter sucesso, antes do `navigate('/restaurante')` — sem isso, mesmo com o backend corrigido, o `role` em memória do front só atualizaria num login futuro.

Migration `supabase/migrations/20260813000001_restaurants_user_id_unique.sql`: adiciona `UNIQUE` em `restaurants.user_id` (Postgres permite múltiplos `NULL`). O código já pressupõe 1 restaurante por dono (`RestaurantOwnerGuard` usa `.maybeSingle()`, que quebraria com 2+), isso só formaliza no schema. Rodar antes uma checagem de duplicatas existentes.

**Correção pontual do registro já em produção**: depois que o código acima estiver no ar, ainda falta rodar uma vez `UPDATE user_profiles SET role = 'restaurant_owner' WHERE id = '<uuid do dono>'` pra esse restaurante específico (confirmando antes que `restaurants.user_id` já bate com esse uuid). Não tenho acesso ao Supabase de produção nessa sessão (só as credenciais locais) — depois que o módulo do item 2 estiver no ar, dá pra fazer isso pela própria tela `/admin/usuarios` (vincular de novo o mesmo dono já resolve, pois passa a acionar `sincronizarVinculoDono`); se precisar mais rápido, você roda o UPDATE direto no SQL Editor do Supabase Studio de produção.

### 2. Módulo admin `usuarios` (backend)

Novo `server_delivery/src/usuarios/` (controller + service, guardado por `AdminGuard`, registrado em `app.module.ts`, importado por `empresas.module.ts` e `restaurante.module.ts` pra reuso do service):

- `GET /admin/usuarios?busca=&role=&page=&limit=` — lista a partir de `user_profiles` (nome/email/role/must_change_password), cruzando com `restaurants` (`user_id IN (...)`) pra mostrar o vínculo de cada um. Paginado.
- `PATCH /admin/usuarios/:id/credenciais` — body `{ email?, senha? }` (pelo menos um). Chama `supabase.auth.admin.updateUserById(id, { email, email_confirm: true, password })` — `email_confirm: true` faz a troca ser imediata (sem exigir confirmação por email), o que é o comportamento certo pro caso de suporte descrito ("usuário travado, sem acesso ao email"). Sincroniza `user_profiles.email` e grava linha de auditoria.
- `GET /admin/usuarios/auditoria?usuario_id=` — histórico de trocas feitas por admins.

**Vincular/desvincular restaurante não ganha endpoint novo** — a tela reaproveita o `PATCH /empresas/:id { user_id }` já existente (agora corrigido no item 1), evitando duplicar a regra em dois lugares.

Migration `supabase/migrations/20260813000002_admin_audit_log.sql`: tabela `admin_audit_log(id, admin_user_id, target_user_id, acao, detalhes jsonb, criado_em)`, RLS habilitado, só policy de `SELECT` pra admin — sem policy de escrita pra `authenticated`/`anon` (só o backend com service_role grava, então ninguém client-side consegue forjar uma linha de auditoria).

Migration `supabase/migrations/20260813000003_sync_user_profile_email.sql`: trigger em `auth.users` (`AFTER UPDATE OF email`) que mantém `user_profiles.email` sincronizado automaticamente — cobre tanto a troca feita pelo admin quanto a autoatendimento (item 4), que sem isso ficaria dessincronizada.

### 3. Tela `/admin/usuarios` (frontend)

`src/pages/admin-usuarios/index.jsx`, seguindo o padrão visual de `admin-empresas/index.jsx` (tabela + `AdminHeader`): colunas Nome, Email, Role, Restaurante vinculado, Cadastro, Ações. Ações por linha: vincular/trocar restaurante (modal com select, chama `atualizarEmpresa`), desvincular (`atualizarEmpresa(id, { user_id: null })`), trocar email/senha (modal → novo endpoint). Busca por nome/email, filtro por role.

Novas funções em `src/services/adminService.js`: `getUsuarios`, `trocarCredenciaisUsuario`, `getAuditoriaUsuario`. Adicionar link em `src/config/adminNavLinks.js` e rota em `Routes.jsx` (`<AdminGuard>`).

### 4. "Meu Perfil" — troca de senha/email pelo próprio usuário

Hoje não existe *nenhuma* tela de autoatendimento pra email/senha (nem pra cliente, nem dono, nem admin — só o fluxo forçado de primeira senha do admin). Criar um componente único `src/components/perfil/CredenciaisForm.jsx` (campos de novo email / nova senha, chama `authService.updatePassword` — já existe — e um novo `authService.updateEmail` usando `supabase.auth.updateUser({ email })`, que dispara a confirmação nativa do Supabase).

Montado em 3 lugares:
- `src/pages/admin-meu-perfil/index.jsx` (com `AdminHeader`) + rota `/admin/meu-perfil`.
- `src/pages/restaurante-meu-perfil/index.jsx` (com `RestauranteHeader`/`RestauranteSidebar`) + rota `/restaurante/meu-perfil`.
- Dentro de `src/pages/customer-profile/index.jsx` como uma seção a mais (não cria página nova pro cliente, já é single-page).

Sem 2FA por enquanto, conforme pedido.

## Arquivos principais

- `server_delivery/src/usuarios/usuarios.module.ts`, `usuarios.service.ts`, `usuarios.controller.ts` (novos)
- `server_delivery/src/restaurante/onboarding.controller.ts` (linhas 162-166)
- `server_delivery/src/empresas/empresas.service.ts` (`atualizar()`, linhas 83-107) e `empresas.module.ts`
- `server_delivery/src/restaurante/restaurante.module.ts`, `server_delivery/src/app.module.ts`
- `src/pages/restaurant-registration-setup/index.jsx` (`handleCompleteSetup`)
- `src/pages/admin-usuarios/index.jsx`, `src/pages/admin-meu-perfil/index.jsx`, `src/pages/restaurante-meu-perfil/index.jsx` (novos)
- `src/components/perfil/CredenciaisForm.jsx` (novo)
- `src/pages/customer-profile/index.jsx`
- `src/services/adminService.js`, `src/services/authService.js`
- `src/config/adminNavLinks.js`, `src/Routes.jsx`
- `supabase/migrations/20260813000001_restaurants_user_id_unique.sql`, `20260813000002_admin_audit_log.sql`, `20260813000003_sync_user_profile_email.sql` (novos)

## Verificação

- `npx supabase start` (local) + `npx supabase db reset` pra aplicar as migrations novas do zero, ou `supabase db push` incremental.
- Rodar a wizard de cadastro local do zero (criar restaurante novo, pagar/trial, ir até o passo 5) e confirmar que `role` vira `restaurant_owner` e o painel aparece sem precisar relogar.
- Simular o bug: criar restaurante via `registrar-inicial` e parar antes do `/finalizar` — confirmar que o botão do painel não aparece (esperado) e que rodar `/finalizar` depois corrige sem erro.
- No admin: editar o UUID do dono em `/admin/empresas` e conferir que `user_profiles.role` do novo dono vira `restaurant_owner` e do dono anterior (se houver e não tiver outro restaurante) volta pra `customer`.
- Testar `/admin/usuarios`: listar, buscar, vincular/desvincular, trocar email (checar que dispara sem exigir confirmação) e senha de um usuário de teste; conferir que a linha aparece em `admin_audit_log`.
- Testar "Meu Perfil" nas 3 telas: trocar senha (login com a nova senha) e trocar email (confirmar que `user_profiles.email` acompanha via trigger).
- Depois do deploy: aplicar a correção pontual do restaurante #3 em produção (via `/admin/usuarios` ou SQL direto) e confirmar com o dono que o painel já aparece.
