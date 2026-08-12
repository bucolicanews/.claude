---
name: deliveryhub-pendencia-api-url-producao
description: "RESOLVIDO — frontend agora usa VITE_API_URL configurável via src/lib/apiUrl.js em vez de /api fixo"
metadata: 
  node_type: memory
  type: project
  originSessionId: 3fe4b1f0-07c7-4d4c-a1eb-375df490dc6f
  modified: 2026-07-23T15:11:51.380Z
---

Pendência identificada em 2026-07-10 (backend separado quebraria em produção com `/api` fixo) — **resolvida**, verificado em 2026-07-23.

Solução implementada: `src/lib/apiUrl.js` exporta `API_URL` (de `import.meta.env.VITE_API_URL`, vazio em dev = usa proxy do Vite) e `apiPath(path)` que remove o prefixo `/api` do path quando `API_URL` está setado (backend não usa prefixo `/api` nas rotas reais). Ver também [[deliveryhub_config_local_lan_vs_vps]] pra uso de `VITE_API_URL` no cenário LAN.

**How to apply:** qualquer serviço novo que monte URL de API deve usar `apiPath()`/`API_URL` de `src/lib/apiUrl.js`, nunca hardcode `/api/...` de novo.
