# El aviso del cambio de Apple ID no dice todo lo que hace el cierre

---
ticket: apple-id-close-notice-does-not-say-what-else-the-close-does
modo: autonomo
cola: A
---

## Contexto
Cierre limpio de PR #301 (carril adaptativo, fase 2: Grupos/Ajustes list-detail + Yala IA en columna). Cola A autónoma sigue armada; turno Cola A (alternancia A ↔ adaptativo; este cierre fue adaptativo). Una sola sesión Yala a la vez. Ticket: `tickets/backlog/apple-id-close-notice-does-not-say-what-else-the-close-does.md` (medium, modo-nube/sesiones/copy). Cola A = riesgo real nube/sync: aquí el copy de seguridad engaña sobre un cierre destructivo (sesión, grupos del teléfono).

Hallazgo separado al cerrar #159 (`apple-id-close-blocked-has-no-visible-outcome`). La hoja «Cambiaste de cuenta de iCloud» cuenta solo que los datos se quedan en el iCloud anterior y hay que quitarlos de aquí; el cierre además cierra la sesión de Yala y, en celdas D (y C con grupos del canal nuevo), borra los grupos del teléfono tras subirlos. Ajustes ya tiene `DestructiveScopeLogic.signOutOperation` con filas por celda; este camino no la usa.

Jürgen ordenó (2026-09-28): una sola sesión Yala a la vez, alternando Cola A y carril adaptativo. Esta es Cola A. No toques simuladores `YalaLane-Adapt-*`. MODO AUTÓNOMO: elige la opción robusta / Recommended sin preguntar; no despiertes a Jürgen por preferencias reversibles. Device-QA opcional no frena merge ni `/cerrar-total`.

**Decisión de producto ya contestada (Frank, opción recomendada del ticket — no la vuelvas a preguntar):**
1. Basta con **una frase más en el mensaje**, solo cuando el cierre se lleva grupos del teléfono (celda D siempre; celda C cuando queden grupos del canal nuevo), con la misma idea que ya usa Ajustes. Ejemplo de línea: «También se quitan de este teléfono tus grupos; siguen en el servidor».
2. **No** traer la hoja de alcance completa de `DestructiveScopeLogic` a este camino: esa hoja sirve a quien decide cerrar desde Ajustes; aquí el cierre lo provoca un cambio de cuenta y la pregunta es una sola.

## Qué se pide
Cierra el ticket `tickets/backlog/apple-id-close-notice-does-not-say-what-else-the-close-does.md`.

1. **Medir primero** la hoja actual en celdas C y D (con y sin grupos del canal nuevo): qué dice hoy, qué hace el cierre de verdad (`CloudSessionSignOut.finalizeSessionExit` / `armAfterCredentials`, `forgetsGroups`, consentimiento de Grupos).
2. Añadir la frase cuando el cierre se lleve grupos del teléfono; en los demás casos no inventes ruido. Nada de lo que diga la hoja puede ser falso para esa celda.
3. Copy en los 16 locales vía `add-l10n-key.sh` (o el flujo vigente), alineado con el catálogo de Ajustes / brand voice.
4. Tests que fijen: D (siempre avisa grupos); C con grupos del canal nuevo (avisa); C sin esos grupos / celdas que no borran grupos (no afirma un borrado que no ocurre). Gate, review adversarial acotada al diff de copy/cierre, PR a `2.1`, merge y `/cerrar-total` en autónomo.

## Qué NO hay que tocar
- Carril adaptativo / iPad / simuladores `YalaLane-Adapt-*`. No `simctl shutdown all`, `erase all` ni `killall Simulator`.
- Producción / deploy.
- Cola B (UI/UX redesign) ni Cola C deferred.
- No reabrir el ticket hermano ya cerrado del bloqueo del cierre (#159).
- No montar la hoja de alcance completa en este camino (decisión arriba).
- Abrir otra sesión Yala en paralelo.
- El crash `ipad-narrowing-the-window-on-groups-crashes-the-app` (espera decisión de Jürgen; no es este turno).

## Cómo se sabe que está bien
- Cuando el cierre se lleva grupos del teléfono (D, y C con grupos del canal nuevo), la persona lo sabe antes de confirmar.
- Nada de lo que dice la hoja es falso para la celda C ni para la D.
- Tests + CI verdes; PR mergeado a `2.1`; ticket a `qa` con guion corto o a `done` si los tests lo cubren; `docs/TICKETS.md` al día; residuales a ticket propio; cierre limpio.

MODO AUTÓNOMO HASTA TERMINAR: gate, commit, PR contra 2.1, merge, board del repo (`tickets/` y `docs/TICKETS.md`) y `/cerrar-total` sin preguntar. AskUserQuestion solo si necesitas acceso, un dispositivo o una decisión demasiado importante para asumirla; lo demás lo decides tú con la opción recomendada (ya fijada arriba).

Avisos al bot dueño (Frank): POSTea al webhook local de la Mini (URL y key en fichero local, no en git) cuando: (1) necesitas una decisión de producto o de acceso de Jürgen; (2) abriste el PR; (3) terminaste y vas a /cerrar-total, con resumen corto en lenguaje de usuario; (4) acabaste un tramo sin siguiente paso claro, una vez. NO avises por test rojo que vas a reclasificar ni ruido de CI advisory.

## Paso 0

Medido en el árbol (2026-09-29):

- **Qué dice hoy la hoja** (`icloud.appleIDChanged.message`): los datos son del iCloud anterior, ahí se quedan, hay que
  quitarlos de aquí y lo que no llegó ya no sube. Nada de grupos, en ninguna celda.
- **Qué hace el cierre**: `armAfterCredentials` marca el borrado del store de grupos si
  `(kind.pushesGroups || hasBackendGroupRows) && groupsBackendCompiledCapability`. D (`privateWithGroups`) siempre;
  C (`privateOnly`) solo con filas del canal nuevo. `hasBackendGroupRows` falla hacia `true` ante un error de fetch
  (el cierre también borra entonces). D además cierra la sesión y olvida el consentimiento de Grupos.

Decisiones:

1. **Un solo predicado para la hoja y para el cierre.** La fórmula de `armAfterCredentials` pasa a una función pura
   (`CloudSignOutFlowLogic.wipeForgetsGroups`) que usan los dos. Si la hoja la copiara, divergirían.
2. **La celda de la hoja sale de la misma resolución que el tap** (capacidad COMPILADA), en vivo al pintar la pregunta.
3. **Copy**: una frase aparte, en párrafo propio (sin espacios de unión que no valen en ja/zh): «También se quitan los grupos que hay en este teléfono.»
   Sin posesivo ni «siguen en…»: la review mostró que en C las filas pueden ser de una cuenta borrada o ajena, y el
   mensaje base ya evita «tus datos» porque el teléfono puede haber cambiado de manos. «servidor» choca con la marca.
4. **Tests**: tabla pura (D avisa, C con filas avisa, C sin filas no, capacidad apagada no), mensaje compuesto,
   source-scan de que el coordinador y la hoja usan el mismo predicado, y XCUITest de la hoja con `seed: grupos`
   (celda C con grupos del canal nuevo) y `minimal` (sin la frase). Nunca se confirma en XCUITest (boot-wipe real).
5. **Asumido**: review adversarial acotada (2 lentes) porque toca una línea del coordinador del cierre.
