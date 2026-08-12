---
name: deliveryhub-config-local-lan-vs-vps
description: "qual clone/config do server_delivery serve pra LAN local vs VPS produção, e o gotcha de VITE_API_URL=localhost quebrando acesso de celular"
metadata: 
  node_type: memory
  type: project
  originSessionId: a1681614-dd0b-4169-8fc6-818c831e6b78
---

Papel de cada clone do backend, confirmado 2026-07-16 pelo usuário (ver [[deliveryhub_dois_clones_server_delivery]]):

- `deliveryhub_white_label\server_delivery` (submodule, dev) — configurado pra **rede local (LAN)**. Backend NestJS já escuta `0.0.0.0:3002` com CORS aberto por padrão (`app.enableCors()` sem opções em `src/main.ts`), então não precisou mudar código, só o `.env` do **frontend**.
- `DEV\server_delivery` (standalone) — **só VPS**, mantido do jeito que já está. Não mexer na config desse clone pra LAN nunca, mesmo que pareça a mesma tarefa.

**Gotcha crítico:** `VITE_API_URL=http://localhost:3002` no `.env` do frontend funciona só no próprio PC — o valor é injetado no bundle JS servido pelo Vite dev e é o MESMO texto pra qualquer cliente (PC ou celular). Um celular na rede abrindo `http://192.168.1.31:4028` recebe esse mesmo `localhost:3002` no JS, e "localhost" no celular aponta pra ele mesmo — a chamada de API falha silenciosamente. Fix: usar o IP de rede do PC (`http://192.168.1.31:3002`) em vez de `localhost`.

Variáveis relevantes no `.env` do frontend (`deliveryhub_white_label/.env`):
- `VITE_API_URL=http://192.168.1.31:3002` — backend local acessível da rede.
- `VITE_LAN_URL=http://192.168.1.31:4028` — usado só pelo QR/link de acompanhamento do cliente (`src/utils/mesaAcompanharUrl.js`) pra gerar a variante de rede local do link, além da variante `window.location.origin` normal. Só entra em jogo quando `window.location.hostname` é `localhost`/`127.0.0.1` (ou seja, nunca em produção).

**Why:** usuário roda o restaurante com celular do cliente na mesma rede WiFi pra escanear o QR de acompanhamento (`mesa-acompanhar`) direto do PC de desenvolvimento, sem precisar deployar pra testar esse fluxo.

**How to apply:** se o IP de rede local mudar (DHCP, troca de roteador), atualizar `VITE_API_URL` e `VITE_LAN_URL` no `.env` do frontend pro novo IP. Nunca propagar esse tipo de config LAN pro clone standalone (VPS) — são propósitos diferentes por design.
