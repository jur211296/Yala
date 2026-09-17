---
id: fresh-start-keeps-a-groups-session-that-migrate-promotes
status: qa
priority: high
area: "modo-nube, handover"
created: 2026-09-16
updated: 2026-09-17
source: "review adversarial de `settings-migrate-to-cloud-adopts-silently-instead-of-migrating` (lente de identidad, hallazgo 2), 2026-09-16"
---

# Tras «Empiezo de cero», «Activar la nube» sube las finanzas de la persona nueva a la cuenta de grupos de la anterior

## El problema, en lenguaje de usuario

Me dan un iPhone que usaba otra persona para sus grupos. En la bienvenida elijo «Empiezo de cero», registro mis
finanzas y un día toco «Activar la nube». La tarjeta dice «Usarás tu cuenta de Yala actual, la de Google» y sigo. Mis finanzas acaban en
la cuenta de la persona anterior, y le aparecen en sus dispositivos.

## Lo medido (2026-09-16, rama `encargo/2026-09-16-settings-migrate-to-cloud-adopts-silently-instead-of-migrating`)

- «Empiezo de cero» **no cierra la sesión en la nube**. Los tres llamadores de `DataWipeService.wipeLocalGroupsDomain`
  (`ContentView.swift`, dos, y `ShellDataAlertsModifier.swift`) no llaman a `signOut`, y el código lo dice en dos sitios:
  `wipeLocalGroupsDomain` («el JWT de la sesión Nube vive en su propio Keychain ⇒ SOBREVIVE al relevo») y
  `GroupsAssociationRegistrar.syncFromLiveSessionIfNeeded`.
- Con el dominio sellado (`groupsDomainSealedForFreshStart`), la asociación no se lee ni se registra
  (`GroupsAccountAssociation`), así que `isAssociated(sub:)` devuelve `nil`.
- La tarjeta de migrar elige `.reuseLiveSession` con cualquier sesión viva (`StorageMigrationSignInLogic.decide`) y solo
  nombra el proveedor (`accountReuseNote`), no la cuenta.
- La comprobación de «Migrar a la nube» deja pasar una cuenta solo de grupos sin asociada (decisión D3 de Jürgen,
  2026-09-16), y el claim la promueve (`claim_account`, rama de la fila ligera → `created`).

**No es una regresión de ese ticket**: en `2.1`, sin comprobación, el claim ya promovía cualquier sesión solo de grupos.
Lo que cambió es que la celda de la tabla del 10-sep, que nunca llegó a cablearse, la habría bloqueado.

**Inferido, no medido en un dispositivo**: que el recorrido completo —relevo con sesión de grupos viva, onboarding
nuevo, migrar— se dé en campo.

## Opciones, sin decidir

- **Cerrar la sesión en la nube en «Empiezo de cero»**, que es la frontera de otro usuario. Hay que medir qué rompe el
  cursor de Grupos que hoy sobrevive a propósito (`.claude/rules/swiftdata-cloudkit.md`, «En una frontera de USUARIO el
  outbox de Grupos y su cursor tienen signos OPUESTOS»).
- **Que la comprobación distinga la sesión preexistente**: `nil → promover` solo si la sesión la abrió el intento,
  porque ahí la persona eligió la cuenta; con sesión de antes, pedir que elija o bloquear.
- **Nombrar la cuenta en la tarjeta** (el correo, no solo el proveedor).

## Criterios de aceptación

- [x] Tras «Empiezo de cero», «Activar la nube» no puede promover la cuenta de grupos de la persona anterior sin que
      la persona nueva la elija. Cerrado en un teléfono sellado; tras reinstalar sin sellar queda abierto con ticket
      propio (ver «Residuales»). Falta el QA en iPhone.
- [x] Quien migra con su propia cuenta de grupos asociada sigue pudiendo promoverla.

## Decisión Jürgen (noche 2026-09-16, vía Frank)

**No promover una sesión de grupos preexistente:** `nil → promover` solo si la sesión la abrió este intento (la persona eligió la cuenta). Si la sesión venía de antes (p. ej. tras «Empiezo de cero» sin cerrar nube), pedir que elija o bloquear — no subir finanzas nuevas a la cuenta de la persona anterior.

**Aplazado a medición:** cerrar la sesión nube en «Empiezo de cero» (riesgo cursor/outbox Grupos). **No basta solo** nombrar el correo en la tarjeta.

## Lo hecho (2026-09-17)

**En un iPhone que pasó por «Empezar desde cero», «Activar la nube» ya no usa en silencio la cuenta que dejó abierta la
persona anterior.** Al tocar el botón, antes del consentimiento, sale el aviso «Esta cuenta puede ser de otra persona»: no
cambia nada y explica la salida, que es desasociar esa cuenta en «Grupos» y volver a tocar «Activar la nube» para elegir
la propia. Quien firma su cuenta en ese mismo intento, o la asoció al entrar en Grupos, sigue como siempre.

- **La regla vive en la comprobación** (`StorageMigrationIdentityGateLogic.check`, motivo `.sessionFromBeforeFreshStart`,
  slug `fresh_start_session`): con el sello de «Empezar desde cero», sin cuenta asociada y con una sesión que no abrió
  el intento, no hay `.proceed`. Cubre promover una solo-grupos y crear una cuenta nueva con esa identidad. Los bloqueos
  que ya existían conservan su aviso, y «Reintentar» (cuenta `complete` con el sello `.proceedMigration`) sigue igual.
- **El controller le pasa los dos hechos**: `preflightMigrationIdentity` dice `false` (solo corre con la sesión de antes)
  y `continueToClaim` el `openedSession` real; el sello se lee de `UserDefaults.standard`.
- **Nadie fabrica el `true` de la persona anterior.** Con el sello, `GroupsAccountAssociation.associate` solo apunta una
  sesión abierta por el propio sign-in (`sessionOpenedByThisSignIn`). `GroupsSignInView` dice de dónde sale la sesión
  (`.signedInHere` / `.alreadyOpen`) y `GroupsBackendInviteModifier` se lo pasa al escritor.
- **La salida no toca el Apple ID de antes**: con el sello, `GroupsAccountAssociation.clear()` borra solo el espejo local.
- Copy nuevo en 16 idiomas (`storage.migrateBlock.freshStartSessionTitle` / `…Body`).

### Ficheros

- `Yala/App/Logic/StorageMigrationIdentityGateLogic.swift` — la regla, el motivo y su docblock con los residuales.
- `Yala/Services/CloudSync/CloudMigrationController.swift` — `checkMigrationIdentity(sessionOpenedByThisAttempt:)`.
- `Yala/Services/CloudSync/GroupsAccountAssociation.swift` — el guard del escritor y el de `clear()`.
- `Yala/App/Views/Groups/GroupsSignInView.swift`, `Yala/App/Views/Shared/GroupsBackendInviteModifier.swift` — el origen.
- `Yala/Utils/L10n.swift` y los 16 `Localizable.strings` — el aviso.
- Docblocks: `CloudIdentityRoutingLogic.swift`, `MetricsService.swift`, `StorageMigrationBlockedView.swift`.
- Tests: `StorageMigrationIdentityGateLogicTests`, `MigrationIdentityGateWiringTests`, `GroupsAccountAssociationTests`.
- `.claude/rules/swiftdata-cloudkit.md` — sexta cosa que no se toca en la entrada de «Migrar a la nube».

### La review adversarial (dos lentes) cazó un agujero en lo mío

1. **El `true` también se podía fabricar** (las dos lentes, por separado). Una invitación que se queda sin token
   re-presenta la hoja de Grupos; con la sesión viva, su cinturón la reusa sin botones y el modificador la asociaba. En
   un teléfono sellado eso apuntaba la cuenta de la persona anterior, y la regla —que mira `nil`— la dejaba promover.
   Arreglado en el escritor.
2. **La salida escribía en el iCloud-KV del Apple ID de antes**: borraba su asociación y dejaba el tombstone, que en sus
   otros dispositivos quitaba la cuenta de la sección y apagaba el registrador. Arreglado en `clear()`.
3. **«Sin sello no cambia nada porque no hubo relevo» era falso.** Reinstalar conserva la sesión en el llavero, y un
   «Empezar desde cero» sin filas locales no sella. Va a ticket (abajo); la puerta no puede verlo.
4. **Dos redes flojas**: una celda (solo-grupos o cuenta nueva con el sello del claim) donde un mutante sobrevivía, y la
   comprobación de copy, que en alemán, japonés y chino casaba con el nombre suelto de la sección. Arregladas.

## Cómo se verificó

- **Build ×2** (`Yala`, `Yala Dev`): verdes, sin warnings en lo tocado.
- **Unit**: 56 suites pedidas y 56 ejecutadas, 536 tests en verde (las que escanean la hoja de Grupos, la asociación, la
  puerta y la paridad de l10n). La suite entera, en el PR.
- **18 mutantes, todos cazados por su test**: cada término de la regla, su orden frente a «Reintentar», el motivo, los dos
  valores del controller, la key del sello, el cuerpo y el título del copy, una traducción sin comillas, el guard del
  escritor (quitado e invertido), el origen de la hoja y del modificador, y el guard de `clear()`.
- **XCUITest de las áreas tocadas**: en el PR, con el centinela.

## Residuales

- **Reinstalar deja la sesión de la persona anterior sin sello**, y el arranque la asocia: ahí «Activar la nube» sigue
  promoviéndola. Lo mismo tras un «Empezar desde cero» sin filas locales. El Welcome, «Activar Yala completo» y la
  tarjeta de adopt también reusan esa sesión. →
  `previous-person-cloud-session-survives-fresh-start-and-reinstall`.
- **Quien empieza de cero en su propio iPhone también ve el aviso** con su cuenta de grupos: la salida le cuesta
  desasociar (sus grupos salen del teléfono y siguen en la cuenta) y volver a entrar. Es el coste de bloquear en vez de
  preguntar (D1 del Paso 0).
- **En una sesión solo-grupos sellada el aviso manda a una sección «Grupos» que no existe**, y la tarjeta queda siempre
  bloqueada: ahí nunca hay asociación. → anotado en `groups-only-session-storage-screen-says-data-lives-in-icloud`.
- **Tras desasociar, elegir Apple firma con el Apple ID del teléfono**, que en un relevo con el mismo Apple ID es el de
  la persona anterior. La hoja de Apple enseña ese Apple ID. → `cloud-sign-in-cannot-choose-another-apple-id`.
- **Un sello `.proceedMigration` de la persona anterior sobrevive al relevo** (`cloudSync.claimAction.*` no se borra), y
  con su migración fallida a la vista «Reintentar» seguiría. Sin medir que haya camino al Welcome con ese journal y la
  sesión viva. → escrito en el ticket de la sesión superviviente.
- **Si el borrado local de un desasociar falla sin asociación registrada, «Terminar de soltar» no sale nunca.** Ya
  pasaba; ahora el aviso manda a ese gesto. → `detach-pending-purge-is-unreachable-without-an-association-record`.

## QA en iPhone (Jürgen)

Hace falta un iPhone real (el simulador no atesta y la tarjeta no sale) y una cuenta de Google de prueba **A** que no
uses para nada más. Todo con `Yala Dev`, que va a staging.

**Montaje: un iPhone que pasa por «Empezar desde cero» con la sesión de A viva**

1. Instala `Yala Dev` desde Xcode en el iPhone. En la bienvenida elige «Es mi primera vez en Yala» → «Tu cuenta en tu
   iCloud privado» y termina el onboarding.
2. En la pestaña Grupos, conecta la cuenta A de Google y crea un grupo «QA relevo» con un gasto.
3. Borra la app del iPhone (mantén pulsado el icono → Eliminar app). La sesión de A se queda en el llavero.
4. Vuelve a instalar `Yala Dev` desde Xcode y ábrela con red. Espera un minuto en la bienvenida para que baje el grupo.
5. Toca «Es mi primera vez en Yala». Yala te ofrece empezar de cero, con el aviso «Empezar desde cero» o con la pantalla
   que dice que ya tienes datos en iCloud: elige empezar de cero y confirma el borrado («Borrar todo y continuar»).
6. Termina el onboarding privado y apunta un gasto («B café»).
7. Abre la pestaña Grupos. **El grupo «QA relevo» no tiene que aparecer**: se borró con el relevo, y eso dice que el
   teléfono quedó sellado. Si aparece, no se selló: apúntalo en el ticket y para aquí, porque es el caso de
   `previous-person-cloud-session-survives-fresh-start-and-reinstall`.

**Prueba**

8. Perfil → «Dónde viven tus datos». La sección «Grupos» dice «Tus grupos usan» y el correo de A.
9. Toca «Activar la nube». **Esperado:** sin consentimiento ni confirmaciones, la hoja «Esta cuenta puede ser de otra
   persona», con un solo botón «Entendido». Tócalo: la tarjeta sigue ahí y no se abre nada más.
10. En el SQL Editor de Supabase (staging): `select id from auth.users where email = '<correo de A>';` y luego
   `select kind, personal_claimed_at from public.profiles where id = '<id A>';`. **Esperado:** `groups_only` y
   `personal_claimed_at` vacío.

**La salida**

11. En «Grupos» toca «Desasociar» → «Conservar los gastos que pagué». La sección pasa a ofrecer asociar una cuenta.
12. Toca «Activar la nube» → «Entiendo y quiero activar la nube» → «Continuar» → «Sí, activar la nube». **Esperado:** sale
    la elección de Apple o Google. Elige Google con otra cuenta de prueba **B** y deja que la migración termine.
13. Repite el paso 10 con A (sigue `groups_only`) y con B: `complete`, y
    `select count(*) from public.tx_items where user_id = '<id B>';` cuenta «B café».
