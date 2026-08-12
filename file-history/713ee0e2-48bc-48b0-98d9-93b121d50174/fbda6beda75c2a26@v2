---
name: feedback-backend-restart-apos-pull
description: "git pull não recarrega processo Node rodando — sempre lembrar restart/rebuild ao investigar campo novo \"sumido\" ou contador zerado"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 713ee0e2-48bc-48b0-98d9-93b121d50174
---

Depois de sincronizar backend (`git pull origin main --ff-only` no `server_delivery`, submodule ou standalone), o processo Node que já está rodando NÃO recarrega sozinho o código novo — `git pull` só atualiza os arquivos no disco.

**Why:** aconteceu durante o trabalho no filtro Delivery/Salão dos painéis KDS (ver [[deliveryhub_modulo_restaurante_ideias]] ideia 29) — editei/commitei/pushei/sincronizei o campo `tipo` no `getKdsSetor`, tudo certo no disco, mas o usuário via contagem 0/0/0 na tela porque o backend que ele tinha iniciado antes continuava rodando o código antigo em memória.

**How to apply:** sempre que um campo novo do backend aparecer ausente/zerado/undefined no frontend logo depois de um merge+sync, a primeira suspeita (antes de procurar bug de lógica) deve ser: "o processo já estava rodando antes desse pull?". Perguntar ao usuário se reiniciou, e lembrar a diferença:
- `npm run start:dev` / `nest start --watch` → recompila sozinho ao salvar, deveria refletir na hora.
- `npm start` / `nest start` (sem watch) → precisa reiniciar o comando manualmente.
- `npm run start:prod` (`node dist/main`) → usa build antigo, precisa `npm run build` antes de reiniciar.
Não reiniciar o servidor proativamente (ver [[feedback_usuario_roda_servers]] — quem controla isso é o usuário), só apontar a causa e perguntar qual comando ele usa.
