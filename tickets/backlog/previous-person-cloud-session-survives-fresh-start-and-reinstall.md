---
id: previous-person-cloud-session-survives-fresh-start-and-reinstall
status: backlog
priority: high
area: "modo-nube, handover, sesiones"
created: 2026-09-17
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
