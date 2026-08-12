---
name: deliveryhub-filtro-geografico-home
description: "Filtro por Estado/Cidade/Bairro/CEP + raio KM automático na home pública, e autocompletar CEP via ViaCEP nos cadastros de endereço"
metadata: 
  node_type: memory
  type: project
  originSessionId: 713ee0e2-48bc-48b0-98d9-93b121d50174
---

Implementado em 2026-07-16, pedido do usuário: home pública (`/`, componente `menu-catalog-product-browse`) deveria filtrar restaurantes por Estado/Cidade/Bairro/CEP e por raio em KM ao redor do cliente, mostrando automaticamente os mais próximos sem o cliente precisar mexer em nada.

**Decisão tomada com o usuário (AskUserQuestion):** em vez de só usar o raio-KM (que já funcionaria de imediato via lat/lng já existente em `restaurants`), o usuário escolheu **raio KM + campos estruturados novos** (`state`, `city`, `neighborhood`, `cep` adicionados à tabela `restaurants` via migration `20260716000005`) e **GPS do navegador** (`navigator.geolocation`) como fonte de localização do cliente (não endereço de perfil).

**Arquitetura:**
- Backend: `GET /api/r` (`catalogo.controller.ts`) aceita query params `state, city, neighborhood, cep, lat, lng, raio_km`. Sem filtro manual + com lat/lng, filtra por `raio_km` (default 15 no frontend) E ordena por distância; com filtro manual, ignora o raio (só filtra por texto). `haversineKm` foi extraído de `comissao.service.ts` pra `src/common/geo.util.ts` (reaproveitado, antes só existia pro cálculo de comissão do motoboy). Novo `GET /api/r/filtros` retorna combinações distintas `{state, city, neighborhood}` pra alimentar dropdowns em cascata sem carregar a lista inteira.
- Restaurantes SEM `lat/lng` geocodificado nunca aparecem quando o raio-KM está ativo (não dá pra saber se estão perto) — trade-off aceito.
- Frontend: home pede geolocalização ao montar (`pedirLocalizacao`), com fallback de 10s caso o navegador nunca resolva o diálogo de permissão. Estados: `pedindo/ok/negado/indisponivel`. Se negado, mostra banner incentivando ativar, mas filtros manuais continuam disponíveis normalmente.
- Cadastro do estabelecimento (`ContactDetailsForm.jsx`, restaurant-registration-setup) **já coletava** CEP/bairro/cidade/estado separadamente mas só concatenava tudo num `address` texto livre pro backend — corrigido pra mandar os campos estruturados também.
- Gap identificado e fechado: não existia tela pra editar endereço depois do cadastro inicial (só existia no onboarding). Criado card "Endereço do estabelecimento" em `restaurante-config/index.jsx` (usa `getMinhaEmpresa`/`updateEmpresa`, endpoint diferente do resto da tela que usa `getConfig`/`updateConfig`).

**Seguida por (mesma sessão):** integração ViaCEP (`src/utils/viaCep.js`, função `buscarCep`) — autocompleta logradouro/bairro/cidade/estado a partir do CEP digitado, aplicado nos 3 formulários que capturam endereço: `ContactDetailsForm` (cadastro do estabelecimento), `EnderecoCard` em `restaurante-config` (edição), e `StepEndereco.jsx` (endereço de entrega do cliente no checkout). Sem essa API antes no projeto — [[deliveryhub_modulo_restaurante_ideias]] já registrava que não havia ViaCEP/Google Maps, só Nominatim pro geocoding de lat/lng.

**How to apply:** se pedirem pra usar geolocalização/distância em outro lugar do projeto (ex: ordenar motoboys por proximidade, ou filtro geográfico em outra listagem), reaproveitar `haversineKm` de `src/common/geo.util.ts` em vez de duplicar. Se pedirem autocompletar CEP em novo formulário, reaproveitar `buscarCep` de `src/utils/viaCep.js`.
