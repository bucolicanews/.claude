---
name: feedback-nao-inferir-pagina-errada
description: "usuário deu URL de uma página mas pedido tratado como se fosse de outra feature relacionada — não presumir, perguntar quando ambíguo"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: a1681614-dd0b-4169-8fc6-818c831e6b78
---

Erro cometido 2026-07-16: usuário mandou a URL `/restaurante/motoboys` pedindo "incluir a possibilidade de revisão, dessa forma o pedido volta a ficar pendente". Sem checar o que realmente existe nessa página, inferi que era sobre pedido/entrega (por causa da palavra "pendente" e do padrão `delivery_occurrence` que eu tinha acabado de mexer na tarefa anterior) e construí uma feature de "revisar ocorrência do motoboy" inteira (backend + botão no `PedidoDetalhe.jsx`, aberto por outro painel) — errado.

O pedido real: `/restaurante/motoboys` tem abas Pendentes/Aceitas/Recusadas de **solicitação de cadastro de motoboy** (não tem nada a ver com pedido/entrega). O usuário queria um botão "Revisão" do lado de cada solicitação **recusada**, que move ela de volta pra aba **Pendentes** — simples e literal.

**Why:** eu estava no meio de duas tarefas seguidas sobre motoboy/delivery (alerta no Bar + rotas de pedido), e isso me fez assumir contexto por proximidade temática em vez de checar o código da página que o usuário realmente citou. O usuário reclamou explicitamente: "não achei o botão que você criou e não entendi a sua função".

**How to apply:** antes de implementar em cima de uma URL/página específica que o usuário deu, **abrir e ler o arquivo dessa página primeiro** pra confirmar que o domínio (dados/estado) bate com o pedido — mesmo que outra tarefa recente pareça relacionada por vocabulário parecido ("pendente", "revisão", "motoboy"...). Se o pedido não bater com o que a página realmente faz, perguntar antes de construir uma feature inteira em outro lugar. Ver também [[feedback_workflow_memory_commits]] sobre não deixar trabalho sem confirmar escopo ambíguo.
