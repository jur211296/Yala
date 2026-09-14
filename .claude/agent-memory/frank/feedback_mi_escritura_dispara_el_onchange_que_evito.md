---
name: mi-escritura-dispara-el-onchange-que-evito
description: Cancelar un efecto ANTES de escribir el @State no cancela nada: el `onChange` que lo arma corre en el update SIGUIENTE. Y el guard que lo tapaba puede depender de algo que tu caso nuevo conserva a propósito.
metadata:
  type: feedback
---

**Si tu código baja un `@State` y hay un `.onChange` que reacciona a esa bajada, cancelar el efecto
ANTES de escribir no sirve: la tarea la crea el `onChange` en el update siguiente, cuando tu `cancel()`
ya pasó.** El orden «cancelar, luego escribir» parece kill-safe y es inerte.

**Why:** el 2026-09-14, en el borrado de «Activar Yala completo → Restaurar → Empezar desde cero». El
envoltorio hacía `wipeGraceTask?.cancel()` antes del `await` —copiado del molde correcto de
`performDeviceCorpusWipe`, donde sí vale porque allí la bajada la produce el propio `wipeAllUserData`— y
después re-medía `hasPersonalData`. Esa asignación disparaba el `.onChange`, que armaba la gracia de 5 s,
y al vencer levantaba el alert de wipe remoto **sobre alguien que estaba escribiendo su nombre en el
onboarding**. Colgando del anchor de `ContentView`, ese alert **desmonta la sheet**; y su botón
destructivo lo dejaba en el Welcome con la activación a medias. Lo cazó la lente de flujo; la suite
estaba verde y el source-scan que lo daba por cubierto comprobaba que el `cancel()` iba ANTES de la
llamada, que es justo lo que no protege.

**La segunda mitad es la que no se ve:** el guard del `onChange` llevaba `&& hasCompletedOnboarding`, y
cerraba solo para los otros borrados **porque ellos se llevan esa key de paso**. El caso nuevo la
CONSERVA a propósito —es lo que impide mandar al Welcome a quien está a mitad de activar— así que era el
único que llegaba con el guard abierto. Un término que te protege «por accidente» deja de hacerlo en
cuanto añades un caso que no tiene ese efecto colateral.

**How to apply:**

- Al escribir un `@State` desde código propio, busca **todos** los `.onChange` de esa propiedad y lee sus
  guards. Pregunta por cada término: *¿es verdad en MI caso, y por qué?*
- Si un guard cierra por un efecto colateral de otro camino (una key que ese camino borra), **no cuenta
  como red para el tuyo**: hazlo explícito con un término propio y legible (aquí,
  `&& !showFullModeActivation` — «mientras la activación está en pantalla, unos datos que desaparecen no
  son un wipe remoto: los está borrando la persona que mira»).
- Cancelar después tampoco arregla: la tarea todavía no existe cuando tu closure termina. La salida es
  **impedir el armado**, no cancelarlo.
- Y el test: afirmar el ORDEN del `cancel()` no distingue esto. Lo que lo fija es el término del guard.

Relacionado: [[feedback_el_consumidor_lee_una_copia]] · [[feedback_mi_arreglo_rompe_la_premisa_de_otro_guard]] ·
[[feedback_un_gate_derivado_de_una_ausencia_falla_abierto]]
