---
name: feedback-deploy-cache-navegador
description: "após deploy no EasyPanel com build sucesso, tela não muda por cache do navegador — hard refresh resolve antes de suspeitar de bug"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: b916cb27-3349-4e47-96d2-e6cf5c20339d
  modified: 2026-07-23T19:48:57.560Z
---

Quando o deploy (EasyPanel) terminar com sucesso mas a tela do frontend continuar com visual/comportamento antigo, suspeitar primeiro de **cache do navegador**, não de falha no deploy.

**Why:** confirmado 2026-07-23 — deploy da venda balcão buildou certo, só não aparecia até o usuário dar hard refresh (Ctrl+Shift+R) / aba anônima.

**How to apply:** antes de investigar hash de commit no EasyPanel, proxy/CDN cache etc., pedir pro usuário testar hard refresh ou aba anônima primeiro — resolve a maioria dos casos e evita investigação desnecessária.
