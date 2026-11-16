---
id: welcome-returns-after-the-account-is-ready
status: backlog
priority: critical
area: "welcome, cloud sync"
created: 2026-11-13
updated: 2026-11-13
source: "Device-QA del bloqueo de 15 min, iPhone 14, cuenta de staging, 2026-11-13 09:41 (Jürgen: «ERROR GRAVE»)"
---

# Tras «Ya está tu cuenta», Yala vuelve a la bienvenida y hay que reabrir la app

Decisión de Jürgen (13-nov, 09:46): después de «Ya está tu cuenta» Yala nunca debe volver a la bienvenida ni pedir reabrir;
se pasa directo al Panel. Se verá en una sesión interactiva; no se arregló en el PR del bloqueo de 15 min.

## Lo medido (no lo inferido)

- Teléfono recién vaciado con «Cerrar sesión» de Ajustes (store personal y de Grupos a cero; solo tipos de cambio).
- «Entrar con Google» con la cuenta de staging (`7fa23530…`, con grupos) a las ~09:40:40; «Conectando con tu cuenta… 0 %»
  a las 09:40:53; el adopt terminó en unos 40 s.
- Estado al terminar (leído del iPhone): journal `notStarted` sin efectos pendientes, `cloudSync.storageMode = cloud`,
  `cloudSync.migration.relaunchRequested` (= `mirrorOffArmed`) `true`, `cloudSync.claimAction.<sub> = routeReturningUser`,
  `hasCompletedOnboarding = true`, store con 2 cuentas ya bajadas. O sea, el adopt terminó bien.
- Jürgen vio «Ya está tu cuenta» (la fase `.reentryReady`, que sale de `.cloudActive`; su botón llama a `onFinishedToApp`,
  que cierra el cover). Al tocarlo apareció la bienvenida (Hero con «Entrar con Google») **en el mismo proceso**: el pid de
  Yala Dev no cambió hasta que Jürgen la cerró a las 09:43:28.
- Al reabrirla en frío (09:43:34) llegó al Panel al instante con los datos de la cuenta (7 movimientos, 5 cuentas).

## Por dónde mirar (inferido, sin medir)

El cierre del cover pasa por `ContentView.welcomeCoverDidDismiss` (respaldo que reabre el chooser con
`!hasCompletedOnboarding`) y por la decisión de pantalla del `ContentView`; el `@State`/`@AppStorage` que lee
`hasCompletedOnboarding` en ese instante, o un destino del Welcome que dejó el cierre de sesión previo
(`persistDestinationOnArm`), son los candidatos. Falta un log del momento del toque. Captura:
`~/Claude/entregas/2026-11-13-bloqueo-15-min-conectando-grupos/evidencia/encontrado-bienvenida-tras-ya-esta-tu-cuenta.jpg`
y el vídeo `flujo-entrada-con-grupos.mp4` de la misma carpeta.
