---
name: deliveryhub_fix_fuso_horario_impressao
description: "Backend server_delivery imprimia hora em UTC (new Date().toLocaleString sem timeZone), 3h à frente da hora local — corrigido pra America/Sao_Paulo"
metadata: 
  node_type: memory
  type: project
  originSessionId: d4d5a3c9-4437-4241-83cd-b23d777d16a9
  modified: 2026-07-27T22:05:11.257Z
---

Bug: comandas/recibos/tickets impressos pela impressora térmica (via agente de impressão) mostravam hora ~3h adiantada (ex: 20:41 impresso vs 17:44 real).

Causa: `server_delivery/src/salao/salao.service.ts` (linhas ~805, 855, 948) e `agente-impressao.service.ts` (linha 89) usavam `new Date().toLocaleString('pt-BR')` sem `timeZone` — esse código roda no backend Node (servidor/VPS em UTC), não no navegador do usuário. Diferente do frontend (`printComanda.js`), que roda no navegador e já pega o fuso local certo.

Fix: adicionado `{ timeZone: 'America/Sao_Paulo' }` nas 4 chamadas. Mesmo padrão já usado antes em `Garcom.jsx` (ver [[deliveryhub_relatorio_garcom_detalhado]]).

**Gotcha pra lembrar**: se aparecer bug de "hora errada" de novo, checar se é `new Date()` rodando no browser (frontend, `src/`) — geralmente correto — ou no backend (`server_delivery/src/`) — precisa `timeZone` explícito sempre, pois servidor roda em UTC.

MERGEADO EM MAIN (server_delivery + repo raiz) + PUSHADO, deploy EasyPanel disparado. Não confirmado em produção ainda.
