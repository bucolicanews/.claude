---
name: design-system-delivery
description: "Design system oficial para plataformas de delivery (referencia Rappi) - paleta, tipografia, componentes"
metadata: 
  node_type: memory
  type: project
  originSessionId: 3eaea5f7-78bd-486d-86dd-4fe0868eb5c2
---

Design system (`my_memory/26-DESIGNER/DESIGN SYSTEM OFICIAL(DELIVERY-RESTAURANTES).md`), referência visual Rappi, aplica-se a [[project_deliveryhub_white_label]].

Pontos chave:
- Stack de referência do doc: React 19 + Vite + Tailwind + TanStack Query + Zustand + RHF + Zod + Framer Motion + Lucide (projeto real usa Redux Toolkit em vez de Zustand/TanStack — divergência aceita, seguir o que já está implementado).
- Mobile first, breakpoints Tailwind padrão (sm640/md768/lg1024/xl1280/2xl1536).
- Paleta: primária `#FF441F` (CTAs), secundária `#FF7A00` (promoções), sucesso `#22C55E`, atenção `#F59E0B`, erro `#EF4444`, neutros de `#FFFFFF` a `#18181B`.
- Fonte Inter. Bordas: input rounded-xl, card rounded-2xl, modal rounded-3xl.
- Estrutura de pastas sugerida: /components/ui, /layout, /features, /pages, /hooks, /services, /store, /types.
- Metas de performance: Lighthouse >90, lazy loading, code splitting, WebP, virtualização de listas.
- Acessibilidade obrigatória: navegação por teclado, labels, contraste AA, focus visível, ARIA.

**Why:** referência de design formalizada pelo usuário para projetos de delivery — evita decisões visuais ad-hoc divergentes do padrão aprovado.

**How to apply:** ao criar/ajustar UI em deliveryhub_white_label, usar essa paleta/tipografia/espaçamento como padrão salvo indicação contrária do usuário.
