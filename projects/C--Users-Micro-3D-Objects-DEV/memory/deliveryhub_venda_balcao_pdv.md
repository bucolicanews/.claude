---
name: deliveryhub-venda-balcao-pdv
description: "venda balcão virou PDV tipo mercado (catálogo+carrinho lado a lado) com pagamento multi-forma — branch feat/venda-balcao-pdv-completo, não mergeada ainda"
metadata: 
  node_type: memory
  type: project
  originSessionId: b916cb27-3349-4e47-96d2-e6cf5c20339d
  modified: 2026-07-23T19:36:28.997Z
---

Tela "Venda balcão" (`restaurante-salao/index.jsx`, componente `VendaBalcaoModal`, era `VendaDiretaModal`) foi reescrita a pedido do usuário: layout tela cheia dividido — catálogo de produtos (busca/categoria/grade, 4 colunas no desktop) de um lado, carrinho + pagamento do outro, igual PDV de supermercado.

**Arquitetura:** em vez de manter endpoint de venda instantânea (1 forma de pagamento só), passou a abrir uma **comanda avulsa** (sem mesa, sem exigir nome/telefone do cliente) e reaproveita os mesmos endpoints já existentes de comanda de mesa (itens, desconto/acréscimo, pagamento parcial, pagar) — isso já dava de graça o pagamento dividido em várias formas (pix + dinheiro + cartão na mesma venda, cada parcela com taxa de cartão própria), sem duplicar lógica.

Backend: endpoint antigo `POST /salao/venda-direta` removido, novo `POST /salao/venda-balcao/abrir` (método `abrirVendaBalcao` em `salao-pdv.service.ts`).

**Status (2026-07-23):** MERGEADO EM MAIN nos dois repos (frontend `89328ea`, backend `076b436`) e pushed pro GitHub. Standalone (`DEV/server_delivery`) sincronizado no mesmo commit. Falta confirmar se EasyPanel redeploya sozinho no push ou se precisa disparar manualmente — e se algo já estiver rodando localmente, reiniciar o processo Node (pull não recarrega sozinho, ver [[feedback-backend-restart-apos-pull]]).

Nota: a branch feature tinha sido criada em cima de `fix/voz-cozinha-speechsynthesis-pausa` (não em cima de main) — esse fix (voz da cozinha parava após horas ligada) foi junto pro main nesse merge, com confirmação explícita do usuário.

**Cuidado:** editei por engano o clone standalone (`DEV/server_delivery`) primeiro nessa tarefa antes de lembrar que dev é sempre no submodule (`deliveryhub_white_label/server_delivery`) — revertido a tempo, sem dano. Reforça [[deliveryhub-dois-clones-server-delivery]]: sempre checar em qual clone está antes de editar backend.
