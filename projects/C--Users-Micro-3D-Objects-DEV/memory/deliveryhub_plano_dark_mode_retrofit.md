---
name: deliveryhub-plano-dark-mode-retrofit
description: Plano pra implantar dark mode completo no deliveryhub_white_label — dividir em tarefas por tela
metadata: 
  node_type: memory
  type: project
  originSessionId: c012bc3f-a116-4487-bf28-de60d1ae9025
  modified: 2026-08-10T22:15:29.841Z
---

Combinado com o usuário em 2026-07-28: no próximo dia útil (2026-07-29), retomar o dark mode e implantar de verdade — dividir em tarefas (provavelmente por tela/página) e ir implantando aos poucos.

**Estado atual (ponto de partida):** infra já em main/produção (ver [[deliveryhub_repasse_garcom_dinheiro_pix]]) — `src/contexts/ThemeContext.jsx` com `ThemeProvider`/`ThemeToggle` (ícone sol/lua fixo `top-3 right-3`, persiste em localStorage, aplica classe `dark` na `<html>`), montado uma vez em `App.jsx`. Funcional, mas nenhuma página reage a ele ainda.

**Why:** decisão anterior (mesma sessão) foi propositalmente escalonada — 57 arquivos usam cor hex fixa (`bg-[#FAFAFA]`, `text-[#18181B]` etc, não os tokens CSS var do `tailwind.config.js` que já suportam `darkMode: "class"`) — retrofit de tudo de uma vez foi considerado arriscado demais pra fazer sem revisar tela por tela.

**How to apply:** ao retomar, checar `MEMORY.md`/memória primeiro (padrão já estabelecido, ver [[feedback_workflow_memory_commits]]), depois: 1) listar as 57 telas/arquivos com `grep -rl "bg-\[#" src/pages src/components`; 2) dividir em tarefas por tela ou por fluxo (ex: Salão, Garçom portal, Relatórios, Admin); 3) branch nova por tarefa (ver [[feedback_branch_por_tarefa]]); 4) confirmar plano/paleta dark antes de sair editando em massa, já que é mudança visual em muita tela — bom candidato pra usar a skill `dataviz`/`artifact-design` como referência de paleta se for definir cores novas, ou só reaproveitar os tokens `--color-*` já existentes no `tailwind.config.js`.

**Progresso (2026-07-29): MERGEADO EM MAIN E PUSHADO** (branch `feat/dark-mode-fundacao` → merge --no-ff → `git push origin main`, commit `3be431a`). Paleta dark = zinc (bg-900 `#18181B`, card/border-800/700 `#27272A`/`#3F3F46`, texto-100 `#F4F4F5`), bloco `.dark{}` em `src/styles/tailwind.css` (antes só existia `:root` light).

**Feito e testado:** grupo 1 (tokens + `Badge`/`Button`/`ImageUpload`/`Skeleton`), grupo 2 (`MobileMenu`/`RestauranteHeader`/`RestauranteSidebar`), grupo 3 (Dashboard+Financeiro, 12 arquivos), grupo 4 (Relatórios, 6 arquivos), e as 12 telas operação/admin pedidas explicitamente pelo usuário: `restaurante-{delivery,produtos,combos,pedidos,entregas,motoboys,clientes,aparencia,config,salao,garcons,impressoras}`.

**Ficaram de fora (intencional):** Cozinha/Produção/Bar/Chamada/KDS-setor — já são telas sempre-escuras por design (`bg-[#111111]`/`#1A1A1A]`, tipo TV/KDS), não usam o toggle. Motoboy portal e páginas cliente-público (cardápio digital, checkout, login/cadastro cliente, mesa-acompanhar, home-router) **ainda não migradas** — ver grupos 7 e 8 do plano original se retomar depois.

**Técnica (reaproveitar se continuar):** script Perl reutilizável salvo em `dark_rules.pl` no scratchpad da sessão (não persistido no repo) — adiciona par `dark:` mantendo prefixo `hover:`/`focus:`/`disabled:` correto (ex: `dark:hover:bg-x`, `dark:disabled:bg-x`), evita bug de duplicar/aplicar incondicionalmente que sed ingênuo causa. Gotchas encontrados: (1) `bg-white/20` (opacidade) quebra se o regex não excluir `/` depois — script corrigido com lookahead `(?!\/)`; (2) `disabled:bg-X` sem capturar prefixo gera `dark:bg-X` incondicional — precisa `disabled:` na lista de prefixos capturados; (3) alguns shells de página usavam `bg-[#F4F4F5]` (tom de elemento pequeno) em vez de `bg-[#FAFAFA]` — mapeamento automático gerava dark:`#3F3F46` (cinza claro demais pro fundo de página inteira), corrigido manualmente pra `#18181B` nesses casos; (4) sempre rodar `npx vite build` depois de cada lote e grep por `dark:.*dark:` pra achar duplicação.

**Outra mudança nesta sessão:** `ThemeToggle` (ícone fixo sol/lua) escondido também na home (`/`), além de `/restaurante/*` — a pedido do usuário.

**Progresso (2026-07-29, sessão seguinte): Portal do Garçom também tinha ficado de fora (não era intencional, foi esquecido).** Usuário reportou letras sumindo em `/garcom/:loginKey` em produção. Corrigido `src/pages/garcom-portal/index.jsx` (arquivo inteiro, ~1290 linhas, todos os componentes: login, mesas, comandas, fila cozinha, modais) + `src/components/TempoMedioTile.jsx`. MERGEADO+PUSHADO EM MAIN (commit `ce3f581`), EasyPanel não confirmado.

**Gotcha novo (causa raiz do bug reportado):** `<input>`/`<select>`/`<textarea>` sem classe de cor de texto/fundo explícita herdam `text-foreground` do `body` (que vira quase-branco `#F4F4F5` no `.dark`), mas o campo em si não ganha `dark:bg-*` — resultado é texto quase-branco dentro de caixa branca, ilegível. Fix: todo input/select/textarea precisa `bg-white dark:bg-[#27272A] text-[#18181B] dark:text-[#F4F4F5]` explícito, não só a borda. Vale conferir isso em qualquer outra tela migrada que tenha formulário.

**Gotcha 2:** script de retrofit mecânico (dessa vez em Python, substituição literal por token) cria bug sutil quando um token mapeado é substring de outro maior sem prefixo de variante capturado — ex. mapear `bg-red-100` global casou dentro de `hover:bg-red-100` já existente e colou `dark:bg-red-950/40` sem o prefixo `hover:`, forçando vermelho fixo no dark em vez de só no hover. Mesmo problema ocorreu com `text-red-600`/`hover:text-red-600`. Sempre grepar `hover:` + token mapeado depois do script pra achar esses casos.

**Progresso (2026-08-10):** `customer-profile`, `customer-account-order-history` (+ moveu `ThemeToggle` fixo pra dentro do header, sobrepunha os botões) e `motoboy-cadastro` migrados. Ainda faltam: `motoboy-portal` (portal em si, não o cadastro) e páginas cliente-público restantes (cardápio digital, checkout, mesa-acompanhar, home-router).

**Gotcha caro (mesmo dia):** o commit de `customer-profile`/`customer-account-order-history` ficou parado numa branch (`fix/dark-customer-profile`) sem nunca mergear em `main` — segui pra próxima tarefa achando que tinha subido. Usuário só percebeu horas depois testando em produção ("subiu sem o dark"). **Sempre confirmar `git log --oneline main | grep <commit>` antes de considerar uma tarefa "concluída", não só o `git commit` local.** Corrigido e mergeado de verdade (commit `75b3715`), junto com um bug achado no meio da correção: botão "voltar" do Meu Perfil usava `navigate(-1)`, que não faz nada se a página foi aberta direto (link, nova aba) sem histórico dentro do app — trocado pra destino fixo (`/customer-account-order-history`).
