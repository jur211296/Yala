# Implementar ticket: remote-wipe-alert-skips-the-router

## Contexto
Una más (Jürgen: decide orden). High del review de #162: la gracia de 5 s enciende `showRemoteWipeAlert` desde Task de fondo (salta el router), es blocker de readiness, y si UIKit descarta el alert el flag queda true → ningún aviso más hasta matar la app. Además las ramas del alert no dicen a dónde aterriza.

## Decisiones (Frank, cola)
- Presentar por el router / cola (`RouterEntryGate` / `.remoteWipe`), como el otro productor — no `@State` directo desde Task.
- Las dos ramas del alert con aterrizaje explícito, como vecinos del mismo fichero.
- Si la presentación no monta, el flag no deja la matriz bloqueada.
- `orphan-alerts-behind-fullscreen-covers` **sigue aparte** (no se cierra con este ticket).

MODO AUTÓNOMO HASTA TERMINAR: review adversarial (routing/presentación), gate, commit, board, `docs/TICKETS.md`, merge, `/cerrar-total`. Bugs/decisiones nuevas → ticket `--solo-crear` y avisar a Frank. Device-QA → `tickets/qa/` si aplica.

Avisos a Frank: (1) decisión/acceso; (2) PR; (3) `/cerrar-total` resumen producto; (4) idle una vez.

No lances el siguiente: pausa tras este. No marketing/.

## Que se pide
1. Leer ticket + ContentView wipeGraceTask + ShellDataAlertsModifier + RouterIntent.remoteWipe.
2. Cumplir criterios de aceptación (salvo cerrar orphan-alerts).
3. PR a `2.1`; board/`TICKETS.md`; `/cerrar-total`.

## Que NO hay que tocar
marketing/. Cerrar orphan-alerts en este PR. Wipe de prod.

## Como se sabe que esta bien
Criterios; tests; PR mergeado; `/cerrar-total`.

## Paso 0 — decisiones resueltas (2026-09-14, autónomo)

**D1 · El intent es NUEVO, no `.remoteWipe`. La premisa del encargo estaba mal en el CASE.**
Medido: `.remoteWipe` no presenta el aviso — su drenaje llama `handleRemoteWipeSignal`, que **borra**
(`performLocalWipeForRemoteSync`). Reusarlo convertiría un aviso que pregunta en un borrado silencioso.
La vía sí es la del encargo (la cola); el case es `.presentRemoteWipeNotice`, al FINAL del bloque F
(el orden del enum se lee desde fuera), id `"remoteWipeNotice"`.

**D2 · `.high` y no `.critical`, y no transitorio.** `.high` hace que un `.remoteWipe` de verdad lo
tire de la cola por la regla que ya existe (`remoteWipe_supersedes_nonCritical`): si la señal explícita
llega, el aviso que sólo SOSPECHA sobra. No transitorio, como sus hermanos de sistema: sobrevive a un
background y lo re-mide el drenaje.

**D3 · El drenaje RE-MIDE las tres condiciones vivas** (eje de sesión, los datos siguen ausentes, el
onboarding sigue completo) en vez de fiarse del veredicto del productor: el intent puede esperar en cola
a través de un background entero, y el aviso afirma un hecho sobre AHORA.

**D4 · La red anti-brick: verificación de presentación efectiva.** Tras encender, se comprueba que
UIKit presentó de verdad (hay algo presentado sobre el root). Si no, se reintenta con el molde ya
existente (`RelaunchNetLogic`: toggle false→true, cadencias y cap del ciclo); al agotarse, el flag se
APAGA —la matriz queda libre— y salta un canario. Se pierde el aviso, no la sesión.

**D5 · Aterrizajes.** Confirmar aterriza donde ya aterriza el wipe remoto por señal: el Hero del
Welcome, fijando `hasShownWelcomeChooser = false` para que el destino no dependa de lo que hubiera.
Cancelar se queda en la app: con el aviso presentado por la cola, debajo sigue montada la shell —que es
lo que la premisa del ticket daba por perdido, y sólo era cierto mientras el alert se encendía desde la
tarea de fondo.

**D6 · Cancelar la gracia pasa a retirar también el intent de la cola.** Ocho call-sites hacen hoy
`wipeGraceTask?.cancel()`; con el aviso en la cola, cancelar la tarea ya no basta. Se unifican en
`cancelWipeGrace()`.

**Fuera:** `orphan-alerts-behind-fullscreen-covers` (sigue aparte), el wipe de producción, `marketing/`.
