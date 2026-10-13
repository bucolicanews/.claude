---
name: feedback-cloudflare-r2-credenciais
description: "Cloudflare R2 setup gotchas: credential setup (3 values on one screen, 2 token UIs) and custom domain setup (apex-domain routing conflict, false 403 during TLS init). Reusable across any project adopting R2."
metadata:
  type: feedback
  originSessionId: 51fec3b0-09a8-4b61-9185-8e0757ba52f2
  modified: 2026-10-13T19:10:05.707Z
---

Ao configurar um cliente S3-compatible pro Cloudflare R2 (qualquer projeto, não só [[project_deliveryhub]]), esperar confusão garantida nos seguintes pontos — levou 3 rodadas de erro pra fechar certo da primeira vez que apareceu:

**1. Duas telas diferentes de criação de token na Cloudflare, fácil pegar a errada:**
- "Account API Tokens" (Meu Perfil → API Tokens, ou tela de conta) — token genérico da API REST da Cloudflare. Se usado com um template tipo "Read all resources", dá permissão `Workers R2 Storage Read` **sem Write** — causa `AccessDenied` (403) em qualquer tentativa de upload, mesmo com credencial "válida" (autentica, mas não autoriza).
- "R2 → Manage R2 API Tokens" (dentro da própria seção R2 do dashboard) — é a única tela que oferece o preset certo: **"Leitura/gravação para objeto"** ("Object Read & Write"), escopado por bucket específico. É essa que serve.

**2. A tela de confirmação do token (aparece uma única vez) mostra 3 valores, só 2 servem pra S3:**
- **Token value** — prefixo `cfat_` (Account) ou `cfut_` (User), é o Bearer token da API REST da Cloudflare. **Não é credencial S3.**
- **Access Key ID** — string hex de 32 caracteres, sem prefixo.
- **Secret Access Key** — string hex de 64 caracteres, sem prefixo (é o hash SHA-256 do Token value, por isso parece "só mais uma string aleatória" e é fácil confundir com o Token value de cima).

Só os dois últimos (Access Key ID + Secret Access Key) vão no client S3 (`@aws-sdk/client-s3`, `region: 'auto'`, `forcePathStyle: true`, endpoint `https://<account_id>.r2.cloudflarestorage.com`).

**Why:** confirmado batendo o mesmo erro 3x segidas numa sessão real (ver [[project_deliveryhub]], seção "Upload de imagem de produto migrado pro R2", 2026-10-13) — primeiro pegou token da tela errada (Read-only), depois pegou o Token value em vez do Secret Access Key (2x), depois só o Secret sem o Access Key ID correspondente.
**How to apply:** ao configurar R2 em qualquer projeto, ir direto na seção R2 do dashboard (não na tela geral de API Tokens da conta) pra criar o token, e ao copiar da tela de confirmação, contar os caracteres antes de colar: 32 hex = Access Key ID, 64 hex = Secret Access Key, qualquer coisa com prefixo `cfat_`/`cfut_` não serve pra S3. Se der `AccessDenied` (403, não erro de assinatura) numa chamada S3 com credencial que parece certa, suspeitar de permissão Read-only no token antes de qualquer outra causa. Também vale checar `.env` por chave duplicada (dotenv: **a última declaração da mesma variável no arquivo vence**) antes de assumir que o valor novo está sendo lido.

**3. Custom Domain do bucket: nunca conectar no domínio raiz/apex se ele já serve outra coisa.** Conectar `pediuvai.com.br` (apex, já apontado pro app principal) como Custom Domain do bucket R2 mostrou "Active" no painel sem erro nenhum, mas o app (já dono daquele hostname) ganhou a disputa de rota — o bucket ficou conectado e inerte, sem servir nada, sem aviso visível. Só descobriu testando um objeto real (`curl` numa chave que existe de verdade no bucket) e vendo que voltava o HTML do app, não o arquivo. Corrigido usando um **subdomínio dedicado** (ex. `imag.pediuvai.com.br`) — sem conflito, porque nenhum outro serviço usa esse hostname. Não precisa remover a conexão do domínio raiz depois, R2 aceita múltiplos Custom Domains por bucket, o antigo só fica parado.

**4. Status "Inicializando" logo após conectar um Custom Domain novo pode dar `403 error code: 1014` ("CNAME Cross-User Banned") por 1-2 minutos** — é só o certificado TLS ainda sendo provisionado, não é erro de configuração. Esperar e testar de novo antes de desconfiar de DNS/token.

**Why (3 e 4):** mesma sessão, mesmo dia (2026-10-13) — painel mostrando "Active"/sem erro não é prova de que o roteamento funciona de verdade.
**How to apply:** ao conectar Custom Domain de bucket R2, usar sempre subdomínio dedicado (nunca apex já ocupado por outro serviço), e validar com um `curl` direto numa chave real do bucket antes de trocar a variável de URL pública em qualquer `.env`/config — status do painel sozinho não basta. Se bater `403`/`1014` logo após conectar, checar primeiro se o status ainda é "Inicializando" antes de qualquer outro diagnóstico.
