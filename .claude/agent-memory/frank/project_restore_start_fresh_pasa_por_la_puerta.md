---
name: restore-start-fresh-pasa-por-la-puerta
description: PR #155 (2026-09-14) — «Empezar desde cero» en Restaurar entra a la puerta de iCloud y borra de verdad. Qué quedó fuera, con qué ticket, y qué falta verificar en device.
metadata:
  type: project
---

**«Empezar desde cero» en la pantalla de Restaurar ya borra: entra a la puerta de iCloud del paso 4.**
Antes solo limpiaba dos preferencias y abría el onboarding, con el espejo adjunto bajando el corpus por
debajo — bajo un copy que prometía «sin tus datos previos». PR #155, rama
`encargo/2026-09-14-restore-start-fresh-keeps-the-imported-corpus`.

**Why:** era un `high` de la cola del rediseño de sesiones, la misma familia que el bug del paso 4 por
otra puerta.

**How to apply:**

- **La activación de Yala completo NO cambió**, y su asimetría está pinneada por test. Allí el borrado
  es de ZONA (restricción del paso 8: `wipeAllUserData` resetea el onboarding y mandaría al Welcome a
  quien está activando) y con el store espejando deja las filas importadas, que se re-exportan: un
  borrado que no borra. Cerrarlo pide un borrador de **filas sin preferencias** que no existe —
  `resetAllUserPreferences` toca router, ProTour, checklist y los espejos del App Group, no solo keys.
  Ticket `activation-restore-start-fresh-keeps-the-imported-rows` (**high**).
- **Y el «volver» de la puerta deja en la rama contraria** («Es mi primera vez» tras haber entrado por
  «Ya tengo una cuenta»). VISTO en simulador. Sin pérdida de datos; arreglarlo pide payload en el
  `case privateICloudGate`, que tiene pin literal. Ticket
  `private-icloud-gate-back-lands-on-the-wrong-branch` (**medium**).
- **El device-QA NO es simulable** y son cinco recorridos, en `tickets/qa/`. El que de verdad cierra el
  criterio es instalar en OTRO dispositivo con el mismo Apple ID y ver que ya no encuentra nada. Dos
  pruebas nacen de la review y conviene no saltárselas: que tras borrar **no salga un tercer alert**, y
  que lo restaurado por «Traer mis datos» **siga ahí un par de arranques después** (el arm huérfano lo
  borraba entero).
- **Residual sin ticket:** con un corpus grande el borrado puede salir `importNotQuiescent` (30 s de
  espera de quiescencia contra un import que sigue en vuelo). No es callejón — la pantalla de fallo
  ofrece «Reintentar» sin salir— pero este PR lo vuelve más frecuente.
