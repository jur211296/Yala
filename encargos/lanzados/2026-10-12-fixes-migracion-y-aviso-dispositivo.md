# l36m + gwfi (decididas por Jürgen 2026-10-12, opción A en ambas)
## Contexto
Dos bugs 2.1 decididos: l36m (tickets/backlog/retry-after-a-failed-migration-resumes-the-pending-icloud-wipe-blindly.md) y gwfi (tickets/backlog/private-gate-device-notice-has-no-forward-exit.md).
## Qué se pide
Aplica la opción A de cada tarjeta (tablero ver <id>; la nota de decisión manda). l36m: un reintento tras migración fallida no debe reanudar a ciegas el borrado pendiente de iCloud. gwfi: el aviso de dispositivo del acceso privado necesita una salida hacia delante.
## Qué NO tocar
Nada fuera de esos dos flujos. Nunca borrar datos reales de iCloud en pruebas.
## Reglas de build y Mini
Pipeline serie, 1 simulador, nice -n 10 xcodebuild -jobs 2, carga < 8. Tests que cubran ambos casos. Capturas antes/después de gwfi.
## Gate tras el CI del PR anterior
Arranca cuando el PR de 0ekl tenga CI verde o esté mergeado.
## PR a 2.1
Uno o dos PR contra 2.1 desde el mismo worktree.
## Cómo se sabe
Test que falla antes y pasa después para l36m; gwfi con salida visible y capturas.

## Paso 0 — decisiones (resueltas en autónomo, bypass)

**Modo.** Sesión de la cola en bypass ⇒ MODO AUTÓNOMO: gate → commit → PR → board → `/cerrar-total` en modo cola.
Precondición medida: el PR de 0ekl (#468) está MERGED (2026-10-12 14:23 UTC).

### l36m — «Reintentar» tras una ida fallida reanuda a ciegas el borrado pendiente (opción A)

1. **Qué es «la marca durable».** Clave nueva `cloudSync.icloudCorpusWipeCrossedFailedMigration`, sub-estado del ARM
   (como `icloudCorpusWipeZoneDone`): solo se escribe con el arm puesto. «A medias» ya pregunta siempre, así que no la
   necesita.
2. **Quién la escribe.** `MigrationRunner.resetAfterRollback`, rama `.failedRollback` (ida), tras drenar los pendientes
   y ANTES del save que journalea `notStarted`. Es la ÚNICA arista de `failedRollback` al reposo (la máquina no tiene
   otra) y la comparten los tres llamadores: «Reintentar» de Almacenamiento, el adopt del Welcome y el panel DEBUG.
   Asumido frente a «al entrar en failedRollback»: el fallo a la vista ya pregunta (`.askAfterFailedMigration`); la
   marca solo hace falta al SALIR al reposo. La reversa (`reverseFailedRollback`) no la escribe: en `.cloud` el arm se
   retira igual.
   Inyección: el runner recibe `wipeDefaults: UserDefaults = .standard` (testing.md prohíbe `.standard` en tests).
3. **Qué hace el arranque con ella.** `lateWipeLaunch` gana el parámetro `armCrossedFailedMigration` (sin default). En
   `.icloud` y en reposo, con arm + marca ⇒ `.askAfterFailedMigration` (el mismo desenlace del fallo a la vista:
   clasificar; zona ida ⇒ «a medias»; nada tocado ⇒ el aviso del espejo tardío vuelve a preguntar y el arm se queda
   hasta que la persona conteste). Sin marca, `.resume` como siempre (el kill a mitad de un borrado sigue reanudando).
   Con la renuncia: caduca en reposo como hoy y, con la marca, pregunta en vez de reanudar.
4. **Quién la retira.** `clearICloudCorpusWipeArm` (todas las salidas del arm: «Déjalo así», a medias, nube, éxito) y
   `armICloudCorpusWipe` (la persona vuelve a confirmar: un kill a mitad de ESE borrado se reanuda).
5. **Prueba.** Test que falla antes y pasa después: arm + journal `failedRollback` → `resetAfterRollback` real → la
   decisión del arranque con lo persistido da `.askAfterFailedMigration` (antes: `.resume`). Más tabla pura y ciclo de
   vida de la marca. Review adversarial: sí (borrado de iCloud = lógica cara).

### gwfi — el aviso «ya hay datos en este teléfono» sin salida hacia delante (opción A)

**Medido (2026-10-12):** una sesión solo-grupos COMPLETADA no vuelve al Welcome con el mount neutro y filas (el alta deja
`hasCompletedOnboarding = true`; wipe remoto, «Vaciar datos», puerta del invitado y cierre de sesión no la devuelven). El
único camino, inferido y sin reproducir, es una cuenta solo-grupos que entra por «Ya tengo cuenta», deja el alta a medias y
elige «Es mi primera vez → privado» mientras el canal de Grupos ya bajó filas. Ahí «Activar Yala completo» arrancaría sin la
sesión solo-grupos terminada que la activación da por hecha.

**Preguntado a Jürgen (AskUserQuestion, 14:17 Lima) → «Solo lo alcanzable».** Se construye:
1. `WelcomePrivateICloudGateLogic.DeviceDataReading` (`none` · `present` · `unreadable`) y `decide(…, deviceData:)` sin
   default. Con iCloud vacío, sin cuenta o sin red y el teléfono ilegible ⇒ `.deviceUnreadable` (antes: «hay datos» ⇒ borrar o
   volver). Con corpus en iCloud gana su aviso, como siempre.
2. Pantalla nueva en la puerta: «No pudimos revisar este teléfono» con «Reintentar» (vuelve a medir) y «Volver» (`leaveGate`).
   Ningún borrado sale de ahí.
3. El lector nuevo, solo para la puerta (`ContentView.readWelcomeDeviceDataForTheGate`, regla pura
   `deviceDataReading(personal:groups:groupsKeptForThisPerson:)`); el resto de consumidores conserva su detector que falla
   cerrado (alert de «Es mi primera vez», puertas de organizador e invitado). `DeviceCorpus.hasData` pasa a `read`.
4. Seam `-uitest-private-gate-device-reading <present|unreadable>` (finge la LECTURA, no la decisión) para el XCUITest y las
   capturas: antes = lo que salía ante un error de lectura (`present`), después = `unreadable`.
5. No se añade «Activar Yala completo». Ticket nuevo para el hueco del alta a medias.
