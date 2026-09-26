---
id: fresh-start-wipe-kills-unsent-group-writes-silently
status: qa
priority: medium
area: "groups, modo-nube"
created: 2026-09-13
source: "review adversarial de `groups-only-private-restart-skips-the-wipe-alert`, lente de datos (A5)"
updated: 2026-09-26
---

# «Empezar de cero» se lleva los gastos de grupo que aún no habían subido, y no lo dice

## El síntoma

Apunté un par de gastos de grupo sin cobertura. Después hice «empezar de cero» en este teléfono. Esos
gastos no llegaron nunca al grupo, y nadie me avisó de que se iban a perder.

## Lo medido (2026-09-13)

`DataWipeService.wipeLocalGroupsDomain` borra las filas de `GroupSyncOutbox` y purga el espejo del App
Group (`GroupsOutboxMirror().purgeAll()`). Las dos cosas son correctas para su propósito —son escrituras
pendientes del humano anterior, firmadas con un JWT que sobrevive al relevo— pero en el camino nuevo de
la puerta privada el humano puede ser **el mismo**, y ahí son **su** trabajo.

Es la única pérdida realmente propia del gesto: lo demás (categorías sembradas, grupos) o lo recrea la
app o sigue en la cuenta. El copy de la pantalla enumera «gastos, cuentas, presupuestos, categorías y tus
grupos» y no nombra esto.

También se van sin vuelta, y tampoco se dicen: `groupPrefs_*` (la cuenta de liquidación por grupo), los
overrides por grupo del bridge, y el desbloqueo de la beta de Grupos.

## Por dónde va

O el aviso cuenta lo que hay pendiente de subir —`CloudSessionSignOut.liveGroupsPendingCount` ya sabe
contarlo— o el borrado espera a que el outbox se vacíe, como hace el cierre de sesión. Lo primero es
barato; lo segundo es lo que hace el resto de la app en la misma situación.

## Cómo se prueba

- Unit: el contador ya existe y tiene tests.
- Device-QA: apuntar un gasto en avión, volver a cobertura solo después del borrado.

## Arreglado (2026-09-26)

**«Empezar de cero» ya no se lleva los gastos de grupo sin subir.** Si quedan, **no se borra nada** —ni iCloud, ni el
teléfono, ni los grupos— y la pantalla lo dice: «Faltan cambios de tus grupos por subir», cuántos, y qué hacer según
el motivo (el mismo texto que el cierre de sesión).

- **Puerta privada del Welcome y aviso del espejo tardío** (`performDeviceCorpusWipe`, `performICloudCorpusWipe(.handover)`):
  antes del primer borrado suben lo pendiente con el mismo push-all y el mismo presupuesto que el desasociar
  (`CloudSessionSignOut.drainGroupsBeforeFreshStart`). Con el outbox vacío no hay ni espera ni red. Tras una subida
  vuelven a esperar al import de iCloud, pegado al borrado. Salidas: «Reintentar» o «Dejarlo por ahora», que **retira
  el arm**: no se borró nada y, armado, el arranque lo reanudaba a ciegas.
- **La reanudación del arranque** (`runLateICloudMirrorCheck`) se desarma si se para en los cambios de grupos, por lo
  mismo; el testigo del espejo tardío sigue y el aviso vuelve a preguntar.
- **Alert «Borrar todo y continuar»** (`ShellDataAlertsModifier`): con el outbox vacío borra en el mismo tap, como
  siempre. Con algo pendiente **no sube**: avisa en el mismo tap y despierta el loop de Grupos. Tras ese alert no queda
  nada montado donde enseñar una subida, y encender el aviso desde un `Task` es el productor asíncrono que la regla de
  presentaciones manda al router.
- **Cinturón en el escritor**: `DataWipeService.wipeLocalGroupsDomain` lanza si quedan filas VIVAS en el outbox
  (`requireNoUnsentGroupWrites`); las dead-letter sí se van. Los callers lo comprueban antes de `wipeAllUserData`, y si
  salta ahí se dice «faltan cambios», no «no pudimos borrar».
- La subida **no toca la fase del coordinador**, y mientras corre el cierre de sesión y el desasociar esperan
  (`freshStartDrainInFlight`). Canario `freshStartBlockedByGroupWrites`.
- **Sin salida «perderlos»**, asumido de noche: la decisión de Jürgen del 2026-09-15 para el desasociar. Lo que eso
  deja sin salida va a `fresh-start-has-no-way-out-when-group-writes-can-never-upload`.
- La regla `.claude/rules/swiftdata-cloudkit.md` («En una frontera de USUARIO…») decía que esas filas «hay que
  borrarlas»; ahora dice que se suben.

**Las hermanas, medidas y sin tocar**: `groupPrefs_*` (cuenta de liquidación por grupo) y los overrides del bridge son
ajustes del dominio que se va entero, y el alert dice «Borrar todo»; `groupsBetaUnlocked` es la marca de adopción, que
vuelve al adoptar Grupos (`GroupsDomainAdoptionMarker`).

**Verificado**: build de `Yala` y `Yala Dev` sin warnings nuevos, suite unitaria completa (8021 tests), XCUITest del Welcome, del onboarding y de la fila de Grupos (18/18, corrida sola), 18 casos nuevos (`FreshStartUnsentGroupWritesTests` + su suite de
cableado). 16 mutantes, todos muertos. Review adversarial con tres lentes (datos, presentación, regresión): lo que
cazaron está arriba; lo que no se tocó, en `groups-drain-failure-reads-as-nothing-pending` y
`late-icloud-notice-exit-after-a-failed-wipe-leaves-the-blind-resume-armed`.

## Device-QA (pendiente, no bloquea)

El camino del ticket original —sesión solo-grupos → puerta privada— ya no se puede montar (lo cerró el override del
2026-09-16 en `groups-only-private-restart-skips-the-wipe-alert`). Este es el que sí queda, **inferido del código, sin
recorrer**: «Vaciar datos» conserva los grupos y su outbox, y deja la app en el Welcome.

1. En el iPhone, con Yala en iCloud privado y **al menos un grupo** con la cuenta de grupos iniciada, activa el **modo
   avión**.
2. Apunta un gasto en ese grupo.
3. Perfil → Ajustes → «Vaciar datos» → «Vaciar definitivamente». La app vuelve a la bienvenida.
4. «Es mi primera vez en Yala» → «Tu cuenta en tu iCloud privado». Sale el aviso «Empezar desde cero» → «Borrar todo y
   continuar».
5. **Esperado**: al momento, aviso «Faltan cambios de tus grupos por subir», con «(1)» y el texto de «no llegaron al
   servidor». Nada borrado: al pulsar OK vuelves a la bienvenida y el grupo sigue con su gasto.
6. Quita el modo avión, espera un minuto (el gasto sube solo: lo ve otro miembro del grupo) y repite el paso 4: esta
   vez borra y sigue hasta el onboarding.
