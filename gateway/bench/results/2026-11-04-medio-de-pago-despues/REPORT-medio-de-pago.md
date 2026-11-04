# text.parse · medio de pago (card v466) — antes y después

Banco del 2026-11-04, `openai:gpt-6-luna`, esfuerzo `low` (la fila `text.parse` de `routes.ts`), una pasada por caso.
Antes: `2026-11-04-medio-de-pago-antes/` (prompt y esquema de `origin/2.3`). Después: esta carpeta (prompt con
«Reglas de medio de pago», un ejemplo «25 almuerzo yape» y `paymentHint` en el esquema estricto).

## Coste por llamada (los mismos 51 casos de siempre)

| | Tokens entrada | Tokens salida | USD / 1 000 llamadas (medido, con caché) | USD / 1 000 sin caché |
|---|---|---|---|---|
| Antes | 3 252 | 175 | 0,248 | 0,413 |
| Después | 3 527 | 183 | 0,265 | 0,445 |
| Diferencia | +275 (+8,5 %) | +8 | +0,017 | +0,032 (+7,7 %) |

Unos 3 centavos de dólar más cada 1 000 frases leídas, en el peor caso (sin caché). El prompt no lleva los nombres de
las cuentas del usuario: la cuenta la elige la app.

## Acierto

- Los 51 casos de siempre: 51/51 antes y 51/51 después (importe, tipo, fecha, divisa y subcategoría sin cambios).
- Los 24 casos nuevos `pago-*` (11 de Perú, y Argentina, España, inglés, Brasil, Francia, Alemania, Italia, Países Bajos,
  Polonia, Japón y China): 24/24. Incluye «todo con yape» (va a los dos movimientos), «café con yape y taxi en
  efectivo» (cada uno el suyo), «yapeé» y dos frases sin medio de pago (sin pista).
- En los 51 de siempre el modelo dio una sola pista: `de-02` «Miete 1.150 € überwiesen» → «überwiesen» (transferencia).
  Está escrita en la frase y no nombra ninguna cuenta ni clase del léxico, así que la app no elige cuenta con ella.
