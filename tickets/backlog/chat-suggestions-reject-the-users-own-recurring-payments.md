---
id: chat-suggestions-reject-the-users-own-recurring-payments
status: backlog
priority: medium
area: chat, ai
created: 2026-10-09
updated: 2026-10-09
source: banco de chat.suggestions del 2026-10-09 (gateway/bench/results/2026-10-09-validador/), sesión de suggestions-rewriter-drops-german-and-polish-rewrites
---

# Las sugerencias del chat descartan las que nombran un pago recurrente real del usuario

## Qué le pasa al usuario

Una sugerencia como «¿Cuánto pagué de Netflix este mes?» o «¿Cuánto suman Alquiler y Spotify?» no se enseña aunque
Netflix, Alquiler o Spotify sean pagos recurrentes suyos: la app la toma por inventada, gasta una segunda llamada de IA
en reescribirla y, si se queda corta, cae a las sugerencias fijas.

## Lo medido (2026-10-09)

- `ChatSuggestionsLLMService` le pasa al modelo los pagos recurrentes del mes (`recurringPaidNames`, «Recurring paid
  this month» en el prompt), pero el whitelist con el que valida (`SuggestionsRewriterService.Whitelist`) solo lleva
  categorías, subcategorías, presupuestos, etiquetas y comercios.
- En el banco, con `gpt-6-luna` y 3 pasadas por contexto, es la causa de **todas** las sugerencias que la app sigue
  mandando a reescribir tras el arreglo del alemán y el polaco: unas 3 de cada 30 en casi todos los idiomas (Netflix y
  Gimnasio, Spotify y Alquiler, Rent, Miete y Deutschlandticket, Affitto y Palestra, Huur y Zorgverzekering, Czynsz,
  Telcel).

## Hecho cuando

- Un pago recurrente del usuario cuenta como nombre real al validar, y una sugerencia que lo nombra se enseña sin
  reescribirse.
- La réplica del banco (`gradeSuggestions` y el `chat.rewrite`) usa el mismo whitelist.
- Decidir antes: si el whitelist del prompt de reescritura (`toPromptSnippet`) también debe listarlos.
