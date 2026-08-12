---
name: deliveryhub-fix-dark-login-toggle-overlap
description: "Dark mode ausente em customer-registration-login + ThemeToggle sobrepondo botão Entrar em /menu-catalog-product-browse — MERGEADO+PUSHADO MAIN, TESTADO"
metadata: 
  node_type: memory
  type: project
  originSessionId: 31cc1ec5-40ca-45dd-ab92-f454ec7203d9
  modified: 2026-07-30T17:30:07.878Z
---

Pedido do usuário 2026-07-30: `/customer-registration-login` feia no dark; depois, ThemeToggle fixo em cima do botão "Entrar" em `/menu-catalog-product-browse`.

**Achado:** `customer-registration-login/index.jsx`, `LoginForm.jsx` e `RegisterForm.jsx` não tinham nenhuma classe `dark:` — diferente do resto do app (padrão já é [[deliveryhub_plano_dark_mode_retrofit]] com paleta `#18181B`/`#27272A`/`#3F3F46`/`#F4F4F5`/`#71717A`/`#A1A1AA`/`#E4E4E7`). `ForgotPasswordModal.jsx` já usava tokens semânticos (`bg-card`, `text-foreground`) e já funcionava — não mexido.

**Bug extra achado em `RegisterForm.jsx`:** barra de força de senha tinha `style={{ color: ... : '#E5E7EB' }}` inline sempre forçando cor mesmo com a classe dark certa — `style` inline sempre vence `className` em React, por isso o dark não pegava ali. Fix: `color: undefined` quando não deve forçar cor, deixando a classe Tailwind (`dark:bg-[#3F3F46]`) valer.

**ThemeToggle** (`src/contexts/ThemeContext.jsx:42`) é fixo `top-3 right-3 z-[100]`, fallback global pra páginas sem toggle próprio. Já tinha exceção pra `/` e `/restaurante/*` (ver comentário no arquivo). Adicionada exceção pra `/menu-catalog-product-browse` (header próprio da página tem "Entrar" nesse canto, sobrepunha).

**Status: MERGEADO+PUSHADO main (commit `8a716e9`) 2026-07-30, testado pelo usuário. EasyPanel não confirmado.**

**How to apply:** se aparecer outra página "feia" no dark, primeiro checar se ela usa `dark:` nenhuma vez (grep rápido) — geralmente é página de fluxo cliente-público, ainda não passou pelo retrofit. Se tiver `style={{ color }}` inline condicional, suspeitar que ele esteja pisando na classe dark.
