---
id: remote-wipe-alert-skips-the-router
status: backlog
priority: high
area: "sesiones, routing, onboarding"
created: 2026-09-14
source: "review adversarial de `wipe-alert-fires-on-a-session-that-no-longer-obeys-the-signal`, lente de producto y concurrencia"
---

# El aviso de «datos eliminados» se presenta desde una tarea de fondo, y si UIKit lo descarta la app deja de mostrar nada más

## El síntoma, en lenguaje de usuario

Estás mirando una pantalla que Yala te acaba de abrir —el aviso del espejo tardío, la oferta de prueba,
las novedades de la versión, el selector de idioma— y en ese momento vence una cuenta atrás interna de
cinco segundos. La pantalla que tenías delante **desaparece sola**, y en su sitio aparece un aviso de
datos borrados. Si eso sale mal, a partir de ahí **la app no vuelve a mostrarte ningún aviso**: ni la
bandeja, ni las invitaciones de grupo, ni la oferta de Pro. Solo se arregla cerrando la app.

## Lo medido (2026-09-14)

Dos hechos que por separado están bien y juntos abren un modo de fallo nuevo — es la regla escrita en
`.claude/rules/swiftui-ds.md` («Un flag de presentación que además es BLOCKER de la matriz de readiness
convierte "la presentación no montó" en un brick de toda la sesión»):

1. **El productor es asíncrono y escribe `@State` directo.** `ContentView`, `onChange` de
   `hasPersonalData`: `wipeGraceTask = Task { … showRemoteWipeAlert = true }`. La regla de área dice
   que *«si el productor de una presentación es asíncrono, va por el router; el `@State` directo solo
   vale cuando quien lo enciende es un tap»*.
2. **Ese flag es blocker de la matriz** (`ContentView`, las dos construcciones de `ShellReadinessState`,
   y `ContentViewReadinessLogic.blocker` devuelve `"remoteWipeAlert"`). Un `.alert` no tiene
   `onDismiss`, así que si UIKit descarta la presentación el flag se queda en `true` para siempre.

Y el daño del punto 1 está medido en el propio repo: `ShellDataAlertsModifier` documenta con traza de
simulador (`screenHash 1njjbcs`) que **encender un alert de este anchor desmonta el cover** que hubiera
debajo. `ContentView` lo vuelve a citar para justificar por qué el borrado del corpus del dispositivo
cancela la gracia **antes** de borrar.

**El hermano de este mismo aviso ya cumple la regla.** El otro productor de la señal de vaciado entra
por la cola: `PreferenceSyncService.checkForRemoteWipeSignal` hace
`RouterEntryGate.shared.submit(.remoteWipe(…))`, y `ContentView` lo drena. El intent existe
(`RouterIntent`). La gracia de 5 s es el único de los dos que se salta la cola.

Qué puede estar montado cuando vence la gracia, todo colgando del mismo anchor: el aviso del espejo
tardío (`lateICloudCorpus`), los ajustes de sync, la oferta de prueba, las novedades, el selector de
idioma, el restore del Welcome, y los modales de MainTab.

## La otra mitad: el aviso no dice a dónde va la persona

Sus dos ramas son `hasCompletedOnboarding = false` y `{}`. Es exactamente lo que hubo que corregir en
sus dos vecinos del MISMO fichero, donde ahora las dos ramas son explícitas sobre el aterrizaje —
porque al cerrar el alert **no queda nada montado debajo**. Este se quedó sin ello.

## Por qué no se arregló en el PR que lo encontró

Ese PR solo estrechó **quién** llega al encendido (el eje de sesión). No toca **cómo** llega, que es
esto. Y cambiar la vía de presentación es un cambio de routing con su propia superficie de riesgo.

## Criterios de aceptación

- [ ] El aviso se presenta por una vía que respeta lo que ya esté montado en el anchor.
- [ ] Sus dos ramas dicen explícitamente a dónde va la persona, como sus vecinos del mismo fichero.
- [ ] Si la presentación no llega a montar, el flag no deja la matriz de readiness bloqueada.
- [ ] Decidido si `orphan-alerts-behind-fullscreen-covers` (el mecanismo general, por el otro lado del
      mismo problema) se cierra con esto o sigue aparte.
