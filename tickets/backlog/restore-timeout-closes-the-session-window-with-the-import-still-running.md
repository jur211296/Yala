---
id: restore-timeout-closes-the-session-window-with-the-import-still-running
status: backlog
priority: medium
area: "icloud, restore, sesiones"
created: 2026-09-21
updated: 2026-09-21
source: "medido durante `abandoned-restore-no-longer-clears-the-session-window-clock`, 2026-09-21 (D5 del Paso 0)"
---

# El tope de 90 s cierra la ventana de sesión con el import todavía bajando

## El problema, en lenguaje de usuario

Entro a «Restaurar desde iCloud» y mis datos son muchos. A los 90 s la pantalla se rinde y me dice
«seguimos trayendo tus datos» — que es verdad: siguen bajando. Toco atrás y firmo con mi cuenta. La
app me dice que **estos datos son de otra persona**. Son míos, y de hecho están entrando en ese
mismo momento.

## Medido (2026-09-21)

`RestoreProgressView.startFlow` llama a `ICloudRestoreSessionSignal.noteRestoreFinished(flowToken)`
**gane o pierda**, o sea también cuando `waitForImportQuiescence` devuelve `false` por agotar su tope
de 90 s. Ese apagado pone `restoreStartedAt = nil`, así que
`ICloudRestoreInProgressLogic.isRestoringNow` devuelve `false` en el acto y
`CrossAccountEntryGuardLogic.decide` vuelve a `.blockedForeignData` para el dueño legítimo.

Es exactamente el mismo daño que cerró `force-fetch-and-wait-ignores-cancellation` —apagar la ventana
con el import vivo— por un eje distinto: allí lo disparaba el ABANDONO, aquí lo dispara el DESENLACE.

El estado `.importIncomplete` es la prueba de que el caso existe y es esperado: se pinta precisamente
cuando el tope se agotó **con un import de CloudKit en marcha**. La pantalla afirma que los datos
están bajando y la señal ya dijo que no.

Con `abandoned-restore-no-longer-clears-the-session-window-clock` (2026-09-21) la señal ya distingue
apagar de soltar (`noteRestoreAbandoned`), así que el mecanismo para arreglarlo ya existe: falta
decidir si `noteRestoreFinished` debe apagar en los dos desenlaces o solo cuando `settled == true`.

## Por qué no se arregló de paso

Toca la semántica de `noteRestoreFinished`, que hoy documenta «gane o pierda» como una decisión, y su
source-scan (`theProgressViewClosesTheWindowWhenTheFlowEnds`) la fija con esas palabras. Cambiarla
pide medir qué pasa con el reintento, que es la superficie a la que lleva `.importIncomplete`: si el
timeout suelta en vez de apagar, la ventana huérfana sobrevive y el reintento NO estrena reloj —lo
cual es correcto o no según lo que se decida aquí.

## Criterios de aceptación

- [ ] Un restore que agota el tope de 90 s **con el import en marcha** no deja al dueño legítimo
      bloqueado en su propia cuenta.
- [ ] Un restore que agota el tope **sin nada que importar** sigue cerrando la ventana sin esperar a
      la caducidad (no se pierde la precisión que el apagado explícito aporta).
- [ ] El reintento desde `.importIncomplete` no puede re-anclar el tope duro a voluntad.

## Relación con otros tickets

- `abandoned-restore-no-longer-clears-the-session-window-clock` — de donde sale; aporta
  `noteRestoreAbandoned`.
- `force-fetch-and-wait-ignores-cancellation` — el mismo daño por el eje del abandono.
