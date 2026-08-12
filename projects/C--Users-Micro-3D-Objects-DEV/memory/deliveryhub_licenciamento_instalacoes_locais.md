---
name: deliveryhub-licenciamento-instalacoes-locais
description: "Licenciamento de instalações standalone/individuais via serial — titular polimórfico, checkin periódico"
metadata: 
  node_type: memory
  type: project
  originSessionId: a3d059f5-e5a3-4f97-a884-e047f4bf4636
  modified: 2026-08-09T16:12:02.952Z
---

Segundo tipo de cliente além do SaaS multi-tenant: quem compra a instalação individual/local do deliveryhub (mesmo código, banco Supabase próprio e separado — não é uma linha em `restaurants`). Admin central gera um serial (`DHUB-XXXX-XXXX-XXXX`) em `/admin/planos` → aba "Instalações Locais", cliente cola em `LICENCA_SERIAL` no `.env` da instalação dele.

**Arquitetura:** `assinaturas`/`plano_faturas` generalizadas pra titular polimórfico — `restaurant_id` OU `instalacao_id`, nunca os dois (CHECK constraint). Reaproveita inteiro o motor de cobrança do [[deliveryhub-planos-assinatura-pagbank]] (`Titular` type em `planos.service.ts`) em vez de duplicar lógica. Instalação local não tem `orders` na tabela central, então fatura sempre no valor cheio do plano (sem isenção por piso de faturamento).

**Checkin:** instalação local roda `server_delivery/src/licenca/licenca.service.ts` — só ativa com `LICENCA_SERIAL` setado, consulta `POST /instalacoes/checkin` (endpoint central sem guard, serial é a credencial) a cada `LICENCA_CHECKIN_INTERVALO_MIN` (padrão 5min, era 6h). Endpoint `POST /licenca/checkin-agora` força verificação na hora — usado depois que admin troca plano/revoga.

**Gotcha corrigido:** serial revogado (`ativo: false`) devolvia 404, e o cliente local tratava isso igual "sem internet" (mantinha status antigo, não bloqueava). Agora revogação responde 200 com `{bloqueado:true, revogado:true}` — só serial que nunca existiu é erro de verdade.

**Why:** usuário quer "controle" real sobre instalações locais — troca de plano ou revogação no admin precisa refletir rápido na instalação do cliente, não só documentação/cobrança manual.

**How to apply:** ao mexer em `instalacoes.service.ts`/`licenca.service.ts`, lembrar que são dois lados do mesmo fluxo rodando em processos/bancos diferentes — teste sempre reiniciando o backend da instalação local pra pegar mudança de env var.

Status: testado com 1 instalação real (serial `DHUB-C86F-43FF-D239`, cliente "teste") — checkin confirmado funcionando (`ultimo_check_em` atualiza). Commits: feature original (`feat/licenciamento-instalacoes-locais`) já MERGEADO+PUSHADO+migration Cloud. Fix de revogação/intervalo (`fix/licenca-checkin-revogacao-intervalo`, submodule) MERGEADO EM MAIN + PUSHADO (2026-08-09).

Pendente: admin ainda não criou nenhum plano `tipo=local` de verdade além do de teste — sem isso o select de "Instalações Locais" fica vazio (não é bug).
