---
id: invite-link-five-causes-one-message
status: qa
created: 2026-08-12
updated: 2026-09-05
source: YalaWiki/Bugs/grupos-enlace-de-invitacion-cinco-causas-un-solo-mensaje.md
---


# El enlace de invitación: cinco causas, un solo mensaje, y un consejo que a veces es mentira

## El síntoma, en lenguaje de usuario

Toco el enlace que me pasaron y Yala me dice:

> **Este enlace ya no es válido o expiró. Pídele al admin que regenere uno.**

Ese mensaje sale tanto si el enlace caducó como si **el grupo ya no existe** — y entonces el consejo es
falso: el admin no puede regenerar el enlace de un grupo borrado. Además, la página web que acabo de ver
me enseñaba el nombre del grupo, y la app me recibe con un título genérico.

## Lo medido

### 1 · Cinco causas colapsadas en una

`join_group` (`supabase-groups-staging.ddl:444-454`) devuelve `yala_invalid_invite` —sin oráculo, **a
propósito**— para: token inexistente · revocado · caducado · agotado · **grupo con `deleted = true`**. El
cliente los clasifica todos a `.invalidInvite` (`GroupBackendAcceptErrorLogic.swift:42-54`) y pinta el
mismo copy.

Que el servidor no dé oráculo es una decisión de seguridad correcta. **El grupo borrado no es un secreto
que proteger**: es el único de los cinco donde el consejo («pídele al admin que regenere uno») manda al
usuario a una acción imposible.

*Dato menor medido: con `max_uses = null` por defecto en los dos call-sites, «ya se usó» ni siquiera es
alcanzable hoy.*

### 2 · El nombre del grupo viaja en el enlace y la app lo tira

`GroupBackendInviteEntryHandler.handle` declara `branded: InviteLinkService.BrandedMetadata = .empty` en
su firma (`:70`) y **no lo referencia ni una vez** en el cuerpo. `AppBootstrapper.swift:2038` calcula
`InviteLinkService.extractMetadata(from: url)` y se lo pasa **para nada**. Por la otra puerta, el drain
de `.presentGroupBackendInviteOnboarding` pone `pendingInviteMetadata = nil` explícitamente.

⇒ `L10n.Groups.Invite.welcomeWithGroup` («Te invitaron al grupo %@»), `groupColor` y `groupIcon` son
código vivo **sin camino alcanzable** en el canal backend. El invitado ve un título genérico con el color
del tema, un segundo después de que la web le enseñara el nombre.

### 3 · La puerta de entrada es más estrecha que el parser

`InviteLinkService.extractBackendInvite` sabe leer `g`+`t` **sin** `s` (`:147`), pero las tres puertas de
entrada (`YalaAppDelegate.swift:94`, `AppBootstrapper.swift:1865`, `InviteRecoveryView.swift:29`) gatean
por `isInviteLink`, que **exige `s`** (`:223`). El AASA hace lo mismo
(`components: { "/": "/invite", "?": { "s": "*" } }`).

Hoy es **inocuo** porque `buildBackendInviteURL` siempre pone `s`. Deja de serlo el día que alguien emita
un enlace sin él: un `yala://invite?g=..&t=..` cae al `switch url.host` y **muere en el `default`, sin una
línea de UI** — el modo de fallo que este subsistema ya pagó una vez.

### 4 · El botón de generar el enlace culpa a la conexión cuando el fallo es permanente

`GroupMembersView.createShareLink` (`:469-473`) usa `L10n.Groups.Errors.inviteFailed` («No se pudo crear
el enlace de invitación. **Revisa tu conexión** e inténtalo de nuevo.») tanto en el `catch` de red como en
el `else` del guard `CloudSyncFlags.groupsBackendEnabled && group.isBackendGroup` — o sea, para un grupo
de la **era CloudKit**, donde el fallo es permanente y no tiene nada que ver con la conexión. Idéntico en
`GroupDetailViewModel.swift:470`.

El comentario del propio código reconoce que el mudismo sería peor; el copy elegido manda al admin a
reintentar algo que **nunca** va a funcionar.

> Corrección de la primera pasada: hay **DOS** superficies de producción que acuñan enlace
> (`GroupMembersView.swift:208-212` y `GroupDetailView.swift:420-428`), no una. Importa para el fix: el
> copy hay que arreglarlo en los dos.

### 5 · El «Atrás» de la pantalla de pegar el enlace devuelve un nivel de más

`InviteRecoveryView.onBack` → `ContentView.returnToWelcomeChooser(dismissing:)`, que fuerza
`welcomeFlowInitialStep = .chooser` — el chooser de nivel 1 («¿qué quieres hacer en Yala?»), **no** el
step de dos vías del que salió («¿Cómo empiezas con tu grupo?»). El helper está compartido con
`WelcomeRestoreView`, para el que sí es correcto. Su hermano de la rama organizador
(`returnToGroupsChooser`, `ContentView.swift:750-760`) sí vuelve al sitio exacto, **y su comentario
explica por qué eso importa**.

## El fix

1. **Separar el grupo borrado de los otros cuatro.** Es el único que necesita otro consejo. Exige que el
   servidor lo distinga — decisión de seguridad a tomar conscientemente, porque hoy el no-oráculo es
   deliberado.
2. **Cablear `branded`** o borrar el parámetro y su copy. Lo que no vale es la firma que promete y el
   cuerpo que ignora: es la forma exacta en que este repo genera código muerto que parece vivo.
3. **`isInviteLink` que acepte lo que el parser sabe leer** (`g`+`t` sin `s`), o un fallo con UI en el
   `default`.
4. **Copy por causa en el botón de generar enlace**, en las dos superficies.
5. **`returnToGroupsChooser` para el «Atrás» de `InviteRecoveryView`.**

## Relacionados

- [[grupos-invitado-el-no-no-tiene-pantalla]]
- [[grupos-recorrido-del-invitado-codigo-muerto-y-docblock-caducado]]
- [[qa_invite-backend-mudo-config-stale]]

## Implementación · pieza 5 (2026-08-12, `e4d660a4`)

**El «Atrás» de `InviteRecoveryView`.** Coordenadas del ticket exactas. El `step` de
`returnToWelcomeChooser` pasa a ser un parámetro EXPLÍCITO y **sin default**: los dos llamadores vienen
de sitios distintos y un valor por defecto los volvería a igualar en silencio, que es el bug. Pin:
`WelcomeBackDestinationTests` (source-scan; las dos aserciones daban 0 coincidencias contra el árbol
anterior, verificado con `git show`).

## Las otras cuatro, con lo que medí de cada una

### 1 · separar el grupo borrado — BLOQUEADA (servidor)

Exige que el servidor distinga ese caso de los otros cuatro, y el no-oráculo de `join_group` es
deliberado. Autorización de esta sesión: solo iOS. **Mi lectura, para cuando se decida**: el grupo
borrado es el único de los cinco donde el consejo actual manda a una acción imposible, y no es un
secreto que proteger — quien tiene el token ya sabía que el grupo existió.

### 2 · cablear `branded` — MEDIDA A FONDO, no hecha, y NO es un cable suelto

El ticket dice «cablear `branded` o borrar el parámetro». Medido, la primera opción cuesta más de lo
que parece y por una razón concreta:

- `GroupInviteOnboardingView` consume la marca por `inviteMetadata?.groupName/groupIcon/groupColor`
  (`:441-457`), y esos tres campos **existen** en `InviteLinkService.BrandedMetadata` (`name`/`icon`/`color`);
- pero `InviteMetadata` —el tipo que la vista recibe— exige `shareMetadata: CKShare.Metadata`
  (`RouterIntent.swift:55`), **un objeto de CloudKit que el canal backend no tiene**. Por eso el drain
  pone `pendingInviteMetadata = nil` con el comentario «backend: sin CKShare metadata — visual genérico»
  (`ContentView.swift:953`): no es un olvido, es que el tipo no le sirve;
- y el intent `.presentGroupBackendInviteOnboarding(pendingJoin: String)` solo transporta el `groupID`,
  así que la marca **no tiene por dónde viajar** del handler a la vista.

⇒ el fix mínimo honesto son **tres piezas**: (a) que la vista acepte la marca sin `CKShare.Metadata`
(un segundo parámetro, o hacer `shareMetadata` opcional); (b) que la marca viaje —en el payload del
intent, o mejor en `PendingJoinEntry`, que ya persiste y así también cubre el **cold start**, que es
el caso dominante: el invitado llega desde la web—; (c) el drain que la ponga.

No lo hice porque toca el router y el modelo persistido del intent, y prefería no dejar eso a medias
en una sesión larga. **Sigue mereciendo la pena**: el nombre del grupo ya viaja en el enlace, ya se
calcula en `AppBootstrapper:2040`, y el copy existe en 16 locales.

### 3 · `isInviteLink` más estrecho que el parser — no tocada

Sigue siendo inocua hoy (`buildBackendInviteURL` siempre pone `s`). Es endurecimiento, y el argumento
del ticket —«el modo de fallo que este subsistema ya pagó una vez»— se sostiene.

### 4 · copy por causa en el botón de generar enlace — no tocada, y el ticket se queda corto

Re-medido: el `else` del guard `CloudSyncFlags.groupsBackendEnabled && group.isBackendGroup` cubre
**DOS** causas distintas, no una:

- **grupo de la era CloudKit** (`!isBackendGroup`) → permanente, y es la que el ticket describe;
- **canal apagado** (`!groupsBackendEnabled`, kill remoto o snapshot de remote-config ausente) →
  **transitorio**, y ahí «revisa tu conexión» es casi lo correcto pero por el motivo equivocado.

⇒ el fix no es «un copy nuevo» sino **clasificar en tres** (legacy · canal · red), en las dos
superficies (`GroupMembersView:470`+`:480` y `GroupDetailViewModel:471`+`:479`). El molde ya existe:
`groups.invite.channelUnavailable` es el tono correcto para el canal apagado.

migrated from YalaWiki Bugs/grupos-enlace-de-invitacion-cinco-causas-un-solo-mensaje.md @ 1934e8ad

---

## DESBLOQUEADO · 2026-09-03

La pieza 1 (separar el caso «grupo borrado» de las otras cuatro causas) estaba **bloqueada por el
servidor**: exigía que el backend distinguiera ese caso, y el no-oráculo de `join_group` era
deliberado.

**El owner autorizó ese oráculo el 2026-09-03**, acotado a la propia fila de quien pregunta. La
decisión y su razonamiento están en `guest-decline-has-no-screen`, que es donde se planteó; las dos
piezas comparten autorización y conviene hacerlas en la misma pasada.

Las piezas 2, 3 y 4 nunca estuvieron bloqueadas: son código y siguen esperando su turno.

---

## Pieza 1 · IMPLEMENTADA y verificada en staging · 2026-09-03

**Qué cambia para el usuario.** Abres un enlace de un grupo que su creador borró. Antes: «Este enlace ya
no es válido o expiró. **Pídele al admin que regenere uno**» — un consejo imposible de seguir, porque no
hay grupo ni admin a quien pedírselo, así que la persona lo intenta, vuelve a fallar y nunca se entera.
Ahora: «Este grupo fue eliminado por su creador».

### Cómo se resolvió el bloqueo del no-oráculo

El ticket lo daba por bloqueado porque distinguir causas parecía dar un oráculo. Medida la función, la
propiedad se sostiene sola: **el `raise` del grupo borrado es el SEGUNDO**, y solo se alcanza después de
que el token pasara las cuatro validaciones (existe, no revocado, no caducado, no agotado). Quien recibe
el error nuevo **tenía un token real que alguien le dio** — ya sabía que el grupo existió. Con un token
inventado se cae en el primer `raise`, que sigue siendo `yala_invalid_invite` y no dice nada.

Eso no se argumenta: se comprueba. El golden `3-quater` afirma las dos mitades, y la segunda —token
inventado → `yala_invalid_invite`— es la que impide que alguien abra el oráculo sin que nada se ponga
rojo.

### Hecho

- `qa/cloud/g13_03_join_group_distinguishes_deleted.sql` — el segundo `raise` pasa a
  `yala_group_deleted`. El resto de `join_group` va verbatim: rebind legacy, ya-member e insert intactos.
- Cliente: `GroupsRPCError.groupDeleted` + mapeo · `GroupBackendAcceptErrorLogic` con kind propio,
  permanente y **slug propio para el canario** (colapsarlo escondería cuánta gente llega por un grupo
  borrado, que es justo lo que esto hace visible) · el handler elige el copy.
- **Copy reutilizado, no nuevo**: `groups.reconnect.deletedForAll.body` dice exactamente este hecho y ya
  está en los 16 idiomas. Es el MISMO hecho por otro camino. Queda avisado en el código que ese copy
  tiene ahora un segundo consumidor.

### Compatibilidad, medida ANTES de aplicar el DDL

`GroupsRPCError.init(yalaCode:)` devuelve `nil` ante un código desconocido y el llamador lo convierte en
`.permanentRejected`, **nunca** en `.transient` (regla A5: un 400 permanente reintentado sería bucle).
⇒ una app que no conozca `yala_group_deleted` lo trata como rechazo permanente y muestra su mensaje
genérico, exactamente como hacía antes. **Por eso se pudo aplicar en el servidor sin coordinar con la
publicación de la app.** Hay un test que fija ese fallback.

### Verificación

`g13_03` aplicada a **staging** y verificada: `yala_group_deleted` aparece una vez, `yala_invalid_invite`
**sigue** apareciendo una vez (el no-oráculo de las otras cuatro intacto) y los grants no cambiaron.
Build en las dos schemes · **6011 tests iOS / 601 suites** verdes · **323 del gateway** (322 + el golden
nuevo), 1 rojo preexistente con ticket. Mutación del cableado del mensaje: cazada.

Nota de método: la primera versión del golden daba `noop` en el tombstone porque usaba un HLC de `T0`
(15-jul-2026) contra una fila creada hoy con `server_hlc()`. Un test que pasa por la razón equivocada es
peor que uno rojo; queda escrito en el propio golden.

### Producción · aplicada y verificada el 2026-09-03

Se aplicó **sobre el cuerpo vivo** (un `do` block que lee `pg_get_functiondef`, sustituye solo el
segundo `raise` y aborta si el fragmento no está exacto), no pegando la versión de staging: así el resto
de la función queda byte-idéntico sin depender de que los dos entornos fueran iguales.

La prueba más limpia es el delta: el cuerpo pasó de **4079 a 4078 caracteres**, una letra menos —
exactamente la diferencia entre `yala_invalid_invite` y `yala_group_deleted`. Y `yala_invalid_invite`
sigue apareciendo una vez, con `pgp_sym_encrypt` × 3 y `rebound` × 4 idénticos a antes.

**Efecto en las apps ya publicadas**: una app que no conoce el código nuevo lo trata como rechazo
permanente y muestra su mensaje GENÉRICO. Deja de dar el consejo imposible, pero todavía no dice que el
grupo fue eliminado — eso llega con la próxima versión del cliente. Neutro-positivo mientras tanto, no
una regresión.

Piezas **2, 3 y 4 siguen abiertas** y nunca estuvieron bloqueadas: son código.

---

## Piezas 2, 3 y 4 · IMPLEMENTADAS · 2026-09-05

Las tres eran código y ninguna estuvo bloqueada. Con esto el ticket queda **cerrado**: pieza 1 en
producción (3-sep), pieza 5 desde el 12-ago, y estas tres hoy.

### Qué cambia para quien usa la app

1. **El nombre del grupo ya no se pierde entre la web y la app.** Tocas el enlace que te pasaron: la
   web te enseña «Viaje a Cusco», y la app te recibía con «Te invitaron a un grupo» y el color del
   tema. Ahora te recibe con **el nombre, el icono y el color del grupo**, también si llegas con la
   app cerrada — que es como llega casi todo el mundo.
2. **Un enlace de invitación que no traiga el parámetro cosmético ya no muere en silencio.** Antes,
   una forma perfectamente legible del enlace abría Yala y no pasaba nada.
3. **El botón de compartir enlace deja de culpar a tu conexión cuando el problema es otro.** Si el
   grupo es de la versión anterior de Yala, te lo dice y te propone lo único que funciona (crear un
   grupo nuevo) en vez de mandarte a reintentar para siempre.

### Pieza 2 · cablear `branded` — HECHA, y salió más barata de lo que el ticket estimaba

La medición del 12-ago decía «no es un cable suelto: cuesta tres piezas, y una es hacer
`shareMetadata` opcional». **Re-medido hoy, la premisa cara ya no se sostiene:**

> `grep -rn "InviteMetadata(" --include="*.swift" .` → **CERO productores en todo el árbol.**

Nadie construía `InviteMetadata`. Era un tipo muerto que arrastraba un `CKShare.Metadata` del canal
que la Fase 3 borró, y esa exigencia era justo lo que dejaba `welcomeWithGroup` inalcanzable. ⇒ no
había que hacerlo opcional ni añadir un segundo parámetro: había que **retirarlo** y poner en su
sitio `InviteLinkService.BrandedMetadata`, que es lo que de verdad viaja en el enlace.

La otra corrección a la lectura de agosto: la marca **no viaja en el payload del intent**, viaja en
`PendingJoinEntry`. El ticket ya lo apuntaba como «mejor» y medirlo lo confirma: el camino caliente
(tap con la app abierta) es la MINORÍA; el dominante es el frío, donde `enterBackendInvite` persiste
y retorna, y el intent de router no existe todavía. `persistIntent` es el choke point de los dos.

- `InviteLinkService.BrandedMetadata.hasBranding` — y **no vale `== .empty`**: `extractMetadata`
  sobre `…&m=` devuelve `members: []`, distinto de `.empty` y sin embargo sin nada que pintar.
- `PendingJoinEntry.branded` (Codable opcional, back-compat con el JSON ya persistido).
- `persistIntent(…, branded:)` **preserva la marca buena** si el tap nuevo no trae ninguna — un
  re-tap sobre la forma mínima, que la pieza 3 acaba de dejar entrar, no debe borrar el nombre.
- `AppBootstrapper` extrae la marca UNA vez y alimenta las tres ramas que persisten, la fría
  incluida (antes ni siquiera la calculaba ahí).
- El drain lee `PendingJoinStore.entry(zoneName:)?.branded` en lugar de poner `nil`.

### Pieza 3 · la puerta acepta lo que el parser lee — HECHA

`isInviteLink` pasa a `(hasShareParam || hasBackendPair)`. El pin no afirma «acepta esta URL» sino
la **propiedad**: todo lo que `extractBackendInvite` lee, la puerta lo deja pasar — con control
positivo por caso, para que un parser roto no deje las aserciones pasando en vacío.

**Residual, medido y con ticket:** el AASA sigue exigiendo `s`, así que el universal link mínimo lo
abre Safari. Cubre las otras dos vías (custom scheme y paste manual). Es despliegue web y depende de
la decisión de Vercel abierta en §9 del informe → `tickets/backlog/invite-aasa-requires-s-param.md`.

### Pieza 4 · copy por causa — HECHA, con la corrección del propio ticket

El ticket ya avisaba de que el `else` cubre **dos** causas, no una, y de que hay **dos** superficies.
Las dos cosas se sostienen contra este árbol. `GroupInviteLinkCreationLogic` clasifica:

| Causa | Naturaleza | Copy |
|---|---|---|
| Grupo de la era CloudKit (`!isBackendGroup`) | **Permanente** | `groups.errors.inviteLegacyGroup` (nuevo) |
| Canal apagado (`!groupsBackendEnabled`) | Transitoria | `groups.errors.inviteChannelOff` (nuevo) |
| Fallo del RPC | Red | `groups.errors.inviteFailed` (el de siempre, ahora bien usado) |

Con las dos caídas gana la permanente: si el canal vuelve mañana, ese grupo sigue sin poder emitir
enlace. Que sea permanente **está medido, no supuesto**: `migrate_group` está revocada y no tiene
endpoint en el cliente, así que no hay ninguna vía por la que un grupo legacy emita un enlace.

Copy nuevo en los 16 locales (es-AR con voseo, como su vecino `inviteFailed`).

### Verificación

Build ×2 verde. **Los 8 pines nuevos verificados por MUTACIÓN** — se revirtió cada pieza y se exigió
rojo. De ahí salió una corrección que importa más que el resto:

> `networkCopyStaysInTheCatchOnly` **contaba** usos de `inviteFailed` (`== 2`), y devolver el `else`
> a `surfaceActionError(inviteFailed)` deja exactamente 2 igual ⇒ **pasaba en verde con el bug
> puesto**, que es justo el fallo que su nombre promete detectar. Reescrito para comprobar **dónde**
> aparece el copy —aislando el bloque del `else`— y re-verificado por mutación: ahora sí cae.

Un test que cuenta cuando debería localizar es la familia del `makeTx` sin `category:` de
`.claude/rules/testing.md`: verde con la regla buena y con la mala.

### Qué falta ver en el simulador o en un device

Todo el ticket está implementado; lo que queda es MIRARLO, y son tres cosas cortas:

1. **El nombre del grupo en la bienvenida.** Tapear un enlace con cosméticos (`&n=`, `&i=`, `&c=`)
   siendo invitado fresco y comprobar que el título dice «Te invitaron al grupo <nombre>» con el
   icono y el color del grupo, no el genérico. **La precondición que hace falta cuidar: hacerlo con
   la app CERRADA**, que es el camino que este ticket arregla y el que antes ni extraía la marca.
2. **El re-tap no borra la marca.** Tapear primero el enlace completo y después la forma mínima
   (`?g=..&t=..`): el nombre debe seguir ahí.
3. **Los dos copies nuevos del botón de compartir enlace.** El de grupo legacy necesita un grupo de
   la era CloudKit (`isBackendGroup == false`); el del canal apagado, `groupsBackendEnabled` en OFF.
