---
name: deliveryhub_botao_fechar_modal_comanda
description: "Modal de comanda/mesa no Salão fechava sozinho ao clicar fora, perdendo edição — adicionado botão X, removido fechar-por-clique-fora"
metadata: 
  node_type: memory
  type: project
  originSessionId: d4d5a3c9-4437-4241-83cd-b23d777d16a9
  modified: 2026-07-27T22:05:17.173Z
---

`src/pages/restaurante-salao/index.jsx`, componente `ComandaModal` (linha ~327): backdrop tinha `onClick={onFechar}` fechando o modal ao clicar fora, sem botão explícito de fechar.

Fix: removido `onClick={onFechar}` do backdrop e `stopPropagation` do conteúdo; adicionado botão X (Icon "X") no header ao lado do badge de status. Usuário escolheu explicitamente essa opção (botão + parar fechar clicando fora) em vez de só adicionar o botão.

MERGEADO EM MAIN + PUSHADO. Testado pelo usuário antes do merge.
