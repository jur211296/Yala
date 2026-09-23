---
updated: 2026-09-22
tags: [now, punto-de-retomada]
---

# NOW — 2026-09-22 (Lima)

**Rama** `2.1` — Merge #214: **Los pasos del 22, 35 y 80 % al activar la nube ya no se quedan parados para siempre.**
TestFlight build **13** (CPV 13). **Subida Yala (TF/store) = solo Mini.**

> ⚠️ **El destino que usan `/gate` y `/verify-ios` NO resuelve en esta Mac** (medido el 22-sep).
> `-destination 'platform=iOS Simulator,name=iPhone 17 Pro'` sin `OS=` significa `OS:latest` = **iOS 27.0**, y no
> hay ningún device de 27.0 creado (el runtime sí está instalado). Eso sale con **exit 70 y CERO tests**, que es
> el modo de fallo que el gate existe para no cometer. Se corre con
> `-destination 'platform=iOS Simulator,id=9D0F6D32-1F49-46AD-8070-603D42B5220F'` (iPhone 17 Pro en 26.5) y pasa
> entero: `SDKROOT` es el 27.0 y el deployment target es 26.0. Ticket:
> `the-gate-destination-no-longer-resolves-on-this-mac`.
>
> **La licencia de Xcode 27.0 SÍ está aceptada** — `IDEXcodeVersionForAgreedToGMLicense = 27.0`, y
> `xcodebuild -version` responde. El aviso anterior de este documento, que decía lo contrario y que «no se puede
> correr un gate en esta máquina», era falso: se midió y se retira.

## Esta sesión (#214 · los pasos del 22, 35 y 80 % al activar la nube ya no se quedan parados para siempre)

**Al activar la nube, la barra ya no se puede quedar quieta para siempre al 22 % (reservar la cuenta), al 35 %
(preparar los datos) ni al 80 % (confirmar el cambio con el servidor).** Es el arreglo de #212 para el 55 %, en los
otros tres pasos: se rinde a los **15 min** si el motivo es de los que esperar no arregla (la sesión ya borrada, la
cuenta que lo rechaza, otro dispositivo de la cuenta que tomó el relevo, el teléfono que no pudo preparar sus datos) y
a las **72 h** en el mismo paso con cualquier causa; pasar al paso siguiente reinicia la cuenta. Sale la tarjeta de
fallo con **un texto por motivo** (dos frases reusadas de la subida y tres nuevas en los 16 idiomas) y hay **«Cancelar
la activación»** también en esos tres pasos. Un «Migrar» cuyo claim perdió la respuesta ya no deja la cuenta bloqueada
con un «ya tiene datos» falso al reintentar.

Decisiones de Jürgen (22-sep, sesión de día, las cuatro con la recomendada): 15 min / 72 h por paso, «Cancelar» en los
tres, texto por motivo y cerrar en el mismo PR la trampa del claim sin respuesta.

**Lo que cazó la review, y es lo que no se toca sin romperlo:** el claim del 22 % lo conducen también el adopt («Ya
tengo una cuenta», «Activar la nube en este dispositivo») y el seguidor, y ahí rendirse era un callejón; el techo y el
botón del claim son **solo de «Migrar»**. Y la marca del claim sin respuesta entra en la puerta de identidad como
parámetro propio, sin saltarse la red de «Empezar desde cero». La regla vive en `.claude/rules/swiftdata-cloudkit.md`,
bullet «Y los otros tres pasos de la ida también…».

`MigrationState` sube a **v10** (cinco campos opcionales). Canarios nuevos: `cloudForwardStepWaiting` (por
observación) y `cloudForwardStepAborted` (salida y cancelación). `confirmCutoverServer` deja de ser un `Bool`.

Gate: 7518 unit en 743 suites y 10 XCUITest en 4 suites, verdes con el destino por `id=`. 22 mutantes, todos muertos.

### Lo que espera de Jürgen

- **Device-QA** del ticket `forward-migration-steps-have-no-ceiling-and-no-exit` (en `qa`): guion de regresión con
  **Yala Dev** (el 22 % no se puede aparcar a mano; el 80 %, con modo avión y suerte). Se mergeó sin esperarlo (cola
  autónoma).
- Dos tickets nuevos o ampliados en `backlog`: `adopt-claim-stays-parked-with-no-ceiling` (el claim del adopt sin techo)
  y `a-failed-snapshot-enqueue-save-leaves-the-journal-unsaved` (ahora también la identidad del 35 %).

## Sesión anterior (#213 · en MODO AUTÓNOMO la sesión ya no pregunta «¿Sigo?» ni deja el merge a Jürgen)

**Una sesión de la cola autónoma ya no se para a preguntar «¿Sigo?» tras listar el plan, ni deja el PR abierto para
que lo mergee Jürgen.** Sigue hasta `/cerrar-total`: gate, commit, PR, CI, merge y board. El device-QA de iPhone deja
el ticket en `qa` con su guion y no frena el merge. En sesión interactiva nada cambia: más de 3 ficheros espera OK, y
tras implementar se para. La norma de día sigue: de 6:00 a 21:00 (Lima), una decisión real de producto o de acceso
se pregunta. La bifurcación vive en `CLAUDE.md` § «Control de Ejecución»; `frank.md` y su memoria remiten ahí.
Solo proceso, sin código. Ticket en `done`.

## Sesión anterior (#212 · la subida al activar la nube ya no se queda al 55 % para siempre)

**Si la subida de tus datos a la nube deja de avanzar, la app ya no se queda en «Activando la nube…» 55 % para
siempre.** Se rinde sola: a los **15 min** si el motivo es de los que esperar no arregla (la sesión ya borrada, la
cuenta congelada por una vuelta a iCloud en otro dispositivo, el teléfono que no puede preparar sus datos) y a las
**72 h sin subir una sola página** con cualquier causa. Cada página confirmada reinicia la cuenta. Al rendirse sale la
tarjeta de fallo con **un texto por motivo** y «Reintentar»; y mientras la subida está parada hay **«Cancelar la
activación»**, con confirmación, que vuelve a «Migrar a la nube» sin aviso de fallo y cierra la sesión que abrió el
intento. Antes de este paso el teléfono sigue entero en iCloud: nada local se deshace.

Decisiones de Jürgen (22-sep, sesión de día): 15 min / 72 h como la vuelta, **texto por motivo** (se apartó de mi
recomendación de reusar el genérico), «Cancelar» con confirmación, y **solo la subida**.

**Lo que cazó la review, y es lo que no se toca sin romperlo** (las tres lentes, por separado): un 401 con la sesión
TODAVÍA GUARDADA no es definitivo. Su caso principal es el reloj del teléfono atrasado, que el SDK cura al renovar;
tratado como definitivo sacaba de la subida a los 15 min y «Reintentar» reusaba el mismo JWT rechazado sin pedir nada.
Solo es definitiva la sesión que el SDK ya borró (`canRenewSession` leído después del push). La regla vive en
`.claude/rules/swiftdata-cloudkit.md`, bullet «La subida del snapshot de la IDA también tiene techo…».

`MigrationState` sube a **v9** (cinco campos opcionales). Canarios nuevos: `cloudSnapshotUploadWaiting` (por
observación) y `cloudSnapshotUploadAborted` (salida). El reloj por causa sale a `CauseStallClock`, que ahora comparten
la subida y las fases previas al montaje de la vuelta (la vuelta no cambia de comportamiento).

Gate: 7478 unit en 742 suites y 10 XCUITest en 4 suites, verdes con el destino por `id=`. 18 mutantes, todos muertos.

### Lo que espera de Jürgen

- **Device-QA** del ticket `snapshot-upload-has-no-ceiling-and-no-way-out` (en `qa`): 7 pasos con **Yala Dev** y
  modo avión a mitad de la subida. Se mergeó sin esperarlo por decisión suya (cola autónoma).

### Lo siguiente de la misma familia

- `forward-migration-steps-have-no-ceiling-and-no-exit` (**very-high**) — el mismo agujero en los pasos del 22 %, 35 %
  y 80 % de la ida. Ya tiene piezas para reusar: `CauseStallClock` y `StorageFailureCopyLogic`.
- `a-failed-snapshot-enqueue-save-leaves-the-journal-unsaved` (medium, inferido por una lente, no medido).

## Sesión anterior (#211 · un fetch de outbox que falla ya no se lee como «no hay nada que subir»)

**Si la base del teléfono no se deja leer, la app decidía con esa lectura igualmente — y en la misma pasada
sacaba dos conclusiones opuestas.** Primero daba por hecho que no tenía nada pendiente de subir y se saltaba
ese paso; veinte líneas después trataba el mismo fallo como algo definitivo. La primera lectura era demasiado
optimista —se saltaba una subida que sí hacía falta— y la segunda demasiado pesimista.

**Y la mitad que más costaba: una tabla que no se dejaba leer se comparaba contra el servidor como si estuviera
VACÍA.** El hash de «vacío» y el de «no lo pude leer» eran el mismo byte a byte (`sha256("")`), así que con el
servidor poblado la app concluía que sus datos no coincidían con los de la nube — una pérdida de integridad que
no había ocurrido, con su canario y, en la vuelta a iCloud, gastando el presupuesto que acaba en
`reverseFailedRollback`.

Ahora, cuando una lectura local falla, **la app no decide nada con ella**: para el paso con un motivo propio y
reintenta.

**Eran TRES helpers homónimos, no uno.** `liveOutboxRows` existe con el mismo nombre, la misma forma y el mismo
`return []` en `MigrationWorkExecutor`, `MigrationSnapshotUploader` y `CloudSyncRuntime`; el ticket nombraba uno.
Diez desenlaces, uno por consumidor: `verify()` y `reverseDrainOnce()` con `.blocked(.localFailure)` —el mismo
al que el mapping manda `outbox-fetch-failed`, o sea UNA conclusión por pasada—, el leader-reconcile propagando
(no manda `complete` con filas del líder sin subir), el adopt con `.transient`, el snapshot sin confirmar la
página ni cerrar la pasada, y el ciclo del motor con `.transient`.

**La relectura post-push de `verify()` era la peor de las cuatro** y el ticket no la nombraba: devolvía
`.newDeltaDetected`, que **no consume reintento**, así que una base ilegible no solo se leía como «todo subido»
sino como «llegó un delta, vuelve a correr gratis» — un bucle sin techo alimentado por la propia avería.

`MerkleSkipReason` pasa de OCHO a NUEVE motivos: `local-merkle-fetch-failed` es propio y no un reuso de
`outbox-fetch-failed`, porque el desenlace de los dos es el mismo pero el `rawValue` es lo único que separa en
la flota «no pude leer la cola de subida» de «no pude leer los datos». **Rastro nuevo en producción**, que no
había ninguno: `outboxFetchFailed(step:)` con doce valores y `merkleLocalReadFailed(stage:)`; las cinco
funciones que se tragaban el error lo dejaban en un `print` de `#if DEBUG`.

**LA REVIEW ADVERSARIAL CAZÓ SEIS DEFECTOS MÍOS**, con cuatro lentes independientes:

1. **El `catch` de `collectLeaves` no lo ejecutaba ningún test.** `computeLocalMerkle` llama a
   `danglingOverrides` ANTES que a cualquier `collectLeaves`, y les puse **el mismo `Bool`**: el primero cortaba
   siempre y el segundo quedaba intestable. Un mutante que le devolviera `return []` —la avería titular del
   ticket— habría pasado en verde. **El argumento ya estaba escrito por mí en el otro seam** («con un `Bool` la
   segunda es inalcanzable»): lo apliqué en el executor y lo olvidé aquí. **Y mi propia verificación lo tapó**,
   porque la primera tanda mutó los dos `catch` a la vez. Desde ahí, los 13 mutantes van uno a uno.
2. **Borré 737 caracteres de la SSOT de cobertura.** El `lastVerified` de `cloud-sync-runtime` no era una fecha:
   llevaba dentro la nota entera de `cloud-tab-does-not-say-this-phone-cannot-sync-personal-data`. Restaurado, y
   verificado con un diff programático de que ninguna de las tres áreas perdió su cola histórica.
3. **Corregí el docblock de `migrationVerifyUnknownReason` y dejé mintiendo la línea que sí viaja a la flota**
   (`logger.notice(… networkTimeout conservador)`) — el mismo defecto que ese docblock denuncia, una línea más
   abajo.
4. **`allReasonsAreListed` prometía cazar un motivo olvidado en `all` y no podía**: comparaba contra una lista
   escrita a mano en el test. Ahora es un source-scan del fichero, con control positivo del propio escáner.
5. Cuatro aserciones que no podían fallar por separado, un matcher de error que no distinguía cinco ramas, dos
   tests sin control positivo, y un `try? ?? []` **haciendo de control de escenario** dentro de
   `CloudSyncRuntimeTests` — el antipatrón de este ticket, dentro del test.
6. Cinco docblocks que el cambio dejó falsos («los dos `fetch`», «durante la verificación»), incluida la regla
   de área `.claude/rules/swiftdata-cloudkit.md`.

**Y un control positivo mío falló al correrlo, que es exactamente para lo que está.** Afirmé que la pasada sana
llegaba al pull; es falso —con filas vivas `verify()` sale por `.newDeltaDetected` sin tocarlo—.

**12 tests nuevos en 5 suites y 13 mutantes medidos UNO A UNO**, cada uno aplicado solo y restaurado desde una
copia del scratchpad. Los seis que cambian un desenlace concreto matan **un solo test cada uno**: eso es lo que
prueba que cada test fija su desenlace y no solo que «algo cambió».

### Lo que este merge deja pendiente, y es lo SIGUIENTE (decisión de Jürgen, 22-sep)

**[CERRADO en #212, 22-sep.]** **`snapshot-upload-has-no-ceiling-and-no-way-out` (very-high) es el próximo ticket, y no es opcional: los dos
arreglos tienen que aterrizar juntos.** Con un fallo PERSISTENTE de la base local, la migración se queda al
**55 %, «Migrando…»**, sin aviso, sin «Cancelar» y sin que el botón «Reintentar» alcance esa fase.

El limbo **ya existía para la red** —`uploadingSnapshot` tiene dos aristas de salida y ninguna es un techo—,
pero antes esta avería concreta salía de él *por la puerta falsa*: daba la página por confirmada sin subirla,
el Merkle divergía y acababa en `failedRollback`. Se aceptó porque **mejora el caso común y empeora el raro**:
con un `fetch` que falla un segundo, antes esas filas se perdían para siempre; ahora se reintentan. El arreglo
correcto es darle techo a la fase, no volver al `[]`.

### Siete tickets nuevos, todos medidos en el árbol

El barrido encontró **~40 sitios** con el mismo patrón en `Yala/Services/CloudSync/`. Entra la familia que la
decisión nombra; el resto sale con ticket:

- `snapshot-upload-has-no-ceiling-and-no-way-out` (**very-high**) — el de arriba.
- `an-unreadable-migration-journal-reads-as-never-started` (**very-high**) — `notStarted` es fase ESTABLE, y de
  paso el `catch` **borra el motivo del aborto**.
- `apply-overwrites-a-pending-local-write-without-its-guards` (**very-high**) — un guard LWW a medias deja que
  un remoto pise una escritura local pendiente.
- `groups-merkle-reads-an-unreadable-table-as-an-empty-one` (**high**) — el mismo patrón en Grupos, con peor
  desenlace: resetea cursores y re-baja el grupo entero.
- `an-incomplete-inventory-reads-as-the-whole-corpus` (**high**) — `makeSpec` da una entidad por subida.
- `alternating-definitive-causes-never-reach-the-short-ceiling` (**high**) — la fase `drain` pasó de uno a dos
  motivos definitivos; alternándose, los 900 s no vencen nunca y la salida se va a las 72 h.
- `the-gate-destination-no-longer-resolves-on-this-mac` (**high**) — ver abajo.

### Dos cosas del entorno, medidas hoy

1. **El destino del gate no resuelve en esta Mac.** `-destination 'platform=iOS Simulator,name=iPhone 17 Pro'`
   significa `OS:latest` = **iOS 27.0**, y no hay ningún device de 27.0 creado (el runtime sí está instalado).
   Sale con **exit 70 y CERO tests**, el modo de fallo que el gate existe para no cometer. Todo el gate de este
   PR corrió con `id=9D0F6D32-…` (iPhone 17 Pro en 26.5) y pasa entero: `SDKROOT` es el 27.0 y el deployment
   target es 26.0, así que 26.5 lo cumple. ⇒ la frase de `.claude/rules/testing.md:145` («el device DEBE casar
   con el runtime del SDK») **no es cierta en este caso**.
2. **La licencia de Xcode 27.0 SÍ está aceptada.** `IDEXcodeVersionForAgreedToGMLicense = 27.0` y
   `xcodebuild -version` responde. El aviso que este documento traía arriba ya no aplica y se retira.

Y una menor: `docs/TICKETS.md` tenía **493 en la cabecera sobre 496 filas**. Regenerado desde el disco: 503.

## Sesión anterior (#210 · un fallo de una vez ya no cobra las horas de otra espera)

**Llevo tres horas volviendo a iCloud sin cobertura y la app espera, que es lo correcto: la red vuelve sola. Vuelve
el wifi y, justo en esa pasada, algo del teléfono falla una vez —una lectura de la base local que no sale—. La app
abandonaba la vuelta EN ESE INSTANTE** y me mandaba al principio. Lo que me sacaba no era el fallo: era haber
esperado mucho antes **por otra cosa**. El mismo fallo a los dos minutos de empezar no habría hecho nada. Ahora
reintenta.

**Lo que NO cambia, y es la mitad que sostiene el arreglo:** un rechazo repetido de la cuenta sigue saliendo a los
15 min de estar parada POR ESO, y una espera de 72 h sigue terminando pase lo que pase.

**Son DOS relojes donde había uno.** El de FASE mide lo que lleva parada, venga de donde venga, y gobierna el plazo
largo; el de CAUSA mide el tiempo **acumulado** bajo un mismo motivo y gobierna el corto. Se sale con el primero que
venza. Que el largo siga aplicando con cualquier causa **no es redundancia**: sin él, dos motivos definitivos
alternándose reinician el corto en cada observación y la espera vuelve a no tener techo — el bug-class que esta
familia existe para cerrar, reintroducido por la puerta de al lado.

`MigrationState` sube a **schema 8** (tres campos aditivos; los cinco de la familia se limpian juntos con
`clearReversePreMountCeiling()` en los seis sitios que lo hacen). Los presupuestos se renombran a
`reversePreMountCauseBudgetSeconds` / `…PhaseBudgetSeconds`: los viejos (`Definitive`/`Unknown`) ya mentían.

**LA REVIEW CAZÓ SEIS DEFECTOS MÍOS**, con cuatro lentes independientes, y tres los vieron dos lentes por separado:

1. **La racha consecutiva volvía el techo corto INALCANZABLE.** Elegí «racha» sobre «acumulado» por barata. La
   pantalla de Almacenamiento re-kickea **cada 30 s**, así que con una cuenta suspendida y cobertura intermitente
   basta un timeout cada quince minutos para que los 900 s no lleguen nunca: el desenlace pasaba de 15 min a **72 h**,
   y era peor cuanto más miraba la persona la pantalla. Pasa a acumulado con PAUSA. **Y la decisión de Jürgen ya lo
   decía**: «tiempo ACUMULADO bajo ESA causa» — mi Paso 0 lo interpretó a la baja.
2. **El motivo journaleado lo escribía un blocker de 0 s.** Con dos vías de salida, la vuelta puede salir por el
   plazo de FASE en una pasada que traiga un 403 recién visto; ese copy acusa a la cuenta y da el correo de soporte.
   Ahora lo elige **el techo que venció**, con el predicado en UN solo sitio.
3. **El canario publicaba un solo reloj** y dejaba ciega la mitad del mecanismo en las dos direcciones.
4. Los nombres de los presupuestos ya mentían.
5. **El test del helper prometía cazar un campo nuevo de la familia y no podía**: una lista literal comparada consigo
   misma. Ahora la familia se deriva del schema.
6. Faltaban cinco casos, incluido el round-trip `save + refetch`, cuyo modo de fallo es silencioso.

**Un hallazgo se refutó, y por medición**: dos lentes pidieron un cinturón `sealedPhase == phase`. La lente de
corrección enumeró los tres `setPhase` que no pasan por `handle` y los tres limpian o no cambian de fase — sería una
condición inalcanzable, de las que recogen lo que el camino bueno deja pasar sin que ningún test pueda matarlas.
Entró el test del call site en su lugar.

**El canario cambia de forma y de valores, segundo día seguido.** `cloudReversePreMountWaiting` pasa a
`<fase>|<tramo de fase>|<tramo de causa>|<causa>`, con `-` cuando no hay motivo. Una caída del tramo alto en `stop_*`
es el arreglo, no una mejora de la flota.

**Ticket en `qa`** con guion de 6 pasos, que dice también lo que NO se puede montar a mano: el escenario exacto
—tres horas de espera y un fallo local en la pasada justa— lo cubren los tests. En el teléfono se comprueban las dos
mitades que el cambio podría haber roto.

**Deja un ticket nuevo, medido de paso: el GEMELO en la espera de SUBIDA**
(`reverse-upload-ceiling-charges-a-wait-to-whoever-stops-it-last`). `observeReverseUploadWait` tiene la misma forma y
sigue con un reloj. Camino medido: tras horas sin cuenta iCloud (plazo largo), entras a iCloud y el espejo contesta
`notAuthenticated` —lo habitual justo al iniciar sesión, y que el propio código trata como pasajero—, lo que elige el
plazo corto y cobra las horas de golpe. Su implementación no es copiar el diff: allí existe una noción de AVANCE (la
cifra de pendientes que baja) con la que el reloj de causa tiene que convivir.

Gate: build ×2 verde, **7426 unit en 741 suites**, 4 XCUITest con el simulador en exclusiva, índice de QA con seis
áreas al día.

## Sesión anterior (#209 · un «no» definitivo en la vuelta ya no espera 72 horas)

**Volviendo a iCloud, si la cuenta en la nube dejaba de estar disponible justo en el paso de comprobación, la app se
quedaba TRES DÍAS en «Comprobando que todo llegó…»** sin decir nada, como si fuera la conexión. No lo era, y esperar no
lo arreglaba. Lo mismo con la sesión caducada y con un fallo de la base de datos del propio teléfono. Ahora, a los 15
minutos vuelve al sitio de donde salió y deja dicho por qué; si lo que caducó es la sesión, sale la tarjeta de «vuelve a
entrar» en vez del silencio.

**La cadena, medida entera.** `SyncMerkleClient` **sí** distinguía 401 / 403 / red, pero `SyncMerkle.verifyIntegrity`
los aplanaba con un `guard case .snapshot` y los tres salían como `fetch-failed`; `VerifyProbeMapping` mandaba ese
reason —y los dos `fetch` de SwiftData, y el `default` de un motivo futuro— a `.networkTimeout`; y desde el 21-sep la
vuelta manda la red al techo LARGO de 259 200 s. La ventana viva era la del rechazo que empieza justo **entre el pull y
el Merkle**: el push y el pull tipan su 401/403 desde el 16-sep, el Merkle era el tercero y no lo hacía.

`MerkleVerdict` gana dos casos tipados y el mapping deja de ser un cajón: `.networkTimeout` es SOLO red, los dos `fetch`
locales van a `.blocked(.localFailure)` y el `default` a `.blocked(.unknownVerdict)`, los dos con techo CORTO (900 s).

**EL 401 CONSERVA EL TECHO LARGO, y es una decisión.** A la sesión la renueva la persona, que ahora ve la tarjeta mucho
antes de que venzan las 72 h. Lo que se le quitó fue el silencio, no la espera. **La IDA no cambia**: `driveVerify` ya
agrupaba los tres, y hay test que lo fija.

**LA REVIEW CAZÓ SIETE DEFECTOS MÍOS**, con tres lentes independientes, y tres son de la misma familia —cosas que eran
inofensivas hasta que el cambio les dio consecuencia—:

1. **El Merkle era el ÚNICO cliente del canal sin `canRenewSession` ni la rama de `yala_attest_required`.** Llevaba
   meses así y no molestaba: su desenlace se aplanaba en «red», así que acertar daba igual. En cuanto empezó a encender
   el aviso, pedía firmar otra vez a quien solo estaba sin cobertura y a quien no puede acuñar App Attest. El docblock
   que justificaba la ausencia **era cierto el día en que se escribió**.
2. **`.unknownVerdict` salía con `preMountRefused`**, cuyo copy dice «tu cuenta en la nube no lo permitió» y da el correo
   de soporte — y ese motivo lo escribe una función LOCAL. Causa inventada para la persona y correos a soporte por un
   desajuste de contrato del cliente. Pasa a `preMountStalled`, con el techo corto intacto: la decisión de Jürgen era
   sobre el TECHO, no sobre el copy.
3. **El canario decía `server_<motivo>`** para dos motivos que no son del servidor: el dashboard contaría averías del
   teléfono como incidentes del backend. Renombrado a `stop_`. **La serie `cloudReversePreMountWaiting` cambia de
   valores con este build**, y `cloudSyncAttestRequired` estrena el edge `merkle`.
4. **El literal del `reason` era una junta medida contra sí misma**: el test del mapping construía el veredicto con el
   mismo literal que consumía, así que un renombrado a un solo lado cambiaba producción sin un rojo. Cerrado por
   construcción con `MerkleSkipReason`.
5. **Tres tests míos no podían fallar** (un `Set` de rawValues que garantiza el compilador, un recorrido de `blocked`
   subsumido por los tres casos de arriba, una tanda de `!=` implicados por sus `==`) y **uno prometía más de lo que
   medía**: los guards antes del fetch se afirmaban con el veredicto, que no cambia. Ahora se cuentan las peticiones.
6. **Un test duplicaba una fila que ya existía**, sin añadir un mutante.
7. **Cinco premisas de las reglas de área y dos comentarios del runner** quedaban falsos.

**16 mutantes verificados.** Gate completo **en la Mini ya actualizada a macOS 27.0 / Xcode 26.6**: los dos builds sin
warnings nuevos, 7412 unit en 741 suites, 15 XCUITest en 6 suites con el centinela del simulador en 0.

**Un rojo de XCUITest que apareció antes del reinicio de la Mini NO era una regresión**: `Failing tests:` sin una sola
línea `Test Case … failed` y con el runner reiniciado, o sea una muerte sin veredicto. Repetido aislado, 4/4 verde.

**Ticket a `qa`** con guion de 5 pasos en teléfono (el caso del 403 necesita staging; los pasos 4 y 5 son los controles
negativos: sin cobertura y sin App Attest **no** debe salir «vuelve a entrar»).

**Dos residuales con ticket propio**, los dos de la review:
`reverse-pre-mount-ceiling-charges-a-stall-to-whoever-stops-it-last` —el reloj del techo es de la FASE y la causa de la
ÚLTIMA observación, así que un fallo local aislado tras horas de espera por red saca en el acto, sin un reintento; existe
desde el 21-sep para el 403 y este cambio lo hace alcanzable por un blip local— y
`verify-reads-a-failed-local-fetch-as-an-empty-outbox` —el mismo `fetch` leído como «outbox vacío» y, veinte líneas
después, como desenlace definitivo—.

## Sesión anterior (#208 · la puerta de descarte ya apaga una ventana huérfana)

**Salir de Restaurar y volver a entrar dejaba el permiso que deja firmar sin aviso VIVO y sin dueño**,
y desde ahí «Empezar desde cero» era un no-op: la persona llegaba a la pantalla que borra con ese
permiso abierto hasta diez minutos, parada delante. En un teléfono con los datos de otra persona, es
tiempo de sobra para firmar encima. El hermano de #207, que cerró el camino en el que la misma
instancia tiene el token.

**Para el dueño legítimo no cambia nada**: quien abandona Restaurar y vuelve **sin** pasar por esa
pantalla sigue con su permiso intacto, porque su import sigue trayendo filas.

**El mecanismo, y son DOS mitades.** El apagado pedía un token en el `@State` de esa instancia **y**
que ese token siguiera siendo el dueño vigente. La instancia nueva nace sin token, y el dueño es `nil`
desde que la anterior se fue. `noteRestoreDiscardRequested` pierde el token y su `guard`, y
`discardImportAndStartFresh()` pierde su `if let`. Es el **único de los cinco verbos** que apaga sin
titularidad, y el porqué es el del diseño llevado hasta el final: la premisa «las filas siguen
entrando y hay que protegerlas» la deroga quien declara que no las quiere, y esa declaración no
distingue de qué intento son. Los otros dos verbos conservan su `guard`: a ésos los llama una pantalla
que sí tiene token.

**El aparcado se escribe SOLO si hay reloj, y esa rama es alcanzable.** Sin ese término, un descarte
sobre una ventana ya apagada pisa con `nil` el reloj que el anterior guardó, y la vuelta estrena 600 s
— el recorrido de tres toques de `restore-session-window-has-no-reachable-ceiling`, reabierto.

**EL ALCANCE SE MIDIÓ, Y EL APAGADO SE QUEDA EN EL GESTO.** El encargo pedía cubrir las **tres**
instanciaciones de la puerta subiendo el apagado a su montaje. Se implementó, y **las tres lentes de
la review lo tumbaron por el mismo motivo**: dos de esas tres no son un descarte —«Soy nuevo» →
«Privado», en el Welcome y en la activación— y sus propios docblocks lo dicen con estas palabras,
«quien llega aquí acaba de elegir privado y **todavía no ha pedido borrar nada**». Apagar desde el
montaje le devuelve al dueño legítimo el «estos datos son de otra persona» sobre sus propios datos, y
**no se auto-repara**: el aparcado solo se hereda volviendo a Restaurar, y ese recorrido va a firmar.
Tampoco se arregla condicionando por `unverifiedExit`: en el Welcome el camino del descarte y el de
«Soy nuevo» comparten el MISMO step. Y hay una razón de robustez: en el gesto el apagado cuelga de un
TAP, que provablemente ocurrió; en el montaje colgaría de una presentación, y en este anchor las
presentaciones se caen — o sea fail-**abierto**, el desenlace que el ticket cierra.

**Lo que queda fuera a propósito:** por «Soy nuevo» → «Privado» se llega a esa puerta con la ventana
huérfana viva y nadie la apaga. Quien llega ahí no ha declarado nada —es el invariante de
`abandoned-restore-…`— y si desde ahí sí borra, el borrado arma el relanzamiento y la señal muere con
el proceso, porque vive en memoria a propósito.

**La review cazó tres cosas mías además del rumbo**: un escáner de OTRO fichero
(`RestoreStartFreshGateTests`) que mi cambio dejaba rojo y que yo no había mirado —lo destapó la suite
completa, no el build—, 12 variables que quedaron muertas al quitar el token, y tres docblocks que
pasaron a afirmar lo contrario del código, entre ellos el de `FlowToken`, que decía «un apagado no
puede venir de un flujo que nunca encendió nada».

**12 mutantes, 12 muertos** sobre 124 casos en 8 suites: reintroducir el `guard` del verbo;
reintroducir el `if let flowToken`; aparcado incondicional; `.wiped` al callback crudo; `.wiped` con el
botón muerto; la confirmación saltándose el punto único; el `cancel` comprometiendo el descarte; una
sentencia antepuesta; el orden invertido; quitar `currentFlow = nil`; quitar `restoreStartedAt = nil`;
y subir el apagado al montaje de la puerta. Gate: build ×2 sin warnings nuevos, **7397 unit**, 10
XCUITest con el centinela en 0, índice de QA OK. CI entero en verde.

**Queda en `qa`** con guion de 4 casos en iPhone (pide dos cuentas de nube y un iCloud con histórico
grande). El **caso 2 es el control negativo del alcance**: por «Soy nuevo» → «Privado» la ventana NO se
apaga, y eso es lo correcto.

**Lección de método, y es la cara:** una premisa del ENCARGO también se mide. «Cubre las tres
instanciaciones» sonaba a simetría y era un daño; lo que lo separó fue leer qué dice cada call-site de
sí mismo, no razonar sobre la forma.

## Sesión anterior (#207 · el estado borrado ya no llega a la puerta con la ventana abierta)

**Había un camino —estrecho— por el que se llegaba a «Empezar desde cero» sin que se cerrara el
permiso que deja firmar sin aviso**, y se quedaba abierto hasta diez minutos con la persona parada en
esa pantalla. En un teléfono con los datos de otra persona, eso es tiempo de sobra para firmar encima.
Era el séptimo de los siete caminos a esa puerta: los otros seis confirman con diálogo y ese diálogo
sí apagaba.

**Para el dueño legítimo no cambia nada**, y eso era lo que había que conservar: quien cancela el
diálogo sigue restaurando con su ventana intacta, y quien cae en «Borraste tus datos» en su primera
búsqueda —casi todo el mundo— no tenía nada abierto que cerrar.

**El mecanismo.** `wipedView` pasaba `primaryAction: onStartFresh`, el callback crudo. El apagado
sube un nivel, a `discardImportAndStartFresh()`, un punto único que apaga aparcando el reloj y
**entonces** llama al callback; el `cancel` no pasa por ahí. `.wiped` sigue **sin confirmar**, y se
ratifica: su búsqueda concluye por acto de la propia persona, que acaba de borrar en ese dispositivo.
Lo que comparten los siete no es el diálogo, es el gesto.

**Por qué casi nunca hay ventana que cerrar por ahí, y por qué a veces sí.** `.wiped` sale de un
`return` temprano de `startSearch()`, que corre ANTES del encendido. Pero `RestoreOfferGate.wasWiped`
lee `PreferenceSyncService.lastWipeTimestamp`, **una preferencia sincronizada por el iCloud-KV**: el
sello puede llegar de otro dispositivo entre la primera búsqueda y el «volver a buscar». Entonces el
reintento cae ahí con la ventana del intento anterior VIVA y su token puesto —`noteRestoreUnavailable()`
tira el aparcado y la gracia, pero no la ventana ni su dueño, por diseño— y el `.onDisappear` solo
SUELTA la titularidad: huérfana y viva hasta el tope duro de 600 s.

**Re-medido antes de tocar nada:** el ticket es del 21-sep y desde entonces entró #206, que añadió
`noteRestoreUnavailable()` a los dos `return` tempranos. El agujero seguía abierto, y está escrito en
el docblock de ese verbo.

**LAS TRES LENTES CAZARON OCHO DEFECTOS MÍOS, y cuatro de los once mutantes solo mueren por lo que
pidieron.** (1) **Tres mutantes vivos dentro del cuerpo del punto único**, por fijarlo con `contains`
sueltos en vez de entero: un `noteRestoreAbandoned(flowToken)` antepuesto —que deja el dueño en `nil`
y hace que el descarte se caiga por su propio `guard`—, un `flowToken = nil` antes del `if let`, y una
sentencia de más. En los tres, el conteo daba 1, el orden era correcto y los cuatro literales estaban.
(2) **El conteo miraba `onStartFresh()`**, así que tres formas de ENTREGAR el callback pasaban, una de
ellas con la grafía que usa el propio helper de la vista. (3) **Mi docblock decía «la red es el
CONTEO»** y para este ticket es al revés: el conteo también daba 2 en el árbol con el bug dentro.
(4) **Mi test de comportamiento no mata ningún mutante que la suite no matara ya** —y su docblock
afirmaba lo contrario—; se queda porque es el recorrido del ticket de punta a punta, pero ahora lo
dice. (5) **El escáner de call-sites contaba FICHEROS**, así que un segundo apagado dentro de esta
misma vista pasaba en verde. Y tres de documentación: la causalidad del orden estaba presentada como
medida y es inferida, el aparcado que escribe `.wiped` es inerte y se justificaba mal, y **ocho
docblocks decían que el verbo lo llama «la confirmación»** cuando `.wiped` no confirma.

**El residual, con ticket propio y es una DECISIÓN de Jürgen**
(`discard-gate-cannot-close-an-orphan-session-window`, medium): el punto único solo apaga si ESA
instancia de la vista tiene el token y sigue siendo el dueño, así que quien sale de Restaurar y
**vuelve a entrar** llega con `flowToken == nil` y el descarte es un no-op sobre una ventana huérfana
todavía viva. No es regresión —es la exposición que ya acepta `noteRestoreAbandoned`— y cerrarlo exige
decidir si el descarte puede apagar una ventana que no es de su intento, que es justo lo que ese verbo
existe para no hacer.

**Gate**: build ×2 sin warnings nuevos, 105 unit en 8 suites, 14 XCUITest de tres suites con el
simulador en exclusiva (centinela 0), índice de QA al día en `welcome-flow-visual`, **11/11 mutantes
compilados muertos**. CI verde. Ticket en `qa` con guion de tres casos: **pide DOS teléfonos con el
mismo Apple ID**, porque el sello del wipe viaja por el iCloud-KV y tiene que llegar con la pantalla
de Restaurar abierta y un import vivo.

## Sesión anterior (#206 · el reintento ya no reabre la ventana de sesión cada 90 s)

**En un teléfono con los datos de otra persona, tocar «volver a buscar» renovaba cada minuto y medio el
permiso que deja firmar sin aviso.** Un toque por vuelta, indefinidamente, sin pasar por ninguna puerta
y sin que tuviera que bajar nada: **más barato que los tres toques y los diez minutos de la puerta de
descarte que cerró #205**, que es de donde salió medido. Ahora el margen inicial de espera —los 60 s que
cubren a quien de verdad está restaurando y aún no ve bajar nada— **se cuenta una vez por sesión de la
app**, no una por cada intento.

**Y quien restaura de verdad conserva su ventana completa**: el tope de diez minutos se estrena entero
en cada entrada, y en cuanto CloudKit trae la primera fila el permiso se reabre solo. Quien entra sin
iCloud, lo enciende y vuelve a buscar estrena margen nuevo: su descarga es otra.

**El mecanismo.** La gracia de 60 s colgaba de `restoreStartedAt`, el reloj de CADA entrada, así que el
ciclo «la espera se rinde a los 90 s → reintentar» compraba 60 s de guard entornado por cada 91. Entra
`graceStartedAt`, un ancla de PROCESO que pone el primer estreno y que **`noteRestoreFinished` no
borra** — ese verbo es por el que pasa cada vuelta del ciclo. Es una FECHA y no un `Bool` «ya se gastó»
porque un final sin imports puede llegar a los 3 s y el reintento no puede perder los 57 que nadie
gastó; y es SEPARADA del reloj porque heredarlo entero —como hace el aparcado de #205— le recortaría el
tope duro al dueño legítimo. `noteRestoreUnavailable` sí la tira, y con la ventana viva la entrada
siguiente la re-deriva de ese reloj, que es el estado correcto.

**LAS TRES LENTES CAZARON OCHO DEFECTOS MÍOS, y cuatro de los doce mutantes solo mueren por los tests
que ellas pidieron.** (1) **Una aserción NO PODÍA FALLAR**: el escáner de «el ancla no tiene valor por
defecto» miraba el fichero de la señal y el parámetro vive en la lógica pura, así que el literal no
aparecía ahí ni con el mutante puesto — copié el molde de su hermano, que sí funciona porque su función
sí vive en ese fichero. (2) **Mi test del recorrido «enciendo iCloud y reintento» medía el caso fácil**:
apagaba el reloj antes, y ahí los dos operandos del `??` coinciden; el recorrido REAL —irse de Restaurar
sin que nadie apague, que deja la ventana viva— no lo tocaba nadie. (3) **La puerta de descarte solo
estaba medida a los 40 s**, donde el aparcado aún se hereda y el mutante es indistinguible; a los 700 s
sí se ve. (4) Faltaba la frontera exacta 59/60. (5) **Un dato falso en un docblock mío**: «seis vueltas,
más de los 600 s del tope» son 546 s.

Y tres de documentación: la cabecera decía **cuatro verbos y son cinco** —falta justo
`noteRestoreUnavailable`, el único que borra el ancla—, dos docblocks pasaron a mentir sobre la gracia,
y el `- Parameters:` de `isRestoringNow` abría con un parámetro inexistente y metía el `- Returns:` en
medio, así que el párrafo nuevo no se renderizaba.

**Refutado un hallazgo:** una lente avisó de que el copy del bloqueo prometía una salida que el fix
quita. Medido: dice «**si acabas de pedir una restauración** desde iCloud…», y quien no ha visto un solo
import no tiene ninguna en curso. El copy no caduca.

**El residual, escrito y aceptado** (el criterio del ticket lo permite): entre el toque del reintento y
el primer `.importEvent` de esa descarga no hay ventana, y **la señal no tiene ningún término que separe
a ese dueño legítimo del teléfono con el corpus ajeno** — el claim murió con la reinstalación, que es la
mitad del escenario en los dos casos. Se cura solo: el latch es monótono y el getter se recalcula vivo.

**Gate**: build ×2 sin warnings nuevos, 7394 unit / 741 suites, 12 XCUITest de tres suites con el
simulador en exclusiva (centinela 0), índice de QA al día en `welcome-flow-visual` y `edge-cases-logic`,
**12/12 mutantes compilados muertos**. CI verde. Ticket en `qa` con guion de tres casos en el teléfono:
no se puede montar en simulador, porque el ciclo son minutos de reloj real por vuelta y la población
exige un teléfono en el que CloudKit no baje nada.

## Sesiones previas (#205 · volver de la puerta de descarte ya no estrena permiso nuevo)

**En un teléfono con los datos de otra persona, pedir «Empezar desde cero» y arrepentirse renovaba el
permiso que deja firmar sin aviso.** Tres toques —«Empezar desde cero», confirmar, «Volver»— y la
cuenta atrás empezaba de cero, sin esperar nada y sin que hiciera falta que bajara nada. Ahora volver
de esa pantalla continúa la cuenta donde estaba: la puerta **solo pregunta, no borra nada**, así que
arrepentirse no es empezar de nuevo.

Y de paso se arregla algo que nadie había notado y que sí muerde al dueño legítimo: **con una
descarga larga, «volver a buscar» no podía reabrir el permiso una vez agotado.** Quien traía un
histórico grande se quedaba, pasados los diez minutos, con la app diciéndole que sus propios datos
eran de otra persona —con las filas entrando en ese momento— y sin más salida que cerrar la app.

**El mecanismo.** La confirmación llamaba a `noteRestoreFinished`, que apaga la ventana **y borra su
reloj**: eso dejaba el estado idéntico al de «nadie ha pedido restaurar en este proceso», y la vuelta
—que remonta la pantalla, cuyo `.task` llama a `startSearch()`— estrenaba 600 s por la puerta grande
del estreno, que no pregunta por ningún testigo. Entra `noteRestoreDiscardRequested`: apaga igual **y
APARCA el reloj**. El estreno lo hereda mientras siga vigente (edad en `[0, 600)`) y lo consume
siempre. **Agotado el tope, la entrada siguiente ESTRENA con normalidad, y eso es lo que lo distingue
del techo de cadena que la review tumbó el día anterior**: aquél, agotado, no dejaba ni re-anclar ni
estrenar en el resto del proceso.

**LAS TRES LENTES CAZARON DEFECTOS MÍOS, y dos eran caros.** (1) Mi primera versión **le quitaba al
dueño legítimo su única salida**: con el reloj heredado caducado y el dueño todavía en pantalla no se
entraba ni al estreno ni al re-ancla, así que ningún reintento la resucitaba — la mitad 2 del techo
tumbado, entrando por la caducidad. Lo cierra una rama nueva, el RESCATE, y **su alcance costó una
segunda iteración**: tratar «ventana agotada» como «apagada» para cualquiera deshace #204, porque el
ciclo salir-volver suelta la titularidad en cada vuelta y pasaba a estrenar sin descarga viva. Lo
cantó su propio test, en rojo. (2) El reloj aparcado se quedaba **VARADO** cuando la vuelta caía en
`.iCloudDisabled` o `.wiped`, y la descarga NUEVA que viniera después nacía con un tope que podía
tener un segundo de vida.

Y tres de verificación: `parkedStartedAt = nil` en `noteRestoreFinished` era **inalcanzable** y
ENMASCARABA al mutante que le quita el consumo al estreno; al verbo nuevo le faltaba el escáner de
unicidad que sus hermanos sí tienen, y **la enmienda D2 de `GroupsOrganizerBranchTests` solo conocía
uno de los dos verbos que apagan**; y un docblock mío afirmaba una premisa falsa. Los tres `600` del
subsistema salen ya de una constante única.

⇒ De los tres criterios del ticket, cierra el 2 y el 3, y el 1 para el recorrido que nombra — **no es
un techo absoluto y no lo habrá**: por debajo sigue el baseline de matar la app.

**Lo que hay que hacer con esto:**

1. **QA en el teléfono** (`tickets/qa/restore-session-window-has-no-reachable-ceiling.md`, guion de
   tres casos). **Solo se puede probar con un histórico que tarde varios minutos en bajar**: con un
   restore pequeño el import asienta antes de llegar al botón y parecerá que el fix no hace nada.
2. **Decidir por dónde sigue el techo.** La review midió una vía **más barata** que la que este PR
   cierra: un toque cada 91 s, sin pasar por ninguna puerta, en el teléfono cuyo corpus ajeno ya se
   importó (`restore-retry-reopens-the-session-window-every-90-seconds`). Su arreglo toca la gracia
   de 60 s, que es decisión de producto.
3. El otro residual, menor: `wiped-state-reaches-the-discard-gate-with-the-window-open`.

## Sesión anterior (#204 · salir y volver a Restaurar ya no renueva con una descarga vieja)

**En un teléfono con los datos de otra persona bastaba UN instante de descarga en todo el arranque
para que salir de «Restaurar desde iCloud» y volver a entrar renovara el permiso que deja firmar sin
aviso** — dos toques, y para siempre. Ahora renovarlo exige una descarga bajando de verdad en ese
momento; cuando la descarga termina o muere, el ciclo deja de renovar nada y la puerta se cierra
sola. Y lo que ya estaba bien no se movió: quien se arrepiente y vuelve minutos después con sus datos
todavía bajando sigue estrenando su permiso completo.

El término era `hasObservedImportActivity`, un **latch monótono del proceso**. Lo sustituye
`ICloudRestoreInProgressLogic.hasLiveImportActivity`, con dos crudos del servicio y un sello nuevo
—`lastImportActivityAt`, el instante en que se OBSERVÓ cada `.importEvent`, que se limpia al cambiar
de cuenta de iCloud porque lo lee un guard de frontera de cuenta—.

**Los dos crudos hacen falta y los dos números salen de la review.** `status` es un escalar ÚNICO que
comparten import, export y setup: lo enciende un sitio y lo apagan trece, así que un export de diez
segundos en el minuto 0 de una bajada de siete minutos deja `isImporting == false` los 6 m 50 s
restantes. Y la fecha sola no cubre un import grande, que emite un evento al empezar y otro al
acabar. La frescura son 600 s —el mismo `hardCap` de la ventana— y **los 60 s de mi primera versión
eran falsos**: el error de import RETRIABLE deja `.idle` mientras CloudKit reintenta con backoff de
minutos, o sea el caso NORMAL de un restore grande con la red floja.

**EL TECHO CON NÚMERO NO ENTRA, y ése es el hallazgo caro.** Implementé uno —un reloj de la cadena de
re-anclas que ningún re-ancla movía— y la review lo tumbó por sus dos mitades: **no acotaba**, porque
`noteRestoreFinished` es alcanzable desde la UI con el import vivo («Empezar desde cero» → «Volver» →
Restaurar, tres toques, y la puerta no borra nada) y por debajo relanzar la app estrena todo; **y sí
bloqueaba al dueño legítimo**, de forma permanente en el proceso, porque agotado el techo ninguna
entrada podía ya ni re-anclar ni estrenar. Un mecanismo que no frena a quien quiere saltárselo y sí
castiga a quien no, se retira. Lo medido va entero en `restore-session-window-has-no-reachable-ceiling`.

⇒ De los tres criterios del ticket, cierra el 2 y el 3, y el 1 a medias: la exposición del ciclo pasa
de la vida del PROCESO a la vida de la DESCARGA, pero no hay número.

**Las tres lentes de la review cazaron defectos míos**, y dos eran el ticket hermano reabierto por mi
propio arreglo. La cuarta cosa que cazaron fueron cuatro huecos en mi red de tests: la frescura no la
fijaba ningún caso, el source-scan del call-site dejaba libres `now:` y `freshness:`, nadie afirmaba
que un export no BORRARA el sello, y el test del criterio 2 se medía pasando el bool a mano — o sea
asumiendo la conclusión.

**Verificado:** build ×2 sin warnings nuevos · unit 7359/7359 · XCUITest 24 en 7 suites con el
centinela limpio en los dos lotes · índice de QA OK · **9 mutantes, los 9 muertos**, y el primero es
mi propia primera versión.

**Queda:** device-QA del ticket (8 pasos, el 7 es el del ticket) y los dos tickets nuevos
—`restore-session-window-has-no-reachable-ceiling` y
`import-activity-latch-survives-an-icloud-account-change`—.

## Sesión anterior (#203 · el tope de 90 s ya no cierra la sesión con el import bajando)

**Entro a «Restaurar desde iCloud» con un histórico grande. A los 90 s la pantalla se rinde y me dice
«seguimos trayendo tus datos» — que es verdad: siguen bajando. Toco atrás, firmo con mi cuenta y la app
me contesta que estos datos son de otra persona.** Son míos, y están entrando en ese mismo momento. Ya
no pasa: mientras el import siga trayendo filas, la app me sigue reconociendo como el dueño.

Y cuando de verdad no hay nada que traer, la puerta se cierra en el acto como hasta ahora: quien no
tiene datos no gana ninguna espera.

**El criterio no es el desenlace que elige el copy, y esa fue la primera versión.** La tumbó la review:
`RestoreImportSettlement` agrupa en `.inconclusive` dos poblaciones que a esta pregunta contestan
distinto —la que no vio un import y la que vio uno con un error vigente—, y esos errores suelen ser
retriables (`isRetriable` da `true` hasta en su `default`), con CloudKit trayendo filas detrás. O sea
que a un restore grande con la red floja —**el caso normal**— se le apagaba la ventana con la descarga
viva: el bug del ticket, sin arreglar, entrando por el copy. Hoy decide
`ICloudRestoreInProgressLogic.closesTheSessionWindow`, con los dos términos crudos.

**El `noteRestoreAbandoned` se mudó de `RestoreProgressView` a `WelcomeRestoreView`**, y era la única
forma de cumplir el tercer criterio sin inventar estado: la pantalla de progreso se desmonta también al
cambiar de `state` —a `.importIncomplete`, a `.found`—, o sea con la persona todavía dentro de
Restaurar. Soltar ahí dejaba la ventana huérfana y el reintento la re-anclaba; como el testigo del
import es un latch monótono, el tope duro de 600 s se renovaba cada 90 s con solo pulsar «volver a
buscar».

**«Empezar desde cero» apaga la ventana desde su propia confirmación**, y eso lo destapó la review como
**regresión de este mismo ticket**: sin ello esa salida se llevaba la ventana abierta hasta diez
minutos, donde antes la cerraba el apagado incondicional. Es la otra salida que sabe que no queda
descarga, porque la persona acaba de decirlo.

**La review de tres lentes cazó tres defectos míos, y dos eran el bug sin arreglar.** El tercero fueron
tres agujeros en mi red de tests: el scan del `.onDisappear` no anclaba a qué vista cuelga —mover el
bloque dentro del `switch` reabría el ticket con todo en verde—, el del apagado no contaba ocurrencias,
y el criterio 1 se afirmaba sobre un campo y no sobre `CrossAccountEntryGuardLogic`, que es donde la
persona lo sufre. Y una premisa mía que era falsa: «el desmontaje de Restaurar significa me fui» —en
`FullModeActivationView` no siempre.

Verificado: build ×2 sin warnings nuevos, **352 unit en 37 suites** (pedidas = corridas), **16 XCUITest
en 4 suites** con el centinela en cero, y **dos tandas de mutantes, 12 en total, todos muertos**.

**Residual con ticket propio:** salir de Restaurar y volver renueva el tope duro
(`leaving-and-reentering-restore-renews-the-hard-cap`). No es regresión —antes el apagado incondicional
estrenaba reloj por la otra rama— y el tercer criterio habla del reintento, que sí queda cerrado.

El ticket va a `qa` con guion de siete pasos para iPhone: el escenario necesita un histórico que
CloudKit tarde más de 90 s en bajar, y eso no se monta en simulador.

## Sesión anterior (#202 · la escala de prioridades pasa de 3 a 6 peldaños)

Sesión de board, sin una línea de Swift. Jürgen pidió el 21-sep ampliar la escala de prioridades y
remapear el board abierto en el mismo gesto.

Con tres peldaños los extremos vivían apelotonados: «esto bloquea salir 2.1» compartía casilla con
«esto es importante», y «polish que puede esperar un año» con «nice-to-have». La escala queda
**`critical` · `very-high` · `high` · `medium` · `low` · `very-low`**, cada una con su definición en
el esquema de `docs/TICKETS.md`, y replicada en los dos comandos que la usan: `/idea` clasifica,
`/backlog` ordena.

**Los dos peldaños de arriba quedan vacíos, y el de arriba del todo es a propósito.** `critical` es
para una emergencia en producción; repartirla la vacía de significado. `very-high` quedó vacío
**tras medir**: leí los nueve `high` abiertos de código que existen —7 en `backlog`, 2 en
`blocked`— y ninguno es un callejón de nube/restore/sesión con el usuario atrapado. Son el chat de
IA caído, el rendimiento de la lista de Grupos, el corpus de staging que crece, cuatro XCUITest en
rojo de una nocturna, el copy de la web (que es de Lola), Siri de iOS 27, el índice del rediseño de
sesiones, y los dos `blocked` cuyo arreglo ya está en el código esperando dos teléfonos reales. El
callejón más vivo del board —`restore-timeout-closes-the-session-window-with-the-import-still-running`—
está `in-progress` con `medium` y lo lleva otra sesión: promoverlo desde aquí era pisarle el ticket.

Los **38 `high` de `qa`** —el device-QA que corre Jürgen— se quedan donde estaban. Cuatro `low`
bajan a `very-low`: el formato JSON del project de Xcode (documentado en beta, no se toca hasta
27.2 estable), los dos del `indice_readme.py` con worktrees anidados, y partir el turno del
simulador para no ocuparlo mientras compila — su propio ticket dice que «la cola funciona; es que
podría ser más corta sin perder nada». `gateway-typecheck-roto-y-fuera-del-ci` **se queda `low`**
aunque venía en la lista de candidatos: un typecheck que falla y que el CI no corre es una red
ausente, no polish. Y los 19 tickets sin `priority` siguen sin ella: no se inventa.

**El índice decía 479 y en disco hay 487.** Crucé las 487 filas contra los ficheros reales —id,
status y path, uno a uno—: cero faltantes, cero sobrantes, cero con el status de otra carpeta. Era
solo el conteo del encabezado. No añadí tabla de conteos por prioridad: envejecería con cada ticket
nuevo y un número que se consulta creyéndolo cierto es peor que no tenerlo.

Conteo de los 381 tickets abiertos tras el remap: `critical` 0 · `very-high` 0 · `high` 47 ·
`medium` 187 · `low` 124 · `very-low` 4 · sin prioridad 19. Ningún ticket del repo, abierto o
cerrado, tiene hoy un valor fuera de la escala.

**Dos cosas vistas de camino, ninguna nueva.** Los dos tickets del `indice_readme.py` son el mismo
bug escrito dos veces (16-sep y 21-sep); no los fusioné porque tocar cuerpos quedaba fuera. Y el job
`changes` del CI disparó la suite entera de simulador —22 min de runner— por un `.md` de
`encargos/`: ya tiene dos tickets propios (`encargos-markdown-triggers-the-whole-ios-suite` y
`ci-allowlist-no-cubre-encargos-ni-qa-scripts`), así que no dupliqué.

Verificado: gate docs-only (sin `.swift` ni infraestructura de build en el diff), `validate-coverage.sh`
en `RESULT: OK`, y el CI del PR entero en verde, suite de simulador incluida.

## Sesión anterior (#201 · la vuelta a iCloud avisa al rendirse, y sin cobertura espera)

Los dos residuales que dejó #199, los dos decididos por Jürgen el mismo día.

**Estaba mirando cómo vuelve a iCloud, la barra desaparecía de golpe y la pantalla cambiaba.** La nota que lo
explicaba quedaba en la tarjeta, pero nadie me la ponía delante — y si hubo otro intento fallido hace días, la nota
que veo puede ser aquella. **Ahora sale un aviso en el momento**, con el mismo texto que la nota, y solo si la salida
es de ahora. Cancelar a propósito sigue sin sacar nada: lo decidió la persona.

**Y quedarse sin cobertura en el paso de comprobación ya no da la vuelta por fallida.** Ocho intentos sin conexión
—unos minutos— la declaraban fallida y dejaban el aviso al servidor pendiente hasta que la red volviera. Ahora espera,
como ya hacía en los otros tres pasos, y cuando la red vuelve sigue sola.

Era la única de las **ocho** combinaciones fase × causa fuera del techo. En la vuelta el único contador S9 vivo pasa a
ser el del mismatch, así que `reverseVerifyOutcome(.networkTimeout)` **dejó de ser un par legal** desde `reverseVerify`:
dejar esa rama viva sin emisor es código muerto que afirma lo contrario del ticket.

El aviso va por un testigo en memoria con secuencia (`ReversePreMountExit`, molde de `ReverseClaimExit` y de
`ForwardClaimRefusal`), escrito **solo al dejar la etapa** — bajo presupuesto no hay salida, así que el re-kick de 30 s
no repite alerta. Y pasa por `ReverseUploadWaitingCopyLogic.abortNote`: ese término es la única diferencia con el helper
del claim, porque «Cancelar y seguir en la nube» vive también en estas cuatro fases y el copy agrupa `cancelled` con
`stalled` — sin el filtro, cancelar sacaba una alerta de error.

**La premisa del ticket volvió a caer al medirla.** D10 dejó el verify fuera «para no arrastrar a la IDA, que comparte
`verify()`»; `driveVerify` y `driveReverseVerify` son funciones distintas desde siempre y la ida ya agrupaba red, sesión
y `blocked` en su rama con el porqué escrito. No se tocó una línea, y se fijó con test en las dos capas.

**Dos cosas medidas, no inferidas.** Desde una fase estable el toque de «Volver a iCloud» **no puede** cruzar el techo
—el cruce limpia el reloj—, pero con el journal ya en la etapa **sí**: `submit` conduce `drive()` aunque el evento sea
inválido. O sea que el aviso de `startReverse` no es camino muerto. Y el comentario del runner que decía que la vuelta
era **DARK** llevaba obsoleto desde que existe el botón de Ajustes: **una lente de la review se lo creyó** y rebajó por
eso la gravedad de un hallazgo.

Verificado: build ×2, **411 unit en 26 suites** (pedidas = corridas), 10 XCUITest en 4 suites con el centinela en cero,
y **10 mutantes muertos**. La review de tres lentes cazó **tres defectos míos, los tres en la red de tests**: el test
estrella tenía tres aserciones incapaces de fallar —y el revert *parcial* las dejaba las cuatro en verde, o sea el limbo
del ticket padre reabierto sin rojo—; nada cazaba el tight-loop (`return true`); y un test de la máquina era duplicado
literal de dos que ya existían. Arreglados y re-medidos.

**Cinco hallazgos quedan fuera con ticket**, uno `medium`: `.networkTimeout` es un cajón que aplana el 401 y el 403 de
`/sync/merkle`, así que esa mitad pasa de degradar en minutos a esperar 72 h — el arreglo está aguas arriba, en
`SyncMerkle`, que comparten la ida y el motor (`reverse-verify-network-bucket-hides-a-definitive-server-no`). Los otros
cuatro: el toque sobre la tarjeta desfasada, el «Cancelar» que borra el aviso recién nacido, el aviso publicado con la
pantalla cerrada, y el panel DEBUG que pinta «red 0» de una vuelta parada por red.

Un XCUITest falló en lote y pasó aislado **con el diff de producción idéntico entre las dos corridas** y el centinela en
cero las dos veces: se suma al ticket de flaky que ya existía, que ahora tiene dos casos de dos suites distintas.

## Sesión anterior (#200 · el restore abandonado ya no se lleva el reloj de la ventana de sesión)

**Entro a «Restaurar desde iCloud», me arrepiento y toco atrás. Vuelvo un rato largo después y esta vez
sí espero — y a media descarga la app me dice que mis datos son de otra persona.** El permiso que deja
entrar a la propia cuenta contaba su reloj desde la PRIMERA vez, no desde ésta, así que se agotaba con
el import a medias y `CrossAccountEntryGuardLogic` devolvía `.blockedForeignData` al dueño legítimo.

**Ahora el reloj empieza cuando entré esta vez**, y lo que ya estaba bien no se movió: salir de la
pantalla con el import bajando sigue sin apagar nada.

El reloj (`restoreStartedAt`) y el dueño (`currentFlow`) pasan a ser dos cosas distintas. Hasta hoy el
invariante era `restoreStartedAt == nil ⇔ currentFlow == nil`, o sea que apagar la ventana y liberar su
reloj eran el MISMO acto; desde que el flujo abandonado dejó de apagar (#198, con razón: el import sigue
bajando) dejó también de liberar. Hoy hay un estado más, **la ventana HUÉRFANA** —reloj puesto, dueño
`nil`—: viva para el import que la justifica, sin nadie que la vigile, y la entrada siguiente la estrena.
La suelta `noteRestoreAbandoned` desde el `onDisappear` de la pantalla de progreso —**mudado a
`WelcomeRestoreView` por #203**, ver arriba—, y **no toca el
reloj**: apagar ahí reabriría entero el ticket del que sale éste.

**La premisa del ticket cayó al medirla.** El docblock decía que conservar el reloj impedía que el botón
de reintentar extendiera el tope a voluntad; no lo impedía. Los cinco botones de «volver a buscar» solo
salen en estados terminales, aguas abajo del apagado, así que cuando la persona los toca el reloj ya es
`nil` y se estrena igual. Lo único que aquel guard producía era el bug.

**Y la review cazó que MI arreglo abría otro.** Con «estrena si no hay dueño» a secas, el ciclo
entrar-atrás-repetir re-ancla el reloj en cada vuelta, y como la gracia de 60 s se mide desde ahí, quien
navegue más rápido que eso mantiene abierto indefinidamente el guard de frontera de cuenta — en un
teléfono con el corpus de otra persona, la adopción que el guard existe para impedir. Antes del ticket no
se podía. Lo cierra el **testigo del import**: una huérfana solo se re-ancla si llegó algún
`.importEvent`. Va **sin default**, como el `restoreInProgress` del guard.

Verificado: build ×2, 268 unit en 28 suites, 16 XCUITest en 4 suites con el centinela en cero, y **8
mutantes muertos**. De paso, un rojo AJENO que llevaba desde el 17-sep mudo en `2.1`:
`NeutralMountWiringTests` seguía anclado a la firma vieja de `personalStoreFileExists()` —perdió su
`private` en `e765ad070`— así que su `#require` de marcador fallaba antes de llegar a las tres
aserciones.

**Queda device-QA** (ticket en `qa`, guion de 8 pasos): no se monta en simulador, exige corpus real en
iCloud y un import de más de 90 s.

**Dos tickets nuevos:** `restore-timeout-closes-the-session-window-with-the-import-still-running` (el
mismo daño por el eje del desenlace: el tope de 90 s apaga la ventana con el import en marcha) y
`restore-error-state-is-never-reached` (el `case error` de `WelcomeRestoreView` lo pinta el `switch` y no
lo asigna nadie).

## Antes de eso (#199 · la vuelta a iCloud ya se puede abandonar antes de montar el espejo)

**Empiezo a volver a iCloud y algo no deja terminar: la barra se queda en el 15, el 30, el 50 o el 62 % y no hay
forma de dejarlo.** No es una barra parada: con cualquiera de esas cuatro fases journaleada **el teléfono deja de
sincronizar**, así que quien se quedaba ahí perdía el canal entero hasta que alguien se diera cuenta. Las cuatro
salían SOLO por éxito.

**Ahora tienen techo y botón.** «Cancelar y seguir en la nube», que solo salía al 95 %, se ofrece también en las
cuatro; y si no hay nadie delante, la app sale sola: **15 min** cuando el servidor ya dijo que no —la cuenta en la
nube no está disponible, otro dispositivo tomó el relevo, el congelado salió rechazado— y **72 h** cuando no se sabe
por qué no avanza, que es lo que cubre el caso peor: una cuenta a la que ya no se puede entrar. Los tres motivos del
servidor **llegaban colapsados en `.transient`**: sin separarlos, el techo corto era inalcanzable.

**El techo mide el tiempo SIN CAMBIAR DE FASE**, no el total de la etapa: aquí no hay cifra que baje, así que avanzar
es pasar a la fase siguiente. Y la salida vuelve al origen en modo nube **sin un solo efecto de máquina**: sin
re-armar el espejo, porque pre-montaje nunca se re-encendió, y sin journalear el `reverse_abort`, porque ese efecto
lanza sin sesión, no se consume y volvería a lanzar en cada arranque — el bug-class que esta salida existe para
cerrar. El aviso al servidor lo intenta el runner una vez, best-effort, DESPUÉS de journalear: si el proceso muere en
medio, «en el origen con la reserva puesta» se cura solo y al revés no.

**La review adversarial con cuatro lentes tumbó nueve cosas, y tres eran de publicación:**

 · **El hold nuevo del claim BORRABA los pendientes del origen.** `reverseClaimLeader` nunca había tenido una arista
   que la dejara en sí misma, y el brazo que descarta lo guardado cazaba ese hold: un corte de red durante el claim
   perdía el `runLeaderReconcileFromFrozenCloudKit` del líder —lo único que manda `complete`— y el rechazo posterior
   reponía una lista vacía. El bug que cerró `reverse-claim-rejection-has-no-way-out-in-the-client`, reabierto por la
   puerta de al lado.
 · **El reloj no se re-sellaba al VOLVER a una fase ya visitada.** `verify` vuelve a `drain` por mismatch, y la
   segunda visita heredaba el sello de la primera: el techo saltaba con cero segundos de parada real. Mi test solo
   cubría el avance a una fase nueva.
 · **Firmar para continuar ejecutaba un «Cancelar» apuntado.** Los dos botones nunca habían podido coexistir —
   «Volver a entrar» solo sale pre-montaje y «Cancelar» solo salía en la espera—, y con el nuevo ahí, quien rescataba
   la vuelta se la encontraba abandonada, en silencio y sin nota.

Y seis más: `CloudSyncSchemaParityTests` en rojo (no pedí esa suite), el abort que no se intentaba si un pendiente
repuesto lanzaba, el ternario del cuerpo del diálogo fallando **abierto**, una regla mía violada —«un escritor y UN
borrador», y dos lentes discreparon sobre si la línea hacía falta: lo zanjó medir quién lee el testigo—, **cinco
aserciones que no podían fallar**, y el copy del relevo diciendo «no pudimos EMPEZAR» cuando desde el congelado la
vuelta sí había empezado.

**Verificado:** build ×2, **460 casos en 22 suites** (ojo: pedí 13 y corrieron 11 — `CloudMigrationI14Tests` y
`CloudWelcomeSignInFlowTests` son nombres de FICHERO, no de tipo, y dentro están justo las suites que roza este
cambio), 6 casos de XCUITest con el centinela en 0, y **13 mutantes, los 13 cazados**. La regla de área ganó una
entrada nueva y **seis correcciones**: el diff dejaba falsas seis afirmaciones que ya estaban escritas.

**Queda:** device-QA en iPhone, con guion de cinco criterios y SQL de montaje en el ticket; y el residual
`reverse-pre-mount-ceiling-has-no-alert-and-leaves-network-verify-out` (el techo no avisa en el momento, y
`reverseVerify` + red pura sigue saliendo por el terminal viejo).

## Sesión anterior (#198 · la espera del import de iCloud se corta al salir de la pantalla)

**Salgo de una pantalla que está esperando a iCloud y esa espera seguía viva por debajo hasta minuto y
medio: la app seguía contando mis movimientos cada seis décimas con la pantalla ya cerrada y yo en otro
sitio.** `forceFetchAndWait` solo resolvía por la notificación de CloudKit o por su propio tope, así que
un `Task` cancelado se quedaba clavado los 15 s del arranque o los 90 s del restore, reteniendo un
observer y un `Task` de sleep. Ahora va envuelta en `withTaskCancellationHandler` y resuelve por
`ForceFetchWaitBox`, una caja con `NSLock` que garantiza **una sola** resolución entre las tres vías que
compiten —un doble `resume` de una `CheckedContinuation` es un **crash**, no un test rojo— y suelta las
dos cosas que retenía. Ese `cancel()` cierra además un fantasma que nadie había contado: una espera
resuelta por la notificación a los 2 s dejaba su sleep de 15 s, o de 90, durmiendo detrás.

**Y la mitad que define la sesión: salir ya NO cierra la ventana que te deja entrar a tu propia cuenta.**
Mientras iCloud baja tus datos, la app mantiene abierto un permiso para que el guard de frontera no te
tome por otra persona. Se apagaba «cuando el flujo termina», y hasta hoy tocar atrás no terminaba nada
—la espera seguía clavada—, así que nunca se apagaba antes de tiempo. **Arreglar la cancelación sin
tocar nada más habría hecho que tocar atrás apagara esa ventana con el import todavía bajando**, que es
justo el bug que la señal existe para evitar; su propia lógica ya lo daba por hecho («el usuario que toca
atrás a mitad cancela ese `Task` y este camino no corre»), y esa frase era **falsa** hasta hoy. El
apagado pasó detrás del `guard !Task.isCancelled`.

**Lo demás del pack, por el mismo patrón:** el refresher de la pantalla de progreso gana handle propio y
se apaga en el mismo `onDisappear` que la espera; el poll de boot-save de `AppBootstrapper` deja de girar
**en caliente** sobre un `Task` cancelado, espejando la rama `.cloudEngine` de su hermana, que ya lo
cerraba; y los dos borrados de `ContentView` conservan su motivo `cancelled` en vez de pasar a decir
`importNotQuiescent`, que sería una mentira nueva.

**La review adversarial cazó SIETE cosas, todas MÍAS, y tres enseñan método:**

 · **Mi source-scan del poll era VACUO.** Sus cuatro pasos —`do {`, `try await Task.sleep(...)`,
   `} catch {`, `return false`— son **byte-idénticos** a los de la rama hermana `.cloudEngine`, que vive
   más abajo en el mismo fichero; como la búsqueda avanza hacia adelante, casaban allí. **Los cuatro
   mutantes del poll sobrevivían, incluido el que el propio test dice cazar.** Es «el tramo sin acotar lo
   cumple el vecino», repetido tal cual pese a tenerlo escrito.
 · **Mis casos de cancelación COLGABAN en vez de fallar** ante el mutante que rompe `arm(...)`: apoyarse
   en el tope del SUT solo funciona si la espera resuelve, y ese mutante la deja sin resolver para
   siempre. Es el AC nº4 del propio ticket, incumplido por mí. Llevan tope propio, y la suite de la caja
   lleva `.timeLimit`.
 · **`refreshTask?.cancel()` delante del guard podía matar el refresher de OTRA generación de la vista**:
   `@State` es una caja compartida entre montajes, así que un `runTask` cancelado que despierta tras un
   re-montaje leía de ella el handle del intento **vivo**.

**Un residual con ticket propio, y no es menor:** el flujo abandonado ya no libera el reloj de la ventana
de sesión. Hasta hoy despertaba a los 90 s y limpiaba el ancla; ahora, quien abandona y vuelve a los 400 s
hereda el reloj de la primera entrada, y si su import tarda, el tope duro caduca a medias y el **dueño
legítimo** ve «estos datos son de otra persona». Arreglarlo pide separar el reloj del dueño y romper el
invariante `restoreStartedAt == nil ⇔ currentFlow == nil`: es rediseño de la señal, otro eje ⇒
`abandoned-restore-no-longer-clears-the-session-window-clock`.

Validación: build ×2 sin warnings nuevos · **unit completa 7286 tests en 738 suites** con **un solo rojo,
ajeno y con ticket** (`neutral-mount-wiring-scan-is-red-on-2-1`, verificado corriendo esa suite en un
worktree limpio desde `HEAD`: falla igual sin nada mío) · **XCUITest 5 suites, 26 casos**, lock del
simulador y centinela en 0 · **10 mutantes, 10 muertos**. Dos tests preexistentes se desarmaron al partir
la línea del `waitForImportQuiescence` y se reescribieron para medir el **invariante** —que el corte
exista y vaya antes del primer borrado— en vez de la forma de la línea.

**Queda en `qa`**: el device-QA no se puede montar en el simulador, porque el caso vive en el tiempo real
de un import de CloudKit.

## Antes de eso (#197 · unos presupuestos en iCloud ya no se leen como «no hay datos»)
**Tenías presupuestos en iCloud y todavía no había bajado nada más. Restaurar te los enseñaba subir en la pantalla
de progreso y la siguiente te contestaba «No encontramos tus datos. No hay datos asociados a tu cuenta de iCloud»**,
con «Empezar desde cero» de botón primario. CloudKit entrega por lotes y sin orden garantizado, así que «bajó un
presupuesto y todavía no una categoría» no es un borde: es un estado normal a media descarga. Ahora los cuenta.

**Y la pantalla del hallazgo enseña también tus categorías.** Ese hueco es anterior al ticket y salió al revisar el
consumidor que su propio criterio manda revisar: `hasAnyData` ya las contaba y ésta era la única de las tres
pantallas que enseñan cifras que no las pintaba — quien restauraba solo categorías veía **«Encontramos tus datos en
iCloud:» encima de un hueco**.

**Lo que NO cambia, y es la corrección que define la sesión: los grupos se quedaron FUERA del criterio, contra lo
que pedía el ticket.** Se implementó primero con ellos dentro, con los mutantes en verde, y la review adversarial lo
refutó con tres medidas:

 · **No vienen de iCloud.** `SplitGroup` vive en `groupsSchema`, cuyo store monta `cloudKitDatabase: .none`, y sus
   filas llegan por el backend de Yala.
 · **Contarlos TAPA cuatro estados.** `WelcomeRestoreView` decide con un `if summary.hasAnyData` que
   **cortocircuita antes de leer el veredicto del import**, así que con un solo grupo local dejaban de alcanzarse
   `.importIncomplete` —el #195, cerrado anteayer—, `.cloudPaused`, `.cloudUnverified` y `.notFound`. En
   `FullModeActivationView`, que monta esa misma pantalla y a la que **solo se llega desde una sesión solo-grupos**,
   eran inalcanzables por construcción; y el docblock de su «Empezar desde cero» dice explícitamente que cuenta con
   que ese `.notFound` ocurra.
 · **La protección que lo motivaba YA EXISTÍA.** El argumento era que `.notFound` ofrece «Empezar desde cero» y ese
   camino purga el dominio de Grupos. Se ofrece, sí, pero no borra sin avisar: pasa por la puerta del paso 4, cuyo
   `deviceHasData` sale de `ContentView.checkHasExistingData()`, que **sí cuenta `SplitGroup`**.

⇒ son **dos preguntas** —«¿trajo algo el espejo de iCloud?» y «¿hay datos que perder en este teléfono?»— y cada una
ya tenía su predicado. Colapsarlas produce el error en las dos direcciones. **Ésa es la lección de método**: al
ampliar un predicado no basta con contar a quién alcanzas — hay que mirar el `if` que lo consume y contar **qué se
vuelve inalcanzable**.

Validación: build ×2 sin warnings nuevos · **162 unit en 17 suites** · **XCUITest 14 en 4 clases** con centinela
limpio · **21 mutantes en dos tandas, 21 muertos** —el primer source-scan dejó uno VIVO: miraba la condición del
`if` y no que la rama pintara nada, y se endureció— · review con 2 lentes + las rules de área, **15 hallazgos** ·
`validate-coverage` OK · `docs/TICKETS.md` al día (478) · **CI verde**.

**Qué te toca:**

1. **Device-QA de `restore-treats-budgets-and-groups-as-no-data`** (en `qa`): 6 pasos en iPhone. **Deciden el 1**
   —con presupuestos bajando, al terminar no puede salir «No encontramos tus datos»— **y el 5**, que es el control
   que protege lo que NO cambió: en un teléfono solo-grupos, «Empezar desde cero» tiene que seguir avisando de que
   hay datos en este teléfono antes de borrar. Los tres primeros no se pueden montar en simulador: CloudKit no
   existe ahí.
2. **El paso 3 es una pregunta de diseño, no un PASS/FAIL**: con las cinco cifras a la vista el grid deja una card
   sola en su fila. Dinos si se ve mal y se cambia; mover UI que nadie pidió no entraba en el ticket.
3. Siguen pendientes los device-QA del **#196** y del **#195**.

**Cuatro tickets nuevos, los cuatro de la review:** `restore-prefill-skips-currency-for-an-empty-summary` (low, un
resumen de solo presupuestos salta el paso de la divisa porque `hasPrefill` es un `!= nil`),
`restore-found-state-leaves-no-breadcrumb` (low, `.found` es el único desenlace sin rastro y este bug reproduce en
CloudKit Production), `group-presence-predicates-disagree-on-archived-and-hidden` (medium, tres sitios cuentan
`SplitGroup` con tres criterios distintos) y `restore-found-copy-says-icloud-for-groups-that-never-were` (low, el
encabezado dice «en iCloud» sobre una lista que puede incluir la card de grupos).

## Sesión anterior (#196 · salir de Restaurar y volver a entrar ya no apaga la búsqueda que sigue viva)

**Tocabas «Restaurar desde iCloud», te lo pensabas, volvías atrás y entrabas otra vez. Minuto y medio después, con
tu histórico todavía bajando, la app dejaba de saber que estabas restaurando** — el primer intento seguía clavado
esperando a iCloud y, al despertar, apagaba la ventana del segundo. A partir de ahí, entrar por la card de tu
propia cuenta te contestaba que esos datos eran de otra persona. Ahora **cada intento lleva su identidad y solo el
vigente puede cerrar la ventana**; el reloj no se reinicia, así que su tope sigue sin ser extensible a voluntad.

**El ticket pedía «un token por flujo» y eso solo no bastaba: la review adversarial encontró dos caminos más, y los
dos los cierra la misma pieza** — que la espera **no se monte sin intento** (`if let flowToken`):

 · **El apagado podía correr ANTES del encendido.** Con el espejo ya importado y quieto,
   `waitForImportQuiescence` vuelve **sin suspenderse**. Como `state` nace en `.searching`, la pantalla de progreso
   se monta en el primer render, así que su apagado podía llegar antes de que `startSearch()` registrara el token:
   ventana sin dueño, abierta hasta el tope de 600 s.
 · **El bug tenía una segunda puerta, dentro de UNA sola pantalla.** Desde el #195 `.iCloudDisabled` ofrece «volver
   a buscar». Quien entraba con iCloud Drive apagado ya había arrancado una espera de 90 s; al encender iCloud y
   recargar tenía **dos esperas vivas**, y la fantasma apagaba la ventana de la buena. Sin cerrarlo, este ticket
   arreglaba el gesto de «atrás» y dejaba ese otro abierto.

**Y el diseño se rehízo a media implementación, que es la lección de método.** La primera versión usaba
`.task(id:)`: apoyaba la corrección en que SwiftUI vuelva a disparar un `.task` al cambiar su `id`, y **la pantalla
de Restaurar no tiene ni un XCUITest que entre en ella**, así que no había forma barata de medirlo — y si el
contrato fallaba, la búsqueda no arrancaba NUNCA. La puerta de montaje no depende de ningún re-disparo. Rehacer
costó veinte minutos con los tests ya escritos, y las dos reviews, que corrían contra el diseño viejo, confirmaron
después que sus hallazgos de más peso los cerraba justo la versión nueva.

Validación: build ×2 sin warnings nuevos · **121 unit en 15 suites** · **XCUITest 16 en 4 clases** con centinela
limpio · **6 mutantes, 6 muertos** (el sexto no compila) · review con 2 lentes + la rule de área, 10 hallazgos
atendidos · `validate-coverage` OK · `docs/TICKETS.md` al día (474) · **CI verde**.

**Qué te toca:**

1. **Device-QA de `restore-back-and-reenter-closes-the-live-session-window`** (en `qa`): 8 pasos en iPhone.
   **Deciden el 3 y el 5**, los dos a los 90 s — no debe salir la pantalla de «estos datos son de otra persona»
   mientras tu histórico baja. El paso 4 pide apagar iCloud Drive. No se puede montar en simulador: el defecto
   necesita que el import de CloudKit **tarde**.
2. Sigue pendiente el **device-QA del #195** (`restore-says-no-data-when-the-icloud-import-never-settled`).

**Un ticket nuevo, del Paso 0 y de la review:** `force-fetch-and-wait-ignores-cancellation` (medium) — la espera de
iCloud no observa cancelación y el refresher de la pantalla no hereda la del padre, así que siguen vivos hasta el
tope. Es coste, no corrupción, y la primitiva la usa el arranque de la app: no se toca de paso.

## Sesión #195 · el tope de la búsqueda de iCloud ya no se lee como «no hay datos»

**Reinstalabas Yala con tu histórico en iCloud y la app te contestaba «No encontramos tus datos. No hay datos asociados
a tu cuenta de iCloud»** — con tus datos ahí. Debajo, «Empezar desde cero» **no preguntaba nada**: un toque y
arrancabas vacío. Bastaba con que el primer import de CloudKit tardase más de 90 s, o sea un histórico grande, una
conexión lenta, o iCloud entregando por lotes. Ahora dice **«Seguimos trayendo tus datos»** cuando siguen llegando,
mantiene el mensaje de siempre cuando de verdad no hay nada, y **el botón destructivo pregunta antes** en todos los
desenlaces donde la búsqueda no concluyó. El único que sigue actuando directo es el de quien acaba de borrar sus datos
en este mismo teléfono.

**El tope no servía de señal, y por eso la opción 2 estaba descartada:** se agota IGUAL para el histórico que tarda que
para quien estrena la app, cuyo store vacío no dispara ningún `importEvent`. Quien las separa es la señal del propio
import más **la palabra vigente de CloudKit** — molde de la reversa (`ICloudCutoverGateLogic`), con `lastImportErrorAt`
espejando a su gemelo del export.

**La review (cuatro lentes) tumbó tres cosas mías y la primera era de publicación.** Mi Paso 0 descartó mirar el error
del import por «redundante, porque el orden ya lo implica» — justo al revés: el flag se enciende ANTES del `if let
error`, así que **se lo traga**. Sin ese término, un fallo de red le prometía datos a quien no los tiene con un
«Reintentar» en bucle, y la peor población era **el usuario nuevo con mala cobertura**: la opción 2 descartada,
entrando por la puerta de atrás. Las otras dos: el test de cableado dejaba pasar el intercambio de las dos ramas del
`if` (o sea el bug entero, en verde), y **`.iCloudDisabled` resultó ser el mismo bug por otra puerta** — su gate lee el
token de iCloud **Drive**, no CloudKit, así que con Drive apagado y la sesión viva esa gente tiene su histórico entero
esperando, y podía tirarlo de un toque. Ahora confirma y ofrece volver a buscar; su mutante **sobrevivía**, así que
además lleva test.

**Y un mutante murió y el término sobraba igual**, que es la lección que me llevo: el `if` que decidía si `.notFound`
pregunta tenía cinco mutantes muertos y **una sola población, y era gente con datos** — quien tiene presupuestos o
grupos en iCloud, que `hasAnyData` no cuenta. Se retiró: `.notFound` confirma siempre.

**Qué te toca:**

1. El **device-QA de `restore-says-no-data-when-the-icloud-import-never-settled`** (en `qa`): 7 pasos en iPhone, con
   dos Apple ID. **Los que deciden son el 3 y el 5** — con un Apple ID sin datos tiene que salir «No encontramos tus
   datos» y **no** el mensaje nuevo (si sale el nuevo, toda instalación nueva queda esperando un import que no existe);
   y con el avión puesto **no** debe prometer datos.
2. **`restore-back-and-reenter-closes-the-live-session-window`** (high, nuevo): salir de Restaurar y volver a entrar
   apaga la ventana del intento que sigue vivo, y el guard cross-cuenta se cierra sobre el dueño legítimo con su import
   a medias. Es previo, pero el copy nuevo empuja justo ese gesto.
3. Siguen pendientes de ti el **QA en iPhone de #194** y la **decisión de
   `reverse-before-mount-has-no-way-to-abandon-the-return`** (los dos, abajo).

**El rojo de `NeutralMountWiringTests` ya tiene causa medida** y no hizo falta bisecar: su marcador busca `private
static func personalStoreFileExists`, y esa función dejó de ser `private` en `339f78259`. El invariante se cumple; el
arreglo es quitar `private ` del marcador. Queda vivo su tercer criterio —**por qué el CI no lo canta**—, y esta sesión
añade el dato: el job `tests` del CI pasó **en verde** (32 min) con ese caso rojo en local.

Validación: build ×2 sin warnings nuevos · **suite completa 7260 casos / 735 suites con 1 solo rojo, el preexistente**
· XCUITest **20 en 5 clases** con centinela limpio · **17 mutantes compilados y corridos** · review con 4 lentes ·
`validate-coverage` OK · `docs/TICKETS.md` igual al disco (472) · **CI verde**.

**Cinco tickets nuevos, todos de la review y ninguno regresión:**
`restore-back-and-reenter-closes-the-live-session-window` (high) ·
`restore-treats-budgets-and-groups-as-no-data` (medium) ·
`start-fresh-dialog-promises-what-the-gate-undoes` (medium) ·
`restore-empty-state-resolution-cannot-be-cancelled` (low) ·
`import-activity-flag-describes-the-process-not-the-search` (low).

## Antes de eso (#194 · la vuelta a iCloud ya pide volver a entrar)

**Pulsaba «Volver a iCloud» y la barra se paraba al 15 %, al 30 %, al 50 % o al 62 %.** Sin mensaje, con un «Retomar»
que recibía lo mismo, y mientras tanto el teléfono no sincronizaba. Lo que fallaba era la sesión de la nube, y la
pantalla no lo decía ni ofrecía volver a entrar. Ahora lo dice —«Tu sesión caducó. Vuelve a entrar para terminar de
volver a iCloud.»— con un botón, y al entrar **la vuelta sigue donde estaba**. Si la sesión seguía viva, que es el caso
más común, se arregla sola sin pedir nada.

**Las cuatro fases son anteriores al montaje del espejo, y ninguna es estable:** con ellas journaleadas el motor de la
nube no corre, así que el aviso de «vuelve a entrar» de Ajustes **no podía salir** —ese exige el runtime en
`.stoppedUntilSignIn` y lo que se pinta es la tarjeta de progreso—. Y quedarse sin cobertura NO pide volver a entrar:
lo separa `canRenewSession`, como el canal personal desde el 16-sep.

**La review (cuatro lentes) tumbó cuatro cosas mías, y la primera era de publicación:** copié de `signInToResumeSync`
un belt que comprueba «¿hay sesión y hay token?», y con un 401 del servidor sobre un token aún vigente los dos son
ciertos ⇒ **el botón que ofrecía entrar no entraba**, justo en el caso principal del ticket. Las otras tres: la firma
no estaba atada a la cuenta (con el selector de Google, elegir la de al lado escribía los datos de una persona en la
cuenta de otra), `isWorking` se tomaba tras el primer `await` y el re-kick de 30 s se colaba, y la caption iba detrás de
una rama cuyo tope de 300 s la deja encendida a propósito. Además cazó **dos tests míos que no podían fallar**.

**Dos mutantes sobrevivieron y cambiaron el diseño**, que es lo que aportaron: uno era cobertura que faltaba (no había
ni un test del executor para el drenaje) y el otro era **código que sobraba** — doce líneas de borrado repartidas que
el vecino cumplía solas, sustituidas por un borrador único.

**Qué te toca:**

1. El **QA en iPhone** de `reverse-before-mount-stays-stuck-with-an-expired-session` (en `qa`): 8 pasos, con staging.
   **Los que deciden son el 6 y el 7** — sin red y con la sesión buena **no** debe pedir volver a entrar, y entrar con
   otra cuenta de Google **no** debe retomar la vuelta.
2. **Decidir `reverse-before-mount-has-no-way-to-abandon-the-return`** (medium): esas cuatro fases salen solo por éxito
   y la tarjeta no ofrece cancelar en ninguna. Este cambio cierra la última puerta automática que quedaba —quitar la
   degradación del verify es el criterio 3 del ticket, que aprobaste— sin abrir otra. No es regresión (ese terminal ya
   llegaba con un abort que lanza sin sesión), pero un `otherLeader` o una cuenta suspendida deja sin salida.
3. **`NeutralMountWiringTests` está ROJO en `2.1` y no lo canta nadie** — reproducido en un worktree limpio desde
   `HEAD`, así que no es de este cambio. Es un source-scan de cableado, de los que existen porque su invariante no lo ve
   ningún test normal. Ticket: `neutral-mount-wiring-scan-is-red-on-2-1`.

Validación: build ×2 · unit **181 casos en 4 suites** tras el rebase, y la suite completa en **7244 casos / 734 suites
con 1 solo rojo, el preexistente de arriba** · XCUITest 15 en 4 clases · **17 mutantes cazados** · review con 4 lentes ·
`validate-coverage` OK · `docs/TICKETS.md` igual al disco (466) · **CI verde** (33 min).

## Sesión #193 · Restaurar dice la verdad cuando no se pudo comprobar la nube

**Reinstalo Yala —o estreno móvil— y la abro sin conexión.** Hasta hoy, «Restaurar desde iCloud» me contestaba **«No
encontramos tus datos»** con mi histórico intacto en el servidor. Ahora dice **«No pudimos comprobar tus datos»** y me
ofrece reintentar; si toco «Empezar desde cero» desde ahí, la app pregunta antes, porque nadie sabe todavía si tengo algo
que perder. Tu decisión del 17-sep, **opción 2**: se corrige el mensaje, no se abre una puerta a la cuenta sin red.

**La señal es la ausencia de snapshot de remote-config tras forzar el refresco**, que dice literalmente «en esta
instalación nunca hemos conseguido que el servidor conteste». Medido y descartado el `settled` de la búsqueda de iCloud:
su propia nota dice que un store que nada importa —un usuario realmente nuevo— agota los 90 s igual que un teléfono sin
red, así que habría cambiado una mentira por otra. `isCloudPaused` pasa a ser `WelcomeRestoreEmptyOutcome.resolve`: una
sola decisión con tres salidas, no dos booleanos que puedan contradecirse.

**La review (tres lentes) tumbó cinco cosas mías, y la primera era de producto.** Mi primer intento mandaba a «no pudimos
comprobar» todo lo que llegara sin snapshot, faro incluido, y eso le retiraba «tus datos siguen a salvo en tu cuenta de
Yala» justo a quien SÍ podemos probar que tiene cuenta: las dos señales viajan por canales distintos —el faro por el
iCloud-KV, el snapshot por nuestro gateway—, así que una red que filtre su dominio o un 5xx dejan el faro puesto. **Ahora
el faro gana.** Las otras cuatro: el copy decía «revisa tu conexión» cuando la que falló es NUESTRA comprobación (y el
icono era un wifi); `es-AR` se quedó sin voseo, byte-idéntico a `es-ES`, con sus tres vecinos de pantalla voseando; un
ancla de test medía la etiqueta del argumento en vez de la lectura; y tres afirmaciones las declaré sin medirlas.

**Un rojo del gate no era mío, y se midió cuatro veces.** `test_extremeMinimumAmountSaves` cayó en la primera corrida del
lote; base limpio verde, mi árbol aislado verde, y **el mismo lote repetido sobre el mismo código, verde**, las cuatro con
el centinela en 0. Es el flaky ya registrado en `edgecases-extreme-minimum-flaky-under-load`, que ahora lleva la tabla.

**Qué te toca:**

1. El **QA en iPhone** de `reinstall-without-network-has-no-cloud-door` (en `qa`): 9 pasos. **El paso 5 es el que decide** —
   reinstalar + modo avión debe decir «No pudimos comprobar tus datos». El paso 8 es el control con red.
2. **Decidir `restore-says-no-data-when-the-icloud-import-never-settled`** (lo abrí en **high**): es el canal gemelo, con
   MÁS población que este ticket. Si el import de iCloud no asienta en 90 s, la pantalla sigue diciendo «no hay datos» y
   ofrece «Empezar desde cero» **sin confirmar**. Puede perder datos.
3. Sigue pendiente el **QA en iPhone de #192** (`previous-person-cloud-session-survives-fresh-start-and-reinstall`), cuyo
   paso 4 decide si eso se publica.

Validación: build ×2 · unit **313 casos en 39 suites** · XCUITest 18 en 5 clases con centinela en 0 · **7 mutantes
cazados** · review con 3 lentes · `validate-coverage` OK · `docs/TICKETS.md` igual al disco (462) · **CI verde**.

## Sesión #192 · la sesión en la nube de la persona anterior ya se retira

**Me dan un iPhone donde otra persona usaba Yala: la app ya no usa su cuenta en la nube sin que yo la elija.** La sesión se
retira por los dos sitios por los que sobrevivía — al «Empezar desde cero», en el mismo gesto que borra los datos, y al
instalar Yala en un teléfono donde ya estuvo, porque el llavero de iOS sobrevive a borrar la app y las preferencias no.
Desde ahí ninguna puerta (el Welcome, «Activar Yala completo», la hoja de Grupos, la tarjeta de adopt) puede usarla:
sencillamente ya no hay sesión que reusar. Es la RAÍZ de lo que #190 empezó a tapar puerta a puerta. Tu decisión del 17-sep,
«las dos mitades», y quien reinstala su propia app vuelve por «Ya tengo una cuenta → Entrar con Apple/Google».

**El cursor de Grupos se conserva, que es lo que pediste medir:** cerrar la sesión no invierte su signo — está indexado por
`groupID`, un re-join ya lo resetea, y si el retiro falla es la única barrera que queda.

**La review (tres lentes) tumbó tres cosas mías, y una era de publicación:** `cloudSync.installSeen` nace con este cambio,
así que está ausente en TODOS los teléfonos del parque — «no hay marca» significaba «primera vez que corre este código», no
«app recién instalada», y la primera actualización habría cerrado la sesión de todos los usuarios de la nube. Las otras dos:
sellar el dominio sobre un store vacío se lo comía quien reinstala su PROPIA app (lo midieron dos lentes por separado), y
consumir el arm en el bootstrap metía hasta 60 s de red delante de la primera pantalla. Además cazó que el sign-out del SDK
no para su auto-refresh, una quinta puerta de «empiezo de cero» sin cubrir, y tres aserciones que no podían fallar.

**Qué te toca:**

1. El **QA en iPhone** de `previous-person-cloud-session-survives-fresh-start-and-reinstall` (en `qa`): 9 pasos. **El paso 4
   es el que decide si esto se publica** — actualizar el build ENCIMA de una instalación viva NO debe cerrar la sesión.
2. Decidir `reinstall-without-network-has-no-cloud-door` (medium): tras reinstalar y sin red no hay puerta a la nube, y el
   mensaje que sale dice «no encontramos tus datos» con los datos intactos. Tres opciones en el ticket.

Validación: build ×2 · unit 243 casos en 26 suites · XCUITest 26 en 7 clases con centinela en 0 · **19 mutantes cazados** ·
review con 3 lentes · `validate-coverage` OK · `docs/TICKETS.md` igual al disco (452) · **CI verde** (tests 35 min).

## Sesión #191 · sin red, salir de un grupo ya no dice «Tu sesión caducó»

**Sin conexión y con el token caducado, las acciones de Grupos ya no dicen «Tu sesión caducó».** Salir de un grupo dice «No
pudimos completar tu salida del grupo. Vuelve a intentarlo en un momento.». Aceptar una invitación ya no abre la hoja de
«Inicia sesión»: la unión espera, a los 20 s dice «Está tardando un poco más de lo normal» y se reintenta al volver Yala a
primer plano. Con la sesión borrada de verdad, las dos siguen pidiendo volver a entrar. Es el hermano de #171 y #188 en las
acciones de Grupos. Fue un encargo de noche, y lo discutible está en el PR.

**La review (tres lentes) retiró el reintento corto que yo había añadido:** el SDK ya reintenta la renovación por dentro, y
reintentarla también fuera pasaba la espera sin red de ~1 s a ~7 s, y de ~3 a ~9 min con una red que no responde. Además
endureció cuatro tests y abrió tres tickets. Crear grupo, aprobar y expulsar siguen enseñando el error crudo de siempre, con
ticket propio (`groups-create-approve-remove-show-a-raw-rpc-error`, low).

**Qué te toca:**

1. El QA en iPhone de `groups-actions-read-an-offline-token-refresh-as-a-session-expiry` (en `qa`): 7 pasos, con modo avión
   y el control de sesión borrada por SQL en staging.
2. Decidir `groups-join-is-not-retried-when-the-network-returns` (low): con la app delante, la unión no se reintenta al
   volver la red, y «Está tardando…» promete que el grupo aparecerá apenas esté listo.

Validación: build ×2 · unit 7215 casos en 732 suites · XCUITest 19 en 5 clases con centinela en 0 · 11 mutantes cazados ·
review con 3 lentes · `validate-coverage` OK · `docs/TICKETS.md` igual al disco (450) · **CI verde** (tests 32 min).

## Dos sesiones atrás (#190 · «Activar la nube» ya no usa la cuenta que dejó abierta la persona anterior)

**En un iPhone que pasó por «Empezar desde cero», «Activar la nube» ya no promueve la cuenta que dejó abierta la persona
anterior.** Sale «Esta cuenta puede ser de otra persona» antes del consentimiento, y la salida es desasociarla en «Grupos» y
volver a activar la nube para elegir la propia. Fue un encargo de noche con tu decisión del 16-sep: elegí bloquear en vez de
preguntar y limitarlo a teléfonos sellados, y las dos elecciones están en el PR como lo discutible.

**La review (dos lentes) tumbó mi primera versión:** las dos cazaron por separado que la hoja de Grupos asociaba la sesión
viva cuando una invitación se quedaba sin token, y eso le daba a la puerta la cuenta de la persona anterior como «asociada».
Ahora el escritor de la asociación exige que la sesión la abriera el propio sign-in, y la salida del aviso ya no escribe en
el iCloud-KV del Apple ID anterior.

**Qué te toca:**

1. El QA en iPhone de `fresh-start-keeps-a-groups-session-that-migrate-promotes` (en `qa`): 13 pasos, con reinstalación y
   SQL de staging.
2. Decidir `previous-person-cloud-session-survives-fresh-start-and-reinstall` (high). Tras reinstalar no queda sello, el
   arranque asocia la sesión anterior y la puerta no la ve; además el Welcome, «Activar Yala completo», Grupos y la tarjeta
   de adopt la reusan. Hay cuatro opciones en el ticket.

Validación: build ×2 · unit 7206 casos en 731 suites · XCUITest 31 en 10 clases con centinela en 0 · 18 mutantes cazados ·
review con 2 lentes · `validate-coverage` OK · `docs/TICKETS.md` igual al disco (446) · **CI verde** (tests 20 min).

## Sesión #189 · «Descargando tus datos…» ya no gira al lado del aviso de App Attest

**En la nube, un teléfono sin App Attest ya no ve la ruedecita girando para siempre al lado del aviso.** Con el veredicto
de App Attest terminal, «Descargando tus datos…» se esconde y queda solo «Este teléfono no puede sincronizar tus datos».
Si el attest vuelve y el motor empieza a bajar, la ruedecita reaparece en un segundo. Sin copy nuevo. Fue un encargo de
noche con la opción 1 del ticket.

**La review (dos lentes) no tumbó el diseño, pero corrigió lo que escribí:** «una descarga exige token» solo es cierto para
el pull del motor (los de la migración bajan sin su puerta), y el cruce de las 24 h por reloj con la app delante deja un rato
sin spinner ni aviso: ya era un hueco del aviso, y el spinner lo tapaba mintiendo. Queda escrito como residual en
`.claude/rules/gateway-attest.md`. También cazó que el source-scan no fijaba dónde cuelga el sondeo.

**Qué te toca:** nada en un iPhone (el ticket queda en `done`, como el #177: la población no se monta en ningún
dispositivo). Dos decisiones `low`: `cloud-hydration-spinner-keeps-spinning-with-the-engine-stopped` (el spinner no mira el
motor) y `cloud-hydration-banner-does-not-see-data-that-arrives-after-mount` (si la píldora se va al llegar los primeros
datos o al terminar la descarga).

Validación: build ×2 · unit 7194 casos en 731 suites · XCUITest 5 en 3 clases con centinela en 0 · 8 mutantes cazados ·
review con 2 lentes · `validate-coverage` OK · `docs/TICKETS.md` igual al disco (444) · **CI verde** (tests 23 min).

## Sesión #188 · sin red, el canal personal ya no lee una renovación fallida como sesión caducada

**Con la cuenta en la nube, un corte de red al caducar la sesión ya no para la sincronización ni pide iniciar sesión.** Si
la sesión caduca sin conexión mientras la verificación de App Attest sigue en caché (los 15 min tras usarla), o si cae el
servidor de sesiones con la red bien, el motor personal reintenta solo y sube al volver la red, y Grupos sube en la misma
vuelta. «Activar Yala completo» sin red ofrece «Reintentar» en vez de «Tu sesión caducó», y el alta del Welcome ya no
cierra la sesión. Fue un encargo de noche: todo con la recomendada, y lo discutible está en el PR.

**La review tumbó la mitad de mi primer diseño:** copié de Grupos que el 401 `yala_attest_required` suma a la racha del
teléfono, y en el canal personal ese 401 llega después de que la puerta consiga el token, así que no habla del teléfono.
Contarlo acababa ofreciendo «Cerrar sesión y perderlos» a un teléfono que sí atesta. Ahora es pasajero, con canario propio
(`cloudSyncAttestRequired`), y no toca la racha. **La segunda pasada cazó que mi guion de device-QA no llegaba al arreglo:**
sin red la verificación caduca y el motor salía antes del push, con el arreglo y sin él.

**Qué te toca:** el QA en iPhone de `personal-sync-reads-an-offline-token-refresh-as-a-session-expiry` (en `qa`), con
`Yala Dev` contra staging: hay que montar una ventana de 14 min, y el guion trae un control con el build de antes. Y dos
decisiones de producto: `cloud-attest-notice-does-not-cover-a-gateway-rejected-token` (si el aviso fijo debe salir a quien
el servidor le rechaza un token bueno) y `cloud-sync-status-says-all-synced-with-changes-still-pending` («Todo
sincronizado» con cambios sin subir). **Ojo al dashboard:** `cloudSyncBlockedByExpiredSession` cambia de definición con
este build.

**Cuatro tickets nuevos:** los dos de arriba (`medium`), el 401 de JWT con el reloj atrasado y el plural de «1 cambios»
(`low`).

Validación: build ×2 · unit 7188 casos en 730 suites · XCUITest 29 en 9 clases con centinela en 0 · 21 mutantes cazados (3
en el gateway) · dos pasadas de review (4 + 2 lentes) · `validate-coverage` OK · `docs/TICKETS.md` igual al disco (442) ·
**CI verde** (tests 23 min).

## Sesión #187 · «Migrar a la nube» ya no mezcla tus datos con una cuenta que ya tiene los suyos

**«Activar la nube» ya no fusiona tus finanzas con las de una cuenta que ya tenía las suyas.** El ticket decía «adopta y
no sube lo mío», y la medición lo corrigió: el adopt subía a esa cuenta todo lo de este iPhone que ella no conocía, y la
mezcla llegaba a todos sus dispositivos. Ahora Yala no mueve nada y lo dice con una hoja: «Esa cuenta ya tiene finanzas
personales» (con «Usar otra cuenta» y «Entendido», y una nota si era de Apple), «Esta cuenta volvió a iCloud», «Ya usas
otra cuenta para tus grupos» o «No pudimos comprobar tu cuenta». Con la sesión de tus grupos sale al tocar, antes del
consentimiento. Son tus respuestas de tres rondas; en D15 elegiste permitir otro Apple ID, en ticket aparte.

**Hacían falta dos capas:** la comprobación antes del claim no ve la cuenta que volvió a iCloud (`/account/exists` la da
como «solo grupos»), así que el runner lleva además la intención de migrar, journaleada: `existing_stable` y
`claiming_in_progress` vuelven al inicio en vez de adoptar o seguir a otro líder. **D18 cierra a sabiendas una salida:**
una migración abandonada por su líder ya no se retoma desde otro dispositivo (va al ticket de D14).

**Qué te toca:** el QA en iPhone de `settings-migrate-to-cloud-adopts-silently-instead-of-migrating` (en `qa`): `Yala Dev`
contra staging, dos o tres cuentas de Google de prueba y el guion con su SQL en el ticket.

**Diez tickets nuevos**; el único `high` es `fresh-start-keeps-a-groups-session-that-migrate-promotes` (ya pasaba en
`2.1`: tras «Empiezo de cero» la sesión de grupos de la persona anterior sobrevive y «Migrar» la promueve). Uno de copy
espera tu decisión: `migrate-card-keeps-promising-an-account-the-check-refused`.

Validación: build ×2 · unit 7169 casos en 730 suites · XCUITest 31/31 con centinela en 0 · 26 mutantes cazados · dos
pasadas de review (4 + 2 lentes) · `validate-coverage` OK · `docs/TICKETS.md` igual al disco (438) · **CI verde** (tests 23 min).

## Sesión #186 · un rechazo al volver a iCloud ya no deja la barra al 15 %

**Si el servidor no deja empezar «Volver a iCloud», la app vuelve a la nube al momento y lo dice.** Hasta hoy la barra se
quedaba al 15 % para siempre, «Retomar» repetía lo mismo y, tras relanzar, el teléfono dejaba de sincronizar con la nube.
Ahora sale una alerta si tienes la pantalla delante (al tocar, con «Retomar» o si llega mientras miras) y la frase queda
en la tarjeta «Volver a iCloud» hasta el siguiente intento, en pasado y con el motivo: la migración aún terminando, la
cuenta que no lo permitía (con el correo de soporte) u otro dispositivo ya volviendo. Son tus cinco respuestas del día,
todas con la recomendada.

**La review cazó que mi salida limpia se llevaba algo:** la vuelta tira los pendientes del origen, y uno de ellos es lo
único que manda `complete` de una migración. Un líder con el `complete` a medias dejaba `migration_in_progress` puesto en
el backend para toda la cuenta. Ahora un intento no concedido devuelve el teléfono exactamente como estaba.

**Qué te toca:** el QA en iPhone de `reverse-claim-rejection-has-no-way-out-in-the-client` (en `qa`): cuenta en la nube
real con `Yala Dev` contra staging, y cada rechazo se monta con una línea de SQL en staging que se deshace al terminar
(guion en el ticket).

**Tres tickets nuevos, ninguno bloquea 2.1:** la sesión caducada antes del montaje de la vuelta, el toque que se pierde si
la app está retomando algo y un residual aceptado (un teléfono con la migración a medias que falla siempre puede quedarse
sin sincronizar hasta reabrir Yala). Y una medición para el backend: tres caminos al mismo `not_complete`, en
`reverse-exit-on-a-reverted-account-rejects-the-retry`.

Validación: build ×2 · unit 7117 casos en 728 suites · XCUITest 7/7 con centinela en 0 · 21 mutantes cazados · dos
pasadas de review · `validate-coverage` OK · `docs/TICKETS.md` igual al disco (428) · **CI verde** (tests 23 min).

## Sesión #185 · la vuelta a iCloud ya no se queda al 95 % para siempre

**«Volver a iCloud» ya no se clava al 95 % sin salida.** Mientras espera, «Dónde viven tus datos» dice cuánto falta por
subir, o que iCloud no tiene espacio o no está disponible, y ofrece «Cancelar y seguir en la nube». Si la subida no
avanza, la app vuelve sola a la nube: a los 15 min si iCloud dijo que no, a las 72 h si no se sabe. Después, la tarjeta
de «Volver a iCloud» dice por qué. Son tus siete respuestas del día, todas con la recomendada.

**Una cuenta nacida en la nube ya no «vuelve» al instante sin subir nada** (D15): el muestreo solo veía filas con
testigo `SyncIdentity`, y lo creado en ese teléfono no lo tiene.

**La segunda pasada de review cazó un callejón en mis propios arreglos:** drenar todos los efectos pendientes antes de
otra vuelta dejaba a un líder desplazado sin su única salida. Ahora solo se drena la salida pendiente. Cazó también un
aviso que se cerraba solo en 30 s y un «Cancelar» que se perdía con iCloud importando.

**Qué te toca:** el QA en iPhone de `reverse-upload-has-no-ceiling-and-no-exit` (en `qa`): cuenta en la nube real,
`Yala Dev` contra staging y un iPhone **sin sesión de iCloud**, que es el caso que nunca drenaba. El techo por tiempo no
se recorre a mano: lo fijan los unit tests.

**Diez tickets nuevos en backlog, ninguno bloquea 2.1:** la entrada a la vuelta sin iCloud (D4), los tres casos raros de
volver a la nube (D17), el muestreo que lee «no pude leer» como «nada pendiente», la fecha puesta atrás durante la
espera, la doble pasada del muestreo en el hilo principal y una acción de Ajustes que se pierde durante un re-kick, entre
otros.

Validación: build ×2 · unit 7097 casos en 727 suites · XCUITest 20/20 con centinela en 0 · 26 mutantes cazados ·
`validate-coverage` OK · `docs/TICKETS.md` igual al disco (425) · **CI verde** (build y unit, 23 min).

## Sesión #184 · la cola de QA baja de 83 a 52, y los 52 tienen montaje

**La cola de QA vuelve a decir la verdad.** De los 83 tickets de `tickets/qa/`, 18 pasaron en el simulador con captura, 11
se cerraron sin verlos por tu override (6 sin forma de montarlos en ningún sitio, 5 cuya prueba vive en otro ticket de la
cola) y 2 volvieron a backlog porque esperaban código. Cero FAIL. Los 52 que quedan tienen montaje en
`qa/guion-tanda.md`, en ocho grupos según lo que haya que preparar: empieza por los 3 de simulador a mano (unos 30 min) y
arranca los 3 de «un día» para mirarlos al siguiente.

**Lo que aprendí montando:** en simulador, Atajos no ejecuta la tarjeta del atajo de Yala (el build no lleva firma de
equipo), pero sí una acción añadida a mano. Así se vieron los dos de Siri, incluido el borrador en caliente. Y «Simular
Pro» persiste y contamina a los unit tests: lo purgué. Las dos cosas están en `docs/aprendizajes-tecnicos.md`.

**Dos hallazgos van a backlog:** con el iPhone en español, las respuestas de error de «Anotar con Siri» salen en inglés
(`siri-shortcut-error-replies-speak-english-on-a-spanish-iphone`), y el importador de CSV no marca sus filas como
importadas (`csv-import-leaves-no-origin-mark-and-reuses-opposite-categories`).

**Dos decisiones te esperan, sin bloquear nada:** si te vale la D6 del Paso 0 (Siri dado por bueno lanzándolo desde Atajos,
sin la voz), y si dejas staging un día en `enforce` para `groups-phone-that-never-attests-is-told-to-retry-forever` o se
cierra como no replicable.

Validación: `docs/TICKETS.md` igual al disco (415) · las 51 cabeceras tocadas parsean · `validate-coverage` OK · **CI verde**
(build y unit, 24 min).

## Sesión #182 · sin App Attest, Ajustes no ofrece la tarjeta de la nube

**Un teléfono sin App Attest ya no ve la tarjeta de la nube en «Dónde viven tus datos».** Ni «Migrar a la nube» ni
«Activar la nube en este dispositivo», la cara que sale en un segundo dispositivo cuando la cuenta ya se migró desde otro:
tu decisión de las 7:1x, porque sin token las dos acaban en el mismo reintento sin fin, y «Migrar» además dejaba la cuenta
creada en el servidor. La pantalla se queda con «iCloud privado» y, si aplica, Grupos, sin texto nuevo. Con App Attest no
cambia nada, y quien ya está en la nube o tiene una migración a la vista conserva su pantalla. Es la tercera puerta del
día, después de #180 y #181.

**La review cazó tres cierres de más sin red, y una frase mía falsa.** Una segunda lectura de la capacidad en el botón, el
guard de aborto invertido o una copia de la declaración bajo `#if DEBUG` le quitaban la tarjeta a un iPhone con App Attest
con todo en verde: ahora tienen red. Y «quien ya está dentro conserva su panel» era falso para quien tocó «Activar en este
dispositivo» antes del cambio: se queda sin tarjeta mientras el adopt reintenta en segundo plano.

**Dos cosas van a otros tickets.** La frase de Grupos «Se decide en Ajustes» ya no lleva a ninguna tarjeta sin App Attest:
la anoté, como elegiste, en `groups-block-has-no-route-to-storage-settings`, que la va a cambiar por un botón. Y un defecto
anterior va a ticket nuevo: `groups-only-session-storage-screen-says-data-lives-in-icloud`.

Gate: build ×2 sin warnings en lo tocado · **unit 7052 casos en 725 suites** · **XCUITest 15 casos** con el centinela en 0
(14 verdes y `test_extremeMinimumAmountSaves`, el flaky conocido, verde aislado 2 de 2) · **mutation-tested ×13**, cada uno
en rojo en su test · tres lentes · **CI verde** (build y los 7052 unit).

**En `qa`, con un paso en iPhone real**: con App Attest la tarjeta sigue saliendo. Comparte montaje con los de #180 y #181.

## Sesión #181 · sin App Attest, la pantalla de entrar no ofrece crear cuenta

**Un teléfono sin App Attest ya no se da de alta en la nube por ninguna puerta del Welcome.** Después del #180 quedaban
dos: «Crear mi cuenta» tras «No encontramos una cuenta» y «Crear cuenta con…» del mismatch. Ahora pasan por la misma puerta
que la tarjeta, `WelcomeNewOptionsGate.offersCloudSignUp`: App Attest, el kill del alta y el resto de la card. Sin ella, «No
encontramos una cuenta» ofrece **«Volver»** —tu decisión de esta mañana, con el texto que ya existía— y el mismatch se queda
con «Iniciar sesión con…». Con App Attest no cambia nada. Encargo nocturno, opción 1.

**La review cazó otra vez el fallo caro en MIS tests.** Medían que los botones de crear cayeran dentro de la puerta, no que
la puerta fuera su única condición: un `if` más o un `#if DEBUG` le quitaba el botón a un iPhone con App Attest con la suite
en verde. Ahora fijan el cuerpo entero de las dos pantallas. Cazó también que mi primera versión dejaba «No encontramos una
cuenta» con la flecha de la esquina sola —el callejón que quitó el bloque [I]— y un guion de device-QA que el faro de
iCloud podía dar por FAIL.

**El simulador ya no crea cuentas en la nube sin `YALA_DEV_SHARED_SECRET`**, por ninguna vía. El montaje del #175 queda
reescrito con el secreto, y ese secreto **no está en `~/Secrets`**: es de Wrangler en staging y no se lee de vuelta. Lo
tienes tú, o hay que rotarlo.

Gate: build ×2 sin warnings en lo tocado · **unit 7048 casos en 725 suites** · **XCUITest 18 casos** con el centinela en 0 ·
**mutation-tested ×22**, todos en rojo en su test · dos lentes + la regla de attest · **CI verde** (build y los 7048 unit).

**Quedaba en backlog `cloud-migration-offers-the-cloud-to-a-phone-without-app-attest`**: «Migrar a la nube» era el único
camino al alta completa que no miraba la puerta. Lo cierra #182.

## Sesión #180 · sin App Attest, el alta no ofrece la nube

**Un teléfono que no puede conseguir App Attest ya no ve «Tu cuenta en la nube».** Antes la elegía, apuntaba sus gastos y
nada llegaba nunca a su cuenta: el motor corta en su puerta de attest antes de subir. Ahora «Es mi primera vez» va directa a
«Tu cuenta en tu iCloud privado», el recorrido de cuando la nube está apagada, sin texto nuevo. Lo mismo en «Activar Yala
completo», y «Crear otra cuenta» enseña la elección con la tarjeta privada sola. Con App Attest no cambia nada. Era la
decisión del owner del 2026-07-06 —bloquear por adelantado—, que vivía en `AttestSyncGate.shouldOfferCloudOnly` sin un solo
llamador y con dos docblocks que decían lo contrario. Encargo nocturno, opción 1.

**«Tener App Attest» lo define un solo sitio, y es lo que cree el cliente**: `AppAttestClient.canObtainSessionToken`, la
primera decisión de `performRefresh` en un booleano (`isSupported`, o en DEBUG el bypass con secreto). **El simulador no
tiene App Attest y no se le exime**: sin `YALA_DEV_SHARED_SECRET` en `Yala Dev` ya no ofrece la nube, a propósito, para que
QA y producción decidan igual. Si en el simulador «no sale la nube», no es la configuración remota.

**La review adversarial cazó el fallo caro en MI test, no en el código.** El scan de la entrada del attest fijaba un prefijo
sin su coma, y un término pegado detrás dejaba a todo iPhone sin la nube con la suite entera en verde: en el host de test la
capacidad vale `false` y nada más podía verlo. Ahora compara el cuerpo entero. Cazó además dos aserciones que no podían
fallar y que «Crear otra cuenta» no hacía bypass ni tenía test.

Gate: build ×2 sin warnings nuevos · **unit 7045 casos en 725 suites** · **XCUITest 20 casos** con el centinela en 0 · dos
lentes + la regla de attest contra el diff · **CI verde** (build y los 7045 unit). **Mutation-tested ×14**, todos en rojo en su caso; el control sin
el seam mide que en XCUITest el simulador de verdad no tiene App Attest.

**Deja dos decisiones tuyas en backlog, las dos nacidas de medir el alcance** (las dos cerradas después, en #181 y #182).
`cloud-sign-in-screen-offers-sign-up-to-a-phone-without-app-attest`: «Crear mi cuenta» tras «No encontramos una cuenta» y
«Crear cuenta con…» del mismatch también dan de alta sin mirar el attest (ni el kill del alta, que es anterior); cerrarlas
vuelve pared dos pantallas que tú abriste. `cloud-migration-offers-the-cloud-to-a-phone-without-app-attest`: «Migrar a la
nube» tampoco lo mira, aunque por lo inferido no atrapa a nadie. Y un tercer productor del «volver» mal calculado de la
puerta de iCloud, anotado en `private-icloud-gate-back-lands-on-the-wrong-branch`.

## Sesión #179 · volver a la app adelanta la subida de grupos

**Quien recupera la conexión y vuelve a Yala ya no espera al reintento.** Me quedo sin red con la app abierta,
salgo, la red vuelve y entro otra vez: antes mis cambios de grupos seguían parados hasta que venciera el
reintento pendiente —5, 10, 20… hasta **cinco minutos**—, salvo que guardara algo o tirase hacia abajo para
refrescar. Ahora vuelven a subir en el acto. Es la decisión de Jürgen del 2026-09-15, opción 1: copiar lo que
el motor personal hace desde I9, que al volver a primer plano corta el sueño en curso y cicla ya.

**Dos ventanas, dos mecanismos, y entre las dos no queda hueco.** El sueño de cada vuelta del loop pasa a
vivir en una tarea propia que el foreground cancela; el foreground que llega **mientras el ciclo corre** no
tiene sueño que cortar y lo sirve una marca que pone a cero el delay de esa vuelta y solo de esa. Despertar
**no borra la racha de fallos**: adelantar un reintento no significa volver a empezar por 5 s, y lo fija una
aserción. Entra por el mismo `startIfEligible(trigger:)` que ya llamaba el bootstrapper, en el `else` donde
antes no pasaba nada — así ningún call-site futuro puede olvidarse de despertar.

**La review adversarial cazó un defecto serio que era MÍO, y las tres lentes coincidieron.** Sacar el sueño a
una tarea aparte le quitaba dos garantías del contenedor. Una, la cancelación: un `Task {}` no hereda la de
quien lo crea, así que `stopLoop()` —los cinco caminos de cierre de sesión— habría esperado el backoff entero;
lo cierra un `withTaskCancellationHandler` con test propio. La otra, la identidad del handle: `stopLoop()`
despublica el loop en el acto pero el viejo sigue dentro de su request, y al morir le borraba el handle al que
había nacido detrás — dos loops vivos, un `stopLoop` posterior cancelando `nil` y un despertar que dejaba su
línea en el log **sin cortar nada**, o sea el bug del ticket resucitado e invisible. Cada loop lleva ahora su
generación. El mismo defecto estaba en el `defer { loopTask = nil }` **anterior a este cambio**.

Y cazó **una aserción mía que no podía fallar**: miraba el efecto de un `cancel()` sin soltar el MainActor, y
el `catch` que lo registra no corre hasta entonces — salía verde también con el gate borrado. Lo destapó el
mutante, no la lectura.

Gate: build ×2 sin warnings nuevos · **unit 266 casos en 19 suites** · **XCUITest 4 casos** con el centinela
del simulador en 0 · tres lentes + las rules de área contra el diff · **CI verde**. **Mutation-tested ×7**, los
siete en rojo. **Sobrevive uno y va declarado**: publicar el sueño sin comprobar la generación, cuyo escenario
exige que el loop nuevo duerma antes que el viejo. **Sin device-QA**: reproducirlo pide cortar la red con
cambios sin subir y esperar a que el backoff crezca; no hay seam de simulador que lo monte y el efecto no tiene
superficie visual. El rastro en Console.app es `GroupsSync loopWoken trigger=foreground sleeping=true`.

**Deja un ticket nuevo y dos residuales escritos.**
`groups-has-no-cadence-when-the-personal-runtime-is-stopped`: con el motor personal parado
(`.stoppedUntilRelaunch`), Grupos se abstiene de su loop porque el gate mira `canRunDomain()` y ése no mira el
estado del runtime — ahí no hay loop que despertar y volver a la app tampoco lo mueve. Los residuales, para no
re-litigarlos: el despertar corta también la cadencia sana de 60 s (igual que el personal en `.running`), y sin
red cada vuelta a la app suma un escalón de backoff (misma aritmética que el personal).

## Sesión #178 · sin conexión, el cierre ya no dice que está guardando algo

**Quien intenta cerrar sesión sin conexión ya no oye que se está guardando algo.** Antes esperaba 45 s mirando
«Guardando tus cambios pendientes…» y al final leía «Un momento más · Todavía estamos terminando de guardar
unos cambios. Espera unos segundos y vuelve a intentarlo». Nada de eso pasaba: faltaba la red, y volver a
intentarlo costaba otros 45 s de lo mismo. Ahora el aviso sale **al primer intento** y dice lo cierto — los
cambios **no llegaron al servidor**, siguen guardados en este teléfono y no se pierden. El texto de «un
momento más» se queda donde siempre fue verdad: el guardado que todavía se asienta, que sigue reintentando
sus 45 s porque ahí esperar es justo lo que hace que el gesto termine solo. Es la decisión de Jürgen del
2026-09-15: separar las dos causas, una con su texto.

**Cuatro superficies y cero keys de l10n nuevas.** Ajustes y la hoja del cambio de Apple ID ya estaban
enrutadas. El desasociar y la puerta de Grupos del Welcome lo estrenan, y al segundo le hacía falta rama
propia: su `switch` no es exhaustivo, así que `.uploadRetryLater` habría caído en el catch-all que dice
«vuelve y entra con esa cuenta» — el consejo contrario para quien no tiene red. Lo anticipaba el propio
docblock del motivo, escrito el 14-sep «para el día en que naciera un segundo productor».

**La review adversarial refutó mi arreglo, y esa es la mitad no obvia.** Mapeé `CadenceOutcome.transient`
entero a «la subida falló» tras inventariar sus 40 productores… y la conclusión era la equivocada, porque no
miré **quién escribe el valor que estaba clasificando**: `syncCycleOnce` corta con el outcome del push solo
si el push PARA, así que en el caso normal el veredicto es **el del pull**. Con la subida perfecta y el pull
caído yo decía «tus cambios no llegaron al servidor»; y al `save()` local de una página —que es
H-2026-07-18-6, el caso que motivó los 45 s— le quitaba encima el reintento que sí lo cura. De ahí sale
`GroupsSyncClient.lastCycleFailedUpload` + `stoppedByFailedUpload(for:)`, molde exacto de sus dos hermanos:
se baja al entrar en el ciclo y lo enciende el push y solo el push, en los nueve puntos donde se choca con el
servidor. La marca es POSITIVA: marcar de menos deja el aviso conservador de siempre, marcar de más acusa al
servidor de algo que pasó en este teléfono.

Gate: build ×2 sin warnings nuevos · **unit 7029 en 725 suites** · **XCUITest 3 clases y 10 casos** ·
review de tres lentes + las rules de área contra el diff · **CI verde**. **Sin device-QA**: reproducirlo
exige cortar la red con cambios de grupos sin subir y una sesión viva, y no hay seam de simulador que lo
ponga; el ticket cierra en `done`.

**Deja un ticket y un colateral que conviene saber.**
`sign-out-block-reason-is-only-logged-on-the-cloud-path`: el motivo del bloqueo solo se registra en el camino
de la nube, justo donde este cambio mueve población entre dos avisos distintos. Y
**`signout-alert-fires-on-detach-blocks-it-did-not-cause` empeora**, anotado allí con su medición: al
desasociar sin red, el aviso colateral de Ajustes pasa de «Un momento más» —impreciso pero neutro— a **«No
pudimos cerrar tu sesión»**, que nombra un gesto que nadie pidió. No se arregló a propósito: cortar por
motivo dejaría sin aviso al cierre de verdad, y el discriminador correcto es el GESTO, que el coordinador no
publica. **Es una decisión de producto que espera a Jürgen.**

De paso, el disco había bajado a 12 GB —los XCUITest habrían empezado a fallar con errores que no mencionan
el disco—: 13 GB recuperados de DerivedData de dos worktrees ya retirados.

## Sesión #177 · la app avisa cuando este teléfono no puede sincronizar tus datos

**Quien tiene sus datos en la nube y este teléfono no consigue la verificación de seguridad ya se entera solo.**
Antes no se lo decía nadie: apuntaba gastos, no llegaban a su cuenta, y solo lo descubría si intentaba cerrar
sesión. Ahora, mientras el veredicto sea terminal, el **Panel** enseña un aviso fijo con el mismo título que ese
cierre —«Este teléfono no puede sincronizar tus datos»— y un cuerpo que añade lo que nadie decía: **lo apuntado
sigue guardado en este teléfono**. Sin X y sin botón, como el hermano de Grupos. Es el ticket que dejó el #176.

**Van DOS superficies porque la segunda mentía.** La opción menos intrusiva era el estado de sync de «Dónde viven
tus datos»… que pintaba un check verde **«Todo al día» con el motor parado**: `refreshSyncBanner` solo mira
`.stoppedUntilSignIn`, y el attest terminal deja el runtime en `.stoppedUntilRelaunch`, que caía al `else`. El
`else` fallaba ABIERTO. Las dos caras comparten una sola decisión y un solo copy, y la rama del attest va **antes**
que la de volver a entrar: re-firmar no arregla un attest roto.

**La review adversarial cazó tres cosas mías y dos cambiaron el producto.** (1) El copy **mandaba a un paywall**:
decía «en Perfil puedes exportar tus datos», y el wizard capa los períodos largos a quien no es Pro — justo la
población que ve el aviso, porque el Modo Nube es gratis. La exportación completa y gratuita existe desde el #175,
pero solo se alcanza al cerrar sesión; el copy ya no la menciona. (2) Faltaba una **cuarta condición**: sin ella,
quien vuelve a iCloud *precisamente porque sus datos dejaron de subir* veía «usa otro teléfono», el consejo
contrario a lo que estaba haciendo. (3) `hasSession` **lee el Keychain** y se evaluaba en cada re-render, también
en los teléfonos que nunca tendrán aviso.

Gate: build ×2 sin warnings nuevos · **unit 7019 en 724 suites** · **XCUITest 8 clases y 20 casos** con cola y
centinela («estuviste solo», 96 muestreos) · **12 mutantes, 12 muertos** · review de tres lentes · **CI verde**.
**Sin device-QA**: el aviso es visual y determinista, y el ticket cierra en `done`.

**Deja dos tickets y un agujero que conviene saber.** `cloud-hydration-spinner-never-gives-up-without-attest` (el
«Descargando tus datos…» que gira para siempre y ahora contradice al aviso), y una anotación dentro de
`personal-sync-reads-an-offline-token-refresh-as-a-session-expiry`: **el canal personal no distingue su propio 401
de attest**, así que a quien el gateway le rechaza el token la app le sigue diciendo «vuelve a iniciar sesión» y el
aviso nuevo **no puede salir**, por construcción. De paso, `docs/TICKETS.md` estaba desfasado en un ticket ajeno;
índice y disco cuadran ahora en 407.

## Sesión #176 · la pestaña Grupos avisa cuando este teléfono no puede sincronizar

**Quien apunta gastos de un grupo desde un teléfono que no consigue App Attest ya se entera.** Antes no se lo decía
nadie: editaba, nadie del grupo lo veía, y el aviso solo aparecía al intentar cerrar sesión, desasociar la cuenta o
salir del grupo. Ahora, mientras el veredicto sea terminal, encima de la lista hay un aviso fijo con el **mismo
título** que esos gestos —«Este teléfono no puede sincronizar tus grupos»— y un cuerpo que ofrece lo único cierto:
usar otro teléfono. Sin X y sin botón, porque describe un estado que sigue ahí después de leerlo y reintentar es
justo lo que lleva un día fallando. Es tu decisión del 15-sep, opción 1.

**Son CUATRO condiciones, no «mientras el veredicto sea terminal».** La racha describe al TELÉFONO: sobrevive al
cierre de sesión a propósito y desde el #175 la escribe también el motor personal, que no sube un gasto de grupo. Con
el enunciado literal, el aviso le mentiría a quien cerró sesión, a quien no tiene Grupos compilado y a quien todavía
no aceptó el consent.

**La review adversarial cazó tres cosas mías y una era el bug del ticket, vivo.** (1) El término del canal iba por el
getter compuesto, que es fail-closed sin snapshot de remote-config: un teléfono **restaurado desde una copia de
iCloud** —que hereda la racha y no la key de attest— se quedaba **sin aviso** en su primer arranque mientras el
cierre de sesión sí se lo enseñaba. Va por la capacidad compilada, como los cuatro teardowns. (2) El aviso se quedaba
mudo con la pestaña delante: medido en el simulador, con la racha escrita un segundo después del arranque no salía
hasta salir y volver — y eso es justo cuando llega el 401. Ahora avisa el **escritor** de la racha. (3) El seam de QA
dejaba el veredicto terminal puesto para todo arranque **manual** del simulador; bajo uitest la racha va ahora a una
suite propia.

Gate: build ×2 sin warnings nuevos · **unit 199 en 33 suites** · **XCUITest 27 clases y 67 casos** con cola y
centinela («estuviste solo», 234 muestreos) · **9 mutantes, 9 muertos** · review de tres lentes · **CI verde**.
**Sin device-QA**: el aviso es visual y determinista, y el ticket cierra en `done`.

**Deja un ticket nuevo:** el mismo aviso fijo para la nube personal, que sigue sin tenerlo. Y anota en
`unit-tests-clear-the-attest-streak-of-a-device-qa-in-progress` que el desvío de uitest **no** lo cubre: los unit
tests corren sin `-uitest`.

## Sesión #175 · sin App Attest en la nube: exportar y salir perdiendo lo personal, con confirmación)

**En la nube, un teléfono que lleva más de un día sin conseguir App Attest ya puede cerrar sesión aunque le
queden cambios suyos sin subir.** Es tu decisión del 15-sep (opción 1). Antes el cierre le mandaba a revisar una
conexión que funcionaba, y así durante días. Ahora Ajustes dice «Este teléfono no puede sincronizar tus datos»,
cuenta los cambios que no llegaron y ofrece tres cosas: exportar todos los movimientos a un CSV, cerrar sesión
perdiéndolos, o dejarlo. Exportar no toca el cierre y devuelve al aviso. Elegir perderlos no borra nada al
momento: el cierre intenta subir una vez y lo que no suba se va con el borrado del arranque. Con cambios de
grupos también, salen los dos avisos seguidos. Y si el attest volvió pero la subida falla por otra cosa, el
cierre se para como siempre en vez de perderlos — también en la salida de grupos del #173, que tenía el hueco.

**Contestaste las tres preguntas de producto con la recomendada:** un aviso con tres botones, exportación directa
de todo sin asistente ni límite de plan, y dos avisos seguidos cuando también hay cambios de grupos.

**La racha de rechazos pasa a ser del TELÉFONO y la escriben los dos canales.** El motor personal nunca manda una
subida sin attest, así que no ve el 401: cuenta el error de su propia puerta cuando habla del attest, y un token
la borra. Sin red o con el gateway caído el veredicto no se acerca. Con dos rachas, aceptar perder lo personal
dejaba los cambios de grupos en «en un rato».

**Una premisa escrita era falsa:** la puerta que no ofrecería la nube a un teléfono sin App Attest **no tiene
llamador**, y dos docblocks decían que sí. Hoy esta salida es la única red para esa gente, y queda su ticket.

**Y media sesión se fue en un rojo que no era del cambio.** Un XCUITest de la hoja del Apple ID cayó 3 de 3 aquí
y pasó en un árbol base: nueve corridas de bisección construyeron una causa falsa, hasta que repetir la MISMA
compilación dio pasa/falla/pasa y el árbol de partida acabó pasando 4 de 4 sin tocar una línea. Es el entorno
—16 sesiones de Claude Code vivas, el sistema matando tandas de tests por memoria— y queda medido en su ticket,
con la corrección de que no es solo «el simulador frío». La lección de método está en la memoria de Frank.

Gate: build ×2 sin warnings nuevos · **unit 6.876 en 699 suites** (por lotes: entera no cabía en memoria) con un
rojo preexistente del resumen de Registros que **pasa aislado** y solo cae junto a las suites de grupos y FX ·
**31 mutantes, 31 muertos** · **XCUITest 71 casos en 31 clases** con cola y centinela, con el rojo del entorno
clasificado en 19 corridas · review de tres lentes · **CI verde**. **Device-QA: no se puede montar aquí**, y el
ticket queda en `qa` con su guion.

**Deja seis tickets nuevos**, uno alto: la puerta del onboarding que no ofrece la nube y no tiene llamador.

## Sesión #173 · un teléfono sin App Attest recibe su veredicto y puede cerrar sesión perdiendo los cambios)

**Un teléfono que lleva más de un día sin conseguir App Attest deja de oír «inténtalo en un rato».** Es tu decisión
del 15-sep (opción 2). Pasadas 24 h con al menos 3 rechazos del servidor —como mucho uno por hora— y ningún acierto,
Grupos dice «Este teléfono no puede sincronizar tus grupos». Si al cerrar sesión quedan cambios de grupos sin subir,
Ajustes, la hoja del cambio de Apple ID y la puerta del Welcome ofrecen «Cerrar sesión y perderlos» con la cifra; a
quien entra por una invitación, no. Desasociar y salir de un grupo enseñan el veredicto sin salida. Elegir perderlos
no borra nada al momento: el cierre intenta subir una vez más, y lo que no suba se va con el borrado del arranque.

**Contestaste las cuatro preguntas con la recomendada:** 24 h y 3 rechazos, solo los cierres ofrecen salir, un botón
que nombra la pérdida, y el aviso fijo en la pestaña Grupos a ticket.

**La review adversarial (tres lentes) cazó uno alto, mío.** Lo aceptado era una cifra, y aceptar «2 cambios» cubría
cualquier par: un cambio nuevo se perdía sin aviso. Ahora son las filas que contó el aviso. Además, 3 rechazos los
cumplía un solo gesto (ahora cuenta uno por hora), y dos tests de pantalla no detectaban sus mutantes. **Y una premisa
del ticket era falsa:** el canal personal no tiene banner terminal, solo un canario.

**El #174 corrige un guion mío.** El device-QA pedía dos lanzamientos separados por 24 h, que dejan la racha en dos y
nunca llegan al aviso; ahora el primero dura algo más de dos horas.

Gate: build ×2 sin warnings nuevos · **unit 1026 en 120 suites**, y la suite completa **6977 en 715** antes de mergear ·
**25 mutantes, 25 muertos** · **XCUITest 89 casos en 38 clases** con el centinela · tres lentes. **Device-QA: solo la
racha** (0-terdecies de la cola); la salida con pérdida no se puede montar en ningún dispositivo.

**Deja dos tickets, los dos con decisión tuya** (ver «Siguiente»).

## Sesión #172 · un 401 por App Attest ausente deja de leerse como «Tu sesión caducó»)

**Con la sesión buena y sin App Attest, ninguna pantalla dice ya «Tu sesión caducó», y el sync de grupos no se
para.** Es tu decisión del 15-sep (opción 1): el 401 `yala_attest_required` es pasajero. Salir de un grupo pide
volver a intentarlo, aceptar una invitación ya no reabre el inicio de sesión, y los cierres de sesión enseñan el
aviso de lo pasajero, como sin red desde el #171. Con el JWT caducado de verdad se sigue pidiendo volver a entrar.

**El cliente de membresía tenía lo mismo**, y se arregla con el mismo criterio.

**La review adversarial (tres lentes) cazó cosas mías.** Una nota daba el caso por «solo en carrera» en el canal
personal, y la migración sube sin esa puerta. Y había huecos en los tests: la re-emisión del pull, un test de loop
que podía colgar y el attest caducado en el gateway. Todo arreglado o con ticket; cuatro costes aceptados quedan
escritos en `.claude/rules/gateway-attest.md`.

Gate: build ×2 sin warnings nuevos · **unit 858 en 86 suites** · **11 mutantes, 11 muertos** (6 iOS, 5 gateway) ·
**XCUITest 5 casos en 2 clases** con el centinela · gateway 20/20 · tres lentes. **Device-QA: parcial** (0-duodecies de la cola).

**Deja cuatro tickets, uno con decisión tuya** (ver «Siguiente»).

## Sesión #171 · sin conexión, «Tu sesión caducó» deja de salir a quien sigue con la sesión viva

**Sin red y con el token caducado, ninguna pantalla dice ya «Tu sesión caducó» ni manda a volver a entrar.** Es tu
decisión del 15-sep: separar en el cliente «sin conexión» de «sesión caducada». Al cerrar sesión en la nube sale al
momento «Los últimos cambios de tus grupos no llegaron al servidor…»; en el «equipo», en solo grupos, en la hoja del
Apple ID y en la puerta del Welcome, tras ~45 s de reintentos, el aviso de lo pasajero. Con la sesión borrada de
verdad se sigue pidiendo volver a entrar. **Y el sync de grupos ya no se para sin red:** reintenta solo.

**Te pregunté tres cosas y elegiste las tres recomendadas:** el mismo mensaje en Ajustes, la hoja y el Welcome;
salir de un grupo y aceptar invitaciones, a ticket; y subir en el siguiente reintento, sin vigilante de red.

**La review adversarial cazó tres cosas mías.** Con el predicado invertido, los tests de loop **colgaban** en vez de
fallar (ahora llevan fusible); el caso del mismo token tras un 401 no estaba fijado; y una premisa mía era falsa:
escribí «Modo Nube apagado» y la tarjeta de alta en la nube se ofrece en producción desde el 9-sep.

Gate: build ×2 sin warnings nuevos · **unit 946 en 105 suites** · **5 mutantes, 5 muertos** · **XCUITest 22 casos
en 8 clases** con el centinela (dos corridas cortadas por memoria) · contrato del SDK ejecutado · tres lentes ·
CI verde. **Device-QA: sí, y no es simulable** (0-undecies de la cola).

**Deja cinco tickets, tres con decisión tuya** (ver «Siguiente»).

## Sesión #170 · se retira el sello que apagaba el canal de Grupos hasta relanzar la app

**No cambia nada en pantalla.** El canal de Grupos tenía un freno: si el servidor decía que la cuenta no
estaba disponible, dejaba de sincronizar hasta matar y reabrir la app. Desde el 13-sep ninguna respuesta
real lo echaba —solo un 409 que `/groups/push` no emite—, y **tu decisión 4A fue retirarlo**. Ahora
cualquier parada del canal se vuelve a intentar en el siguiente arranque, vuelta a la app o inicio de sesión.

**La review adversarial cazó dos huecos míos en los tests, y los dos están arreglados.** El único cambio de
conducta —el 409 ya no cierra el canal— no lo fijaba ningún test, así que volver a poner el freno salía verde.
Y al quitar la aserción sobre el seam, el test del apagado del canal dejó de cubrir el save local y el silent
push.

Gate: build ×2 sin warnings nuevos · **unit 555 en 59 suites** · **3 mutantes, 3 muertos** (el freno
retirado, puesto tal cual, cae) · XCUITest 4 casos en 2 clases con el centinela · dos lentes adversariales ·
CI verde. **Device-QA: no aplica.**

**Un rojo de XCUITest que no era de este cambio:** `test_extremeMinimumAmountSaves` cayó una vez y pasó la
siguiente con el mismo binario; la base pasó con el mismo comando, y el test no ejecuta el código tocado. La
medición va a `edgecases-extreme-minimum-flaky-under-load`.

**Deja un ticket `low`:** `groups-loop-restart-docs-cite-a-retired-mount-guard`, tres comentarios que
prometen un guard de la sesión de visita que ya no existe.

## Sesión #169 · al cerrar sesión en la nube, una sesión de grupos caducada ya pide volver a entrar

**Cuenta en la nube, cambios de grupos sin subir y la sesión caducada: «Cerrar sesión» ya no dice «revisa tu
conexión».** Dice «Tu sesión caducó. Vuelve a iniciar sesión e inténtalo de nuevo.», como las otras tres formas
de cerrar sesión. Es tu opción 1 del ticket. El bloqueo no cambia: nada se sube, nada se borra y la sesión
sigue abierta.

**Medir antes de escribir sacó dos decisiones tuyas, las dos `medium`.** El aviso afirma más de lo que el
motivo sabe:

- `groups-push-reads-an-offline-token-refresh-as-a-session-expiry`: «Tu sesión caducó» también sale **sin
  conexión**, con el token caducado. Ya pasaba en el «equipo», en solo grupos, en el desasociar y en el
  Welcome; desde hoy, también en la nube. Recomendación: separar los dos casos en el cliente.
- `cloud-session-expiry-with-only-group-changes-has-no-sign-in-door`: en la nube, «vuelve a iniciar sesión» no
  dice dónde. La única puerta es «Nuevo grupo», solo si el SDK borró la sesión, y no está medido que exija la
  misma cuenta.

Gate: build ×2 sin warnings nuevos · **unit 198 en 22 suites** · **3 mutantes, 3 muertos** · **XCUITest 5
casos en 2 clases** · una lente adversarial, que no encontró acciones que cambien y matizó el segundo
hallazgo. **Device-QA: sí, y no es simulable** (0-decies de la cola).

**Y un rojo intermitente de XCUITest, con ticket `low`:** en la primera corrida tras arrancar el simulador, la
oferta en cola no apareció al cerrar la hoja del Apple ID. Pasó 3 de 4 con el mismo binario
(`queued-offer-after-dismiss-flakes-on-a-cold-simulator`).

## Sesión #168 · si el cierre por cambio de Apple ID se bloquea, ya se ve y se sale

**Cambias de cuenta de iCloud, tocas «Cerrar sesión y quitarlos», y si el cierre no puede completarse Yala
ya lo dice.** Hasta hoy el aviso se cerraba y no pasaba nada visible —sin red con una cuenta de grupos, con
los grupos en pausa o con cambios de grupos de una sesión caducada—, y encima el teléfono se quedaba sin
poder cerrar sesión desde ningún otro sitio hasta reabrir la app. Ahora el aviso es **una hoja con fases**:
la pregunta, un progreso y, si se bloquea, **el motivo con el mismo texto que Ajustes, «Reintentar» y «Ahora
no»**, que deja libre el cierre.

**Una segunda puerta del mismo síntoma que el ticket no nombraba:** el botón leía el interruptor de Grupos
compuesto y el coordinador el compilado, así que con el kill remoto de Grupos el tap no hacía nada.

**La review y los mutantes cazaron cosas mías.** La review, un progreso eterno con Ajustes abierto debajo:
las hojas de las pestañas no entran en la matriz del shell. Los mutantes de XCUITest, dos afirmaciones falsas
del propio test: el manejador de interrupciones de XCTest reconocía el bloqueo por el test, y en iOS 26.5
otra hoja no sirve para medir que la matriz retiene la cola. Las dos trampas están en
`.claude/rules/testing.md`.

Gate: build ×2 sin warnings nuevos · **unit 6921 en 708 suites** · **21 mutantes unit, 21 muertos**, y de
XCUITest 2 muertos y 1 vivo explicado · **XCUITest 111 casos en 47 clases**, todas las que pide el
cruce del índice, con el centinela sin intrusos. **Device-QA: sí, y no es simulable**: recorrido 5 de
`device-qa-apple-id-change-closes-private-session`.

**Te deja una decisión de copy, con recomendación:**
`apple-id-close-notice-does-not-say-what-else-the-close-does`. El aviso no dice que el cierre también quita
del teléfono los grupos.

**Y un hallazgo del cierre**, `generated-index-lands-above-yaml-frontmatter` (`medium`): `indexar_doc.py`
pone su índice encima del frontmatter. Hay 7 ficheros así, entre ellos la rule `git-hooks.md`, que podría
estar cargándose sin respetar sus `paths:`.

## Las de antes
- **#167 · las preferencias ya no cruzan entre el dueño y un móvil prestado.** Quien entra por un grupo en un
  móvil prestado ya no le cambia el idioma ni los ajustes al dueño, ni al revés (`OwnerKeyValueGate`). Dejó dos
  decisiones tuyas y un `medium`. Device-QA en la cola (0-nonies).
- **#166 · el hueco del vaciado remoto se cierra con el número, no con código.** Quien entró por un grupo
  antes del 10-sep no lleva la marca del eje, y el ticket daba dos salidas: Jürgen zanjó **población cero**,
  medida por cuatro vías independientes (telemetría, backend, App Store y builds distribuidos). No cambia nada
  en pantalla; un test fija las dos escrituras de la marca y el censo de armadores. Device-QA: no aplica.
- **#164 · el aviso de datos borrados ya no aparece encima de lo que estuvieras mirando.** Ahora espera su
  turno en la cola de avisos, así que ya no tumba la pantalla que tuvieras delante ni deja la app sin avisos.
  Quedan `orphan-alerts-behind-fullscreen-covers`, la segunda celda de
  `wipe-data-does-not-cancel-the-remote-wipe-grace` y el desarme de la red, probado solo a mano. Device-QA: no
  aplica.
- **#162 · el aviso de datos borrados ya no le habla de iCloud a quien no lo tiene en juego.** Tras
  «Vaciar datos», el aviso de «borrado desde otro dispositivo» ya solo sale en la sesión cuyos datos viven
  en el iCloud de este Apple ID. La premisa del ticket era falsa: lo que se cerró fue el aviso
  auto-infligido. Device-QA: no aplica.
- **#161 · vaciar tus datos ya no promete que se borran de todos tus dispositivos.** La hoja
  prometía un borrado en todos tus dispositivos que el #157 había dejado de cumplir; hoy promete solo lo
  que se cumple, fijado por unit desde el camino de producción. Sin decisiones.
- **#160 · «Empezar desde cero» sin iCloud ya vuelve a Restaurar y no promete nada.** Si la app no
  conseguía mirar tu iCloud te decía «Seguir así», te llevaba al onboarding y tus datos viejos seguían
  enteros: un borrado anunciado que nunca ocurrió. Y te dejaba apuntado para el aviso del espejo tardío,
  cuyo botón se lleva el dominio de Grupos — o sea que activar Yala completo para conservar los grupos
  podía acabar sin ellos. Hoy dice que no pudo mirar, que no borró nada, y te devuelve atrás.
- **#159 · cambiar el Apple ID del teléfono ya cierra la sesión privada.** La app no se enteraba del
  cambio de cuenta de iCloud y seguía enseñando los datos de la anterior; hoy lo detecta y pregunta.
  «Ahora no» no toca nada, y volver a tu cuenta anterior lo silencia solo. Dejó vivo un ticket
  **high**, `apple-id-close-blocked-has-no-visible-outcome` (si el cierre se bloqueaba, nadie lo enseñaba
  y el coordinador quedaba tapiado), que cerró el **#168**.
- **#158 · «Empezar desde cero» al activar Yala completo ya borra de verdad.** Ese botón no borraba
  NADA y el corpus viejo se re-exportaba a iCloud; hoy pasa por la puerta que pregunta a iCloud, enseña
  las cifras y exige un segundo gesto. Los grupos, el nombre y la divisa no se tocan.

El **#157** (vaciar tus datos ya no vacía el teléfono que prestaste) dejó su parte en el PR y en
`git log`; lo vivo de él es su device-QA. Los partes de los merges #144 a #156 viven igual en sus PR — el
del **#156** (un fallo pasajero de grupos ya no dice «revisa tu conexión») deja 4 tickets. Del **#155**
(«Empezar desde cero» en Restaurar ya borra) queda vivo su device-QA (cola, 0-quinquies) y un ticket,
`private-icloud-gate-back-lands-on-the-wrong-branch` (`medium`).

## Marketing (Lola · #142 · el estudio de vídeo)

**Ya hay sistema para sacar vídeo del producto sin dibujar la app**: `marketing/remotion/`, con dos
formatos —una presentación 16:9 por escenas y clips 9:16 por función— sobre grabaciones reales.
**Espera tu ojo** y tres decisiones cortas (`marketing/remotion/out/`, se regenera con
`bun run render:presentation` y `bun run render:reels`).

## Tu cola

0-quindecies. **Device-QA del #181, dos pasos**
   (`tickets/qa/cloud-sign-in-screen-offers-sign-up-to-a-phone-without-app-attest.md`). **A, en el simulador** con Yala Dev
   y sin el secreto: «Ya tengo una cuenta» → «Entrar con Google» con una cuenta sin Yala. Tiene que salir «Volver» y **no**
   «Crear mi cuenta» (o el mismatch sin «Crear cuenta con…»). **B, en un iPhone** con el TestFlight, mismo montaje que el
   0-quattuordecies: el mismo recorrido enseña el botón de crear, **sin tocarlo**. Borrar la app se lleva lo que no esté en
   tu iCloud o en la nube.

0-quattuordecies. **Device-QA del #180, un solo paso en iPhone real**
   (`tickets/qa/cloud-onboarding-offers-the-cloud-to-a-phone-without-app-attest.md`). Con el primer TestFlight tras el
   merge: borra Yala, instálala, espera unos segundos con conexión y toca «Empezar» → «Es mi primera vez» (si sale «Entra a
   tu cuenta», «Crear otra cuenta»). Tienen que salir **las dos** tarjetas, «Tu cuenta en la nube» incluida. Si sale una
   sola, la nube habría desaparecido para todos: es lo único que el simulador no puede probar.

0-terdecies. **Device-QA del #173, solo la racha**
   (`tickets/qa/groups-phone-that-never-attests-is-told-to-retry-forever.md`). Scheme **Yala** (no Dev) en el
   simulador, con tu cuenta de Grupos y la consola filtrada por `GroupsSync`. Primer lanzamiento: la app en primer
   plano **algo más de dos horas**, con `attestRequired edge=pull` repetido. Segundo, pasadas 24 h: **una sola vez**
   `attestTerminal rejections=N hours=H`. La salida «Cerrar sesión y perderlos» no se puede montar: sin App Attest no
   baja ningún grupo.

0-duodecies. **Device-QA del #172, parcial**
   (`tickets/qa/groups-sync-reads-a-missing-attest-401-as-a-session-expiry.md`). Scheme **Yala** (no Dev) en el
   simulador, que no tiene App Attest contra producción, con tu cuenta de Grupos. La consola tiene que decir
   `attestRequired edge=pull` cada vez más espaciado y **nunca** `loopStopped reason=session-expired`; y abrir un
   enlace de invitación no puede reabrir el inicio de sesión.

0-undecies. **Device-QA del #171, y NO es simulable**
   (`tickets/qa/groups-push-reads-an-offline-token-refresh-as-a-session-expiry.md`, siete pasos con Yala Dev).
   Gasto de grupo en modo avión, token caducado y **sin quitar el modo avión** al cerrar sesión. En la nube tiene
   que decir al momento «no llegaron al servidor»; en «equipo» o solo grupos, «Un momento más» tras ~45 s;
   **nunca** «Tu sesión caducó». Y el control: con la sesión borrada en staging, sí. Comparte montaje con el
   0-decies.

0-decies. **Device-QA del #169, y NO es simulable**
   (`tickets/qa/cloud-signout-collapses-a-groups-session-expiry-into-permanent.md`, seis pasos contra staging
   con Yala Dev). Cuenta en la nube con un gasto de grupo hecho en modo avión, sus sesiones borradas en el
   Supabase de staging y el token caducado. Al cerrar sesión, el aviso tiene que decir «Tu sesión caducó…», no
   «Revisa tu conexión». Comparte montaje con el 0-sexies.

0-nonies. **Device-QA del #167, y NO es simulable** (`tickets/qa/icloud-kv-prefs-cross-sessions-on-a-lent-phone.md`).
   Dos dispositivos del **mismo Apple ID**: uno con tu sesión privada y otro «prestado» que cierra sesión y
   entra por «Vengo por un grupo» con **otra** cuenta. Cambias el idioma en uno y compruebas que el otro no
   se entera, en los dos sentidos. **Lo que más importa:** que un dispositivo privado **siga recibiendo** los
   cambios de otro privado del mismo Apple ID — si no llegan, la puerta se habría cerrado para el dueño.

0-octies. **Device-QA del #159, y NO es simulable**
   (`tickets/qa/device-qa-apple-id-change-closes-private-session.md`, cinco recorridos). Hacen falta **dos
   Apple ID de verdad**: el simulador no tiene cuentas de iCloud reales, así que `userRecordID()` da
   `notAuthenticated` y el predicado sale por la rama que NO cierra. **Lo que más importa es el paso 8 del
   recorrido 1:** tras confirmar el cierre, vuelve a tu Apple ID anterior y comprueba que «Ya tengo cuenta
   → iCloud» **restaura tus datos** — si no están, el borrado se llevó el contenedor de iCloud y eso es
   grave. Y el **control negativo** del recorrido 2, que es el que prueba que la detección no se hizo con
   el predicado equivocado: **apagar iCloud Drive sin cambiar de cuenta NO debe disparar el aviso.**
   **El recorrido 5 cubre también el #168:** sin red, la hoja enseña el bloqueo con «Reintentar» y «Ahora no»,
   y Ajustes no queda tapiado; con red, lo que quedaba sin subir sube antes de borrar.

0-ter. **Device-QA del #158, y NO es simulable** (`tickets/qa/device-qa-activation-restore-start-fresh.md`,
   cinco recorridos). `ICloudPersonalCorpusProbe` no tiene ni un seam de `uitest`, así que el estado
   «Encontramos tus datos» de la puerta no existe en simulador — y a la pantalla de Restaurar de la
   activación solo se llega desde ahí. **Lo que hay que mirar siempre, porque es el fallo más probable
   del PR: tras borrar, abre el selector de subcategorías y comprueba que hay categorías y que está
   «Ajuste de saldo».** Y dos cosas más que la review dejó apuntadas: que los gastos de tus grupos
   **vuelvan al Panel al reabrir la app** (no antes — los repone la convergencia del bridge), y que con
   un corpus grande la zona de iCloud **no vuelva a llenarse** tras sincronizar.
0-bis. **Marketing · el estudio de vídeo espera tu ojo** (`marketing/remotion/out/` se regenera con
   `bun run render:presentation` y `bun run render:reels`). Tres decisiones cortas: fondo de la
   presentación **oscuro o blanco**; el **guion de 8 líneas** en `copy.ts`; y cuándo grabas los **clips por
   función** desde QuickTime, en Liquid Glass y sin la píldora roja. Sin eso, la presentación sigue
   repitiendo el mismo mp4 del piloto.
0. **Device-QA del eje 1 (#150), y NO es simulable.** El simulador no tiene sesión de nube, así que
   las dos celdas que deciden datos hay que verlas en device con dos teléfonos del mismo Apple ID:
   **cerrar sesión en «equipo»** (privada + cuenta de grupos) y **eliminar la cuenta de grupos sin
   sesión privada**. Lo que hay que mirar es que la hoja prometa exactamente lo que el borrado hace.

0-ter. **Device-QA de la RETIRADA de la visita (#151), y NO es simulable.** Hay que verlo en un
   teléfono que SÍ llegó a tener una sesión de visita, o sea un build **DEV contra staging** — el parque
   de TestFlight nunca pudo crear esos archivos, así que en el simulador no hay ni un
   `YalaModel-Secondary` que borrar. Lo que se comprueba: que al actualizar desaparezcan los tres stores
   `-Secondary` y el cajón `yala.session.*`, y que el widget deje de pintar los saldos de la otra
   persona. **Y lo que la retirada NO alcanza, con ticket propio**: la sesión de nube que la visita
   dejara en el Keychain sobrevive (`secondary-session-retirement-leaves-the-guest-cloud-session`).


0-quater. **Device-QA del aviso de datos del teléfono (#153), y NO es simulable.** La puerta sale de
   largo bajo `-uitest` —la hermeticidad va antes de la red— y ningún seed arma la marca del neutro
   solo-grupos, así que las cuatro pantallas nuevas solo existen en device. El montaje pide **dos
   teléfonos del mismo Apple ID**: uno en solo-grupos y otro que vacíe sus datos, para que la señal de
   wipe remoto devuelva al primero a la bienvenida **con los grupos dentro**. Guion de 9 pasos en
   `tickets/qa/device-qa-private-gate-device-corpus.md`. Lo que solo se ve ahí: que el corpus de la etapa
   de grupos **no** aparezca en el iCloud del Apple ID después.

0-quinquies. **Device-QA de «Empezar desde cero» en Restaurar (#155), y NO es simulable.** CloudKit no
   existe en el simulador, así que el estado «encontramos tus datos» con corpus real solo se ve en un
   iPhone. Cinco recorridos en `tickets/qa/restore-start-fresh-keeps-the-imported-corpus.md`. **El que de
   verdad cierra el criterio**: tras borrar, instalar Yala en OTRO dispositivo con el mismo Apple ID y
   comprobar que ya no encuentra nada. Dos pruebas nacen de la review y conviene no saltárselas: que tras
   borrar **no salga un tercer alert**, y que lo restaurado por «Traer mis datos» **siga ahí un par de
   arranques después**.

0-sexies. **Device-QA del aviso pasajero al cerrar sesión (#156), y NO es simulable.** Hace falta que el
   servidor falle de verdad: no hay seam que provoque un fallo del canal de grupos ni que pueble su
   outbox en una sesión de nube. Montaje: cuenta en la nube con un gasto de grupo sin subir **y el
   outbox personal vacío** —si quedan filas personales, bloquea el paso 1 y sale el aviso viejo, que es
   otro ticket—, hacer que `/groups/push` devuelva 5xx, y cerrar sesión. Lo que se mira: que el aviso
   salga **al momento** y diga «no llegaron al servidor», no «revisa tu conexión». Guion en
   `tickets/qa/cloud-signout-collapses-every-groups-transient-into-permanent.md`.

0-septies. **Device-QA del vaciado remoto (#157), y NO es simulable — es el SEGUNDO que pide dos
   teléfonos.** No hay seam que escriba `lastWipeTimestamp` en el iCloud-KV y `bootstrap()` no corre bajo
   `-uitest`, así que la señal solo viaja entre dispositivos reales del mismo Apple ID. Montaje: **A**
   privado con datos, **B** entrando por invitación de grupo. Vacías en A y **compruebas que B NO se
   vacía** (en su consola, `sessionObeys=false`). **El control positivo es obligatorio**: repetir con B en
   sesión privada, donde sí tiene que vaciarse. Guion en
   `tickets/qa/remote-wipe-signal-honored-by-any-session.md`.

1. **Cierra sesión en el iPhone y recrea los grupos de prueba.** Es lo ÚNICO que falta para el device-QA
   del paso 3: el móvil apunta a la cuenta que borró el fresh start y cada llamada da 409/502. **Mira antes
   el orden del punto 2-quinquies.**
2. **Device-QA del paso 3** — los cuatro recorridos del ticket. Sal del bloqueo **por swipe y por
   «Entendido»**, no solo por el botón; y en el recorrido 1 **fuerza el cierre de la app** antes de darlo
   por bueno. Más los device-QA de los pasos 4, 5, 6, 8 y 9.
2-bis. **Device-QA del paso 4, y empieza por su punto BLOQUEANTE** (`welcome-private-fresh-start-skips-icloud-check`,
   guion dentro): comprobar que la sonda de CloudKit **no lanza**. Baja una lista de `desiredKeys` única
   sobre una zona multi-tipo, y si el servidor la validara contra el schema de cada tipo, la rama privada
   quedaría en «reintentar» para siempre. El plan B está escrito. Después, los cinco recorridos —y el
   feo: **mata la app a mitad del borrado** y comprueba que al reabrir vuelve a preguntar.
2-quater. **Device-QA del paso 5** (`groups-only-second-launch-mounts-icloud-mirror`, guion dentro). **NO
   es simulable**: sin cuenta de iCloud no hay espejo que adjuntar. Cuatro recorridos, y el que más caro
   sale es el **tercero** —la no-regresión—: restaurar de iCloud tiene que seguir trayéndote tu histórico.
   Si en vez de eso te pide reabrir la app una y otra vez, es el fallo grave de este cambio.
2-quinquies. **Device-QA del paso 6** (`beacon-routes-only-never-blocks`, guion dentro). Necesita un
   TestFlight con este cambio, y su mitad de sign-in real **NO es simulable**. Su recorrido 1 usa el faro
   que dejó el fresh start en tu iPhone, y **el orden importa**: si recreas los grupos del punto 1 con el
   build 13, el faro sigue ahí; con el TestFlight nuevo, entrar con Apple por Grupos ya lo limpia —a
   propósito: el motor lo hace en toda puerta— y el recorrido 1 se comprueba en Console.app en vez de en
   pantalla.
2-sexies. **Device-QA del paso 8** (`full-mode-activation-must-ask-where-personal-data-lives`, guion de 10
   recorridos dentro). **NO es simulable.** Antes, **reinstala** si tu sesión solo-grupos es de antes del
   10-sep: si no, verás el aviso de reinstalar —correcto— y no el chooser. El que más caro sale es
   **restaurar**: los gastos de grupo tienen que salir UNA vez, y los que ya habías clasificado conservan
   su cuenta y su nota.
2-septies. **Device-QA del paso 9** (`session-exits-one-verb-per-session`, guion dentro). **NO es
   simulable**: sin cuenta de iCloud no hay espejo, y el testigo del export solo se prueba en device.
   **Empieza por su spike de tres supuestos**, que ningún test puede medir: que el espejo firme sus
   importaciones con su autor, que emita un evento de export tras cada save, y que un export con éxito
   haya subido todo lo anterior a su inicio. **Si falla el primero, todo cierre privado acaba en la
   salida de emergencia diciendo «1 cambio»** —falla seguro, pero inservible—. Y una decisión tuya
   dentro: qué hacer con cambios de grupos que ya no tienen a dónde subir
   (`groups-outbox-rows-without-a-live-session-have-no-exit`).
2-octies. **Device-QA de la mitad 2 del paso 5** (`groups-entry-on-a-mirrored-store-still-blocks-the-owner`,
   guion de cinco recorridos dentro). **NO es simulable**: sin cuenta de iCloud no hay espejo. El que más
   caro sale si falla es el **segundo**: después de que la puerta devuelva el teléfono al neutro,
   «Restaurar desde iCloud» tiene que traerte TODO el histórico. Y el quinto es el que prueba la otra
   mitad del bug: con el teléfono vacío pero aún espejando, crea el grupo tras el relanzamiento y
   comprueba en otro dispositivo del mismo Apple ID que ese gasto **no aparece** en tu Panel personal.
2-nonies. **Device-QA del paso 10** (`device-qa-groups-account-association`, guion de siete recorridos
   dentro). **NO es simulable**: el simulador no tiene sesión de nube. El que más caro sale es el
   **quinto**: desasocia en un teléfono, abre el otro del mismo Apple ID, y comprueba que la asociación
   **sigue soltada**. Si reaparece, el tombstone no está llegando y el gesto se deshace solo. El tercero
   es el que prueba lo demás: re-asocia la misma cuenta y **cuenta los movimientos del Panel** — tres
   gastos tienen que seguir siendo tres, no seis. **Y desde hoy hay un octavo, que es el más caro de todos
   y necesita DOS personas**: desasocia, **mata la app y vuélvela a abrir** —el daño estaba en el arranque
   siguiente, no en el gesto—, re-asocia, y comprueba en el teléfono del OTRO miembro que sus gastos siguen
   ahí. Si desaparecen sin que él toque nada, para el release.
2-decies. **Device-QA del #144** (`detach-failure-looks-like-success`, dentro de su ticket). **NO es
   simulable**, y necesita provocar el fallo: desasocia con el borrado roto y comprueba que la app lo DICE
   y que la pestaña Grupos sigue entera; que «Terminar de soltar la cuenta» funciona **sin sesión viva**;
   y que re-asociar después **no duplica** los gastos que elegiste conservar — tres siguen siendo tres.
2-undecies. **Device-QA del #146** (`device-qa-cloud-killswitch-groups-door`, cuatro recorridos dentro).
   **Éste SÍ es simulable**, al revés que todos los de arriba: el toggle «Simular remote OFF» del panel
   DEBUG en un build **Yala Dev**, y el panel se alcanza desde Ajustes → iCloud, sin pasar por la pantalla
   que se va a mirar. El que importa es el **tercero**: tras desasociar, la fila tiene que DESAPARECER —si
   sigue ahí, el término no es un término, es un `true`.
2-ter. **Device-QA de la reversa born-cloud → iCloud** (`reverse-cutover-cerrado-para-cuentas-born-cloud`).
   Dos cosas: el **contador de testigos con `ckRecordName`** del panel DEBUG tiene que pasar de 0 a cubrir
   tus filas vivas —ése es el único testigo real de que la subida ocurrió—, y **borra 2-3 transacciones
   antes de empezar**: lo que no debe pasar es que reaparezcan.
3. **Física, la de siempre**: push APNs real (4), RPC de producción (3), sign-in real SIWA/Google (6),
   Apple Pay y carreras de red (4).
4. **De FX quedan cuatro** · **tres veredictos de QA caducos** · **el build 13 no llega al grupo externo**
   hasta pasar beta review.
5. **DMARC el 15-sep** · **cobertura de UI el 22-sep**. Esperan al calendario.

## Siguiente

**El #173 te deja dos decisiones.** En la nube, un teléfono sin App Attest con cambios **personales** sin subir sigue
sin poder cerrar sesión: la salida con pérdida es solo para los de grupos
(`cloud-phone-without-app-attest-cannot-sign-out-with-personal-changes`, `medium`). Y si la pestaña Grupos avisa de
forma fija de que este teléfono no puede sincronizar (`groups-tab-does-not-say-this-phone-cannot-sync-groups`, `low`).
Del #172 siguen `groups-join-intent-expires-silently-after-transient-failures` (`medium`) y dos `low`.

**El rediseño de sesiones llega al final de su lista.** El paso 12 está cerrado con el #151: la shell
deriva de un solo eje y M1 no existe. Lo que queda del ADR son los device-QA acumulados, que son tuyos
y en su mayoría **no son simulables**.

**El rediseño de sesiones no deja nada abierto en código.** Lo que queda son device-QA tuyos, y el del
#153 se suma a la lista: es el único que necesita **dos teléfonos** del mismo Apple ID.

**El #157 te deja cuatro `high`, y tres son decisiones tuyas, no tareas.** (1) El arreglo del vaciado
remoto **no alcanza a toda su población**: un alta solo-grupos anterior al 10-sep sigue obedeciendo la
señal, porque no tiene la marca del mount neutro y el backfill le escribe «tiene sesión privada»
(`remote-wipe-axis-misses-groups-only-installs-before-the-mount-mark` — mide primero si esa población
existe). (2) La hoja de «Vaciar datos» sigue prometiendo que el borrado alcanza a **todos** tus
dispositivos, y eso **no es computable desde el emisor**: el iCloud-KV no lleva inventario de sesiones
(`wipe-sheet-still-promises-every-apple-id-device`, tres opciones escritas). (3) **CERRADO en #162**, y de paso se midió que la celda que lo motivaba no era la que disparaba:
lo que salía era el aviso auto-infligido tras «Vaciar datos» en solo-grupos. (4) **CERRADO en #167**: las preferencias —eran 36,
no 37— ya no cruzan con un móvil prestado; deja dos decisiones tuyas (ver «Esta sesión»).

**El #162 te deja uno `high` y es una decisión tuya.** El aviso de datos borrados se enciende desde una
tarea de cinco segundos escribiendo estado de la vista directamente, en vez de pasar por la cola de avisos
— y su hermano, el intent de la misma señal, sí pasa. Como ese flag además **bloquea la cola entera**, si
el sistema descarta la presentación la app deja de mostrar cualquier aviso (bandeja, invitaciones, Pro)
hasta que se la mata (`remote-wipe-alert-skips-the-router`). Es preexistente; el #162 solo estrecha quién
llega. Con él van dos `medium`: la causa de fondo del caso que hoy tapa el eje
(`wipe-data-does-not-cancel-the-remote-wipe-grace`) y la asimetría entre cómo leen el eje la shell y el
aviso (`shell-and-wipe-alert-read-the-session-axis-differently`).

**Y un hallazgo medido que no es decisión, es hecho:** widget, Siri y notificaciones locales cuelgan del
**cierre de sesión**, no del borrado, así que un vaciado que llega por el espejo no las toca. En claro:
**los recordatorios de pagos del dueño se siguen entregando, con sus montos, en el teléfono que prestó**, y
su widget sigue pintando el saldo. Anotado con coordenadas en
`after-session-redesign-review-widgets-siri-applepay-and-web-copy`, que hasta hoy era una lista sin medir.

**Lo primero de la cola técnica sigue siendo el board de testing**: los cuatro de
`nocturna-del-9-sep-dejo-cuatro-xcuitest-en-rojo` llevan dos noches rojos y ya no se sostienen como
«flaky de runner frío» (ver Bloqueo).

**El #158 deja cuatro tickets, uno `high`:**
`activation-discard-gate-exits-without-wiping-when-icloud-is-unreachable` — tres salidas de la puerta
(`.noICloud`, `.unreachable`, `.proceed`) llaman a `onProceed()` **sin pasar por el borrado**. En la puerta
del chooser es un daño menor; en la nueva las filas importadas **ya están en el teléfono**, así que quien
confirma «empezar de cero» sin red sigue con todo. Y el aviso del espejo tardío que llega después usa el
scope del handover, o sea que **purgaría los grupos**. Los otros tres:
`activation-discard-loses-the-group-history-question` (`medium`, la pregunta «¿traemos tus gastos de
grupo?» se mide después del borrado y da 0),
`private-gate-wipe-failure-copy-claims-icloud-is-intact` (`medium`, el copy del fallo parcial dice que
iCloud sigue entero cuando la zona ya no está — el copy correcto ya existe traducido) y
`activation-resume-returns-to-restore-on-an-emptied-zone` (`low`).

**El #171 te deja tres decisiones y dos tickets de trabajo.** Decisiones: qué dice el aviso sin red fuera de la
nube, y si la espera de 45 s tiene sentido sin red (`signout-pending-copy-says-wait-seconds-when-offline`); el
401 por App Attest ausente, que también dice «caducó» (`groups-sync-reads-a-missing-attest-401-as-a-session-expiry`,
`medium`); y despertar el sync de grupos al volver a la app (`groups-loop-in-backoff-ignores-the-return-to-foreground`).
Trabajo, con tu criterio ya decidido: salir de un grupo sin red (`groups-actions-read-an-offline-token-refresh-as-a-session-expiry`)
y el canal personal, que en `.cloud` frena también a Grupos (`personal-sync-reads-an-offline-token-refresh-as-a-session-expiry`,
que sube a `medium` porque Modo Nube no está apagado).

**El board: 398 en disco = 398 en `docs/TICKETS.md`** (medido el 15-sep, tras el #173), cero desajustes de estado. El
#173 pasa su ticket a `qa/` y suma dos.

## Bloqueo

**La nocturna del 11-sep confirma que los cuatro de
`nocturna-del-9-sep-dejo-cuatro-xcuitest-en-rojo` siguen rojos**, tres de ellos 3/3 reintentos en dos
noches distintas. Eso ya no se sostiene como «flaky de runner frío».

Los otros dos de testing: `shared-state-guard-misses-wipelocalgroupsdomain` (el guard del trait de
aislamiento busca `wipeAllUserData(` y se le escapa el otro escritor del espejo) y
`spike-r3-eje-4b-flaky-en-suite-completa` (rojo en la suite completa, verde en solitario; su control
negativo afirma un modo de fallo que cambia según lo que corriera antes).

**Y lo que deja el #144, por orden de lo que más cuesta si falla:**
`groups-purge-save-crosses-two-stores-without-atomicity` — el borrado del dominio Grupos promete «todo o
nada» y su `save()` cruza **dos archivos**; si el segundo falla después del primero queda el par que la
regla de área marca como peligroso, «cursor borrado + filas vivas». Y
`uitest-seam-for-a-seeded-groups-association` (**medium**): sin un seam que siembre la asociación hay dos
estados de la pantalla que **nadie puede probar en simulador** — la celda del segundo móvil, sin cobertura
desde el paso 10, y el botón «Terminar de soltar la cuenta» de hoy.
