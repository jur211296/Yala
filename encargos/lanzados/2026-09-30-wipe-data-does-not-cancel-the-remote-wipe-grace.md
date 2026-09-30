# «Vaciar datos» (y el wipe del restore remoto) cancelan la gracia de 5 s del aviso de vaciado remoto

---
ticket: wipe-data-does-not-cancel-the-remote-wipe-grace
modo: autonomo
cola: A
---

## Contexto
Tras CI propio aparcado (#309) y liberar-disco-mini-r3: Cola A + adaptive se reanudan. Una sola sesión Yala a la vez. Turno **Cola A** (alternancia A ↔ adaptativo). El adaptive `ipad-keyboard-shortcuts-pointer-context-menus-and-drop` fue matado antes y **sigue pendiente para DESPUÉS de este Cola A** — Avisos/Frank lo encadenan al cerrar.

Ticket: `tickets/backlog/wipe-data-does-not-cancel-the-remote-wipe-grace.md` (medium, settings/sesiones). Cola A = riesgo real nube/sync: aquí un borrado deliberado en este teléfono enciende la gracia de 5 s del aviso «tus datos fueron eliminados de iCloud» como si viniera de otro dispositivo.

Medido en el ticket (2026-09-14):
1. **Vaciar datos** (`UserDataResetView.handleWipeAllData`) es el único borrado deliberado que **no** cancela la gracia antes de bajar `hasPersonalData`. Los otros cuatro caminos sí (Welcome «empiezo de cero», corpus del dispositivo, puerta privada, Restaurar → empezar desde cero). Hoy el eje de sesión lo tapa en solo-grupos, pero la causa sigue viva: si el eje vuelve a `true`, el aviso falso reaparece.
2. **Segunda celda (mismo arreglo):** `ContentView.performLocalWipeForRemoteSync` rama `skipOnboarding: true` (onboarding ya terminado en otro dispositivo) borra local, **repone** `hasCompletedOnboarding = true` y no cancela la gracia; `dataVersion` hace caer `hasPersonalData` y a los ~5 s puede salir el aviso de vaciado remoto justo después del toast positivo. Aquí el eje **no** lo tapa.

Hermano ya cerrado: `wipe-alert-fires-on-a-session-that-no-longer-obeys-the-signal` (done) — puso el eje delante del aviso; no arregló la cancelación de la gracia.

Jürgen ordenó (2026-09-28 16:31, vigente): una sola sesión Yala a la vez, alternando Cola A y carril adaptativo. Esta es Cola A. Sims normales de Cola A — **no** toques `YalaLane-Adapt-*`. Nunca `simctl shutdown all` / `erase all` / `killall Simulator`. Disco ~46 GB libres: no llenes DerivedData/caches. MODO AUTÓNOMO / bypass: opción robusta / Recommended sin preguntar; no despiertes a Jürgen por preferencias reversibles. Device-QA opcional no frena merge ni `/cerrar-total`.

**Decisión de producto ya contestada (opción recomendada — no la vuelvas a preguntar):**
1. Cancelar la gracia en el sitio que borra a propósito, **antes** de que la señal baje — el mismo patrón que ya usan los cuatro hermanos (`onCancelWipeGrace` / equivalente).
2. Cubrir **las dos celdas** en el mismo PR: `handleWipeAllData` y `performLocalWipeForRemoteSync` (ambas ramas, con y sin `skipOnboarding`).
3. Tests con el eje de sesión **forzado a true** (o el arreglo no se distingue del tapón del eje).

## Qué se pide
Cierra el ticket `tickets/backlog/wipe-data-does-not-cancel-the-remote-wipe-grace.md`.

1. **Medir primero** las dos celdas: Vaciar datos y restore remoto `skipOnboarding` arrancan la gracia; los hermanos no.
2. Cancela la gracia en ambos caminos (y en las dos ramas de `performLocalWipeForRemoteSync`) antes de bajar filas/`hasPersonalData`.
3. Tests que fijen: con eje forzado a `true`, esos borrados deliberados no encienden el aviso de vaciado remoto a los 5 s; el camino remoto real (otro dispositivo) sigue pudiendo enseñarlo; los cuatro hermanos no regresan.
4. Gate, review adversarial acotada a gracia/wipe/restore-remoto, PR a `2.1`, merge (auto-merge OK) y `/cerrar-total` en autónomo.

## Qué NO hay que tocar
- Carril adaptativo / iPad / simuladores `YalaLane-Adapt-*`. No `simctl shutdown all`, `erase all` ni `killall Simulator`.
- Producción / deploy.
- Cola B (UI/UX redesign) ni Cola C deferred / post-2.1.
- Abrir otra sesión Yala en paralelo.
- Reabrir el hermano done del eje de sesión salvo regresión inmediata.
- Llenar el disco (DerivedData/caches/sims); margen ~46 GB libres.

## Cómo se sabe que está bien
- «Vaciar datos» cancela la gracia antes de que `hasPersonalData` caiga, como sus cuatro hermanos.
- `performLocalWipeForRemoteSync` cancela en las dos ramas.
- Tests con eje forzado a `true` + CI verdes; PR mergeado (o en cola auto-merge) a `2.1`; ticket a `qa` o `done` según cobertura; residuales a ticket propio; cierre limpio.

MODO AUTÓNOMO HASTA TERMINAR: gate, commit, PR contra 2.1, merge/cola, board del repo (`tickets/` y `docs/TICKETS.md`) y `/cerrar-total` sin preguntar. AskUserQuestion solo si necesitas acceso, un dispositivo o una decisión demasiado importante para asumirla; lo demás lo decides tú con la opción recomendada (ya fijada arriba).

Avisos al bot dueño (Frank): POSTea al webhook local de la Mini (URL y key en fichero local, no en git) cuando: (1) necesitas una decisión de producto o de acceso de Jürgen; (2) abriste el PR; (3) terminaste y vas a /cerrar-total, con resumen corto en lenguaje de usuario; (4) acabaste un tramo sin siguiente paso claro, una vez. NO avises por test rojo que vas a reclasificar ni ruido de CI advisory. Al cerrar, Avisos/Frank debe encadenar el adaptive pendiente `ipad-keyboard-shortcuts-pointer-context-menus-and-drop` (fue matado antes; toca DESPUÉS de este Cola A).

## Paso 0 (Frank, 2026-09-30 — autónomo, auto-contestado)

**Medido antes de decidir:**
- `wipeAllUserData` NO bumpea `dataVersion` (lo dice ContentView y lo confirma el grep). El ticket afirmaba lo contrario: `hasPersonalData` cae en el SIGUIENTE bump de quien sea, en un momento no acotado.
- Cancelar la gracia «antes» no la evita: la tarea la crea el `onChange(hasPersonalData)` en el render SIGUIENTE, cuando el `cancel()` ya pasó (lo documenta el propio `onChange`, término `!showFullModeActivation`). Los cuatro hermanos no se salvan por su `cancelWipeGrace()` sino porque bajan `hasCompletedOnboarding` y cierran el guard. Las dos celdas del ticket lo REPONEN, así que el «mismo patrón» literal no arreglaría nada — heredaría la forma del bug.

**Decidido:**
1. El sitio que borra a propósito cancela la gracia **y** re-mide las señales en la misma vuelta del main actor que el borrado, dejando armada una absorción de UNA caída: la siguiente transición `true → false` de `hasPersonalData` se reconoce como deliberada y no arranca la gracia. Se desarma en la primera transición en cualquier sentido, o si la medida dice que los datos siguen.
2. La decisión va a un tipo puro (`RemoteWipeGraceLogic`) que `ContentView` usa tal cual, para poder probarlo con el eje forzado a `true`.
3. `UserDataResetView` no ve el estado de `ContentView`: pide el asentamiento por `SessionState` (contador observado), en éxito y en fallo (un borrado a medias baja la señal igual).
4. `performLocalWipeForRemoteSync`: asentamiento tras el `do/catch` del borrado, antes del primer `await` ⇒ cubre las dos ramas de `skipOnboarding`.
5. Tests: unitarios del tipo puro (eje forzado a `true`, camino remoto real sigue avisando, hermanos sin regresión) + source-scan del cableado en los dos sitios. Mutantes a mano sobre los puntos de carga.
6. Ticket a `qa` (el guion de dispositivo no frena el merge).
