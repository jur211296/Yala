---
id: groups-phone-that-never-attests-is-told-to-retry-forever
status: qa
priority: medium
area: "groups, attest, sesión, copy"
created: 2026-09-15
updated: 2026-09-15
source: "review adversarial de `groups-sync-reads-a-missing-attest-401-as-a-session-expiry` (2026-09-15)"
---

# Un teléfono que nunca consigue App Attest oye «inténtalo en un rato» para siempre

## El problema, en lenguaje de usuario

Mi teléfono no consigue App Attest, y esperar no lo arregla. Grupos no sube nada. Cada aviso me dice que lo intente en
un rato; lo intento durante días y nada cambia. Y si tengo cambios de grupos sin subir, no puedo cerrar sesión: no hay
forma de salir igualmente.

## Lo medido (leído en el código, sin ejecutar)

- Desde el 2026-09-15 un 401 `yala_attest_required` es pasajero en el canal de Grupos
  (`groups-sync-reads-a-missing-attest-401-as-a-session-expiry`). Antes era «Tu sesión caducó», igual de falso:
  volver a entrar tampoco lo arreglaba.
- Lo que ve la persona no distingue un attest que vuelve de uno que no:
  - Cierre en la nube sin cambios personales pendientes: «Los últimos cambios de tus grupos no llegaron al
    servidor…», que invita a intentarlo en un rato.
  - «Equipo», solo grupos, hoja del cambio de Apple ID y puerta de Grupos del Welcome: 45 s de reintentos y «Un
    momento más», que pide esperar unos segundos.
  - Desasociar en Almacenamiento: «Quedan cambios de tus grupos sin subir. Inténtalo de nuevo en un momento.»
  - Salir de un grupo: «No pudimos completar tu salida del grupo. Vuelve a intentarlo en un momento.»
  - Aceptar una invitación: espera y caduca en silencio
    (`groups-join-intent-expires-silently-after-transient-failures`).
- Ninguno de esos cierres ofrece salir sin subir: los cambios de grupos no se descartan nunca.
- El canal personal SÍ tiene un veredicto terminal: `CloudSyncRuntime.performCycle` clasifica el fallo del attest con
  `AttestSyncGate` y, agotados los reintentos, para con el canario `cloudSyncBlockedByAttestUnavailable` y el banner
  de que este dispositivo no puede sincronizar. En `.cloud` conviven los dos mensajes: el banner dice que no puede, y
  el cierre de sesión dice que se intente en un rato.
- Sin medir: cuántos teléfonos están así, y qué errores de `AppAttestError` o `DCError` son de verdad permanentes. La
  clasificación de `AttestSyncGate` es el punto de partida.

## Lo que hay que decidir (Jürgen)

1. Llevar a Grupos el veredicto terminal del canal personal: tras varios fallos de attest, un aviso propio que diga
   que este teléfono no puede sincronizar grupos, en lugar de «en un rato».
2. Además de lo anterior, una salida para cerrar sesión en ese caso que avise de que los cambios de grupos sin subir
   se pierden. Choca con la regla de no descartarlos nunca.
3. Dejarlo, y medir antes cuántos teléfonos hay así.

## Decisión Jürgen (2026-09-15)

**Opción 2:** además del veredicto terminal (este teléfono no puede sincronizar grupos), una salida de cierre con texto honesto que avise de que los cambios de grupos sin subir se pierden, y pida confirmación explícita. Excepción acotada a la regla de no descartarlos nunca.

## Hecho el 2026-09-15 — opción 2

**Lo que cambia para la persona.** Con la sesión buena y un teléfono que lleva más de un día sin conseguir App Attest
(24 h y al menos 3 rechazos del servidor en ocasiones distintas —como mucho uno por hora— sin un solo acierto,
recordado entre arranques):

- **Cerrar sesión con cambios de grupos sin subir ya no dice «en un rato».** Ajustes enseña «Este teléfono no puede
  sincronizar tus grupos», cuántos cambios se pierden y dos botones: «Cerrar sesión y perderlos» y «Ahora no». La hoja del
  cambio de Apple ID dice lo mismo. La puerta de Grupos del Welcome dice «si continúas ahora» y «Continuar y perderlos», y
  a quien entra por una invitación no se lo ofrece.
- **Elegir perderlos no borra nada en ese momento.** El cierre sigue como siempre e intenta subir una vez: si el attest
  volvió, los cambios suben. Si no, se van con el borrado del arranque. Lo que se pierde son los cambios que contó el
  aviso: si mientras tanto aparece otro, vuelve el aviso con la cifra nueva. Si aparece después de cerrar el canal, en el
  último recuento, el cierre se para con el aviso genérico, como con cualquier cambio escrito en ese tramo.
- **Desasociar la cuenta de grupos y salir de un grupo** enseñan el aviso terminal, sin salida.
- **Antes de las 24 h no cambia nada**: sigue el aviso de lo pasajero del #172.
- **En la nube, con cambios PERSONALES sin subir, el cierre sigue bloqueado**: la excepción es para los de grupos
  (`cloud-phone-without-app-attest-cannot-sign-out-with-personal-changes`).

**Una premisa de este ticket era falsa.** El canal personal no tiene banner de «este dispositivo no puede sincronizar»:
su veredicto terminal emite el canario `cloudSyncBlockedByAttestUnavailable` y para el runtime, sin nada visible. Lo
prometían dos docblocks (`AttestSyncGate`, `AttestSessionProvider`), ya corregidos.

**Lo que se tocó.** Las decisiones, con su porqué, están en el Paso 0 de
`encargos/lanzados/2026-09-15-groups-phone-that-never-attests-is-told-to-retry-forever.md`.

- `GroupsAttestVerdictLogic` (pura) y `GroupsAttestStreakStore` (`UserDefaults`): la racha, el umbral, un rechazo por
  hora como mucho y un canario por racha.
- `GroupsSyncClient` y `GroupsMembershipClient` apuntan cada 401 `yala_attest_required` y borran la racha con un 200. El
  ciclo de sync guarda su testigo (`stoppedByUnavailableAttest(for:)`).
- `CloudSignOutFlowLogic`: el motivo `.attestUnavailable`, `classify(_:channelKilled:attestUnavailable:)`, que se enseña al
  momento y la nube no traduce, y la cifra aceptada (`continuesWithoutUploadingGroups`).
- `CloudSessionSignOut`: `exitDiscardingUnsyncedGroups`, desde dónde retomar (`lossExit`, `nil` en el desasociar), las
  filas que contó el aviso y los recuentos finales comparados por fila. «Ahora no» solo retira lo aceptado con la fase
  bloqueada. Colaterales: la suma del residual de la nube satura, en vez de atrapar, cuando los dos recuentos fallan; y el
  aviso del desasociar se cierra una sola vez, porque su doble cierre reconocía el bloqueo de un cierre ajeno.
- Pantallas: el alert propio de Ajustes, la etapa `losingGroupChanges` de la hoja del Apple ID, la puerta del Welcome, la
  sección de asociación y las dos pantallas de salir de un grupo (`GroupLeaveErrorLogic.Kind.deviceCannotSyncGroups`).
- 10 claves nuevas en los 16 idiomas y tres canarios: `groupsAttestTerminal`, `groupsSignOutAttestUnavailable` y
  `groupsSignOutAttestDiscarded`.
- `.claude/rules/gateway-attest.md`: sección nueva.

**Lo que queda fuera.**

- Un aviso fijo en la pestaña Grupos: `groups-tab-does-not-say-this-phone-cannot-sync-groups`.
- La nube con cambios personales pendientes: `cloud-phone-without-app-attest-cannot-sign-out-with-personal-changes`.
- Una invitación que caduca en silencio: `groups-join-intent-expires-silently-after-transient-failures`.
- Las demás acciones de membresía (crear grupo, enlace de invitación, aprobar) no leen el veredicto:
  `invite-link-creation-blames-the-connection-for-any-rpc-failure` y su familia.
- El texto de lo pasajero antes de las 24 h: `signout-pending-copy-says-wait-seconds-when-offline`.

## Cómo se verificó

- **Gate:** build `Yala` y `Yala Dev` sin warnings nuevos en los ficheros tocados · unit **1026 tests en 120 suites**
  (119 pedidas), 0 fallos · XCUITest **89 casos en 38 clases, 0 fallos (la primera corrida la cortó la falta de memoria del sistema a los 3 casos y se repitió entera, en cinco lotes)**, con cola y centinela · audit limpio · índice de cobertura OK.
- **Mutantes: 25 de 25 muertos.** Cinco lotes, y dentro de cada lote ningún test esperado lo comparten dos mutantes, así que cada
  muerte se atribuye a su mutante: el borde de las 24 h, uno por hora, la marca del canario, el testigo (su reinicio y su
  outcome), rechazo y acierto en push, pull y membresía, `classify`, la decisión inmediata, la aceptación por filas, la
  guarda de la salida, el guard de Ajustes, el invitado del Welcome, el botón de la hoja, el reconocimiento solo en
  bloqueo, `dismissBlocked`, el residual personal, la cifra que guarda Ajustes, la lectura del veredicto al salir de un
  grupo, y el mensaje con y sin cifra.
- **Review adversarial con tres lentes**, antes de los mutantes: tabla en el Paso 0 del encargo.

## Device-QA — no simulable

La salida que pierde los cambios exige cambios de grupos sin subir, y un teléfono sin App Attest no baja ningún grupo:
ningún montaje de simulador llega ahí. Esa parte la cubren los unit tests y los source-scans. Lo que sí se puede ver es
la racha:

**Montaje.** Xcode con el scheme **Yala** (no `Yala Dev`) en el simulador iPhone 17 Pro, y una cuenta real de Grupos. En
el simulador no hay App Attest, así que cada petición de Grupos sale sin token y el servidor responde 401.

1. Lanza la app, entra en Grupos, filtra la consola de Xcode por `GroupsSync` y **deja la app en primer plano algo más
   de dos horas** (el simulador no se bloquea solo).
   - **Esperado:** `GroupsSync attestRequired edge=pull` repetido, cada vez más espaciado (hasta cada 5 min).
   - **Por qué dos horas:** la racha cuenta como mucho un rechazo por hora y necesita tres. Con un lanzamiento corto
     se queda en uno, al día siguiente sube a dos, y el aviso terminal no sale nunca.
2. Cierra la app. Vuelve a lanzarla desde Xcode al día siguiente, más de 24 h después del paso 1, y entra en Grupos.
   - **Esperado:** una sola línea `GroupsSync attestTerminal rejections=N hours=H`, con `N` de 3 o más y `H` de 24 o
     más.
   - **En ningún caso** vuelve a salir en los lanzamientos siguientes: el canario cuenta una vez por racha.

**En campo, tras publicar:** el canario `groupsAttestTerminal` en Analytics Engine dice cuántos teléfonos están así.

## Relación con otros tickets

- `groups-sync-reads-a-missing-attest-401-as-a-session-expiry` — de donde sale.
- `signout-pending-copy-says-wait-seconds-when-offline` — el texto de lo pasajero, que esta población no puede cumplir.
- `groups-join-intent-expires-silently-after-transient-failures` — la invitación que caduca.
- `.claude/rules/gateway-attest.md` — la recuperación de la key, la escalera y los dos 401 de la guard.
