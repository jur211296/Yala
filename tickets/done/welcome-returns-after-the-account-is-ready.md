---
id: welcome-returns-after-the-account-is-ready
status: done
priority: critical
area: "welcome, cloud sync"
created: 2026-11-13
updated: 2026-11-22
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

## Cierre (2026-11-22)

**Ya no pasa en `2.3`.** La causa era la que apuntaba «Por dónde mirar»: el respaldo del `onDismiss` del cover
(`welcomeCoverDidDismiss`) leía `hasCompletedOnboarding` del `@Binding` capturado al presentar el cover (`false`), y
`onAdoptStarted` lo marca con el cover abierto; el respaldo reabría el elector encima de la app. Se arregló el 14-nov en
el lote A del barrido del iPhone 14 (card c8i9): el respaldo lo lee de disco. Este ticket no se movió entonces.

**Qué se añadió ahora:** la prueba de interfaz que faltaba, `YalaUITests/WelcomeTrasCuentaLista/WelcomeTrasCuentaListaUITests`,
con cuatro casos que recorren el final de cada entrada por los callbacks de producción (seam
`-uitest-unified-access-phase reentry-ready|born-ready|groups-only`, sin red): re-entrada en Modo Nube («¡Tu cuenta está
lista!» → «Empezar»), alta en Modo Nube («Creamos tu cuenta» → conversación), cuenta nueva con iCloud privado y cuenta de
solo grupos (primer grupo → Grupos). Los cuatro afirman que se llega a la app y que la bienvenida no vuelve en los 6 s
siguientes.

**Medido:** los cuatro en verde (iPhone 17 Pro, iOS 27.2). Con el mutante —el respaldo leyendo otra vez el `@Binding`—
la re-entrada cae con «tras entrar, Yala volvió a la bienvenida»: la prueba distingue el fallo del ticket.
Evidencia (antes con el mutante, después con el código actual): `~/Claude/entregas/2026-11-22-welcome-vuelve-tras-cuenta-lista/evidencia/`.

**Sin probar en el iPhone:** la re-entrada real con Google y backend de staging. El simulador no inicia sesión; la
prueba cubre el cierre del cover, que es donde estaba el fallo.
