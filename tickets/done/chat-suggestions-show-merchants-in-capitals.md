---
id: chat-suggestions-show-merchants-in-capitals
status: done
priority: low
area: yala-ia, copy
created: 2026-10-20
updated: 2026-10-25
source: barrido de la revisión de Yala IA 2.2 (simulador, semilla realista)
---

# Las sugerencias del saludo de Yala IA escriben los comercios en mayúsculas

## Qué ve el usuario

Al abrir Yala IA con la semilla `realista`, una de las tres sugerencias dice «¿Cómo se comparan mis gastos de
SUPERMERCADO y MERCADO?» (captura en `~/Claude/worktrees/_capturas/revision-ia-2-2/03-saldo.png`, antes de enviar).

## Lo medido

Los comercios del chat salen de `MerchantCanonicalizer.canonicalize`, que los normaliza en mayúsculas para agruparlos.
`ChatSuggestionsLLMService` manda esos nombres a `chat.suggestions` y el modelo los copia tal cual. El chat ya tiene
una regla para escribirlos con mayúscula inicial (revisión 2.2, regla 15g); las sugerencias no.

## Qué hay que hacer

Mandar a las sugerencias el nombre visible del comercio (la nota más frecuente de ese comercio) o pedir en su prompt la
mayúscula inicial, y medirlo con el banco de `chat.suggestions` y la reescritura (`chat.rewrite` compara nombres).

## Resuelto (lote 12.4, 2026-10-25)

Arreglado en el dato, no en el prompt: el resumen del mes sigue agrupando por el canónico, pero manda a `chat.suggestions` la forma visible más frecuente de cada comercio (`MonthSums.displayName(forMerchant:)`, `MerchantCanonicalizer.displayName(for:)`: sin el prefijo del procesador de pago y con mayúscula inicial si venía todo en mayúsculas o minúsculas; una sigla corta como «KFC» se queda).
- Lo fija `ChatSuggestionsMerchantNameTests` (tabla de nombres, agrupado por canónico con nombre visible, empate determinista y scan del cableado).
- El banco de `chat.suggestions` no se repitió: el arreglo no depende de que el modelo obedezca una regla, y repetirlo gasta del saldo prepago de producción (`.claude/rules/ai-gateway.md`). El reescritor compara en minúsculas, así que la lista blanca sigue casando.
