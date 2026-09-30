---
id: sign-out-wipe-abort-loops-the-groups-gate
status: done
priority: medium
area: "modo-nube, groups"
created: 2026-09-11
updated: 2026-09-30
source: "review adversarial de la mitad 2 del paso 5 (`groups-entry-on-a-mirrored-store-still-blocks-the-owner`), lente de pérdida de datos"
---

# Si el borrado de arranque no puede borrar los archivos, la puerta de Grupos entra en bucle

## Lo medido (2026-09-11)

`SwiftDataConfiguration.performSignOutWipeIfArmed` aborta (guard S3) cuando `deleteFiles` falla por algo
que no es «no existe», y desde el paso 9 **con el modo en `.icloud` DESARMA** en vez de reintentar — que es
lo correcto: con el espejo montado, un reintento tardío se llevaría cambios que nadie esperó a exportar.

El problema es lo que pasa después, cuando quien armó fue la puerta de Grupos:

1. El wipe aborta y desarma. Los archivos siguen ahí; `hasCompletedOnboarding` sigue `false`.
2. `presentNextOnboardingScreen` consume el destino pendiente `.groupsOrganizer` y abre el Welcome en la
   puerta.
3. La puerta re-mide: los datos siguen y el espejo también ⇒ vuelta al neutro ⇒ arma ⇒ persiste el destino
   ⇒ pantalla «reabre Yala» ⇒ el arranque siguiente vuelve al paso 1.

Cada vuelta corre además `clearLocalSurfacesForArmedWipe`, que cancela **todas** las notificaciones locales
y vacía la caché del widget. Los datos sobreviven —el borrado falló— pero la app queda dando vueltas.

## Por qué no se arregló en el PR que lo encontró

No hay señal que distinga «este arranque viene de un S3» de «este arranque es el primero»: el arm se
desarmó y los datos siguen, que es exactamente el estado de partida. Inventar esa señal es una superficie
durable nueva, y el disparador (un fallo de borrado persistente: permisos, disco, un archivo bloqueado) no
es el caso común.

## Por dónde va

- Un testigo one-shot que el abort S3 deje puesto, y que la puerta lea para enseñar una pantalla honesta
  («no pudimos preparar este teléfono») en vez de reintentar.
- O que el destino pendiente no se re-persista cuando el arranque anterior ya lo consumió sin resultado.

## Criterios de aceptación

- [x] Con `deleteFiles` fallando siempre, la puerta de Grupos deja de reintentar tras el primer intento y
      lo dice.
- [x] Las notificaciones locales no se cancelan en cada vuelta.
- [x] El camino normal (borrado que sí funciona) no cambia.

## Cierre (2026-09-30)

**Qué cambia para quien usa la app.** Si la puerta de Grupos del Welcome deja el teléfono listo para borrarse y el
arranque siguiente no consigue borrar sus archivos, la puerta ya no vuelve a intentarlo sola: enseña «No pudimos
preparar este teléfono» con «Volver», y al invitado además «Reintentar» (su puerta pregunta antes de borrar). El
siguiente intento es siempre un gesto de la persona.

**Cómo.** Testigo durable `GroupsGateWipeFailureMarker` (`cloudSync.groupsGate.wipeCouldNotDelete`):
- Lo apunta `performSignOutWipeIfArmed` en el abort S3 con modo `.icloud`, ANTES del desarme, y también cuando el
  archivo de grupos no se deja borrar (review adversarial: la puerta volvía a encontrar filas). Solo si hay destino
  pendiente de la puerta (`.groupsOrganizer`/`.groupsInvite`).
- Lo lee la puerta como primera sentencia de las celdas que borran, en las dos ramas. No va delante de la celda: en
  la de la nube su pantalla de siempre es la verdad (review).
- Lo retiran: salir del aviso, `.proceed`, el borrado que completa, «Vaciar datos» y `-uitest-reset`.

**Probado.** `GroupsGateWipeFailureTests` (hook inyectable, tres arranques con `deleteFiles` fallando siempre: un solo
intento y cero cancelaciones), `GroupsGateWipeFailureWiringTests` (orden y puerta, source-scan),
`GroupsGateWipeFailureDataWipeTests`, y el XCUITest
`WelcomeChooserUITests.testGroupsGate_afterAWipeThatCouldNotDelete_saysSoAndDoesNotRetry` (seam
`-uitest-groups-gate-wipe-failed`). Dos mutantes del hook muertos (sin la condición de la puerta: 8 fallos; sin la
limpieza al completar: 1).

**Sin device-QA**: el fallo de `removeItem` no se puede provocar en un iPhone sin herramientas; el recorrido de la
pantalla lo cubre el XCUITest y la decisión, los unit.

**Residuales con ticket:** `groups-gate-wipe-failed-notice-can-outlive-its-attempt`,
`welcome-groups-gate-button-identifiers-are-shadowed-by-their-screen`.
