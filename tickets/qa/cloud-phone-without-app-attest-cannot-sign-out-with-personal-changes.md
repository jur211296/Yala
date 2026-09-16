---
id: cloud-phone-without-app-attest-cannot-sign-out-with-personal-changes
status: qa
priority: medium
area: "modo-nube, attest, sesión"
created: 2026-09-15
updated: 2026-09-15
source: "alcance de `groups-phone-that-never-attests-is-told-to-retry-forever` (2026-09-15): la excepción de Jürgen es para los cambios de grupos"
---

# En la nube, un teléfono sin App Attest con cambios personales sin subir no puede cerrar sesión nunca

## El problema, en lenguaje de usuario

Tengo mi cuenta en la nube y este teléfono no consigue App Attest. Mis gastos nuevos no suben. Cuando quiero cerrar
sesión, Yala me dice «Hay cambios sin subir a la nube… Revisa tu conexión». Mi conexión va bien; lo intento durante días
y nada cambia.

## Lo medido (leído en el código, sin ejecutar)

- `CloudSyncRuntime.performCycle` pide el attest antes de subir (paso 2, `resolveAttest`). Sin él devuelve `.transient`
  ante cualquier error que no sea `AppAttestError.unavailable` —un `DCError` cae en el `catch` genérico—, y
  `.accountUnavailable` tras tres `.unavailable` seguidos (`AttestSyncGate.classify`). En los dos casos no sube nada del
  outbox personal.
- El cierre en la nube sube primero lo personal (`CloudSessionSignOut.performCloudSecureSignOut`, paso 1,
  `CloudMigrationController.pushAllPendingForSignOut`), que cicla ese mismo runtime. Con filas pendientes bloquea, tira el
  motivo y escribe `.permanent`: el aviso genérico que manda a revisar la conexión
  (`cloud-signout-collapses-the-personal-push-all-reason-into-permanent`).
- La salida con pérdida confirmada de `groups-phone-that-never-attests-is-told-to-retry-forever` solo alcanza a los
  cambios de GRUPOS, por decisión de Jürgen: con cambios personales pendientes, el paso 1 bloquea antes y no se ofrece.
- Perder aquí serían datos PERSONALES que no están en ninguna otra parte: en `.cloud` la copia es el servidor, y no
  llegaron.
- Sin medir: cuántos teléfonos `.cloud` están así. `cloudSyncBlockedByAttestUnavailable` solo cuenta los `.unavailable`.

## Lo que hay que decidir (Jürgen)

1. Ofrecer exportar los datos y, después, una salida con pérdida confirmada también para lo personal.
2. Solo el aviso honesto («este teléfono no puede sincronizar»), sin salida: la persona sigue sin poder cerrar sesión,
   pero sabe por qué.
3. Dejarlo hasta medir la población.

## Decisión Jürgen (2026-09-15)

**Opción 1:** ofrecer exportar los datos y, después, una salida con pérdida confirmada también para lo personal (misma idea que en grupos: texto honesto + confirmación explícita).

## Hecho el 2026-09-15 — opción 1

**Lo que cambia para la persona.** Con la cuenta en la nube, cambios suyos sin subir y un teléfono que lleva más de un día
sin conseguir App Attest. El umbral es el de Grupos: 24 h y al menos 3 rechazos contados, como mucho uno por hora, sin un
solo acierto, recordado entre arranques.

- **Cerrar sesión deja de mandar a revisar una conexión que funciona.** Ajustes enseña «Este teléfono no puede
  sincronizar tus datos», cuántos cambios no llegaron y tres botones: «Exportar mis movimientos», «Cerrar sesión y
  perderlos» y «Ahora no».
- **«Exportar mis movimientos»** genera un CSV con todos los movimientos, sin asistente, sin límite de fechas ni de plan,
  y abre la hoja de compartir. Al cerrarla vuelve el aviso. Los cambios en cuentas, categorías o presupuestos no van en el
  archivo, y el aviso los cuenta como «cambios», no como movimientos.
- **«Cerrar sesión y perderlos» no borra nada en ese momento.** El cierre intenta subir una vez: si el attest volvió, los
  cambios suben. Si no, se van con el borrado del arranque. Se pierden los cambios que contó el aviso; si aparece otro,
  vuelve el aviso con la cifra nueva. **Si el attest volvió y la subida falla por otra cosa**, el cierre se para como
  siempre, también en la salida de grupos del #173.
- **Con cambios de grupos también**, dos avisos seguidos: el de tus datos y después el de tus grupos.
- **Antes de las 24 h, sin red o con el gateway caído**, no cambia nada.

**Una premisa escrita era falsa.** `AttestSyncGate.shouldOfferCloudOnly` —la puerta que no ofrecería la nube a un teléfono
sin App Attest— no tiene llamador, y dos docblocks decían que sí: ticket
`cloud-onboarding-offers-the-cloud-to-a-phone-without-app-attest`. Hoy esta salida es la única red para esa gente.

**Lo que se tocó.** Las decisiones, con su porqué, y la tabla de la review están en el Paso 0 de
`encargos/lanzados/2026-09-15-cloud-phone-without-app-attest-cannot-sign-out-with-personal-changes.md`.

- `AttestSyncGate.countsTowardAttestStreak` y `CloudSyncRuntime`: la puerta de attest del motor personal alimenta la racha
  del TELÉFONO, la misma de Grupos, y deja su testigo por ciclo (`stoppedByUnavailableAttest(for:)`).
- `CloudSignOutFlowLogic`: el motivo `.personalAttestUnavailable`; `classify` también con la parada terminal de la puerta;
  `continuesAfterBlockedUpload`; y la aceptación por filas con nombre neutro (`LossAcceptance`, `continuesWithoutUploading`,
  `shownLossCount`).
- `CloudSessionSignOut`: el paso 1 del cierre en la nube, `exitDiscardingUnsyncedPersonalChanges` y el recuento final por
  outbox. Los tres sitios que retoman con lo aceptado exigen que el bloqueo siga siendo el attest.
- `CloudMigrationController`: el push-all pregunta el testigo al runtime y da las filas vivas del outbox.
- Ajustes (`ProfileView`): el aviso, la exportación directa con su indicador y su aviso de error, y la vuelta al aviso.
  `ExportFilters.allTransactions`, y `scheduleTagBackfill` en `TransactionsExportService` para no crear cambios al exportar.
- 8 claves en los 16 idiomas y tres canarios: `cloudSignOutAttestUnavailable`, `cloudSignOutAttestExported` y
  `cloudSignOutAttestDiscarded`.
- `.claude/rules/gateway-attest.md`: sección nueva y las anteriores acotadas a Grupos.

**Lo que queda fuera, con ticket.** El resto de motivos del paso 1
(`cloud-signout-collapses-the-personal-push-all-reason-into-permanent`), las preferencias sin subir
(`cloud-signout-drops-unsynced-preference-changes-without-counting-them`), la puerta del onboarding
(`cloud-onboarding-offers-the-cloud-to-a-phone-without-app-attest`), el `yala_attest_invalid` que tapa un fallo de D1
(`attest-gateway-reports-a-storage-failure-as-an-invalid-attestation`), los errores del asistente de exportación
(`export-errors-are-hardcoded-in-spanish`) y los tests que borran la racha del host
(`unit-tests-clear-the-attest-streak-of-a-device-qa-in-progress`). Aceptado sin ticket: la exportación corre en el hilo
principal, como la del asistente, ahora con indicador.

## Cómo se verificó

- **Build ×2** (`Yala` y `Yala Dev`): los dos en verde y con **cero warnings nuevos**. Los 14 del log son de cuatro ficheros que este cambio
  no toca (`GroupsSaveSyncTrigger` ×10, `AccountEntitlementService` ×2, `WelcomeFlowContainer`, `ContentView`).
  Medido uniendo TODOS los logs de la sesión y filtrando por los 22 `.swift` del diff: el build final no sirve
  para esto, porque es incremental y no compila los tests.
- **Unit**: **6.876 tests en 699 suites**, en diez lotes, con **un** rojo: un test del resumen de Registros que
  **pasa aislado** (39 casos en 0,21 s) y cae acompañado de las suites de grupos y FX. Es preexistente —su
  test nació en `415193daa`, de otra sesión, en un área que este cambio no toca— y queda con ticket propio,
  `records-summary-approximate-mark-fails-only-alongside-group-suites`. **La suite entera en un solo proceso
  no se pudo correr**: el sistema la mató tres veces por falta de memoria (16 sesiones de Claude Code vivas,
  6,4 GB de swap de 7,1), y en su última pasada llevaba 6.680 marcas en verde y ese mismo rojo. Lo que hizo
  viable medirla fue separar el compilador de la corrida: `build-for-testing` una vez y `test-without-building`
  después en la suite completa. La tanda de las 11 suites del área da 82 casos en 11 suites.
- **31 mutantes, 31 muertos**, en cinco lotes con su línea base verde y el árbol restaurado byte a byte al
  terminar. Cada mutante con sus tests exclusivos en rojo: la racha que no cuenta la red, el testigo sin racha,
  el `classify` sin la parada terminal, el retomar sin motivo, el paso 1 tratando todo como attest, la salida sin
  guard, el recuento final sin lo personal, «Ahora no» conservando lo aceptado, el aviso sin oferta, la cifra sin
  honestidad, los botones cruzados entre idiomas y el relleno de etiquetas al exportar.
- **XCUITest**: **71 casos en 31 clases** (las que cruzan con lo tocado), en ocho lotes con cola y centinela; el
  centinela dio 0 en los ocho, o sea sin intrusos durante las corridas enteras.
- **Un rojo, y es del entorno** (`queued-offer-after-dismiss-flakes-on-a-cold-simulator`, ya abierto):
  `AppleIDCloseNoticeUITests.test_notice_presentsThroughTheQueue_andLaterReleasesTheRouter`. Se persiguió a
  fondo —**19 corridas**, un árbol base sin el cambio, y una bisección de nueve variantes— y el veredicto es que
  **no es del cambio**: la misma compilación cae 1 de 3, y este mismo árbol, sin tocar una línea, pasó 4 de 4
  después de haber fallado 3 de 3. El sistema mató una tanda por falta de memoria con 16 sesiones de Claude Code
  vivas y 4,6 GB de swap de 6,1. Los números y las hipótesis descartadas están en ese ticket.
- **Auditoría** de las líneas añadidas: sin `try?` que silencie, sin force unwraps, y las cuatro trazas nuevas
  dentro de `#if DEBUG`.
- **Índice de cobertura** actualizado en las cinco áreas tocadas; `bash qa/validate-coverage.sh` → OK. El índice
  de tickets cuadra con el disco: 403 filas y 403 ficheros, comparados por conjunto y no por conteo.
- **Review adversarial de tres lentes** más la relectura de la regla de área contra el diff, con refutación por
  hallazgo. Lo que sobrevivió está arreglado o tiene ticket.
- **Lo que esta sesión NO puede verificar**: el recorrido en un teléfono de verdad. El guion está abajo.

## Device-QA — montaje sin verificar en esta sesión

**Montaje.** Xcode con el scheme **Yala Dev** en el simulador iPhone 17 Pro. Ningún scheme define `YALA_DEV_SHARED_SECRET`,
así que el simulador no consigue App Attest y la puerta del motor falla con `.unavailable`, que cuenta. Hace falta una
cuenta en la nube creada desde ese simulador («Tu cuenta en la nube»). Si esa opción no sale, la nube está apagada por
configuración remota y el QA no se puede montar.

> **Desde el 2026-09-16 «Tu cuenta en la nube» ya no sale en este simulador, y no es la configuración remota**
> (`cloud-onboarding-offers-the-cloud-to-a-phone-without-app-attest`): el simulador no tiene App Attest y sin él no se
> ofrece la nube. Para crear la cuenta: «Ya tengo una cuenta» → Google → firma con una cuenta de Google sin cuenta de Yala
> → «No encontramos una cuenta» → «Crear mi cuenta». Esa puerta no mira el attest
> (`cloud-sign-in-screen-offers-sign-up-to-a-phone-without-app-attest`). Si un día se cierra, crea la cuenta con
> `YALA_DEV_SHARED_SECRET` en el scheme y quítalo antes del paso 1. **Sin probar**: deducido del código.

1. Lanza la app, apunta un gasto y déjala en primer plano unos minutos, con la consola filtrada por `CloudSyncRuntime`.
   - **Esperado:** `CloudSyncRuntime stopped reason=attest-terminal` tras unos ciclos. La puerta para el motor hasta
     relanzar, así que cada lanzamiento cuenta un rechazo como mucho.
2. Relanza la app pasada una hora, y otra vez pasadas dos. Son el segundo y el tercer rechazo.
3. Pasadas 24 h desde el paso 1: Ajustes → Cerrar sesión → confirma.
   - **Esperado:** «Este teléfono no puede sincronizar tus datos», con «Cambios que no llegaron a tu cuenta en la nube: 1»
     y los tres botones.
4. «Exportar mis movimientos».
   - **Esperado:** un indicador y la hoja de compartir con un CSV que lleva el gasto. Al cerrarla, vuelve el aviso.
5. «Ahora no»: el aviso se va y la sesión sigue. Cerrar sesión otra vez: vuelve el aviso.
6. «Cerrar sesión y perderlos».
   - **Esperado:** la pantalla de reabrir la app; al relanzar, el Welcome.

**En campo, tras publicar:** `groupsAttestTerminal`, que desde hoy también cuenta teléfonos en la nube sin grupos, y
`cloudSignOutAttestUnavailable`, `cloudSignOutAttestExported` y `cloudSignOutAttestDiscarded` en Analytics Engine.

## Relación con otros tickets

- `groups-phone-that-never-attests-is-told-to-retry-forever` — de donde sale.
- `cloud-signout-collapses-the-personal-push-all-reason-into-permanent` — el motivo que el paso 1 tira.
- `personal-sync-reads-an-offline-token-refresh-as-a-session-expiry` — el mismo 401 en el canal personal.
