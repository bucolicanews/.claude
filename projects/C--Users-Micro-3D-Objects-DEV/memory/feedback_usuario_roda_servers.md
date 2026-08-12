---
name: feedback-usuario-roda-servers
description: "usuário prefere rodar os servers (backend/frontend) manualmente ele mesmo, não eu iniciar"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 61bd9ff7-dd86-42e2-98a3-bd0208787756
---

Em 2026-07-14, depois de várias vezes eu subir/derrubar backend (`server_delivery`, porta 3002) e frontend (Vite, porta 4028) pra verificar mudanças, o usuário pediu explicitamente: "para todos os server que estão rodando eu rodo manualmente".

**Why:** o usuário quer controlar quando e qual server sobe (tem múltiplos clones de `server_delivery` — ver [[deliveryhub_dois_clones_server_delivery]] — e trocar de branch pra testar), e prefere fazer isso ele mesmo em vez de eu gerenciar os processos.

**How to apply:** não iniciar `npm run dev`/`npm run start:dev` proativamente pra "testar" depois de mudanças — verificação de sintaxe via `tsc --noEmit` (backend) e checagem de transform do Vite via curl continuam ok quando já existe um server rodando, mas evitar subir novos processos de servidor sem pedir primeiro. Se precisar mesmo rodar pra validar algo, perguntar antes. Sempre que eu subir algum a pedido, derrubar no final também (isso já era prática, manter).
