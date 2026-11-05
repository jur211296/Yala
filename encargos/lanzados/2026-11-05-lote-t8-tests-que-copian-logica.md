# Lote T8 · Tests que copian la lógica, ejes del spike del borrado y selectores de registro
toca: `YalaTests/`, `YalaUITests/` (solo `test_recordSelectorsOpenAtMediumDetent`)

Rama base: 2.3. Un solo PR. Máquina: cualquiera. Usa simulador (pipeline serial, sim-lock).
Lote tests (cola-2-3-propuesta.md §3 T8).

Cards:
1. Los tests del cambio de divisa preferida copian la lógica en vez de ejecutarla.
2. Los ejes 4a y 4b del spike del borrado del store salen rojos de vez en cuando en el gate, también con la suite aislada.
3. `test_recordSelectorsOpenAtMediumDetent` falla porque toca el chip de etiquetas cuando está fuera de pantalla.

Hecha cuando: los tests ejecutan el código real, los ejes 4a y 4b pasan diez corridas seguidas y el test de selectores sale en verde.

PREGUNTAR, NO SALTAR. `tablero` + cierre con la sección «Saltado o asumido sin preguntar». Termina con /cerrar-total.

## Paso 0 — decisiones

> Resueltas en autónomo (bypass): las recomendaciones se dan por buenas. Se discuten en el PR.

**D1 · ¿Sobre qué rama?** → `2.3`, como dice el encargo, y el PR contra `2.3`. El worktree nació de `2.2`, sin commits propios; se re-apuntó la rama a `origin/2.3`.
Por qué: el encargo es del lote de 2.3 y sus cards llevan `version 2.3`. Alternativa descartada: `2.2` (lo que dice el CLAUDE.md genérico), porque mezclaría el lote con la otra línea.

**D2 · Tests de divisa: ¿cómo llamar al servicio sin red?** → Con el molde de `ManualWriteRateQualityBehaviorTests`: store de test con la fila de tasas del día sembrada, sin tocar los seams del singleton (`ensureRatesOverride`/`saveOverride`). Se lee lo PERSISTIDO con un fetch nuevo.
Por qué: los seams son estado global del singleton y otra suite (`CurrencyChangeFailureTests`) los pone a lanzar; no tocarlos evita acoplar suites. Alternativa descartada: seam no-op de `ensureRates`, innecesario con la fila sembrada.

**D3 · ¿Qué pasa con los dos casos de progreso?** → El de `% 20` llama al servicio con su `onProgress` real (45 registros ⇒ 0, 20/45, 40/45, 1); el de «progreso al completar» se sustituye por el caso del store vacío (⇒ `[1]`), que sí es una rama del servicio.
Por qué: el AC permite llamar o borrar; llamar deja red real. Se añade la pareja «monto pequeño por ENCIMA del umbral» para que mover el umbral en cualquier dirección dé rojo.

**D4 · Ejes 4a/4b: ¿se arregla el test o el harness?** → Primero se mide (corridas repetidas de la suite aislada y en frío). Si la causa está en el harness (`Yala/Services/CloudSync/SpikeR3Harness.swift`, código DEV-only del spike), se toca ahí aunque el `toca:` diga `YalaTests/`: es el instrumento del test, no producto, y ninguna otra sesión lo tiene en vuelo. El borrado real sigue fallando cerrado; no se afloja nada de producción.
Por qué: el criterio es «diez corridas seguidas en verde», y el harness es parte del instrumento. Alternativa descartada: Lista Negra sin arreglo, que no cumple el criterio.

**D5 · Selectores: el rojo de hoy no es el del título de la card.** → Se mide el rojo actual (desde el 27-oct es «el selector de etiquetas no enseña filas», no el chip fuera de pantalla) y se arregla ese. La pregunta de producto abierta del ticket (si la fila de chips enseña que hay uno más a la derecha en 402 pt) sale a su propio ticket de backlog y este se cierra.
Por qué: el encargo pide el test en verde; la pregunta de producto no es de este lote.
