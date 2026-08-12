---
name: deliveryhub-menu-lateral-cache-ordenado
description: "Menu lateral do painel restaurante: fix do 'piscar' (itens aparecendo aos poucos) + ordem alfabética com Dashboard fixo no topo — MERGEADO+PUSHADO+DEPLOY CONFIRMADO"
metadata: 
  node_type: memory
  type: project
  originSessionId: 078ad696-7b05-45b5-88a0-d9961bf703d9
  modified: 2026-08-10T16:18:41.352Z
---

Usuário reportou: ao abrir o menu lateral do painel (`/restaurante/*`), a lista de favoritos e os links do menu demoravam pra aparecer — surgiam em ondas (alguns primeiro, resto depois) e fora de ordem. Pediu "Redis" como solução, mas causa real era outra.

**Causa raiz encontrada**: `RestauranteHeader.jsx` usava 3 hooks separados (`useModulosEmpresa`, `useMinhaLojaSlug`, `useMinhaLojaLogo`) — cada um fazia sua própria chamada a `getMinhaEmpresa()` (`GET /restaurante/minha-empresa`), sem dedupe. As 3 chamadas resolviam em instantes ligeiramente diferentes, causando o efeito de itens "pipocando" aos poucos. Ordem dos links também não era alfabética (array manual fixo em `restauranteNavLinks.js`).

**Fix aplicado**:
1. `src/hooks/useMinhaEmpresaData.js` (novo) — hook compartilhado com dedupe de chamada em voo + cache em memória (TTL 15s). `useModulosEmpresa`, `useMinhaLojaSlug`, `useMinhaLojaLogo` viraram wrappers finos dele, mesma API pública (nenhum call-site fora do header precisou mudar — `garcom-portal`, `restaurante-cardapio-digital`, `RelatorioNav`, `restaurante-salao` continuam iguais).
2. Backend (`server_delivery/src/restaurante/restaurante.service.ts`): cache Redis cache-aside na query `minhaEmpresa()` (chave `restaurante:minha-empresa:${userId}`, TTL 15s, sem invalidação manual — mesmo trade-off já aceito no cache do catálogo, ver [[deliveryhub_redis_cache_catalogo]]). `RedisModule` é `@Global()`, só injetar `RedisService` no construtor.
3. `src/config/restauranteNavLinks.js`: `getRestauranteNavLinks()` agora ordena por `label.localeCompare(..., 'pt-BR')`. Depois de testar em produção, usuário pediu um ajuste extra: Dashboard fixo no topo, fora da ordenação (resto continua alfabético).
4. Loja/Sair no rodapé do menu (`RestauranteSidebar.jsx`/`MobileMenu.jsx`) mantidos como estavam — já ficam num footer fixo fora da área de scroll, não precisou mudar nada aí.
5. Extra fora de escopo, pedido na mesma sessão: `autocomplete="current-password"` no campo de senha do login (`LoginForm.jsx`) — sumia o aviso de acessibilidade do DevTools, sem relação com segurança real (valor no DOM só visível no próprio navegador do usuário).

**Status**: branch `feat/menu-lateral-cache-ordenado` (frontend + submodule backend) → mergeada e pushada em `main` nos dois, standalone (`DEV/server_delivery`) sincronizado via `git pull`. Deploy EasyPanel disparado automático pelo push em main, **confirmado pelo usuário que ficou perfeito** depois do ajuste do Dashboard.

**Gotcha da sessão**: depois de `git checkout <branch>`, rodar `git checkout main -- .` por engano apaga qualquer edição não commitada daquele branch (sobrescreve com a versão de `main`). Aconteceu aqui e precisei refazer o fix do Dashboard. Cuidado ao combinar troca de branch com checkout de path na mesma sequência de comandos.

Ver [[deliveryhub_dois_clones_server_delivery]] pro fluxo de sincronizar o standalone, [[feedback_trigger_suba_para_deploy]] pro que a frase "sobe pra deploy" cobre (só push de branch feature, merge em main é passo separado que sempre pede confirmação).
