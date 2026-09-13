# 2FA (autenticação em duas etapas) para Admin e Dono de Restaurante

## Context

Depois de integrar Resend como SMTP do Supabase Auth (pra emails transacionais), o usuário quer oferecer autenticação em duas etapas (2FA) — configurável, podendo ser ligada/desligada por quem usa — para dois papéis: **admin da plataforma** e **dono de restaurante** (não garçom, não motoboy, não cliente). Cada um desses dois perfis deve poder escolher entre três opções: **nenhum 2FA**, **app autenticador (TOTP)**, ou **código por email (via Resend)**.

Duas explorações no código confirmaram: hoje não existe NENHUMA infraestrutura de 2FA (nem TOTP nem código por email) — é greenfield total. Mas existe uma peça de arquitetura que resolve o requisito "admin E dono de restaurante" de forma natural: o login de **todos** os papéis (customer/dono/admin) passa pelo mesmo endpoint backend (`POST /auth-principal/login`, `AuthLoginService.login`), e a tabela `user_profiles` (não `restaurants`) é a que cobre tanto admin quanto dono — então um único campo em `user_profiles` cobre os dois papéis, sem duplicar lógica. Da mesma forma, `CredenciaisForm.jsx` já é o componente compartilhado de "trocar senha/email" usado tanto em `admin-meu-perfil` quanto em `restaurante-meu-perfil` — é o lugar certo pra colocar o toggle de 2FA uma vez só.

**Importante:** isso é estritamente opt-in — contas que nunca configurarem 2FA (`two_factor_method = 'none'`, default) continuam logando exatamente como hoje, sem nenhuma mudança de comportamento.

## 1. Modelo de dados

Novas colunas em `user_profiles` (não em `restaurants` — precisa cobrir admin também, que não tem linha em `restaurants`):
- `two_factor_method` — text, default `'none'` (`'none' | 'totp' | 'email'`)
- `two_factor_totp_secret` — text, nullable (segredo base32, só existe quando `method = 'totp'`; nunca é reenviado ao frontend depois de confirmado)

Sem migration versionada no repo (schema do Supabase é aplicado direto, confirmado pela exploração) — aplicar via `ALTER TABLE user_profiles ADD COLUMN ...` no Supabase (local primeiro, depois `--linked` em produção, seguindo a ordem já padrão do projeto).

## 2. Backend (`serer_delivery`, replicar no submódulo depois)

### 2.1. Ponto de interceptação no login — `src/auth-login/auth-login.service.ts`

Hoje (`AuthLoginService.login`, linhas 47-87): busca `user_profiles`, chama `signInWithPassword`, e devolve `{access_token, refresh_token}` direto na linha 86.

Mudança: estender o `select` de `user_profiles` (linha ~51-55) pra incluir `two_factor_method`. Depois de `signInWithPassword` ter sucesso (linha 61):
- Se `two_factor_method === 'none'` → devolve os tokens exatamente como hoje (zero mudança de comportamento).
- Se `'totp'` ou `'email'` → **não devolve os tokens ainda**. Gera um `challenge_id` (`crypto.randomUUID()`), guarda no Redis (TTL 5 min) um payload com `{ userId, method, session: data.session }` — ou seja, a sessão que o Supabase já emitiu fica "retida" até o segundo fator ser confirmado. Se `method === 'email'`, gera um código de 6 dígitos, guarda junto no mesmo payload, e manda por email via o novo serviço Resend (abaixo) — **sempre pro email já cadastrado em `user_profiles.email`, nunca um email vindo do corpo da requisição** (mesmo princípio de segurança que já validamos no fluxo de recuperação de senha). Devolve `{ requires2fa: true, method, challenge_id }` (HTTP 200, sem tokens).

### 2.2. Novo endpoint — `POST /auth-principal/verify-2fa`

Mesmo controller/módulo do login, mesmo estilo de rate-limit (`@Throttle`, mais agressivo aqui — ex. 10/min — já que é um código de 6 dígitos). Body `{ challenge_id, code }`:
- Busca o challenge no Redis. Expirado/inexistente → erro claro.
- `method === 'email'`: compara `code` com o guardado (uso único — apaga do Redis após a tentativa, sucesso ou falha).
- `method === 'totp'`: verifica `code` contra `two_factor_totp_secret` do usuário usando `otplib` (nova dependência), janela padrão de ±1 passo.
- Sucesso: apaga o challenge, devolve `{access_token, refresh_token}` guardados nele — daí em diante o frontend segue o fluxo normal (`setSession`).
- Falha: 401 genérico. Limitar tentativas por `challenge_id` (ex. 5, depois invalida e obriga a logar de novo) — mesmo espírito do contador de tentativas que já existe em `user_profiles.tentativas_login_falhas`.

**Ponto de atenção arquitetural:** `RedisService` hoje (`src/redis/redis.service.ts`) é *fail-open* por design (cache-aside — se o Redis cair, recalcula e segue). Isso é **errado** pra esse caso: se o Redis cair durante um login com 2FA, a checagem tem que **falhar fechada** (bloquear o login com erro, nunca pular o segundo fator). Vou usar o cliente ioredis diretamente pro challenge de 2FA (não a wrapper `getJSON`/`setJSON` existente), propagando erro se a operação falhar, em vez de reaproveitar o padrão best-effort atual. Preciso também adicionar um método de "consumir" (get + delete atômico) no `RedisService`, que hoje só tem get/set — não existe.

### 2.3. Endpoints de gerenciamento (usados pela tela de configuração)

- `GET /auth-principal/2fa/status` → `{ method }`.
- `POST /auth-principal/2fa/enroll/totp` → gera segredo novo (`otplib`), devolve `{ secret, otpauth_url }` pra virar QR code — **ainda não ativa**.
- `POST /auth-principal/2fa/enroll/totp/confirm` → `{ secret, code }`, confirma que o app do usuário está sincronizado antes de gravar `two_factor_method='totp'` + o segredo em `user_profiles` (padrão padrão de enrollment TOTP — evita trancar o usuário fora com um QR mal escaneado).
- `POST /auth-principal/2fa/enroll/email` → grava `two_factor_method='email'` direto (sem segredo — cada login gera um código novo).
- `POST /auth-principal/2fa/disable` → exige a senha atual no corpo (reautentica via `signInWithPassword`, mesmo client isolado do login) antes de zerar `two_factor_method`/o segredo — pra uma sessão comprometida não conseguir desligar o 2FA sozinha.

### 2.4. Serviço de email via Resend (novo, backend)

Não existe integração direta com Resend no backend hoje (só o Supabase Auth usa Resend, via config do painel, pra emails próprios dele — isso é separado). Adicionar:
- Dependência `resend` no `package.json`.
- `RESEND_API_KEY` no `.env.example` (documentado) e no `.env` real (dois checkouts).
- Um serviço pequeno (`src/auth-login/two-factor-email.service.ts` ou similar) que envia o código de 6 dígitos com um template simples.

## 3. Frontend (`deliveryhub_white_label`)

### 3.1. Login — `src/contexts/AuthContext.jsx` (`signIn`, linhas 90-128) + `customer-registration-login/index.jsx`

`AuthContext.signIn` hoje faz POST em `/api/auth-principal/login` e, se `ok`, chama `supabase.auth.setSession(...)` direto. Mudança: se a resposta trouxer `requires2fa: true`, **não** chama `setSession` — devolve `{success:false, requires2fa:true, method, challengeId}` pro chamador.

`CustomerRegistrationLogin.handleLogin` (`index.jsx:41-59`): ao receber `requires2fa`, troca a tela de `LoginForm` por uma tela de "digite o código" em vez de navegar embora.

**Reaproveitar `WhatsAppVerification.jsx`** (`customer-registration-login/components/`) como base — já tem exatamente a state machine certa (campo de 6 dígitos, contador de reenvio, validação, `onVerify`/`onResendCode`/`onBack`). Vou generalizar/copiar pra um componente `TwoFactorVerification.jsx` (mover pra `src/components/` já que passa a ser usado tanto no login quanto na tela de configuração), trocando os textos fixos de WhatsApp e escondendo "Reenviar código" no modo TOTP (não faz sentido reenviar um código que já muda sozinho a cada 30s no app do usuário).

Novo `authService.verifyTwoFactor(challengeId, code)` → `POST /api/auth-principal/verify-2fa` → em caso de sucesso, `setSession(...)` com os tokens devolvidos e segue o redirect normal já existente (`getRedirectUrl`).

### 3.2. Tela de configuração — `src/components/perfil/CredenciaisForm.jsx`

Esse componente já é compartilhado entre `admin-meu-perfil` e `restaurante-meu-perfil` (e também usado no perfil de cliente) — é o lugar certo, editando **uma vez só**, pra aparecer nos dois papéis pedidos. Pra não vazar pra cliente/motoboy (fora de escopo), passar um prop novo tipo `mostrarSeguranca2FA` que só `admin-meu-perfil` e `restaurante-meu-perfil` passam como `true` (a tela de perfil de cliente não passa, então não aparece lá).

Novo card "Autenticação em duas etapas" com um seletor de 3 opções (segmented control — mesmo padrão visual já usado em outras telas do projeto pra esse tipo de escolha, ex. `PillSelect` do admin-aparência): **Nenhum / App autenticador / Código por email**.
- Escolher "App autenticador": chama `enroll/totp`, mostra o `otpauth_url` como QR code (precisa adicionar uma lib de QR code ao frontend — não existe nenhuma hoje, ex. `qrcode.react`) + campo pra confirmar o primeiro código.
- Escolher "Código por email": chama `enroll/email` direto.
- Voltar pra "Nenhum" quando já está ativo: pede a senha atual (mesmo padrão de confirmação que já existe no card "Trocar senha" desse componente) antes de desativar.

## 4. Aplicar nos dois checkouts do backend

Como sempre nesse projeto: qualquer mudança em `serer_delivery/` precisa ser replicada em `deliveryhub_white_label/server_delivery/` (checkouts git independentes) — código, `.env.example`, e o `.env` real (a nova `RESEND_API_KEY`) nos dois.

## 5. Verificação

- Rodar `npx supabase migration` / aplicar as colunas novas no banco local primeiro, testar o fluxo local (login sem 2FA continua igual; ativar TOTP com um app tipo Google Authenticator e confirmar; ativar código por email e checar que o Resend manda pro email certo — mesmo que Resend só esteja configurado em produção, localmente dá pra testar a lógica com o e-mail retornando erro/mock).
- Testar: login com 2FA ativo mas Redis local desligado → deve bloquear o login com erro claro, não pular o 2FA (valida o fail-closed).
- Testar: 6 tentativas erradas de código → challenge invalidado, precisa logar de novo.
- Testar: desativar 2FA sem senha correta → deve recusar.
- Conferir visualmente em `/admin/meu-perfil` e `/restaurante/meu-perfil` que o card aparece nos dois, e que não aparece no perfil de cliente.
