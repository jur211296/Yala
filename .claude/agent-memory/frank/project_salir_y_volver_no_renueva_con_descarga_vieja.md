---
name: salir-y-volver-no-renueva-con-descarga-vieja
description: PR #204 (2026-09-21) — el re-ancla de la ventana de sesión del restore pide descarga VIGENTE en vez del latch monótono; en qa esperando device-QA, y el techo con número se fue a ticket propio porque la review lo tumbó
metadata:
  type: project
---

**El re-ancla de la ventana de sesión de «Restaurar desde iCloud» ya no se apoya en un latch
monótono.** PR #204, mergeado el 2026-09-21. El ticket está en `tickets/qa/` esperando device-QA de
Jürgen: guion de 8 pasos, y el que importa es el 7 (ciclo repetido **sin** descarga pendiente ⇒ tiene
que bloquear).

**Why:** salir de Restaurar y volver a entrar renovaba el permiso que abre el guard cross-cuenta,
con dos toques y para siempre, porque bastaba un solo `.importEvent` en todo el proceso. Ahora exige
descarga vigente, así que la exposición pasa de la vida del PROCESO a la vida de la DESCARGA.

**How to apply:**

- **El techo con número NO entró, y es lo que hay que saber antes de volver a intentarlo.** Lo
  implementé y la review lo tumbó: no acotaba (`noteRestoreFinished` es alcanzable desde la UI con
  tres toques, y relanzar la app estrena todo igual) y sí bloqueaba al dueño legítimo de forma
  permanente. Lo medido está entero en el ticket `restore-session-window-has-no-reachable-ceiling`
  con los tres caminos posibles sin decidir. **El criterio 1 del ticket original queda a medias y
  así está escrito.**
- **Segundo ticket que dejó**: `import-activity-latch-survives-an-icloud-account-change` —
  `hasObservedImportActivity` sigue sobreviviendo a un cambio de Apple ID; tiene otros consumidores
  (`BootSaveGateLogic`, el gate de Grupos) y tocarlo sin ellos delante es otro ciclo.
- **Si vuelve un reporte de «mis datos son de otra persona» al restaurar**, el sospechoso es la
  frescura de 600 s de `ICloudRestoreInProgressLogic.hasLiveImportActivity`: su modo de fallo es
  cerrar antes, y para el ticket hermano cerrar antes ES el daño.

Relacionado: [[el-estado-compartido-no-es-testigo-de-su-rama]], [[el-techo-que-se-resetea-no-es-un-techo]],
[[un-plazo-nuevo-se-clava-con-sus-dos-vecinos]], [[tope-90s-no-cierra-con-import-bajando]].
