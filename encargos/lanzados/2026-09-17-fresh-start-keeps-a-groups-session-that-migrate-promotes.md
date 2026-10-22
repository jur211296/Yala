# Tras «Empiezo de cero», no promover la sesión de grupos de la persona anterior

## Contexto
Ticket: `tickets/backlog/fresh-start-keeps-a-groups-session-that-migrate-promotes.md` (high).
Must-fix 2.1: iPhone prestado → Empiezo de cero → Activar la nube puede subir finanzas nuevas a la cuenta de grupos de la persona anterior.

## Decisión Jürgen (noche 2026-09-16, vía Frank) — YA EN EL TICKET
**No promover una sesión de grupos preexistente:** `nil → promover` solo si la sesión la abrió este intento. Si venía de antes, pedir que elija o bloquear.
**Aplazado:** cerrar sesión nube en Empiezo de cero (medir cursor Grupos). No basta solo nombrar el correo.

## NOCHE (21:00–6:00 Lima)
Sin AskUserQuestion. Implementa la decisión de arriba. Si aparece otra decisión demasiado gorda, aparca y avisa a Frank.

## Que se pide
1. Que «Activar la nube» no promueva/reutilice una sesión de grupos que sobrevivió a «Empiezo de cero» sin que la persona nueva la elija.
2. Quien migra con su propia cuenta de grupos asociada sigue pudiendo promoverla.
3. Tests, gate, commit, tickets + docs/TICKETS.md, PR, merge 2.1, `/cerrar-total`. Bugs → ticket.

## MODO AUTÓNOMO HASTA TERMINAR
Gate/commit/board/merge/cerrar-total sin preguntar. UI CI advisory.

## Que NO
marketing/; no implementar el sign-out en Empiezo de cero salvo ticket/medición aparte.

## Como se sabe que esta bien
Tras Empiezo de cero, Activar la nube no sube finanzas nuevas a la cuenta de la persona anterior sin elección. Board + cerrar-total.

## Avisos Frank
Webhook Mini local: (1) decisión/acceso; (2) PR; (3) cerrar-total + resumen; (4) idle una vez. NO: test rojo a reclasificar, build retry, CI advisory.

## Paso 0 — decisiones

> Resueltas en autónomo (noche, bypass): las recomendaciones se dan por buenas. Se discuten en el PR.

**Hechos medidos antes de decidir (2026-09-17, este árbol).** El sello `groupsDomainSealedForFreshStart` lo escriben solo
los tres «Empezar desde cero» del Welcome y no se borra nunca. Con él, `GroupsAccountAssociation` no lee ni escribe el
iCloud-KV y `GroupsAssociationRegistrar` no registra la sesión viva: por eso `isAssociated(sub:)` da `nil`. Sin sello, el
registrador del arranque asocia cualquier sesión viva de un teléfono con sesión privada. La tarjeta de migrar se ve
también en una sesión solo-grupos (ticket `groups-only-session-storage-screen-says-data-lives-in-icloud`), y ahí la
sección «Grupos» no aparece. En el teléfono sellado con la sesión anterior, la sección «Grupos» dice «Tus grupos usan
<correo>» y ofrece «Desasociar», que cierra esa sesión con su teardown (`CloudSessionSignOut.detachGroupsAccount`).
`GroupsSignInView` con sesión viva sigue sin pedir cuenta, así que entrar a Grupos tras empezar de cero usa la sesión
anterior.

**D1 · ¿Bloquear o pedir que elija?** → Bloquear, con la salida que ya existe: desasociar en «Grupos» y volver a tocar
«Activar la nube», que sin sesión abre la elección de cuenta.
Por qué: la protección no puede depender de un toque al lado de un correo (Jürgen: nombrarlo no basta), y cambiar de
cuenta ya exige desasociar primero (Jürgen, 2026-09-09). Alternativa descartada: una hoja «¿Es tuya esta cuenta?» con
«Sí, usarla»; son dos comportamientos y una confirmación que tendría que viajar del toque al claim y se perdería al
relanzar, y un «Sí» sin leer es el bug.

**D2 · ¿A qué sesiones previas se aplica?** → Solo en un teléfono sellado por «Empezar desde cero», con la sesión no
abierta por este intento y sin cuenta de grupos asociada (`nil`).
Por qué: `nil` no significa lo mismo con y sin sello. Sin sello, una sesión previa de una sesión privada ya estaría
asociada; la que llega con `nil` es la del teléfono solo-grupos, que es suya y tiene su decisión pendiente. Con sello,
`nil` es justo el registrador negándose a dar por buena una sesión que puede ser de la persona anterior. Alternativa
descartada: la letra de la decisión para todo teléfono, que bloquearía al solo-grupos con su propia cuenta y le
mandaría a una sección «Grupos» que no ve. **Es lo más discutible del PR.**

**D3 · ¿Qué destinos?** → Los dos que hoy siguen con `nil`: promover una cuenta solo-grupos y crear una nueva.
Por qué: con cuenta nueva el alta usa la identidad de la persona anterior (su Apple ID o su Google), así que las
finanzas acabarían en una cuenta que solo ella puede abrir. Alternativa descartada: solo promover, que es la letra del
ticket pero deja el mismo daño por la otra rama.

**D4 · ¿Cambia «Reintentar» (cuenta completa que este teléfono reclamó)?** → No.
Por qué: el sello `.proceedMigration` lo deja el propio intento, y bloquearlo cerraría «Reintentar» tras un fallo en
todo teléfono que empezó de cero. Residual ≈0 y escrito: una migración de la persona anterior a medias en este mismo
teléfono (`cloudSync.claimAction.*` sobrevive al relevo).

**D5 · ¿Motivo nuevo o uno existente?** → Nuevo: `sessionFromBeforeFreshStart`, slug `fresh_start_session`.
Por qué: «Ya usas otra cuenta para tus grupos» pide «entra con la cuenta de tus grupos» a quien ya está dentro, y «ya
tiene finanzas personales» sería falso. La regla solo retira un `.proceed`: los bloqueos de hoy no cambian de texto.

**D6 · Copy** → Título «Esta cuenta puede ser de otra persona». Cuerpo «No cambiamos nada. Tus grupos usan una cuenta
que ya estaba abierta en este dispositivo, y como aquí se empezó desde cero, puede ser de otra persona. Para llevar tus
datos a la nube, desasóciala en «Grupos» y vuelve a tocar «Activar la nube»: podrás elegir tu cuenta.» Sin correo y
sin «Usar otra cuenta». 16 idiomas.
Por qué: la sección «Grupos» de la misma pantalla ya nombra la cuenta. «Ya estaba abierta» vale también para la sesión
de un intento interrumpido. Residual: en un solo-grupos sellado la sección «Grupos» no existe; se anota en su ticket,
como ya lo está el mismo defecto de `personalDataBodyNoSwitch`.

**D7 · ¿Se toca la nota de la tarjeta («Usarás tu cuenta de Yala actual…»)?** → No.
Por qué: la comprobación se adelanta al toque, antes del consentimiento, y repetir el predicado en la vista es como
divergen.

**D8 · ¿Dónde vive la regla?** → En `StorageMigrationIdentityGateLogic.check`, con `sessionOpenedByThisAttempt` y
`deviceSealedForFreshStart`; no en la tabla [I].
Por qué: son hechos solo de la puerta de Ajustes, como `claimedForMigrationHere`; la tabla la comparten cuatro puertas.

**D9 · ¿De dónde lee el sello el controller?** → `UserDefaults.standard` con la key, como el bridge. Sin API nueva.

**D10 · Tests** → Unit de la lógica (celdas nuevas, controles y eje), cableado por source-scan de los cuerpos enteros y
mutantes. Sin XCUITest nuevo: la hoja no cambia y la cubre `StorageMigrationIdentityBlockUITests`.

**D11 · ¿Review adversarial?** → Sí: identidad y caminos de entrada, con refutación por hallazgo.

**D12 · Tickets** → Anotar el efecto en `migrate-attempt-session-survives-a-relaunch-mid-attempt` (en un teléfono
sellado esa sesión ahora se bloquea) y en `groups-only-session-storage-screen-says-data-lives-in-icloud`. Las demás
puertas que usan la sesión superviviente van a ticket si no lo tienen (buscar duplicado antes).

**D13 · ¿ADR?** → No. Aplica la decisión de Jürgen del 16-sep, que ya está en el ticket; la regla durable va a
`.claude/rules/swiftdata-cloudkit.md`.

### Tras la review adversarial (dos lentes, 2026-09-17)

- **D2 se mantiene, pero su porqué era falso.** «Sin sello, una sesión previa ya estaría asociada» no significa que no
  hubo relevo: tras reinstalar, la sesión anterior sobrevive en el llavero, un «Empezar desde cero» sin filas locales no
  sella y el arranque la asocia. La puerta no puede verlo; va al ticket
  `previous-person-cloud-session-survives-fresh-start-and-reinstall`, que recoge además las otras puertas que reusan esa
  sesión (Welcome, «Activar Yala completo», Grupos, adopt).
- **D14 añadido · el `true` tampoco se puede fabricar.** Las dos lentes cazaron que el cinturón de `GroupsSignInView`
  asociaba la sesión viva cuando una invitación se quedaba sin token. → Con el sello, `GroupsAccountAssociation.associate`
  exige `sessionOpenedByThisSignIn`. Por qué en el escritor: el registrador ya cumplía la regla y un tercer llamador
  nacería sin ella.
- **D15 añadido · la salida no toca el Apple ID de antes.** Desasociar borraba las keys del iCloud-KV y dejaba el
  tombstone. → Con el sello, `clear()` solo borra el espejo local, simétrico a `associate` y `readICloud`.
- **D6, residual confirmado**: en una sesión solo-grupos sellada la tarjeta queda siempre bloqueada y el aviso manda a una
  sección que no existe. Anotado en `groups-only-session-storage-screen-says-data-lives-in-icloud`.
- **Aceptados y escritos**: tras desasociar, Apple firma con el Apple ID del teléfono
  (`cloud-sign-in-cannot-choose-another-apple-id`); el sello `.proceedMigration` de la persona anterior sobrevive al
  relevo (≈0, en el ticket de la sesión); y quien empieza de cero en su propio iPhone paga la salida (coste de D1).
- **Hallazgo ajeno, a ticket**: un desasociar que falla a medias sin registro no ofrece terminarlo
  (`detach-pending-purge-is-unreachable-without-an-association-record`).
