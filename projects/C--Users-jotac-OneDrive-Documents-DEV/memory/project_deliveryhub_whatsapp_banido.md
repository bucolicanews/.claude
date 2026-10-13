---
name: project-deliveryhub-whatsapp-banido
description: Número do WhatsApp usado via Evolution API (n8n) foi banido pelo WhatsApp — pivô pra Telegram-only no atendimento automatizado
metadata: 
  node_type: memory
  type: project
  originSessionId: bb5a7945-456c-4fd6-92af-41db59c8a905
  modified: 2026-10-06T19:29:32.387Z
---

Em 2026-10-06, o número de WhatsApp conectado na instância Evolution API (self-hosted, `jota-empresas-evolution-api` no Easypanel, usada pelo workflow n8n "PediuVai - WhatsApp") foi **banido pelo WhatsApp**. Decisão do usuário: abandonar WhatsApp/Evolution como canal de atendimento automatizado, trabalhar **somente com Telegram** daí em diante.

**Why:** WhatsApp pune agressivamente números usando APIs não-oficiais (Evolution API/Baileys) quando detecta padrão de bot — especialmente com envio automatizado via webhook/n8n como estava configurado (ver [[project_deliveryhub]] seção "notificações via Telegram", 2026-09-21, que já registrava Evolution como canal WhatsApp externo ao backend).

**How to apply:**
- Não reativar nem recomendar a Evolution API / workflow "PediuVai - WhatsApp" (n8n) pra reabrir canal WhatsApp sem o usuário pedir explicitamente e entender o risco de ban de novo.
- Qualquer nova automação de atendimento/agente conversacional (ex. tools `estabelecimentos_proximos`, buscas de produto) deve ser direcionada pro workflow **"PediuVai - Telegram"** no n8n, não pro de WhatsApp.
- O workflow "PediuVai - WhatsApp" tem um AI Agent (Groq, modelo `openai/gpt-oss-120b` após fix de 2026-10-06) com tool `estabelecimentos_proximos` já configurado — mas o workflow em si está **desativado** (`active: false`) e não deve receber tráfego real.
- **2026-10-06, mesma sessão:** suporte a location + tool `estabelecimentos_proximos` já foi portado pro workflow "PediuVai - Telegram" (id `cjaCGHcCvfwnxeFQ`), que também tinha o mesmo bug `groq/compound` (corrigido pro mesmo `openai/gpt-oss-120b`). Telegram é o canal ativo único agora. Não duplicar esse trabalho — ele já existe lá.
- **2026-10-06, mesmo dia:** achado e corrigido conflito sério — `@jotaMaster_bot` (token `TELEGRAM_TOKEN` no `.env`) era usado TANTO pelo `TelegramService` do backend (notificações transacionais, webhook `/telegram/webhook`, re-registrado a cada boot via `OnModuleInit`) QUANTO pelo node "Telegram Trigger" do workflow n8n (agente de IA). Telegram só aceita 1 webhook por bot — todo deploy do backend roubava o webhook de volta, derrubando o agente silenciosamente (aconteceu ao vivo nessa sessão, logo após o deploy do fix de busca de produto). **Resolvido definitivamente**: criado bot novo dedicado `@pediuvai_bot` (token novo, credencial n8n `VvuNvX6pbZFtJiZJ` "Telegram account - PediuVai Bot (agente)") só pro agente/n8n; `@jotaMaster_bot` volta a ser exclusivo do backend. Não existe mais conflito — deploy do backend não afeta mais o agente.
- Credenciais `EVOLUTION_URL`/`EVOLUTION_KEY` no `.env` ficam obsoletas pro uso de atendimento (mantidas só por histórico).

Ver também [[project_jota_integrador]] não relacionado — este é específico do DeliveryHub/PediuVai.
