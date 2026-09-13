---
name: feedback-migration-order
description: "Supabase migrations: always apply to local dev DB first (npx supabase migration up), only then to production (--linked) — never the reverse"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 8d09f23b-e3a5-46d5-805e-025eb4acef26
  modified: 2026-09-07T00:13:16.676Z
---

Sequência obrigatória pra migration nova do Supabase neste projeto (`deliveryhub_white_label`): **local primeiro, produção depois**.

1. `npx supabase migration up` (sem `--linked`, a partir de `deliveryhub_white_label/` onde fica `supabase/config.toml`) — aplica no banco local.
2. Só depois, `npx supabase db push --linked` — aplica no projeto de produção linkado (`delivery_jota`, ver [[project_deliveryhub]]).

**Why:** numa sessão (2026-08-28, feature de módulo GDOOR comprável), apliquei direto em produção (`--linked`) primeiro, sem tocar no banco local. O backend local do usuário (rodando contra `127.0.0.1:54331`, Supabase local) ficou sem a coluna nova (`planos.inclui_gdoor`) e quebrou em runtime com `PGRST204 — Could not find the 'inclui_gdoor' column ... in the schema cache` assim que o usuário tentou editar um plano pela tela. Usuário corrigiu a ordem explicitamente: local primeiro, sincronizar depois.

**How to apply:** toda vez que uma migration nova for criada e for hora de aplicá-la, rodar `migration up` local ANTES de perguntar/confirmar o `db push --linked` de produção — não pular a etapa local achando que só produção importa. Isso vale mesmo quando o pedido do usuário for só "sincroniza e sobe pra produção" — local faz parte do "sincroniza".

**Gotcha descoberto de novo (2026-09-06, sessão da feature de pagamento/troco-gorjeta):** `npx supabase db push` **sem nenhuma flag** não é neutro — se o projeto já está `link`ado (é o caso deste repo), ele aplica direto no projeto remoto de produção, igual `--linked`. A saída do comando ("Connecting to remote database...") é a única pista, fácil de não perceber no meio de outros comandos. `npx supabase status` mostrar URLs `127.0.0.1` não significa nada sobre pra onde o `db push` vai — são comandos independentes. **Comando certo pra aplicar só local é `npx supabase db push --local`** (equivalente ao `migration up` do passo 1) — nunca rodar `db push` sem flag alguma achando que é "modo padrão/seguro". Aconteceu de eu rodar sem flag por engano e aplicar em produção antes do local nessa sessão — migration era aditiva/inofensiva (`ADD COLUMN IF NOT EXISTS`), sem dano real, mas quebrou a ordem. Avisei o usuário na hora, ele seguiu em frente mesmo assim.
