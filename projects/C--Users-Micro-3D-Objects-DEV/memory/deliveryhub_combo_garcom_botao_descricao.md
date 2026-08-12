---
name: deliveryhub-combo-garcom-botao-descricao
description: Botão Combos ao lado da busca + descrição do combo visível pro garçom no modal Adicionar produto — portal garçom
metadata: 
  node_type: memory
  type: project
  originSessionId: b0275991-235f-4199-a0b8-897e422c4959
  modified: 2026-08-01T19:04:26.263Z
---

Portal garçom (`src/pages/garcom-portal/index.jsx`) tinha o modal "Adicionar
produto" desatualizado em relação ao Salão do dono: faltava o botão "Combos"
ao lado da caixa de busca (existia só em `restaurante-salao/index.jsx` desde
commit `fd8cee2`) e não mostrava a descrição do combo — garçom precisava
saber o que tem dentro do combo pra poder informar o cliente antes de
inserir na comanda.

Corrigido: botão Combos replicado no portal garçom (mesmo padrão visual do
dono) + descrição do combo (`p.description`, já vinha da API
`listarComDisponibilidade`, só faltava renderizar) aparece em itálico abaixo
do preço, só quando `p.tipo === 'combo' && p.description`.

**Why:** commits de feature às vezes só tocam o Salão (dono) e esquecem o
portal garçom, que tem modal duplicado/paralelo — checar os dois lugares
quando a tarefa for "modal de adicionar produto".

**How to apply:** ao mexer em UI de venda/comanda, sempre conferir se existe
o par restaurante-salao (dono) + garcom-portal (garçom) — são componentes
JSX separados, não compartilham código, mudança em um não propaga pro outro.

Status: TESTADO pelo usuário local, MERGEADO+PUSHADO em main (`f41da81`,
2026-08-01). EasyPanel redeploy não confirmado.
