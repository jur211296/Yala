---
id: previous-person-cloud-session-survives-fresh-start-and-reinstall
status: qa
priority: high
area: "modo-nube, handover, sesiones"
created: 2026-09-17
updated: 2026-09-23
source: "review adversarial de `fresh-start-keeps-a-groups-session-that-migrate-promotes` (lentes de identidad y de puertas), 2026-09-17"
---

# La sesión en la nube de la persona anterior sobrevive a reinstalar y a «Empezar desde cero», y varias puertas la usan

## El problema, en lenguaje de usuario

Me dan un iPhone donde otra persona usaba Yala para sus grupos. Instalo Yala, empiezo mi Yala y un día activo la nube, o
creo un grupo, o elijo «Tu cuenta en la nube». La app no me pide cuenta: usa la de la persona anterior, y mis finanzas o mis
grupos acaban en su cuenta, a la vista en sus dispositivos.

`fresh-start-keeps-a-groups-session-that-migrate-promotes` cerró una puerta de esto («Activar la nube» en un teléfono que
pasó por «Empezar desde cero» y quedó sellado). Lo que queda no se puede cerrar puerta a puerta: la sesión sigue ahí.

## Lo medido (2026-09-17, leído en el código, sin ejecutar)

**La sesión sobrevive:**

- El JWT vive en el llavero con `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` (`CloudAuthKeychainStorage.swift`), y
  no hay ninguna purga en el primer arranque tras instalar. Que el llavero sobrevive a borrar la app está medido en
  dispositivo para el keyId de App Attest (`.claude/rules/gateway-attest.md`).
- «Empezar desde cero» no la cierra: `DataWipeService.wipeLocalGroupsDomain` lo dice en su cabecera, y la decisión de
  Jürgen del 2026-09-16 dejó cerrarla «aplazado a medición» (riesgo: el cursor de Grupos, que ahí es la barrera que
  impide que baje el corpus del anterior; `.claude/rules/swiftdata-cloudkit.md`, «En una frontera de USUARIO el outbox de
  Grupos y su cursor tienen signos OPUESTOS»).

**No siempre queda el sello:**

- Tras reinstalar, `UserDefaults` empieza vacío: el sello de un relevo anterior ya no está.
- «Es mi primera vez» sin datos locales va directo al onboarding, sin borrado ni sello (`ContentView.swift`, rama
  `else` de `hasLocalDataNow()`).
- El borrado del corpus de iCloud sale antes de sellar si no hay filas locales (`ContentView.swift`,
  `guard scope.deletesLocalRows, checkHasExistingData() else { return nil }`), aunque `ICloudWipeScope.handover` promete
  «purga + sello» en su docblock.
- Con red, el canal de Grupos suele bajar los grupos de la persona anterior antes de la bienvenida y eso sí hace saltar el
  borrado con sello; sin red, o si esa cuenta no tenía grupos, no (inferido, sin medir en dispositivo).

**Sin sello, la sesión se da por buena:**

- El arranque la registra como cuenta de grupos del teléfono en cuanto hay sesión privada
  (`GroupsAssociationRegistrar.syncFromLiveSessionIfNeeded`, `AppBootstrapper`), así que «Activar la nube» ve `true` y la
  promueve con las finanzas de la persona nueva.

**Puertas que la reusan sin preguntar, con o sin sello:**

- **El Welcome**: `ensureSignedIn` no firma si ya hay sesión (`WelcomeCloudSignInView.swift`); lo usan el alta
  («Tu cuenta en la nube», que promueve una solo-grupos en `BornCloudSignUpService.signUp`) y la re-entrada.
- **«Activar Yala completo» → nube** desde solo-grupos: promueve la sesión viva (`FullModeActivationView`, paso
  `.promote`).
- **Grupos**: `GroupsSignInView` reusa la sesión viva (cinturón del `onAppear`) y crear o unirse a un grupo con ella deja los
  grupos de la persona nueva en la cuenta de la anterior.
- **La tarjeta de adopt** («Activar en este dispositivo»): no pasa por la comprobación, y `CloudMigrationController.continueToClaim`
  va directo al claim con `.adoptIfExisting`. Anotado en `adopt-uploads-a-foreign-corpus-without-a-lineage-check`.

**Un residual más de «Reintentar»:** el sello `.proceedMigration` (`cloudSync.claimAction.*`) y el journal de migración no
se borran en «Empezar desde cero». Si la persona anterior dejó una migración fallida, la persona nueva vería su tarjeta de
fallo con «Reintentar», y la comprobación seguiría por la excepción de la cuenta `complete`. No está medido que haya camino
al Welcome con ese journal y la sesión viva.

## Lo que hay que decidir (Jürgen)

1. **Cerrar la sesión en la nube en el relevo** («Empezar desde cero»), midiendo antes qué le pasa al cursor de Grupos.
   Cierra todas las puertas del teléfono sellado, pero no la reinstalación sin sello.
2. **Purgar la sesión en el primer arranque tras instalar** (marca en `UserDefaults` ausente + sesión en el llavero).
   Cierra la reinstalación, y a cambio quien reinstala su propia app tiene que volver a entrar.
3. **Las dos.**
4. **Preguntar en vez de cerrar**: al primer uso de una sesión que no se abrió en esta instalación, «¿Sigues siendo
   <correo>?». Es lo que la decisión del 16-sep descartó para la tarjeta («no basta nombrar el correo»).

## Relación con otros tickets

- `fresh-start-keeps-a-groups-session-that-migrate-promotes` — de donde sale; cerró la puerta de «Activar la nube» en un
  teléfono sellado.
- `adopt-uploads-a-foreign-corpus-without-a-lineage-check` — la tarjeta de adopt.
- `fresh-start-wipe-kills-unsent-group-writes-silently` — el otro coste del relevo sobre el dominio de Grupos.
- `cloud-sign-in-cannot-choose-another-apple-id` — tras cerrar la sesión, elegir Apple vuelve al Apple ID del teléfono.

## Criterios de aceptación

- [ ] Tras reinstalar o empezar de cero, ninguna puerta usa la sesión en la nube de la persona anterior sin que la
      persona nueva la elija.
- [ ] Quien reinstala su propia app, o empieza de cero en su propio iPhone, tiene un camino claro para volver a su cuenta.

## Decisión Jürgen (2026-09-17)

**Las dos:**
1. Cerrar la sesión en la nube en el relevo («Empezar desde cero»), midiendo el cursor de Grupos.
2. Purgar la sesión en el primer arranque tras instalar (marca UserDefaults ausente + JWT en llavero).

Quien reinstala su propia app vuelve a entrar. No basta preguntar «¿Sigues siendo…?» ni solo una de las dos.

## Qué cambia para quien usa la app (2026-09-17)

**Un iPhone que cambia de dueño ya no deja abierta la cuenta en la nube de la persona anterior.** Se cierra
por dos sitios, que son los dos por los que sobrevivía:

1. **Al «Empezar desde cero»**, en el mismo gesto que borra los datos.
2. **Al instalar Yala en un teléfono donde ya estuvo**, porque el llavero de iOS sobrevive a borrar la app
   y las preferencias no.

Desde ahí, ninguna puerta —el Welcome, «Activar Yala completo», la hoja de Grupos, la tarjeta de adopt—
puede usar esa cuenta sin que la persona nueva la elija: sencillamente ya no hay sesión que reusar.

**Quien reinstala su propia app vuelve por «Ya tengo una cuenta → Entrar con Apple / Entrar con Google»**,
que es la consecuencia aceptada de la decisión.

## Cómo está hecho

Un **arm durable** en `UserDefaults` y **dos consumidores**, que no son simetría sino física distinta:

- **`purgeIfArmed()` — PRE-MOUNT, síncrono y sin red.** Es el principal. Corre como primera cosa del
  proceso, cuando `CloudAuthService.shared` todavía no se ha construido: no hay auto-refresh que pueda
  reponer lo que borra y no hay ninguna llamada de red delante de la primera pantalla. Cubre la
  reinstalación y repara cualquier relevo que quedara a medias.
- **`retireForHandover()` — en proceso, asíncrono.** El relevo no relanza, así que ahí el SDK está vivo con
  la sesión en memoria y hay que decírselo.

La purga es del **service `com.yala.cloudauth` entero**: la sesión del SDK, el perfil capturado, el
provider, el par SIWA y el par Google. Una lista de `account` es como diverge de lo que ese service acabe
guardando.

## La medición que pediste: el cursor de Grupos

**Cerrar la sesión no invierte el signo del cursor.** Está indexado por `groupID`, así que los grupos de la
persona nueva son otros IDs y bajan enteros; si comparten grupo, el re-join ya lo resetea
(`cursorResetGroupIDs`); y si el retiro falla, el cursor es la única barrera que queda. El par coherente
sigue siendo **outbox muerto + cursor vivo**, y `HandoverGroupsDomainTests` lo pinnea en los dos sentidos.

## Lo que la review adversarial tumbó de mi primera versión

Tres lentes independientes, y las tres cazaron algo que era mío:

1. **El parque entero.** `cloudSync.installSeen` nace con este cambio, así que está ausente en TODOS los
   teléfonos que ya tienen Yala: «no hay marca» significaba «primera vez que corre este código», no «app
   recién instalada». La primera actualización habría cerrado la sesión de todos los usuarios de la nube.
   Ahora exige evidencia de instalación previa y **falla hacia no armar**.
2. **El sello sobre un store vacío.** Mi primera versión metía `wipeLocalGroupsDomain` en la celda sin
   filas «porque el enum lo promete». Dos lentes por separado midieron que eso sella —irreversible— el
   teléfono de quien reinstala su PROPIA app y el de quien contesta al aviso del espejo tardío, que es la
   misma persona. Es el daño que mi propio docblock nombraba como razón para no sellar en la rama hermana.
   Ahí ahora **solo se retira la sesión**.
3. **Hasta 60 s de red delante de la primera pantalla.** La primera versión consumía el arm en
   `AppBootstrapper` con un `await`; el sign-out del SDK habla con el servidor sin tope propio, y ese
   `await` dejaba el `defer` de `bootstrap()` sin ejecutar y con él el blocker `bootstrapPending`. Con un
   portal cautivo, el primerísimo arranque se quedaba sin Welcome y sin drenar un solo intent. Por eso el
   consumo se fue PRE-MOUNT.

Y tres más, medidas: **`signOut()` no para el auto-refresh del SDK** (`stopAutoRefreshToken` no aparece en
el repo), así que la purga se VERIFICA releyendo el llavero y el arm se conserva si alguien lo repuso; una
**quinta declaración de «empiezo de cero»** —la que relanza para adjuntar el espejo— no pasaba por ningún
escritor común y ahora arma; y un unit test disparaba el retiro DE VERDAD sobre el llavero del host, en un
`Task` huérfano.

## Residuales medidos, con ticket

- Tras reinstalar y **sin red**, el snapshot del flag remoto se fue con la app y el Welcome ofrece solo
  «Restaurar desde iCloud», que para una cuenta de nube dice «no encontramos tus datos». No lo empeora este
  cambio (la card de nube tampoco salía antes), pero ahora es el único camino de vuelta que queda.
- `cloudSync.storageMode` sobrevive al relevo: un teléfono en Modo Nube queda con el modo puesto y sin
  sesión. No se encontró entrada alcanzable.

## QA en iPhone (device) — 9 pasos

**Montaje.** Hace falta un iPhone con TestFlight y una cuenta en la nube de PRUEBA ya creada (no la tuya
principal). El simulador no vale para los pasos 3-6: sin `Secrets.xcconfig` con el secreto de App Attest no
se pueden crear cuentas, y el llavero del simulador no reproduce la supervivencia al borrado de la app.

1. **Prepara el teléfono como «persona A».** Instala el build, entra con la cuenta de prueba
   (Welcome → «Ya tengo una cuenta» → Entrar con Apple o Google) y crea un grupo. Comprueba en
   Ajustes → «Dónde viven tus datos» que la fila enseña el correo de A.
2. **Control de que la sesión SOBREVIVE hoy** (opcional, para ver el bug): con el build ANTERIOR, borra la
   app, reinstala y abre. La fila de Ajustes seguía enseñando el correo de A. Con el build de este PR ya no.
3. **La mitad de la REINSTALACIÓN.** Borra Yala del teléfono. Reinstala el build de este PR. Ábrelo.
   · Esperado: Welcome de instalación nueva. Entra a «Ya tengo una cuenta»: sale el sub-chooser con
     **«Entrar con Apple»** y **«Entrar con Google»**, y pide elegir. **No** entra solo.
   · Y en Ajustes, si llegas a la fila, **no** aparece el correo de A.
4. **La ACTUALIZACIÓN no cierra nada** — es el caso que decide si esto se puede publicar. Con el teléfono
   del paso 1 (sesión de A viva, app instalada con el build anterior), instala el build de este PR ENCIMA,
   sin borrar. Ábrelo.
   · Esperado: **la sesión de A sigue abierta.** La fila de Ajustes sigue enseñando su correo y Grupos
     sigue entrando sin pedir nada. Si aquí te pide volver a entrar, PARA: es la regresión de parque.
5. **La mitad del RELEVO.** Vuelve a dejar el teléfono como A (paso 1). Ve al Welcome
   (Ajustes → «Vaciar datos» no vale: hace falta el Welcome) y elige **«Es mi primera vez» → «Privacidad
   total»**, confirmando el borrado.
   · Esperado: entras al onboarding. Al terminarlo, Ajustes → «Dónde viven tus datos» **no** enseña el
     correo de A, y «Activar la nube» pide elegir cuenta en vez de promover ninguna.
6. **La puerta de Grupos.** Desde ese mismo estado, entra a Grupos.
   · Esperado: pide iniciar sesión. **No** entra con la cuenta de A ni enseña sus grupos.
7. **Sin red.** Repite el paso 5 con el **modo avión puesto**.
   · Esperado: el borrado y la entrada al onboarding funcionan igual y **sin quedarse esperando**. Si la
     app tarda en montar la primera pantalla o se queda en negro, PARA: es el modo de fallo que el PR
     movió a pre-mount y significa que volvió.
8. **Un kill a mitad.** Repite el paso 5 y **mata la app** (deslizar desde el conmutador) en cuanto veas el
   onboarding, antes de tocar nada. Vuelve a abrirla.
   · Esperado: la sesión de A tampoco está. Es el arm durable haciendo su trabajo.
9. **El camino de vuelta de A.** En el teléfono del paso 3 (reinstalado), entra con la cuenta de A.
   · Esperado: recupera sus grupos. Si el teléfono pasó por el paso 5, el dominio de Grupos está SELLADO y
     los grupos no se puentean al Panel hasta que adopte Grupos a propósito — eso es lo esperado, no un fallo.

**Lo que NO se puede montar aquí:** que el `SecItemDelete` del llavero falle (`errSecInteractionNotAllowed`
pide un arranque en background antes del primer desbloqueo) y que el auto-refresh del SDK reponga la sesión
justo entre la purga y la relectura. Los dos van por unit test con sus mutantes.

## Barrido de `qa` · 2026-09-23 · se queda para el iPhone

Está en la lista corta de device-QA del 2026-09-23 (`qa/guion-tanda.md`). Se prueba con **Yala Dev compilado desde `2.1`**: el TestFlight 13 es del 9-sep y no lleva los arreglos posteriores. Para cerrarlo basta con el paso 3 hoy (sale gratis en el bloque D: tras reinstalar, «Ya tengo una cuenta» pide elegir y no entra solo) y el paso 4 (actualizar sin borrar no cierra la sesión) al instalar el próximo TestFlight encima del 13; hasta entonces el ticket sigue en `qa`. Los pasos 5 a 8 quedan cubiertos por `CloudSessionRetirementTests` y sus mutantes.
