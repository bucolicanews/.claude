# Menu sanduíche + sidebar + favoritos no painel admin

## Contexto

O painel do estabelecimento (`RestauranteHeader`) já tem um padrão de
navegação bem resolvido: no desktop, um botão "Menu" abre uma sidebar
deslizante com todos os links (com estrelinha pra favoritar cada um), e os
favoritados aparecem como pills com ícone na própria barra superior; no
mobile, um hambúrguer abre um dropdown simples com a lista de links. O painel
admin (`AdminHeader`) já tem o hambúrguer mobile (`AdminMobileMenu`, cópia
quase idêntica do `MobileMenu` do estabelecimento), mas no desktop ainda usa
uma `<nav>` horizontal fixa com os 13 links — o pedido é substituir isso pelo
mesmo padrão sidebar+favoritos que o estabelecimento já tem, tanto no
desktop quanto (mantendo o que já existe) no mobile.

Investigação confirmou que é uma réplica direta e mecânica de um padrão já
testado — não precisa reinventar nada, só adaptar pro vocabulário/paleta do
admin:
- `useRestauranteFavoritos` (`src/hooks/useRestauranteFavoritos.js`) —
  favoritos são **só localStorage**, chave por `user.id`, nada de
  tabela/coluna no banco. `keyFor`/`keyForNomes` viram
  `favoritos_admin_*`/`favoritos_admin_nomes_*`.
- `RestauranteSidebar.jsx` — drawer desktop-only (`hidden md:block`), abre
  por cima com backdrop, lista de links com estrela de favoritar por item
  (`onToggleFavorito`), badge de pendência (motoboys), rodapé com
  Loja/Config/Meu Perfil/Sair. Pro admin: **sem Loja** (não existe loja
  própria), e **sem Config/Meu Perfil no rodapé** — esses dois já são
  entradas normais da lista (`ADMIN_NAV_LINKS` já tem "Configurações" e "Meu
  Perfil"), diferente do estabelecimento onde são puxados pra fora da lista.
  Rodapé do admin fica só com "Sair".
- `RestauranteHeader.jsx` — monta a barra de favoritos (pills com ícone,
  encolhendo com `tamanhoFavoritos()` conforme a quantidade, toggle
  ícone-só/ícone+nome via `mostrarNomes`), o botão "Menu" que abre a sidebar,
  e o hambúrguer mobile que já existe. É o arquivo que orquestra tudo.
- `restauranteNavLinks.js` tem `icon` por link (obrigatório pra sidebar
  desenhar o ícone) — `adminNavLinks.js` hoje é `{label, path}` sem `icon`,
  precisa ganhar esse campo.
- Paleta: estabelecimento usa laranja (`#FF441F`) e hex customizado
  (`#18181B`/`#27272A`/`#3F3F46`); admin já usa `blue-600`/`zinc-*` em todo
  canto (`AdminHeader`/`AdminMobileMenu` atuais) — a sidebar/favoritos novos
  do admin seguem a paleta que o admin já usa, não a do estabelecimento.
- Breakpoint: estabelecimento usa `md` (768px), admin já usa `lg` (1024px)
  pro corte mobile/desktop (`AdminMobileMenu` é `lg:hidden`) — mantém `lg`
  no admin, só troca o que aparece do lado desktop (nav fixa → botão Menu +
  sidebar), sem mexer no breakpoint em si.

## Arquivos

**Novo `src/hooks/useAdminFavoritos.js`** — cópia de `useRestauranteFavoritos.js`
com as chaves de localStorage trocadas pra `favoritos_admin_${userId}`/
`favoritos_admin_nomes_${userId}` (mesmo hook, `user` vem do mesmo
`useAuth()` — funciona porque `user.id` já é o UUID do Supabase Auth, igual
pro dono de restaurante e pro admin).

**`src/config/adminNavLinks.js`** — cada entrada de `ADMIN_NAV_LINKS` ganha
um campo `icon` (nome válido do `Icon`/lucide): Dashboard→`LayoutDashboard`,
Empresas→`Store`, Usuários→`Users`, Categorias→`FolderTree`,
Tipos→`Building2`, Tags→`Tags`, Comissões→`Percent`, Motoboys→`Bike`,
Planos→`CreditCard`, Marketplace→`Megaphone`, Aparência→`Palette`,
Configurações→`Settings`, Meu Perfil→`UserCircle`.

**Novo `src/components/admin/AdminSidebar.jsx`** — cópia adaptada de
`RestauranteSidebar.jsx`: mesma estrutura (backdrop + drawer `w-72`
deslizando de `x:-320`, header "Menu" + X, `<nav>` com a lista + estrela de
favoritar, rodapé condicional), mas:
- `hidden lg:block` no wrapper (breakpoint do admin, não `md`).
- Paleta `blue-600`/`zinc-*` em vez do hex do estabelecimento.
- Props: `{ open, onClose, links, activePath, motoboysPendentes = 0, onSair, isFavorito, onToggleFavorito }` — sem `slugLoja`/`onMeuPerfil`.
- Badge de pendência checa `l.path === '/admin/motoboys'`.
- Rodapé só com o botão "Sair" (`{onSair && (...)}`), sem Loja/Config/Meu Perfil.

**`src/components/admin/AdminHeader.jsx`** — reescreve o bloco
`hidden lg:flex` atual (que hoje é a `<nav>` fixa com os 13 botões):
- importa `useAdminFavoritos`, `AdminSidebar`, adiciona `sidebarAberto` state.
- `linksFavoritos = ADMIN_NAV_LINKS.filter((l) => favoritos.includes(l.path))`.
- renderiza a barra de pills de favoritos (só se `linksFavoritos.length > 0`),
  reaproveitando a mesma lógica de `tamanhoFavoritos()`/`mostrarNomes` de
  `RestauranteHeader.jsx` (duplicar a função local, é só ~5 linhas — não
  compensa extrair pra um util compartilhado entre admin/estabelecimento por
  um único uso).
- botão "Menu" (`Icon name="Menu"` + texto) abrindo `sidebarAberto=true`,
  substitui a `<nav>` de botões soltos.
- mantém `ThemeToggle` e o botão "Sair" que já existem nessa área.
- lado mobile (`flex lg:hidden`) **não muda** — já tem hambúrguer +
  `AdminMobileMenu`, que já funciona igual ao do estabelecimento (dropdown
  simples, sem favoritos — mesmo padrão de lá, onde favoritar só existe no
  desktop).
- renderiza `<AdminSidebar>` (sempre montado, visibilidade via `open`) com
  `isFavorito`/`onToggleFavorito` vindos do novo hook.

## Verificação

- `npx vite build` limpo.
- Testar em `/admin` (ou qualquer página admin): no desktop, clicar "Menu"
  abre a sidebar com os 13 links + ícones; clicar na estrela de um link
  marca/desmarca favorito e ele passa a aparecer como pill na barra superior;
  o toggle de ícone-só/ícone+nome funciona; recarregar a página mantém os
  favoritos (persistidos em localStorage). No mobile (ou reduzindo a janela
  abaixo de 1024px), o hambúrguer continua funcionando como já funcionava,
  sem favoritos ali (igual ao estabelecimento).
- Conferir que o badge de motoboys pendentes ainda aparece certo tanto na
  sidebar quanto na barra de favoritos quando `/admin/motoboys` está
  favoritado.
- Sem migration, sem mudança de backend — feature 100% frontend/localStorage.
