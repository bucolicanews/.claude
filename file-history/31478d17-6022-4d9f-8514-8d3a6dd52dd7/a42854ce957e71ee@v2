---
name: deliveryhub-desconto-acrescimo-linha-fechamento
description: "Fix: painel de fechamento da comanda (Salão) não mostrava linha separada de Desconto/Acréscimo — sumia até a comanda fechar"
metadata: 
  node_type: memory
  type: project
  originSessionId: 31478d17-6022-4d9f-8514-8d3a6dd52dd7
  modified: 2026-08-09T23:10:48.032Z
---

Bug: `src/pages/restaurante-salao/index.jsx` — painel de fechamento (`podeEditar`, ~linha 1142) mostrava "Valor da comanda" já líquido (subtotal - desconto + acréscimo) sem quebrar em linhas. Desconto aplicado sumia da tela até a comanda ser fechada (só aparecia no resumo pós-fechamento, ~linha 969).

Fix: "Valor da comanda" agora mostra subtotal bruto + linhas condicionais de Desconto (-) / Acréscimo (+) logo abaixo, mesmo padrão do resumo pós-fechamento. Total final (com gorjeta) manteve o cálculo.

**Status:** MERGEADO+PUSHADO MAIN 2026-08-09, EasyPanel confirmado.

**Why:** usuário aplicou desconto numa comanda real e não viu refletido na tela até fechar — reportou via screenshot com component picker (deu file:line exato).

**How to apply:** ao investigar "sumiço" de campo numa tela, checar se existe mais de um componente/bloco de resumo renderizando os mesmos dados (esse arquivo tem múltiplos blocos parecidos: fechamento aberto, resumo pós-fechamento, modal venda balcão) — o bug pode estar só num deles.
