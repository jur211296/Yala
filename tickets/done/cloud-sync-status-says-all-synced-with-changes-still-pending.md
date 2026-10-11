---
id: cloud-sync-status-says-all-synced-with-changes-still-pending
status: qa
priority: medium
area: "modo-nube, sync, ajustes"
created: 2026-09-16
updated: 2026-10-09
qa-status: needs-testing
source: "decisión D11 del Paso 0 de `personal-sync-reads-an-offline-token-refresh-as-a-session-expiry` (2026-09-16), ampliada por su review adversarial"
---

# «Dónde viven tus datos» dice «Todo sincronizado» con cambios que todavía no han subido

## El problema, en lenguaje de usuario

Tengo mis datos en la nube. Me quedo sin conexión y apunto dos gastos. Abro Ajustes → «Dónde viven tus datos» y la
sección de sincronización enseña un check verde con «Todo sincronizado». Mis dos gastos todavía no están en la nube.

## Lo medido (leído en el código, sin ejecutar)

- `StorageSettingsView.syncStatusSection` tiene tres ramas: el aviso del attest terminal, `syncNeedsSignIn` y un `else`
  que pinta el check verde. Todo estado que las dos primeras no enumeran cae al `else`.
- `CloudMigrationController.refreshSyncBanner` solo pone `syncNeedsSignIn` con el runtime en `.stoppedUntilSignIn` y
  filas vivas en el outbox. Con el runtime en `.running` y en backoff, `pendingUploadCount` se queda a 0 y la sección no
  mira el outbox.
- **Quién cae ahí:** cualquiera sin red con cambios pendientes y el token vigente (el push falla por transporte, que es
  `.transient`), o con la verificación de App Attest caducada (el motor sale en su puerta). **Desde el 2026-09-16 también
  quien pierde la sesión sin red mientras esa verificación sigue en caché**: hasta ese día el runtime paraba con
  `stopUntilSignIn` y la sección pedía «Inicia sesión para subir N cambios», que tampoco era verdad y sin red no se podía
  hacer (`personal-sync-reads-an-offline-token-refresh-as-a-session-expiry`, decisión D11).
- **Y quien tiene la red bien pero el gateway le rechaza el token de App Attest** (401 `yala_attest_required`: un build
  que no manda la cabecera, el reloj atrasado, el servidor). Desde el mismo día ese 401 es pasajero y tampoco para el
  motor. **Ahí no se cura al volver la red**, porque la red funciona: dura lo que dure la causa. Lo encontró la review
  adversarial y es lo que sube la prioridad a `medium`.
- **Y el motor `.idle`** (añadido el 2026-09-22, review de `an-unreadable-migration-journal-reads-as-never-started`):
  `refreshSyncBanner` solo mira `.stoppedUntilSignIn`, así que un `CloudSyncRuntime` que se quedó `.idle` por el gate de
  dominio (`canRunDomain` en `false`: fase no estable, par a medias, mount del espejo, o un journal que no se dejó leer al
  arrancar) cae también al check verde. El caso del journal ilegible lo acota ese ticket —el re-kick de cada primer plano
  arranca el motor `.idle` en cuanto la fase es estable—; los demás siguen aquí.
- Sin red, en cambio, se cura solo: con la red de vuelta el siguiente ciclo sube y el check vuelve a ser cierto.
- Familia del mismo `else`: `reverse-abort-rejected-leaves-a-frozen-cloud-saying-up-to-date` (la nube congelada) y
  `cloud-tab-does-not-say-this-phone-cannot-sync-personal-data` (el attest, ya cerrado).

## Lo que hay que decidir (Jürgen)

1. Contar las filas vivas del outbox siempre que el modo sea `.cloud` y, con alguna pendiente y el motor sin
   `.completed` reciente, enseñar «N cambios esperando conexión» (copy nuevo en los 16 idiomas).
2. Quitar el check verde cuando haya filas vivas, sin texto nuevo (la sección se queda sin estado).
3. Dejarlo: es transitorio y se cura al volver la red.

Recomendación: la 1. Es la única que no afirma nada falso, y el conteo ya existe (`livePendingUploadCount`). Para quien
el gateway le rechaza el attest, el texto de la 1 («esperando conexión») culparía a la red: si se elige, decidir también
si esa población lleva su propia frase (`cloud-attest-notice-does-not-cover-a-gateway-rejected-token`).

## Criterios de aceptación (si se elige la 1)

- [x] Sin red y con cambios pendientes, la sección no enseña «Todo sincronizado» (test de la lógica de la sección).
- [x] Con el outbox vacío y el último ciclo completado, sí (test en la dirección contraria).
- [x] Las ramas del attest y de `syncNeedsSignIn` conservan su prioridad.

## Decisión de Jürgen (2026-10-07)

Sí a la opción recomendada, la 1: el estado muestra **«N cambios esperando conexión»**, con el texto nuevo en todos los
idiomas de la app.

Para quien lo implemente: cuenta las filas vivas del outbox (`livePendingUploadCount`) siempre que el modo sea `.cloud`;
con alguna pendiente y sin `.completed` reciente del motor, ese texto sustituye al check verde. Los criterios de aceptación
de arriba («si se elige la 1») pasan a ser los del ticket. La decisión **no** dice si quien tiene el attest rechazado por el
gateway lleva su propia frase, que la recomendación dejaba abierto: ese caso sigue en
`cloud-attest-notice-does-not-cover-a-gateway-rejected-token`.

## Lo hecho (2026-10-09)

La tarjeta «Sincronización» decide con `SyncStatusSectionLogic.decide`, en este orden: aviso del attest > «Inicia sesión
para subir N cambios» > **«N cambios esperando conexión»** > «Todo sincronizado». Decisiones que tomó la implementación
(sesión autónoma de noche) y que conviene conocer:

- **«Sin `.completed` reciente» = motor no sano**: sano es `CloudSyncRuntime.state == .running` con
  `consecutiveTransients == 0` (el runtime lo pone a cero en `.completed`). Sin ventana de tiempo inventada. Único toque
  al motor: `consecutiveTransients` pasa a `private(set)`, solo lectura.
- **Se cuentan tres colas, no solo `livePendingUploadCount`**: filas vivas del outbox personal + cambios del History que
  ningún drain capturó (sin red, un gasto nuevo no entra al outbox hasta el siguiente ciclo, y el backoff llega a 300 s)
  + filas vivas del outbox de grupos. Sin la mitad del History, el caso exacto de este ticket seguía diciendo «Todo
  sincronizado» hasta cinco minutos.
- **Recuento ilegible** → «Cambios esperando conexión», sin cifra; nunca el check verde.
- **Cuándo se recuenta**: al abrir la sección y en cada guardado (`ModelContext.didSave`). El sondeo de 1 s que ya tenía
  la pantalla solo relee el estado del motor.
- Con el motor sano y un cambio recién apuntado, la tarjeta sigue diciendo «Todo sincronizado»: sale en el siguiente
  ciclo (60 s), y decir «esperando conexión» con la red bien sería otra frase falsa.
- Quien tiene el attest rechazado por el gateway ve «esperando conexión», como decidió Jürgen; su frase propia sigue en
  `cloud-attest-notice-does-not-cover-a-gateway-rejected-token`.

Tests: `YalaTests/CloudSync/SyncStatusSectionLogicTests.swift` (dos direcciones, prioridad, motor sano, recuento con
store real y plurales en los 16 idiomas), con control rojo sobre el `else` de antes.

## Guion de device-QA

El simulador no llega a la nube sin inventar datos, así que no hay capturas. Hace falta un iPhone con **Yala Dev** de
este build y una cuenta **en la nube** (staging).

1. Abre Yala Dev → Ajustes → «Dónde viven tus datos». Comprueba que dice que tus datos están en la nube.
2. Mira la tarjeta «Sincronización». **Esperado:** check verde y «Todo sincronizado».
3. Activa el Modo avión desde el Centro de control.
4. Vuelve a Registros y apunta **dos gastos** cualesquiera.
5. Entra otra vez en Ajustes → «Dónde viven tus datos» y espera en la pantalla hasta un minuto.
   **Esperado:** «2 cambios esperando conexión», con una nube gris y sin check verde. Si el último ciclo había terminado
   bien justo antes del Modo avión, puede tardar ese minuto en cambiar: es el ciclo que falla el que lo enciende.
6. Apunta un gasto más y vuelve a la pantalla. **Esperado:** «3 cambios esperando conexión».
7. Quita el Modo avión y quédate en la pantalla. **Esperado:** en un minuto como mucho, vuelve a «Todo sincronizado».
8. Repite los pasos 3-5 con **un solo** gasto. **Esperado:** «1 cambio esperando conexión», en singular.
9. Opcional: con Yala en inglés, el mismo paso 5 dice «2 changes waiting for a connection».

Si en el paso 5 sigue saliendo el check verde pasados dos minutos, o en el paso 7 no vuelve, el ticket no pasa: anota
en qué paso y qué texto salía.
