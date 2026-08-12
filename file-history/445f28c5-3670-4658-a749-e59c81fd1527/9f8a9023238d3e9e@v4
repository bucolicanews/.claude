---
name: deliveryhub-alerta-visual-pedido-pronto
description: "Alerta visual de item pronto no portal do garçom vira faixa fixa no topo com Mesa+Cliente+Pedido — commitado, não mergeado"
metadata: 
  node_type: memory
  type: project
  originSessionId: 445f28c5-3670-4658-a749-e59c81fd1527
  modified: 2026-07-26T01:42:42.346Z
---

Alerta de "pedido pronto pra buscar" no portal do garçom (`/garcom/:loginKey`, aba Salão) era um toast pequeno no rodapé (`avisoPronto`, bottom-2, texto curto). Virou modal centralizado (backdrop preto/60%, card branco, ícone `BellRing` pulsando, texto "Seu pedido está pronto! Mesa: X · Cliente: Y · Pedido: Z") com botão "OK, entendi" — só fecha no clique do garçom, sem auto-dismiss por timeout (mesmo componente reusado pro aviso de conferência solicitada pelo cliente).

**Implementado, commitado e pushado em 2026-07-26 (branch `feat/alerta-visual-pedido-pronto` em ambos repos, testado local e validado pelo usuário "perfeito"):**
- Backend (`server_delivery`, commit `e60e512`): `SalaoService.itensProntos()` (`src/salao/salao.service.ts`) seleciona `cliente_mesa_nome` da comanda e retorna campo `cliente` no item.
- Frontend (`deliveryhub_white_label`): commit `ef979a5` trocou toast rodapé por faixa fixa no topo; commit `68bcc8c` (final) trocou a faixa por modal central com botão de fechar e removeu os `setTimeout` de auto-dismiss (tanto do aviso de item pronto quanto do aviso de conferência, que compartilham o mesmo state `avisoPronto`).

Validado com `tsc --noEmit` (backend) e `vite build` (frontend), ambos limpos, e testado localmente pelo usuário.

**Why:** toast pequeno no rodapé passava despercebido no salão; garçom precisa ver claramente e confirmar que viu (clique), com detalhe de mesa/cliente pra não confundir comandas.

**Mergeado em main e pushado em 2026-07-26:** backend `ecb86d7`, frontend `077249b` (ponteiro submodule já atualizado). Clone standalone (`DEV/server_delivery`) sincronizado via `git pull` (fast-forward `b618487..ecb86d7`).

**How to apply:** merge em main + push feito, mas deploy real no EasyPanel é ação do usuário, não confirmada ainda.
