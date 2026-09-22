---
name: feedback-homologacao-pasta
description: "Arquivos de homologação (PagBank, GDOOR, etc — logs/evidências/textos de chamado) sempre vão em c:\\Users\\jotac\\OneDrive\\Documents\\DEV\\HOMOLOGACAO, não no scratchpad temporário"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 11f15783-9250-42cd-a460-373cf1a11360
  modified: 2026-09-14T21:48:27.932Z
---

Qualquer arquivo relacionado a homologação com terceiros (logs de teste, evidências de request/response, texto de e-mail/chamado) deve ser salvo em `C:\Users\jotac\OneDrive\Documents\DEV\HOMOLOGACAO`, não só no diretório de scratchpad temporário da sessão.

**Why:** usuário pediu explicitamente (2026-09-14) depois que os primeiros arquivos de homologação PagBank (chamado 1432665524) foram gerados só no scratchpad — ele quer um lugar fixo e permanente pra achar esses arquivos depois, já que scratchpad é limpo/efêmero por sessão.

**How to apply:** ao gerar qualquer arquivo de homologação (log de teste real, texto de resposta pra suporte de gateway de pagamento/integração, etc), escrever direto em `HOMOLOGACAO/` (criar a pasta se não existir) em vez de só no scratchpad — ou gerar no scratchpad e copiar pra lá antes de considerar a tarefa concluída. Ver [[project_deliveryhub]] para contexto do caso PagBank que originou isso.
