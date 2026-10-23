---
id: cloud-activation-stalls-without-uploading-until-relaunch
status: done
priority: high
area: "attest, modo-nube"
created: 2026-10-19
updated: 2026-10-20
source: "tablero-activar-la-nube-se-queda-en-60-sin-subir-axgf (QA guiado 2026-10-19)"
---

# «Activar la nube» se queda al 55 % sin subir nada hasta cerrar y abrir Yala

## En lenguaje de usuario

Toco «Activar la nube» en un iPhone recién instalado. La barra se para en «Activando la nube» y «Retomar» sale apagado. Pasan diez minutos y no sube nada. Cierro Yala del todo, la abro, y en segundos sube.

## Lo medido (2026-10-19)

- Telemetría de producción: el iPhone que migraba es la instalación `79a1ba45` (`cloudConsentAccepted migration` 22:13:05). **No emitió ningún `cloudSyncAttestRequired`** ni `cloudSnapshotUploadWaiting` antes de reabrir; el spool de métricas es kill-tolerante, así que no se perdió. El `cloudSyncAttestRequired prefs-pull` de las 22:17:20 que citaba la card es del iPad (`5fc8fa9f`). ⇒ la premisa «401 de attest en producción» era falsa para ese iPhone: el push del snapshot **nunca llegó a salir**.
- La barra al 55 % es `uploadingSnapshot`, y «Retomar» apagado es `isWorking`: una pasada del runner esperando dentro de un `await`.
- En ese tramo, el único `await` sin techo es el token de App Attest: `AppAttestClient.currentSessionToken` colapsa todo en un single-flight y nadie le pone techo. `DCAppAttestService` (`attestKey`, `generateAssertion`) y `Transaction.currentEntitlements` no traen timeout; token de Supabase y lease van por `URLSession` (60 s).
- INFERIDO: el refresh del attest se colgó y todo el que pedía token esperaba para siempre. Relanzar mata la tarea colgada.

## Lo que cambia

1. **Techo de 90 s a la espera de un refresh en vuelo** (`AttestSessionTokenLogic.refreshStallCeiling`). Vencido, la tarea se abandona, el que espera recibe un error de red (pasajero, sin sumar a la racha del teléfono) y el siguiente llamador arranca otra. Canario `attestRefreshAbandoned` con el paso en el que se quedó (`refreshStage`): confirma o refuta la inferencia en la flota.
2. **Un 401 `yala_attest_required` hace olvidar el token que viajó** (`AttestSessionProvider.reportRejected(sentIn:)`, en los ocho sitios que leen ese 401), y el reintento de cada llamador pide uno nuevo. Cierra `attest-session-token-rejected-by-the-gateway-stays-cached`.
3. **El executor de la migración ya no pide el token con `try?` mudo** (`CloudMigrationController.migrationAttestProvider`): deja rastro y sigue con el contrato «cabecera o nada».

Precio aceptado: si la tarea abandonada vuelve a la vez que la nueva, pueden cruzarse dos assertions con la misma key y el gateway rechaza la de contador menor (un error más, con su backoff).

## Tests

`AttestSessionTokenLogicTests` (techo y olvido, con controles), `AttestSessionTokenWiringTests` (los 8 sitios y el cuerpo de la espera, sin `TaskGroup`), y en `MigrationWorkExecutorTests` el 401 de la subida: olvida exactamente el token que viajó y el reintento lleva otro; control con `yala_attest_invalid`. Mutante verificado: quitar el aviso del push pone rojo el test del executor.

## Device-QA (Jürgen, iPhone de QA, TestFlight 19)

1. Borra Yala e instala el TestFlight 19. Haz el onboarding privado o restaura tu iCloud con pocos movimientos.
2. Ajustes › Dónde viven tus datos › «Activar la nube» › consentimiento › Google.
3. Quédate en la pantalla. Esperado: la barra pasa del 55 % y la activación termina **sin cerrar Yala**. Si se para más de 2 minutos, dime la hora: miro el canario `attestRefreshAbandoned`.

## Relación

- vv0k (2.2, primera foto que falla al instante): forma distinta (falla en el acto, no se cuelga). Pista común, sin medir: el token guardado lleva el tier y podía ser de antes de la compra.

Cerrado en el QA guiado 2026-10-20 (tanda del TestFlight 19): TestFlight 19 en producción: «Activar la nube» terminó sin reabrir a mitad y sin canario attestRefreshAbandoned (9,5 min; la lentitud sigue en ppxk, 2.2).
