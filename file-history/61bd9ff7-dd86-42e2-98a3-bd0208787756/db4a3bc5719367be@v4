# Agente de impressão local (Python) — módulo Salão

## Contexto

O módulo Salão (já implementado) tem o conceito de "impressora por setor" (`impressoras` table: cozinha/bar/salgados), mas hoje a impressão real acontece via `window.print()` numa iframe escondida no **navegador de quem está com a tela aberta** (`printComanda.js`/`printTicketSetor`, chamado pelo `garcom-portal` depois de `enviarItens`). Isso não funciona pro cenário real: o garçom vende pelo celular, mas quem precisa receber o ticket é uma impressora térmica física na cozinha/bar, ligada num PC diferente na rede do restaurante. O celular do garçom não tem acesso a essa impressora.

Solução: um **agente local em Python**, baixado e executado pelo dono do restaurante no PC onde as impressoras estão instaladas/acessíveis. Ele detecta as impressoras do sistema, se pareia com o restaurante via token, e fica consultando o backend por trabalhos de impressão pendentes — imprimindo-os na hora.

Decisão de arquitetura: **polling HTTP simples** (agente pergunta a cada poucos segundos "tem trabalho pra mim?"), não WebSocket. Motivo: o agente roda atrás do NAT do restaurante sem porta exposta — teria que ser o agente a iniciar a conexão de qualquer forma; polling é muito mais simples de implementar dos dois lados (Python e NestJS), não exige gerenciar reconexão/socket vivo, e um atraso de 2-3s pra sair um ticket de cozinha é imperceptível na prática. WebSocket fica como otimização futura se a latência incomodar.

Dois lados: (1) **preparo do backend** pra virar fila de trabalhos ao invés de só devolver dados pro navegador imprimir, e (2) **o app Python** em si.

## Fase 1 — Migrations

1. `restaurants.agente_impressao_token UUID` (nullable, gerado sob demanda) — pareamento do agente com o restaurante, mesmo padrão do `cozinha_token` já existente.
2. `restaurants.agente_impressao_ultimo_ping TIMESTAMPTZ` — atualizado a cada poll do agente, usado pra mostrar "agente online/offline" na UI.
3. `impressoras.nome_sistema TEXT` (nullable) — identificador exato da impressora no sistema operacional (nome reportado pelo agente), usado pra saber pra qual impressora física mandar o job. `endereco` (já existente) continua servindo pro modo manual/legado (impressora de rede sem agente).
4. `impressoras_detectadas` — tabela simples: `id, restaurant_id, nome_sistema, detectado_em` — cache do que o agente reportou, populada a cada `POST /agente-impressao/impressoras`, pra alimentar um dropdown "escolher impressora detectada" no cadastro (em vez de digitar nome à mão).
5. `impressao_jobs`: `id, restaurant_id, impressora_id, conteudo TEXT, status CHECK IN ('pendente','impresso','erro') DEFAULT 'pendente', erro_msg, criado_em, impresso_em`.

## Fase 2 — Backend: API do agente (espelha `cozinha.guard.ts`/`cozinha-portal.controller.ts`)

- `server_delivery/src/auth/agente-impressao.guard.ts`: header `x-agente-token`, busca `restaurants` por `agente_impressao_token`, seta `request.agenteRestaurantId`; atualiza `agente_impressao_ultimo_ping` a cada chamada (mesmo padrão do `GarcomGuard` atualizando `ultimo_acesso_em`).
- Novo módulo `server_delivery/src/agente-impressao/`:
  - `POST /restaurante/agente-impressao/gerar-token` (`RestaurantOwnerGuard`) — gera/rotaciona `agente_impressao_token`, devolve o token pro dono copiar e colar no app.
  - `GET /restaurante/impressoras/detectadas` (`RestaurantOwnerGuard`) — lista o que o agente reportou, pro dropdown no cadastro de impressora.
  - `GET /agente-impressao/me` (`AgenteImpressaoGuard`) — healthcheck/confirma pareamento.
  - `POST /agente-impressao/impressoras` (`AgenteImpressaoGuard`) — agente reporta `{ impressoras: [{nome_sistema}] }`, backend faz upsert em `impressoras_detectadas`.
  - `GET /agente-impressao/jobs/pendentes` (`AgenteImpressaoGuard`) — retorna `impressao_jobs` com `status='pendente'` cujo `impressora_id` pertence a uma impressora com `nome_sistema` preenchido (ou seja, já mapeada pelo dono) — inclui `nome_sistema` no payload pra o agente saber onde mandar.
  - `POST /agente-impressao/jobs/:id/concluido` / `/erro` (`AgenteImpressaoGuard`) — marca resultado.

## Fase 3 — Backend: gerar o job na hora certa (integração com o que já existe)

- `SalaoService.enviarItens` (`server_delivery/src/salao/salao.service.ts`) — ponto onde hoje se monta `grupos` pra devolver pro frontend imprimir via `printTicketSetor`. Ajuste: pra cada grupo cuja `impressora` tenha `nome_sistema` preenchido (agente pareado), **insere um `impressao_jobs`** com o texto do ticket já formatado (setor, mesa/cliente, itens com observação, hora) — em vez de devolver esse grupo pro frontend imprimir. Grupos cuja impressora **não** tem `nome_sistema` (sem agente, modo antigo) continuam sendo devolvidos normalmente pro fallback de `window.print()` no navegador. Os dois modos convivem por impressora — não é tudo-ou-nada pro restaurante inteiro.
- Formato do `conteudo`: texto simples monoespaçado (cabeçalho do setor, mesa/cliente, lista `qtd x produto` + observação, timestamp) — suficiente pra maioria das impressoras térmicas ESC/POS (aceitam texto puro + corte automático). Formatação avançada (negrito/corte via bytes ESC/POS) fica de fora do v1, ver riscos.

## Fase 4 — App Python (novo, `print-agent/` na raiz do repo `deliveryhub_white_label`, projeto standalone)

Estrutura:
- `print-agent/agent.py` — loop principal: lê config local, faz `GET /agente-impressao/jobs/pendentes` a cada 3s, pra cada job manda imprimir e reporta `concluido`/`erro`; a cada poucos minutos reenvia lista de impressoras detectadas.
- `print-agent/printers.py` — detecção e impressão real, abstraído por SO:
  - Windows (`pywin32`): `win32print.EnumPrinters` pra listar; `OpenPrinter`/`StartDocPrinter`/`WritePrinter` pra mandar texto puro (RAW datatype) pra impressora escolhida.
  - Fallback Linux/Mac (via `lpstat -p` / `lp -d <nome>`), sem dependência compilada extra — suporte secundário, foco é Windows (PC de balcão de restaurante).
- `print-agent/config.py` — guarda `backend_url` + token pareado em `%APPDATA%/DeliveryHubAgent/config.json`.
- `print-agent/gui.py` — janela mínima em Tkinter (nativo do Python, sem dependência extra): campo pra colar o token na primeira execução, lista de impressoras detectadas, status "conectado"/"offline", log das últimas impressões. Pensado pra usuário não-técnico ("baixa e liga").
- `print-agent/requirements.txt`: `requests`, `pywin32` (Windows).
- Empacotamento em `.exe` via PyInstaller fica **fora do escopo desta rodada** (é um passo de build/distribuição, não de código) — o agente roda via `python agent.py` nesta fase; empacotamento é um follow-up quando o fluxo estiver validado.

## Fase 5 — Frontend: `/restaurante/impressoras`

- Nova seção "Agente de impressão local": botão "Gerar token de pareamento" (mostra o token pra copiar), indicador online/offline (`agente_impressao_ultimo_ping` recente = online, mesmo critério de "garçom online" já usado em `garconsOnline`).
- No formulário de impressora: troca o campo `endereco` livre por um select "Impressora detectada pelo agente" (busca em `GET /restaurante/impressoras/detectadas`), mantendo o campo de texto manual como alternativa se nenhum agente conectado ainda.

## Riscos / decisões assumidas

- Polling 3s → atraso perceptível mas aceitável pra ticket de cozinha; não é tempo real.
- V1 manda texto puro pra impressora — sem corte automático garantido em todo hardware (ESC/POS raw bytes fica pra depois se necessário).
- Empacotamento/distribuição do `.exe` fica fora — usuário roda via Python instalado nesta fase (ok pro dev/teste; produção real vai precisar de instalador, mas isso é decisão de distribuição, não arquitetura).
- Multi-impressora por agente: um único token pareia o **restaurante inteiro** com um agente (uma máquina reporta todas as impressoras que enxerga) — se o restaurante tiver impressoras em PCs diferentes, precisa rodar um agente em cada PC, ainda usando o mesmo token (o pareamento é por restaurante, não por máquina).

## Ordem de execução sugerida

1. Fase 1 (migrations) + Fase 2 (API do agente no backend) — fundação, testável via curl/script direto.
2. Fase 3 (gerar job no `enviarItens`) — validado com um job fake sendo criado e puxado via `GET /agente-impressao/jobs/pendentes`.
3. Fase 4 (app Python rodando local, imprimindo de verdade numa impressora real ou numa impressora virtual/PDF de teste).
4. Fase 5 (frontend: gerar token, ver impressoras detectadas, indicador online).

## Verificação

- Backend: `tsc --noEmit` limpo a cada fase.
- Gerar token em `/restaurante/impressoras`, rodar `python agent.py` local com esse token colado, confirmar que aparece "impressoras detectadas" no backend (`GET /restaurante/impressoras/detectadas`).
- Vender algo no portal do garçom, enviar pra um setor cuja impressora tem `nome_sistema` mapeado → confirmar que aparece um `impressao_jobs` pendente, o agente Python puxa, imprime (numa impressora real ou virtual "Microsoft Print to PDF" pra teste sem hardware) e marca concluído.
- Confirmar que uma impressora **sem** agente pareado continua caindo no fallback antigo (`printTicketSetor` no navegador) sem quebrar.
