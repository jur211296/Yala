---
id: handover-leaves-the-storage-mode-without-a-session
status: backlog
priority: low
area: "modo-nube, sesiones, handover"
created: 2026-09-17
source: "review adversarial de `previous-person-cloud-session-survives-fresh-start-and-reinstall` (lente de escritores), 2026-09-17"
---

# Tras el relevo, el modo de almacenamiento sigue diciendo «nube» y ya no hay sesión

## Lo medido (2026-09-17, leído en el código)

`cloudSync.storageMode` (`CloudSyncFlags`) está **excluido a propósito** del barrido de preferencias
(`DataWipeService.removeUserPreferenceKeys` documenta el prefijo `cloudSync.*` como exclusión: es infra
del propio sign-out y la gobierna `StorageModePersistence` en el orden kill-safe del boot).

Desde el 2026-09-17 «Empezar desde cero» retira la sesión en la nube (`CloudSessionRetirement`). En un
teléfono con `storageMode == .cloud` eso deja un par que antes no existía: **modo `.cloud` + sin sesión**.
Los consumidores leen `canRenewSession == false` y encaminan a «vuelve a entrar», que para la persona
NUEVA es un callejón: la cuenta no es suya.

## Por qué es `low`

**No se encontró una entrada alcanzable**, y eso está medido, no supuesto: las tres puertas del relevo
cuelgan del Welcome, y con `.cloud` el teléfono tiene `hasCompletedOnboarding == true`, así que el Welcome
no se monta. Queda como pregunta abierta si el par `.cloud` + `hasCompletedOnboarding == false` es
alcanzable después de un cierre de sesión.

## Criterio de aceptación

- [ ] Medido si el par es alcanzable. Si lo es, el relevo devuelve el modo a `.icloud` (que es lo que hace
      `performSignOutWipeIfArmed` en su camino); si no lo es, se escribe por qué y se cierra.
