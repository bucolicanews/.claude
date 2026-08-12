---
name: deliveryhub-fix-dark-endereco-config
description: "Fix: 6 campos de endereço do estabelecimento (Config) sem bg/text no dark mode — texto mesma cor do fundo"
metadata: 
  node_type: memory
  type: project
  originSessionId: 31478d17-6022-4d9f-8514-8d3a6dd52dd7
  modified: 2026-08-09T23:11:06.795Z
---

`src/pages/restaurante-config/index.jsx` — inputs de Logradouro/Número/CEP/Bairro/Cidade/Estado (bloco "Endereço do estabelecimento") ficaram fora do retrofit de dark mode: sem `bg-white dark:bg-[#18181B] text-[#18181B] dark:text-[#F4F4F5]`. No dark, texto digitado ficava invisível (mesma cor do fundo).

**Status:** MERGEADO+PUSHADO MAIN 2026-08-09, EasyPanel confirmado. Só front, sem migration.

**Why:** sobrou desse bloco no retrofit de dark mode (ver [[deliveryhub_plano_dark_mode_retrofit]]) — página de config tem múltiplos blocos de formulário, esse não foi coberto na varredura original.

**How to apply:** se aparecer outro campo "invisível" no dark em telas de Config/formulário, suspeitar do mesmo padrão — input sem `bg`/`text` explícitos herda estilo que colide no dark.
