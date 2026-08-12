---
name: deliveryhub_relatorio_garcom_detalhado
description: "Relatorio /restaurante/relatorios/garcom ganhou detalhamento por comanda (mesa/cliente/gorjeta/taxa), totais no rodape, filtro+impressao por garcom, fix fuso horario"
metadata: 
  node_type: memory
  type: project
  originSessionId: c1bd5bd0-296a-4dfe-a338-f74f21fe5841
  modified: 2026-07-26T22:35:04.099Z
---

`/restaurante/relatorios/garcom` (src/pages/restaurante-relatorios/Garcom.jsx) agora tem:
- Tabela "Detalhamento das Vendas": comanda a comanda com garcom, mesa, cliente, total, gorjeta, taxa cartao, forma pagamento, total geral. Linha de somatorio no rodape (tela e impressao).
- Backend `getRelatorioGarcom` (server_delivery/src/restaurante/restaurante.service.ts) retorna `vendas[]` alem de `garcons[]`, reusando `buscarPagamentosPorComanda` pra taxa cartao/forma pagamento.
- Select "Garçom" filtra tela inteira (resumo+detalhe+totais) e libera botao "Imprimir só {nome}".
- Fix fuso: `dataHora`/`agora` no arquivo forcavam `timeZone: 'America/Sao_Paulo'` porque `toLocaleString('pt-BR')` sem timeZone explicito estava exibindo horario UTC (3h a frente do horario real do Brasil).

MERGEADO+PUSHADO EM MAIN (deliveryhub_white_label + submodule server_delivery), 2026-07-26. Usuario confirmou horario ok apos deploy.

**Why:** feito direto em `main` sem branch de tarefa (fugiu do padrão [[feedback_branch_por_tarefa]]) — usuário pediu deploy na mesma sessão sem branch criado antes.
**How to apply:** se pedir mudança nesse relatório de novo, já sabe onde mexer sem precisar reexplorar Routes.jsx/service.

Outros relatorios (Financeiro.jsx, Produtos.jsx) tem o MESMO bug potencial de fuso — usam `new Date(...).toLocaleString('pt-BR')` sem `timeZone` explicito. Se usuario reclamar de hora errada la tambem, aplicar mesmo fix.
