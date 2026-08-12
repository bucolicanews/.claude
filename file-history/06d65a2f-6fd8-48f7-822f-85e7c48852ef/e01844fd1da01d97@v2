---
name: deliveryhub-agente-impressao-local
description: "IMPLEMENTADO E MERGEADO EM MAIN — app local (Python) que o dono do restaurante instala/roda no PC, detecta impressoras e recebe comandos de impressão do backend"
metadata: 
  node_type: memory
  type: project
  originSessionId: 61bd9ff7-dd86-42e2-98a3-bd0208787756
  modified: 2026-07-23T15:12:54.258Z
---

**Atualizado 2026-07-23:** branch `feature/agente-impressao-local` mergeada em `main` nos dois repos (backend merge commit `60ade3f`, frontend merge commit `148fc50`). Não é mais "aguardando teste" — já em produção do fluxo normal.

Pedido do usuário em 2026-07-14, marcado como "super importante": criar um **agente/servidor local** (Python), que o usuário-restaurante baixa e roda no computador do estabelecimento. Objetivo: detectar as impressoras disponíveis (instaladas no PC ou na rede local) e disponibilizá-las pra nossa aplicação (deliveryhub), de forma que quando o sistema precisar imprimir uma comanda (ver [[deliveryhub_modulo_restaurante_ideias]], ideia 11/12 — impressão por setor cozinha/bar/salgados), ele saiba exatamente **qual impressora física** deve receber aquele ticket.

**Why:** hoje (módulo Salão, já implementado) a "impressora" cadastrada em `/restaurante/impressoras` é só metadado (nome/setor/endereço) — a impressão real acontece via `window.print()` numa iframe escondida no navegador de quem está com a tela aberta (`printComanda.js`/`printTicketSetor`), dependendo da impressora padrão do SO daquele PC/aba. Isso não escala pro cenário real: cozinha e bar são impressoras físicas diferentes, muitas vezes em outra máquina da rede, e a comanda pode ser gerada por qualquer garçom em qualquer celular — o navegador do celular do garçom não tem acesso físico à impressora térmica da cozinha.

**How to apply:** este é um subsistema novo e separado dos dois repos existentes (frontend React + backend NestJS) — é um app standalone em Python que roda localmente na rede do restaurante. Antes de implementar, um plano de arquitetura precisa cobrir pelo menos:
- Detecção de impressoras (locais via SO — Windows/CUPS — e possivelmente impressoras de rede).
- Como o agente local se comunica com o backend Nest na nuvem sem IP público (provável: conexão persistente iniciada pelo agente — WebSocket ou polling — já que o restaurante não expõe porta).
- Pareamento/autenticação: o agente precisa saber a qual `restaurant_id` pertence (token de pareamento, similar ao `cozinha_token` já existente).
- Formato do trabalho de impressão enviado (texto simples vs ESC/POS pra impressora térmica).
- Fallback: o que acontece se o agente estiver offline (comanda não sai impressa em lugar nenhum) — precisa de alguma sinalização de "impressora offline" na tela do garçom/caixa.
- Distribuição: como o usuário instala (executável empacotado via PyInstaller? instalador?).

Ver também [[deliveryhub_modulo_restaurante_ideias]] (ideias 11/12, origem do requisito de impressão por setor) e [[project_deliveryhub_white_label]].

**Status em 2026-07-14: implementado e testado, aguardando o usuário testar antes do merge.**

Branch `feature/agente-impressao-local` nos dois repos (frontend `deliveryhub_white_label` e backend `server_delivery`, commits até `4124402`/backend correspondente) — **mergeada em main em 2026-07-23** (ver atualização no topo do arquivo).

O que existe:
- Migrations: `restaurants.agente_impressao_token`/`agente_impressao_ultimo_ping`, `impressoras.nome_sistema`, tabelas `impressoras_detectadas` e `impressao_jobs`.
- Backend: `AgenteImpressaoGuard` (header `x-agente-token`, mesmo padrão do `cozinha_token`), módulo `agente-impressao` (gerar token, status, reportar impressoras, jobs pendentes/concluído/erro). `SalaoService.enviarItens` gera `impressao_jobs` só pra impressoras com `nome_sistema` mapeado — as sem agente continuam no fallback `window.print()` do navegador.
- App Python em `print-agent/` (raiz do repo frontend): `agent.py` (CLI), `gui.py` (janela Tkinter simples pro usuário colar o token), `printers.py` (detecção via `win32print` no Windows / `lpstat`+`lp` no Linux-Mac), `backend_client.py` (chamadas HTTP), polling de 3s. Testado de verdade nesta sessão: detectou impressoras reais da máquina do dev (achou até uma térmica "POS-80" instalada), puxou um job de teste e imprimiu em "Microsoft Print to PDF", marcou concluído no banco.
- Frontend `/restaurante/impressoras`: painel com botão "gerar token de pareamento" + indicador online/offline (baseado em `agente_impressao_ultimo_ping` recente), e o campo de endereço da impressora virou um select das impressoras detectadas pelo agente (fallback pra texto livre se nenhum agente conectado ainda).

**Fora do escopo desta rodada (decisão consciente, ver plano):** empacotamento em `.exe` (PyInstaller) — por enquanto roda via `python agent.py`/`gui.py` com Python instalado. Formatação ESC/POS avançada (negrito, corte automático) — v1 manda só texto puro.

**How to apply:** já em produção — se pedirem melhoria (empacotamento .exe, ESC/POS avançado), tratar como extensão do que já existe, não como feature nova do zero.
