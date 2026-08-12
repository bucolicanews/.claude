---
name: feedback-migration-precisa-push-cloud-apos-deploy
description: Deploy do backend não aplica migration na Supabase Cloud sozinho — checar supabase migration list --linked sempre que uma feature nova quebrar só em produção
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 31cc1ec5-40ca-45dd-ab92-f454ec7203d9
  modified: 2026-07-30T17:54:47.202Z
---

Incidente 2026-07-30: deploy de [[deliveryhub_sessao_unica_garcom_motoboy]] e [[deliveryhub_decrementar_estoque_venda]] foi feito (EasyPanel rebuildou o backend com o código novo), mas as migrations `20260730000001`/`20260730000002` nunca tinham sido rodadas na Supabase Cloud — só existiam local. Resultado: lista de garçons parou de carregar em produção (`garcons.service.ts listar()` já selecionava colunas `active_session_id`/`session_expires_at` que não existiam na Cloud), mesmo com teste local passando 100%.

**Por quê:** EasyPanel só faz deploy do código (build+restart do container). Migration é responsabilidade separada — só é aplicada quando alguém roda `supabase db push --linked` manualmente. Ver [[feedback_banco_local_nunca_mudar_cloud]] — dev sempre local, só esse comando específico mexe na Cloud (schema, não dado).

**Fix:** `npx supabase migration list --linked` mostra quais migrations têm `remote` vazio (não aplicadas); `npx supabase db push --linked` aplica as pendentes.

**How to apply:** sempre que uma feature envolver migration nova E o usuário disser "fiz o deploy", perguntar/checar se rodou `db push --linked` também — deploy de código e deploy de schema são dois passos separados nesse projeto. Se algo funciona local mas quebra só em produção logo após um deploy com migration nova, suspeitar disso primeiro antes de procurar bug no código.
