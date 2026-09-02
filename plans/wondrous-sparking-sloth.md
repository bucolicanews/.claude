# Aparência da plataforma (marketplace) editável pelo admin

## Contexto

O usuário quer que vários elementos hoje hardcoded em `/menu-catalog-product-browse`
(a home/marketplace pública do DeliveryHub) virem editáveis por um admin, sem precisar
de deploy de código pra trocar textos/cores da marca — o mesmo racional que já existe
pro dono de restaurante em `restaurante-aparencia` (branding por loja), só que agora no
nível da plataforma como um todo. Elementos pedidos ao longo da conversa:

- Ícone da logo (SVG `Utensils` no quadrado laranja do header) e o texto "DeliveryHub"
- Textos do Hero: tagline, título, subtítulo
- Bloco de estatísticas do Hero (rótulos "Restaurantes"/"Avaliação média"/"Min. entrega"
  + o valor fixo "~30" min. de entrega — os números de `totalRest`/`mediaNota` continuam
  calculados, só os *rótulos* e o valor estático viram editáveis)
- Fundo do Hero, cor da barra superior (header), cor de fundo da página
- Cor de fundo do rodapé e cor da fonte do rodapé

Decisões já confirmadas com o usuário:
- **Logo**: trocar o ícone (reaproveita o sistema de `icon_name` que categorias já usam),
  não upload de imagem.
- **Fundo do Hero**: mesmo padrão de 3 abas já usado em `restaurante-aparencia`
  (Gradiente fixo / Cor sólida / Imagem).

## Modelo de dados — sem migration nova

A plataforma já tem uma tabela single-row `platform_settings` (`config jsonb`, `id=1`),
usada por `PlataformaService.getConfig()`/`updateConfig()`
(`serer_delivery/src/plataforma/plataforma.service.ts:87-165`, mesmo código no
submódulo `deliveryhub_white_label/server_delivery/`). Basta adicionar uma nova chave
aninhada `aparencia_marketplace` dentro desse JSONB — **nenhuma migration necessária**.

Criar um arquivo novo `src/plataforma/aparencia-marketplace.constants.ts` (duplicado
idêntico nos dois checkouts do backend, mesmo padrão já documentado no projeto) com os
defaults — devem bater exatamente com os valores hoje hardcoded no frontend, pra nada
mudar visualmente até o admin editar algo:

```ts
export const DEFAULT_APARENCIA_MARKETPLACE = {
  logo_icon: 'Utensils',
  nome_marca: 'DeliveryHub',
  header_bg_color: '#FFFFFF',
  page_bg_color: '#F4F4F5',
  hero_tagline: 'Delivery · Rápido · Confiável',
  hero_titulo: 'Seu delivery favorito',
  hero_subtitulo: 'Peça dos melhores restaurantes da sua cidade',
  hero_fundo_tipo: 'gradiente', // 'gradiente' | 'cor' | 'imagem'
  hero_fundo_cor: '#FF441F',
  hero_fundo_imagem_url: '',
  stat1_label: 'Restaurantes',
  stat2_label: 'Avaliação média',
  stat3_label: 'Min. entrega',
  stat3_valor: '~30',
  footer_bg_color: '#FFFFFF',
  footer_text_color: '#71717A',
  footer_link_color: '#FF441F',
};
```

## Backend (aplicar nos DOIS checkouts: `serer_delivery/` e
`deliveryhub_white_label/server_delivery/` — gotcha já conhecido do projeto)

1. **Novo arquivo** `src/plataforma/aparencia-marketplace.constants.ts` com o const acima.
2. **`src/plataforma/plataforma.service.ts`**:
   - `getConfig()` (linha 87-112): incluir no objeto retornado
     `aparencia_marketplace: { ...DEFAULT_APARENCIA_MARKETPLACE, ...(cfg.aparencia_marketplace ?? {}) }`.
   - `updateConfig()` (linha 114-165): se `body.aparencia_marketplace` vier definido,
     `novo.aparencia_marketplace = { ...(cfg.aparencia_marketplace ?? DEFAULT_APARENCIA_MARKETPLACE), ...body.aparencia_marketplace }`.
   - Novo método `uploadImagem(folder, file)` — cópia do padrão já existente em
     `RestauranteService.uploadImage` (`src/restaurante/restaurante.service.ts:1867-1879`,
     bucket `restaurante-imagens`, mesmo bucket reaproveitado, pasta `'plataforma'`).
   - Novo método `getBrandingPublico()` — mesma forma de `getConfig()` mas só devolvendo
     `{ ...DEFAULT_APARENCIA_MARKETPLACE, ...(cfg.aparencia_marketplace ?? {}) }` (esse
     bloco já é 100% seguro pra expor sem auth — não tem token/segredo).
3. **`src/plataforma/update-config.dto.ts`**: adicionar
   `@IsOptional() @IsObject() aparencia_marketplace?: Record<string, any>;` (validação
   solta, mesmo estilo do resto do DTO — o whitelisting de verdade já é feito no service).
4. **`src/plataforma/plataforma.controller.ts`** (mantém o `@UseGuards(AdminGuard)` de
   classe já existente): adicionar
   ```ts
   @Post('upload')
   @UseInterceptors(FileInterceptor('file', { limits: { fileSize: 5 * 1024 * 1024 } }))
   upload(@UploadedFile() file: Express.Multer.File, @Query('folder') folder = 'plataforma') {
     return this.service.uploadImagem(folder, file);
   }
   ```
5. **`src/restaurante/catalogo.controller.ts`** (`@Controller('r')`, **sem guard** —
   mesmo controller que já serve `/api/r/produtos`, `/api/r/filtros` etc pro
   `menu-catalog-product-browse`): adicionar rota pública
   ```ts
   @Get('branding')
   async getBranding() {
     const { data } = await this.supabase.client
       .from('platform_settings').select('config').eq('id', 1).maybeSingle();
     return { ...DEFAULT_APARENCIA_MARKETPLACE, ...(data?.config?.aparencia_marketplace ?? {}) };
   }
   ```
   (importar o arquivo de constants novo). Fica acessível sem login em `GET /api/r/branding`.

## Frontend (`deliveryhub_white_label/`)

1. **`src/services/restauranteService.js`** — conferir a implementação exata de
   `uploadImagem` (~linha 189-207) antes de espelhar.
2. **`src/services/adminService.js`**: adicionar `uploadImagemPlataforma(file, folder)`
   espelhando o multipart-upload de `uploadImagem`, mas indo pra
   `POST /plataforma/upload` (admin, com Bearer token da sessão).
3. **`src/components/ui/ImageUpload.jsx`**: generalizar — prop nova
   `uploadFn = uploadImagem` (default preserva o comportamento atual de todo mundo que já
   usa o componente), trocar a chamada hardcoded por `uploadFn(file, folder)`. Mudança
   não-quebradora.
4. **Nova página** `src/pages/admin-aparencia/index.jsx` — visual no estilo de
   `admin-configuracoes`/`admin-categorias` (zinc/gray + acento orange-500 do admin, NÃO
   o estilo `#FF441F`/rounded-2xl do dono de restaurante):
   - Carrega com `getPlataformaConfig()`, usa `config.aparencia_marketplace` (já vem com
     defaults preenchidos pelo backend).
   - Seções: **Cabeçalho** (nome da marca + seletor de ícone, reaproveitando o grid+campo
     livre de `admin-categorias/index.jsx:108-143` incluindo o link pra lucide.dev/icons,
     + cor da barra superior); **Hero** (tagline/título/subtítulo + as 3 abas
     gradiente/cor/imagem, espelhando exatamente `restaurante-aparencia/index.jsx:398-441`,
     usando `ImageUpload` com `uploadFn={uploadImagemPlataforma}` e `folder="plataforma"`
     na aba imagem); **Estatísticas** (3 rótulos + valor do "Min. entrega"); **Página**
     (cor de fundo); **Rodapé** (cor de fundo, cor do texto, cor dos links).
   - Salva com `updatePlataformaConfig({ aparencia_marketplace: form })`.
5. **`src/config/adminNavLinks.js`**: adicionar `{ label: 'Aparência', path: '/admin/aparencia' }`.
6. **`src/Routes.jsx`**: importar `AdminAparencia`, registrar
   `<Route path="/admin/aparencia" element={<AdminGuard><AdminAparencia /></AdminGuard>} />`.
7. **`src/pages/menu-catalog-product-browse/index.jsx`** — consumo real:
   - Const `DEFAULT_MARCA` no topo do arquivo, idêntica aos defaults do backend (garante
     que a página renderiza igual a hoje antes do fetch resolver e caso o admin nunca
     tenha configurado nada).
   - `const [marca, setMarca] = useState(DEFAULT_MARCA)` + `useEffect` fazendo
     `fetch(apiPath('/api/r/branding')).then(r => r.json()).then(setMarca).catch(() => {})`
     — mesmo padrão de fetch inline já usado nesta página (linhas 725-798), sem service
     wrapper novo.
   - Header (~linha 867-875): `Icon name="Utensils"` → `Icon name={marca.logo_icon}`;
     texto "DeliveryHub" → `{marca.nome_marca}`; `<header>` troca a classe `bg-white/95`
     fixa por `style={{ backgroundColor: hexToRgba(marca.header_bg_color, 0.95) }}`
     (pequeno helper `hexToRgba` local), mantendo `backdrop-blur-md`.
   - Wrapper externo da página (linha 864): `bg-[#F4F4F5]` → `style={{ backgroundColor: marca.page_bg_color }}`.
   - `Hero` (linhas 566-633): recebe `marca` como prop; tagline/título/subtítulo vêm de
     `marca.*`; div de fundo (linha 568) condicional por `marca.hero_fundo_tipo`:
     `'gradiente'` mantém a classe CSS de 3 stops de hoje (default fixo, sem mudança),
     `'cor'` vira `style={{ background: marca.hero_fundo_cor }}`, `'imagem'` vira
     `style={{ backgroundImage: `url(${marca.hero_fundo_imagem_url})`, backgroundSize: 'cover', backgroundPosition: 'center' }}`;
     rótulos das estatísticas (linhas 616/622/628) vêm de `marca.stat1_label/stat2_label/stat3_label`,
     e o valor fixo `~30` (linha 627) vira `marca.stat3_valor` — os números computados
     `totalRest`/`mediaNota` (linhas 615/621) continuam como estão, intocados.
   - Footer (linhas 1309-1330): `bg-white` → `style={{ backgroundColor: marca.footer_bg_color }}`;
     botões de link (`text-[#FF441F]`) → `style={{ color: marca.footer_link_color }}`;
     texto de copyright (`text-[#71717A]`) → `style={{ color: marca.footer_text_color }}`.

## Verificação

- Backend (nos dois checkouts): `npm run build && node dist/src/main.js` — confirmar que
  ainda sobe (`"Nest application successfully started"`), sem `UnknownDependenciesException`
  (lição já registrada no projeto sobre DI quebrar só em runtime).
- `curl` sem token em `GET /api/r/branding` → espera JSON com os defaults.
- Logado como admin: `GET /api/plataforma/config` → confirma chave `aparencia_marketplace`
  presente; `PATCH` um campo (ex. `nome_marca`); re-`GET` confirma persistência; re-`GET /api/r/branding`
  confirma que o público reflete a mudança.
- Frontend: abrir `/admin/aparencia`, mudar nome da marca / título do hero / cor do
  rodapé, salvar, abrir `/menu-catalog-product-browse` (recarregar) e conferir visualmente.
  Conferir também que, sem tocar em nada, a página continua idêntica à de hoje (defaults
  batem com o hardcoded atual).
- Lembrar do fluxo de deploy já documentado: aplicar os commits de backend nos dois
  checkouts, push em um, `git fetch && git diff origin/main main --stat` no outro antes
  de tentar push (evita duplicar commit com hash diferente), depois atualizar o ponteiro
  do submódulo no frontend.
