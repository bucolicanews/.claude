---
name: deliveryhub-kds-layout-padronizado
description: "Layout padronizado (garcom destaque + busca + prontos limitados) aplicado em Cozinha, Producao e Bar"
metadata: 
  node_type: memory
  type: project
  originSessionId: ce53651c-2bd0-46ad-9cf7-505577dd6605
  modified: 2026-07-26T21:27:27.039Z
---

Em 2026-07-26, as 3 telas de KDS do módulo Salão (`/restaurante/cozinha`, `/restaurante/producao`, `/restaurante/bar`) ganharam o mesmo padrão visual, mergeado em main:

- Card do item: faixa branca no topo com nome do garçom (só aparece se `item.garcom` existir), mesa/cliente em texto maior e amarelo, "Quantidade: X" / "Produto: Y" em linhas separadas com fonte maior (pedido do usuário: "bem distintas separadas").
- Lista de itens "prontos/entregues" não fica mais limitada a 10min (backend `getKdsSetor` em `salao.service.ts` mudou de janela de 10min pra "desde início do dia") — a tela que decide quantos mostrar por padrão (Cozinha: 5, Produção/Bar: 2) com botão "Ver todos (N)" que vira "Recolher / fechar a lista" quando expandido.
- Produção e Bar ganharam campo de busca por cliente/mesa/comanda/garçom (backend expõe `mesa_numero` e `numero_comanda` no item do KDS pra isso).
- Ordenação: prontos/entregues ordenam por `pronto_em` decrescente (mais recente primeiro).

**Why:** usuário queria facilidade de leitura rápida na cozinha (letra maior, garçom destacado) e não perder o histórico de itens já prontos/entregues do dia.

**How to apply:** se pedirem melhoria parecida em qualquer tela de KDS nova, replicar esse mesmo padrão (`SalaoItemCard`/`ItemCard` nos 3 arquivos são cópias quase idênticas — não há componente compartilhado, é preciso editar os 3 arquivos separadamente).

Ver [[project_deliveryhub_white_label]].
