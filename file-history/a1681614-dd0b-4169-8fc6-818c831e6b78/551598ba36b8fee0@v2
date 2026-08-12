# Perfil do cliente: endereço completo + foto + filtro por km funcionando de verdade

## Contexto

Hoje o filtro geográfico da home (`/`) depende 100% do GPS do navegador a cada visita — se o cliente nega ou o navegador não pede permissão, o filtro simplesmente não funciona, mesmo que o cliente já tenha um endereço salvo no perfil. Além disso:
- O campo "número" nunca é obrigatório em nenhum formulário de endereço (perfil do cliente, checkout).
- A página `/customer-profile` já existe e tem o formulário completo, mas **não tem link nenhum na navegação** — cliente só chega lá digitando a URL.
- O CEP no perfil não busca endereço automaticamente (o checkout já faz isso, o perfil não — inconsistência).
- `customers` já tem colunas `lat`, `lng`, `address_geocode_hash`, `address_geocoded_at` prontas (usadas hoje só na criação de pedido, e só quando o restaurante paga motoboy por km) — a infra de geocodificação já existe, só não é acionada ao salvar o perfil nem usada pelo filtro da home.

Objetivo: fechar esse ciclo — perfil completo (endereço + número obrigatório + foto) vira acessível e visível (avatar na home), o endereço salvo é geocodificado automaticamente, e o filtro por km passa a usar essa localização salva como fallback quando não há GPS ao vivo.

**Fora do escopo** (confirmado com o usuário): motoboys continuam só com o fluxo de documentos que já têm, sem endereço novo. Avatar entra só no cabeçalho da Home/cardápio (`menu-catalog-product-browse`) — as outras 3 páginas do cliente (carrinho, meus pedidos, acompanhar pedido) e os dashboards de restaurante/motoboy ficam de fora desta tarefa. `BrandedHeader.jsx` não é usado em lugar nenhum — cada página tem seu próprio `<header>` inline; não vamos mexer nele.

## Backend (`server_delivery`)

**1. Exigir "número"** — `src/perfil/perfil.service.ts` `updateMeuPerfil`: se `address_json` vier no body, exigir `numero` (e `logradouro`) não-vazios, senão `BadRequestException`. Defesa em profundidade — o front já valida, mas API crua não devia aceitar endereço sem número.

**2. Geocodificar ao salvar perfil** — reaproveitar a lógica que já existe em `src/pedidos/pedidos.service.ts` (`geocodificarEnderecoCliente`, linhas ~74-98: hash do endereço, pula se não mudou, junta `logradouro/numero/bairro/cidade/estado/cep` e chama `GeocodingService.geocodeEndereco`). Extrair o miolo (hash-check + montar texto + chamar geocode) pra um método novo em `src/motoboy/geocoding.service.ts` (ex: `geocodificarSeNecessario(addressJson, hashAtual)` → retorna `{lat,lng,hash}` ou `null`), já que esse serviço é puro (sem dependência de DB) e já é exportado pelo `MotoboyModule` pra reuso cross-domínio (o próprio `PedidosModule` já importa `MotoboyModule` por causa dele).
   - `PedidosService.geocodificarEnderecoCliente` passa a chamar esse método novo (comportamento idêntico ao de hoje, só refatorado).
   - `PerfilModule` importa `MotoboyModule`; `PerfilService` injeta `GeocodingService`. Em `updateMeuPerfil`, depois de salvar o `customers`, se veio `address_json`, chama o método novo e — se retornar algo — faz um segundo update em `customers` com `lat/lng/address_geocode_hash/address_geocoded_at`. **Aguarda essa chamada** (é um clique deliberado de "Salvar perfil", não um caminho quente; precisa que `lat/lng` já estejam prontos na próxima visita à home), envolta em try/catch pra uma falha do Nominatim nunca derrubar o save do perfil em si.

**3. Foto de perfil** — endpoint novo, não reaproveita `restaurante/storage/upload` (esse é guardado por `RestaurantOwnerGuard`, rejeitaria token de cliente, e usa bucket errado pra isso).
   - `perfil.service.ts`: `uploadFoto(userId, file)` — mesmo padrão de `restaurante.service.ts` (`setupStorage`/`uploadImage`, bucket público, `getPublicUrl`), só que num bucket próprio `customer-avatars` (criado sob demanda na primeira chamada, igual o padrão existente). Salva `foto_perfil_url` em `customers`. Não usa o padrão de URL assinada do motoboy (isso é pra documento sensível; foto de perfil pode ser pública).
   - `perfil.controller.ts`: `POST /perfil/foto` (multipart, `FileInterceptor`), já protegido pelo `JwtGuard` que o controller já tem.
   - `getMeuPerfil`/`updateMeuPerfil`: incluir `foto_perfil_url` no `.select(...)`.

**4. Filtro da home usa endereço salvo como fallback** — `src/restaurante/catalogo.controller.ts` (endpoint `GET /api/r`, que hoje fica anônimo/público): injeta `SupabaseJwtService` (já existe, já é o padrão documentado pra "endpoint público que opcionalmente recebe token de cliente logado") — **sem guard**, endpoint continua acessível sem login. Lê `Authorization` header se vier; se validar e **não vierem `lat`/`lng` na query string**, busca `customers.lat/lng` desse `user_id` e usa como coordenada efetiva pro filtro/ordenação por distância que já existe. Nunca confia em coordenada "de fallback" vinda do cliente — só usa o que está salvo no banco pro usuário autenticado daquele token. Se o cliente não tem endereço geocodificado ainda, comportamento fica igual ao de hoje (lista cheia, sem filtro de distância). Quando cair nesse fallback, aplica o raio padrão (15km) igual ao caminho de GPS ao vivo, pra manter o mesmo comportamento visual.

## Frontend

**5. `src/pages/customer-profile/index.jsx`**
   - Exigir `numero` no `handleSalvar` quando `logradouro` estiver preenchido (não força endereço só pra trocar nome/telefone).
   - Adicionar autopreenchimento por CEP igual ao `StepEndereco.jsx` (`buscarCep` de `src/utils/viaCep.js`), hoje esse campo não busca nada.
   - Adicionar upload de foto (preview circular clicável, chama o `uploadFoto` novo do `perfilService.js` ao selecionar arquivo).

**6. `src/pages/shopping-cart-checkout/StepEndereco.jsx`** — adiciona `numero` na validação de `handleNext` (hoje só exige nome/telefone/logradouro) e marca o campo como `required` visualmente.

**7. `src/services/perfilService.js`** — nova função `uploadFoto(file)`, `FormData` + POST multipart pro endpoint novo, seguindo o padrão de auth (`supabase.auth.getSession()`) já usado nas outras funções desse arquivo.

**8. `src/pages/menu-catalog-product-browse/index.jsx`** (cabeçalho real da Home)
   - Avatar no cabeçalho: foto do cliente (busca via `getPerfil()` num `useEffect`, só quando autenticado) ou iniciais/ícone genérico como fallback — clique navega pra `/customer-profile`.
   - No fetch de `/api/r`: quando `isAuthenticated()`, anexa header `Authorization: Bearer <token>` (precisa importar `supabase` de `src/lib/supabase`, hoje não é importado nesse arquivo) independente de ter GPS ou não. Se `localizacao` for `null` (GPS negado/indisponível), a query já não manda `lat`/`lng` — o backend cobre o resto (item 4). Filtro manual (Estado/Cidade/Bairro/CEP) continua intocado, não interfere nisso.

## Banco de dados

Migração nova em `supabase/migrations/` (raiz do repo frontend, é onde ficam as ~59 migrations existentes, convenção `YYYYMMDDHHnnnnn_descricao.sql`):
```sql
ALTER TABLE public.customers
  ADD COLUMN IF NOT EXISTS foto_perfil_url TEXT;
```
`lat/lng/address_geocode_hash/address_geocoded_at` já existem, não precisa migração pra eles. Bucket `customer-avatars` é criado sob demanda pelo backend no primeiro upload (mesmo padrão já usado em `restaurante.service.ts`).

## Ordem de execução

1. Migração SQL (coluna `foto_perfil_url`).
2. Backend: método novo em `GeocodingService` → refatora `PedidosService` pra usá-lo (comportamento não muda, só verificar que pedido com motoboy por km ainda geocodifica certo) → `PerfilModule`/`PerfilService` (número obrigatório + geocodificação ao salvar) → endpoint de foto → fallback autenticado no `catalogo.controller.ts`.
3. Frontend: `perfilService.js` (`uploadFoto`) → `customer-profile/index.jsx` (número + CEP + foto) → `StepEndereco.jsx` (número) → `menu-catalog-product-browse/index.jsx` (avatar + header autenticado no fetch).

## Verificação manual

- Salvar perfil com endereço completo + número, sem foto → salva. Tentar salvar com logradouro preenchido e número vazio → bloqueia com mensagem clara.
- Conferir no Supabase que `lat/lng/address_geocode_hash/address_geocoded_at` populam após salvar endereço real (~1-2s, rate limit do Nominatim).
- Salvar o mesmo endereço de novo sem mudar nada → não deve chamar o Nominatim de novo (hash bate) — `address_geocoded_at` não muda.
- Upload de foto no perfil → confere URL pública salva e imagem renderizando após reload.
- Deslogado ou sem endereço salvo: home continua funcionando exatamente como hoje (GPS ao vivo ou filtro manual), sem `Authorization` no fetch quando deslogado.
- Logado, com endereço salvo e geocodificado, **negando a permissão de GPS no navegador**: recarrega a home → request pra `/api/r` agora leva `Authorization` → lista vem filtrada/ordenada pela distância do endereço salvo (confere comparando com um cálculo de haversine manual, ou logando `distancia_km` temporariamente).
- Checkout: tentar avançar do `StepEndereco` com número vazio → bloqueia.
- Clicar no avatar da home (logado) → vai pra `/customer-profile`.

## Arquivos principais
- `server_delivery/src/motoboy/geocoding.service.ts`
- `server_delivery/src/perfil/perfil.service.ts`, `perfil.controller.ts`, `perfil.module.ts`
- `server_delivery/src/restaurante/catalogo.controller.ts`
- `server_delivery/src/pedidos/pedidos.service.ts`
- `src/pages/customer-profile/index.jsx`
- `src/pages/shopping-cart-checkout/StepEndereco.jsx`
- `src/pages/menu-catalog-product-browse/index.jsx`
- `src/services/perfilService.js`
- `supabase/migrations/` (arquivo novo)
