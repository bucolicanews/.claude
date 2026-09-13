---
name: feedback-jsx-sequential-edits
description: "Sequential Edit calls on the same nested JSX fragment block can duplicate a closing </> — verify with a real parser, not just a visual diff read"
metadata:
  node_type: memory
  type: feedback
  originSessionId: 17ba2212-8eb7-4a71-9374-946fbc240171
  modified: 2026-09-07T00:14:32.144Z
---

Quando duas edições sequenciais mexem no mesmo bloco JSX aninhado (`{cond && (<>...</>)}`), e a segunda edição insere conteúdo **depois** de algo que a primeira edição acabou de adicionar — se o `old_string` da segunda edição capturar só o trecho novo (sem incluir o `</>`/`)}` original que já existia logo em seguida no arquivo), o resultado é um fechamento de fragmento duplicado. O `new_string` frequentemente precisa repetir o `</>`/`)}` de fechamento (porque agora ele fecha o fragmento na posição nova), mas o fechamento ORIGINAL que já estava mais abaixo no arquivo continua lá, intocado — sobra um par extra.

**Why:** aconteceu de verdade em `[[project_deliveryhub]]` (2026-09-06, feature de troco/gorjeta) em dois arquivos JSX (`garcom-portal/index.jsx`, `restaurante-salao/index.jsx`) — o erro só apareceu quando o usuário rodou `npm run dev` de verdade (erro de parser do Babel, "Expected corresponding JSX closing tag"), não na leitura visual do diff logo depois da edição, que parecia correta.

**How to apply:** depois de qualquer edição que adiciona ou remove uma tag de fechamento de fragmento (`<>`/`</>`) dentro de um bloco condicional já aninhado — especialmente quando é a segunda de duas edições seguidas no mesmo trecho — validar com um parser de verdade antes de dizer que está pronto, não confiar só na leitura do Read/diff:

```
node -e "require('@babel/parser').parse(require('fs').readFileSync('<arquivo>','utf8'), {sourceType:'module', plugins:['jsx']})"
```

Isso pega o erro exato (linha/coluna) sem precisar levantar o dev server inteiro, e deveria ser rotina sempre que a edição envolve balancear fragmentos JSX manualmente, não só nesse projeto.
