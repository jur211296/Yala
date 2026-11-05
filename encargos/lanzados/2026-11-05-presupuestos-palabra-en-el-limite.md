# Presupuestos: mostrar la palabra «en el límite» con el naranja al 80 %
toca: textos/UI de Presupuestos (barra y etiqueta de estado), strings en todos los idiomas

Rama base: 2.3. Un solo PR chico contra 2.3, un solo cierre. Sin simulador si solo es copy; si hace falta UI, pipeline serial.

## Contexto
Decisión de Jürgen 2026-11-05 (docs/DECISIONS.md, entrada del 5-nov): SÍ se muestra la palabra «en el límite» junto al naranja, con el mismo umbral del 80 % (`BudgetStatusCounter.atLimitPercent`). Va en 2.3 (2.2 está en QA/TestFlight y no recibe copy nuevo).

Card: «Presupuestos: «en el límite» ya no se dice en ningún sitio y el naranja de la barra va sin palabra» (tablero-presupuestos-en-el-limite-ya-no-se-dice-2ose). Cierre autónomo.

La card hermana del umbral 75 %→80 % ya está en in qa / PR a 2.2; no la reabras ni la reimplementes. Solo la palabra/etiqueta.

## Qué se pide
1. Donde la barra ya pasa a naranja al 80 %, mostrar también el texto «en el límite» (o la clave i18n equivalente según BRAND-VOICE (los idiomas de la app)).
2. Mismo umbral 80 %; no inventes otro.
3. `tablero`: en curso al empezar, in qa al cerrar, con guion corto de prueba en iPhone.

## Hecha cuando
- La palabra se ve junto al naranja desde el 80 %.
- Strings según BRAND-VOICE.
- Card en in qa.
- `/cerrar-total` con sección «Saltado o asumido sin preguntar».

PREGUNTAR, NO SALTAR. `tablero` + /cerrar-total.

## Paso 0 — decisiones

> Resueltas en autónomo (bypass): las recomendaciones se dan por buenas. Se discuten en el PR.

Hechos medidos antes de decidir: el worktree nació de 2.2 y se rehízo sobre `origin/2.3`. En 2.3 **no existe**
`BudgetStatusCounter.atLimitPercent` ni la barra al 80 %: el arreglo hermano (umbral único) está mergeado en 2.2 y no ha
llegado a 2.3, donde la barra sigue en naranja desde el 75 %. `BudgetStatusCounter.classify` sí existe en las dos ramas
y clasifica «en el límite» desde el 80 %. La app tiene 16 `.lproj` (la card dice «7 idiomas»: dato viejo). El copy
antiguo del hero retirado era «al límite»; la decisión del 5-nov dice «en el límite».

**D1 · ¿De dónde sale el umbral de la palabra?** → `BudgetStatusCounter.classify(spent:limit:) == .atLimit`.
Por qué: existe en 2.2 y 2.3 con el 80 %, y es la misma fuente que la barra lee en 2.2: al llegar 2.2 a 2.3, color y
palabra coinciden sin tocar nada. Alternativa descartada: añadir `atLimitPercent` en 2.3 (reimplementa la card hermana y
choca al mergear 2.2).

**D2 · ¿Toco la barra de 2.3 (75 %)?** → No. Confirmado por el bot dueño (opción A): solo la palabra.
Por qué: el encargo prohíbe reimplementar la card hermana. Riesgo: hasta que 2.2 llegue a 2.3, de 75 a 79 % la barra va
naranja sin palabra.

**D3 · ¿Dónde se ve la palabra?** → En la fila de la lista de Presupuestos y en el detalle, justo bajo la barra.
Por qué: es lo que pide la card («la fila y el detalle»). Las otras barras (Panel, Estadísticas, Grupos, Flujo de caja)
quedan fuera; van a «Encontrado».

**D4 · ¿Cuándo se enseña?** → Solo 80–99 %. Desde el 100 % ya hablan el rosa, el triángulo y el ánimo.
Por qué: decir «en el límite» con el límite pasado es falso.

**D5 · Copy** → es (todas las variantes): «En el límite». en/en-GB «Near your limit», de «Fast am Limit»,
fr «Proche de la limite», it «Vicino al limite», pt/pt-BR/pt-PT «Perto do limite», nl «Bijna aan je limiet»,
pl «Blisko limitu», ja «上限間近», zh-Hans «接近上限».
Por qué: en español, la palabra decidida; en los demás, el sentido (al 80 % aún no se llegó), en el tono cercano de
BRAND-VOICE. Alternativa descartada: «At limit», que afirma algo que no pasó.

**D6 · VoiceOver** → la fila (un elemento combinado con etiqueta propia) añade «En el límite» al final de su etiqueta.
Por qué: si no, quien no ve el color tampoco oye la palabra.

**D7 · Prueba** → unit del predicado (79,99 / 80 / 99,99 / 100 / límite 0) + XCUITest no: el seed no garantiza un
presupuesto al 80–99 %. QA en iPhone con guion en la card.

Ningún ADR: la decisión durable ya vive en `docs/DECISIONS.md` (entrada del 5-nov).
