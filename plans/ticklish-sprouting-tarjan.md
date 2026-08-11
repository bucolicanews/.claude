# Layout compartilhado + favoritos na topbar (área restaurante)

## Contexto

Pedido original: telas favoritas — usuário marca uma página, e um botão de atalho pra ela aparece na barra superior (topbar), só desktop.

Investigação (`src/pages/restaurante-*/index.jsx`) achou que não existe layout compartilhado hoje: `<header>` + `RestauranteSidebar` + `MobileMenu` + a lista de links do menu estão duplicados em 17 dos 22 arquivos `restaurante-*`. Pior: a lista de links **diverge** entre arquivos — 7 variantes diferentes, algumas faltando Combos, Financeiro, Caixa, Sessão, Cozinha ou Motoboys (bug de inconsistência já existente). 10 desses 17 arquivos já isolaram o bloco num componente local `NavRestaurante` (copiado e colado igual em cada arquivo, não importado de lugar nenhum) — sinal de que a extração pra um componente compartilhado já era necessária antes mesmo dos favoritos.

Decisão confirmada com o usuário: ao centralizar, unificar pra lista completa de links em todas as páginas (corrige a divergência, não preserva os subconjuntos incompletos de hoje).

Páginas **fora de escopo** (não usam header/sidebar/menu hoje — telas de estação tipo KDS/cozinha/bar, ficam como estão): `restaurante-caixa`, `restaurante-kds-setor`, `restaurante-producao`, `restaurante-catalogo`, `restaurante-bar`, `restaurante-cozinha`.

## Passo 1 — Registry central de links

Novo arquivo `src/config/restauranteNavLinks.js`. Exporta uma função `getRestauranteNavLinks(tipoRestaurante)` que retorna o array completo `{ label, path, icon }` (união de todas as variantes achadas: Dashboard, Relatórios, Delivery, Cozinha, Produtos, Combos, Pedidos, Entregas, Motoboys, Clientes, Financeiro, Caixa, Designer, Cardápio Digital, Config, Sessão), inserindo condicionalmente quando `tipoRestaurante` truthy: Produção, Bar (grupo "copa") e Salão, Garçons, Impressoras (grupo "salão"). `icon` usa nomes do `lucide-react` já suportados por `src/components/AppIcon.jsx`.

## Passo 2 — Persistência de favoritos

Novo hook `src/hooks/useRestauranteFavoritos.js`, seguindo o padrão já usado em `src/utils/multiCart.js` (helper simples de localStorage, sem Zustand/Redux — essas libs estão no `package.json` mas não são usadas em lugar nenhum do projeto).

- Chave: `favoritos_restaurante_${user.id}` (via `useAuth()` de `src/contexts/AuthContext.jsx`) — namespaced por usuário, não vaza entre contas.
- Expõe `{ favoritos, toggleFavorito(path), isFavorito(path) }`.

## Passo 3 — Componente de header compartilhado

Novo arquivo `src/components/restaurante/RestauranteHeader.jsx`, absorvendo o padrão `NavRestaurante` (já quase idêntico em 10 arquivos, ver `src/pages/restaurante-salao/index.jsx:28-94` como referência) e o bloco de header inline dos outros 7.

Props: `{ active, title, subtitle }`.

Renderiza:
- `<header>` com logo/título (+ subtítulo quando passado, usado pelo dashboard).
- Barra de favoritos — `hidden md:flex`, só renderiza se `favoritos.length > 0`, botões-pílula com o label de cada favorito (via `getRestauranteNavLinks` pra resolver label/path), destaca o ativo, fica entre o título e o botão "Menu".
- Botão "Menu" desktop (abre `RestauranteSidebar`) e hambúrguer mobile (abre `MobileMenu`) — mantidos como estão.
- `MobileMenu` e `RestauranteSidebar` (componentes existentes, reusados sem mudança de contrato externo) recebendo `links` de `getRestauranteNavLinks(tipoRestaurante)`.

## Passo 4 — Toggle de favorito na sidebar

Editar `src/components/restaurante/RestauranteSidebar.jsx`: adicionar botão de estrela ao lado de cada item de link, chamando `toggleFavorito(l.path)`, preenchida quando `isFavorito(l.path)`. Como esse componente já é `hidden md:block` (desktop-only), o toggle fica desktop-only automaticamente — sem tocar em `MobileMenu.jsx`, cumprindo o pedido "só pra pc".

## Passo 5 — Migração das 17 páginas

Em cada uma das 17 páginas `restaurante-*` em escopo:
- Remover o `<header>...</header>` inline (ou o componente local `NavRestaurante`, nos 10 arquivos que já o têm) e a definição local de `links`/`LINKS`/`COPA_LINK`/`SALAO_LINKS`.
- Substituir pela chamada `<RestauranteHeader active="/restaurante/xxx" title="Xxx" />`.
- Manter `RestauranteSidebar`/`MobileMenu` fora da página (agora internos ao `RestauranteHeader`) — remover imports não usados.

Arquivos representativos de cada padrão (os outros seguem o mesmo molde):
- Padrão "já extraído" (`NavRestaurante` local): `src/pages/restaurante-salao/index.jsx`, `restaurante-config/index.jsx`, `restaurante-sessao/index.jsx`, + 7 outros (delivery, motoboys, entregas, cardapio-digital, aparencia, impressoras, garcons).
- Padrão "header inline": `src/pages/restaurante-dashboard/index.jsx:346-384`, `restaurante-produtos/index.jsx:256-289`, + 5 outros (pedidos, combos, clientes, financeiro, relatorios).

## Verificação

- `npm run build` — garante que a remoção dos 17 blocos duplicados e imports não quebrou nada em tempo de compilação.
- Rodar o app manualmente (usuário sobe o servidor — não subir proativamente) e conferir por página migrada: header renderiza, hambúrguer mobile e botão Menu desktop abrem os menus certos, link ativo destacado continua correto.
- Marcar 2-3 favoritos pela estrela na sidebar (desktop), confirmar que aparecem na barra de favoritos no header.
- Redimensionar pra mobile (`md` breakpoint) e confirmar que a barra de favoritos some.
- Reload da página — favoritos persistem. Logar com outro usuário — favoritos não aparecem (namespace por `user.id` funcionando).
