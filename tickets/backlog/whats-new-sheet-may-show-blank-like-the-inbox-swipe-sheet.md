---
id: whats-new-sheet-may-show-blank-like-the-inbox-swipe-sheet
status: backlog
priority: medium
area: "whats-new, ui"
created: 2026-11-13
updated: 2026-11-13
source: "review adversarial del lote de fallos altos (2026-11-12), al buscar el mismo patrón que la hoja de éxito de la Bandeja"
---

# «Novedades» usa el molde que dejaba vacía la hoja de éxito de la Bandeja

## Qué se vio (en el código, sin reproducir)

`ContentView` presenta Novedades con `.sheet(isPresented: $showWhatsNew)` y saca el contenido de otro `@State`
(`whatsNewData`, una tupla) con `if let data = whatsNewData`. Los dos se escriben en el mismo paso (el manejador de
`.presentWhatsNew`) y el `body` no lee `whatsNewData` fuera del cierre. Es la trampa de `swiftui-ds.md` («sale VACÍA
si el `body` no lee ese estado fuera del cierre»), la misma que el 2026-11-12 dejaba vacía la hoja de éxito de
deslizar en la Bandeja **a ratos** (1 de 2 vueltas medidas).

Si muerde: Novedades sale en blanco y, además, su `onDismiss` no apunta `lastSeenAppVersion` (lee `whatsNewData`, que
quedaría en `nil` también ahí), así que volvería a salir en el arranque siguiente.

`WhatsNewLaunchUITests` espera el título y pasa, pero el fallo de la Bandeja era intermitente: un verde suelto no lo
descarta.

## Qué hacer

El molde de la regla: `.sheet(item:)` con un valor identificable que lleve `features` y `version`, y el `onDismiss`
apuntando la versión del valor presentado. Medir antes con `-test-iterations 3 -run-tests-until-failure` sobre
`WhatsNewLaunchUITests` para saber si hoy reproduce.
