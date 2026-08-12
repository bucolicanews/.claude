---
name: deliveryhub-admin-header-e-status-dot
description: AdminHeader compartilhado (hambúrguer mobile) + bolinha de status do plano no header do restaurante
metadata: 
  node_type: memory
  type: project
  originSessionId: a3d059f5-e5a3-4f97-a884-e047f4bf4636
  modified: 2026-08-09T16:11:56.619Z
---

Painel `/admin/*` tinha nav duplicado (levemente divergente) em cada uma das 9 páginas, sem colapsar em mobile — usuário reportou "barra bagunçada" e "movimentação lateral indesejada". Criado `src/components/admin/AdminHeader.jsx` + `AdminMobileMenu.jsx` + `src/config/adminNavLinks.js` (lista única), mesmo padrão hambúrguer já usado em `RestauranteHeader`/`MobileMenu` de `/restaurante/*`. Todas as 9 páginas trocadas pra usar `<AdminHeader active title subtitle />`.

**Gotcha:** primeira versão usava breakpoint `md` sem `flex-wrap` na nav desktop — estourava lateral em telas médias (nem mobile nem larga o suficiente pros 8 botões). Fix: breakpoint subiu pra `lg` + `flex-wrap` de volta.

Também adicionado: bolinha verde/laranja/vermelha no `RestauranteHeader` (barra do dono da loja) refletindo `planoStatus` do `AuthContext` (já existia, usado pelo `RestauranteGuard` — só faltava indicador visual). Verde = em dia, laranja = vencendo em ≤5 dias ou vencida dentro da tolerância, vermelho = bloqueado. Clica e vai pra `/restaurante/plano`.

**Why:** consistência de UX mobile entre `/admin/*` e `/restaurante/*`, que já tinha o padrão certo.

**Gotcha 2 (2026-08-09):** header tinha `flex-wrap` no container pai junto com `truncate` no título/subtítulo — combinação quebrada: `truncate` usa `white-space:nowrap`, então o tamanho intrínseco (flex-basis) do bloco de texto é a linha inteira sem quebra, bem maior que o espaço disponível. O algoritmo de wrap do flexbox decide quebra de linha pelo tamanho intrínseco (não pelo tamanho já encolhido por `flex-shrink`), então empurrava hambúrguer+toggle de tema pra linha de baixo no mobile sempre que o subtítulo era longo. Fix: removido `flex-wrap` do header, div do título ganhou `flex-1 min-w-0` (agora encolhe de verdade), subtítulo trocou `truncate` fixo por `sm:truncate` (quebra em 2 linhas no mobile, trunca com reticências só a partir de `sm`).

Status: MERGEADO EM MAIN + PUSHADO (2026-08-09), testado visualmente pelo usuário (mobile real, ambos os gotchas). Ícones ficam fixos na mesma linha do título em qualquer tela.
