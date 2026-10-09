---
id: suggestions-rewriter-drops-german-and-polish-rewrites
status: qa
priority: medium
area: chat, ai, l10n
created: 2026-10-07
updated: 2026-10-09
qa-status: needs-testing
source: banco de chat.rewrite (sesión 2 del gateway de IA, gateway/bench/results/2026-10-07/REPORT-chat-y-nota.md)
---

# Las sugerencias del chat en alemán (y a veces en polaco o inglés) caen siempre a las fijas

## Qué le pasa al usuario

Con Yala en alemán, las sugerencias del chat que reescribe la IA no se enseñan nunca: la app las descarta y pone las
fijas, con cualquier modelo.

## Lo medido (2026-10-07)

- `SuggestionsRewriterService.isValid` toma por nombre propio toda palabra con mayúscula que no sea la primera. En alemán
  todos los sustantivos van con mayúscula («Ausgaben», «Monat»), así que ninguna reescritura pasa.
- En polaco no casan los nombres declinados («w Biedronce» frente a «Biedronka»); en inglés, los meses («October»).
- El banco lo replica en `gateway/bench/lib/chatRewrite.ts` y lo mide aparte («lo que la app conserva»).

## Hecho cuando

- Una reescritura alemana correcta pasa el validador y se enseña; una con un comercio inventado sigue sin pasar.
- Test con frases reales en alemán, polaco e inglés.

## Arreglo (2026-10-09)

`SuggestionsRewriterService.isValid` recibe el idioma de la app y una palabra con mayúscula ya no invalida la frase si:

- es una palabra común **de ese idioma**: en alemán, los sustantivos genéricos de una pregunta de finanzas («Monat»,
  «Ausgaben», «Kosten», «Budget», «Vergleich», «Wochentagen»…), meses, días y el «Sie» formal; en polaco, el «Ci/Twój»
  de cortesía; en inglés, «I», meses y días. No entran sustantivos que podrían ser una categoría inventada («Abos»,
  «Rechnungen», «Miete», «Strom»): esos tienen que estar en la lista del usuario;
- en polaco, es una forma declinada de un nombre de la lista: raíz sin la vocal final, con la alternancia del
  locativo (k→c, g→dz, ch→sz, ł→l, t→ci, d→dzi, r→rz), y 4 letras o menos detrás («Biedronce», «Żabce», «Aptece»,
  «Rozrywkę», «Restauracjach»);
- en alemán, es el plural con diéresis de un nombre de la lista («Supermärkte» de «Supermarkt»).

La réplica del banco (`gateway/bench/lib/chatRewrite.ts`) lee las listas del Swift y repite la lógica; las mismas
frases se prueban en los dos lados (`YalaTests/SuggestionsRewriterServiceTests.swift` y `gateway/test/ai.bench.test.ts`).

## Lo medido después (2026-10-09, `gpt-6-luna`, el modelo de producción; gasto 0,024 USD con `--max-usd 0.10`)

Reescrituras (`chat.rewrite`, 3 pasadas por caso). «Antes» es la pasada del 2026-10-07 con el mismo modelo.

| Caso | Antes: la app conserva | Antes: ≥ 3 sugerencias al final | Ahora: conserva | Ahora: ≥ 3 | Inventadas conservadas |
|---|---|---|---|---|---|
| alemán (`rw-de`) | 6 de 15 | 0 de 3 | 6 de 6 | 3 de 3 | 0 |
| polaco (`rw-pl`) | 3 de 9 | 3 de 3 | 9 de 9 | 3 de 3 | 0 |
| inglés (`rw-en`) | 6 de 9 | 3 de 3 | 9 de 9 | 3 de 3 | 0 |
| casos nuevos `rw-de-02`, `rw-pl-02`, `rw-en-02` | — | — | 27 de 27 | 9 de 9 | 0 |
| los otros 11 idiomas | 99 de 99 | 33 de 33 | 99 de 99 | 33 de 33 | 0 |

En `rw-de` hoy solo se reescriben 2 frases (antes las 5 del caso: el validador viejo rechazaba también las buenas).
Re-calculado sobre las 1 936 frases guardadas del 2026-10-07 (7 modelos): alemán 44 → 220 de 220, polaco 88 → 131 de
132 (la que falta nombra Netflix, inventado), inglés 91 → 132 de 132; ninguna inventada pasa, ni antes ni después.

Primera pasada (`chat.suggestions`, 3 pasadas por contexto): cuántas enseña la app sin pasar por la reescritura.

| Contexto | Antes | Ahora |
|---|---|---|
| alemán (`de-01`) | 5 de 29 | 27 de 29 |
| polaco (`pl-01`) | 18 de 30 | 27 de 30 |
| los demás | iguales | iguales |

Las 25 frases que se abren nombran solo cosas reales del usuario (revisadas una a una). Todas las que siguen sin
pasar nombran un pago recurrente real (Netflix, Miete, Telcel…), que el whitelist no incluye: ticket aparte,
`chat-suggestions-reject-the-users-own-recurring-payments`. Datos: `gateway/bench/results/2026-10-09-validador/`
(la corrida de `calibracion/` es la de antes de añadir «Wochentagen», el «Ci/Twój» polaco y la diéresis alemana).

## Device-QA (Jürgen, iPhone con Yala Pro)

Sin capturas de simulador: ver las sugerencias de la IA exige App Attest y el simulador no lo tiene sin el secreto de
staging. La lógica la cubren los tests y el banco; esto confirma que llega a la pantalla.

1. Instala el build que lleve este cambio (TestFlight o Xcode con el scheme `Yala`).
2. En la app **Ajustes del iPhone** → baja hasta **Yala** → **Idioma** → **Deutsch**. iOS reabre Yala en alemán.
3. Abre **Yala IA** (el chat). En la burbuja de bienvenida mira las tres sugerencias.
4. **Pasa si** al menos una nombra algo tuyo (una categoría, un comercio o un presupuesto que tengas, p. ej. «Wie viel
   habe ich diesen Monat bei … ausgegeben?»). Las fijas son genéricas y no nombran nada tuyo; si salen solo ésas,
   no pasa.
5. Si hoy ya abriste el chat en alemán, las sugerencias vienen de la caché del día: repite mañana o cambia a otro
   idioma y vuelve a Deutsch.
6. Repite los pasos 2–4 con **Polski**. Vuelve a tu idioma al terminar.
