# Implementar ticket paso 3: cloud-sign-in-discovers-account-kind

## Contexto
Cola autónoma del rediseño de sesiones (Jürgen 2026-09-10). Pasos 0–2 en `2.1` (#127 vocab, #128/#129 percents+deploy, #130 kind + fresh start prod).

Decisiones YA tomadas: sección **«Decisiones de Jürgen (2026-09-09, pasada de desbloqueo)»** del ticket + índice `docs/sessions/2026-09-09-desbloqueo-decisiones-rediseno-sesiones.md`. **Mandan.** (adopción silenciosa; `.notFound` → consentimiento; Grupos cambia de motor no de aspecto; tests = 15 celdas + bordes de sesión privada).

MODO AUTÓNOMO HASTA TERMINAR: este paso es **[spec] [adv]** → `/spec` + Plan Mode + `/review-plan` + review adversarial, gate, commit, board, `docs/TICKETS.md`, merge, `/cerrar-total` sin preguntar. Bugs/decisiones nuevas → ticket `--solo-crear`. Ambigüedad NUEVA: elige lo más seguro alineado con Decisiones y regístralo. Para solo por credencial/acceso real (p.ej. deploy Worker si no hay Cloudflare).

Avisos a Frank: (1) bloqueo acceso; (2) PR; (3) `/cerrar-total` resumen producto; (4) idle — una vez.

Nota: Jürgen debe desplegar Worker si aún no (base ya en staging/prod) y recrear grupos de prueba en device. No bloquees la implementación del cliente por eso; si el Worker prod aún no sirve `kind`, mide y documenta.

## Que se pide
1. Leer: Decisiones → ADR → matriz → ticket entero → runbook.
2. Implementar el bloque [I]: ruteo según `kind` del backend; criterios del ticket + Decisiones.
3. Un PR a `2.1`. Marcar filas de matriz / coverage según runbook.
4. `/cerrar-total`.

## Que NO hay que tocar
marketing/. Pasos 4–13 salvo dependencias mínimas inevitables. Wipe adicional de prod.

## Como se sabe que esta bien
Criterios del ticket + Decisiones; review adversarial hecha; PR mergeado; board/`TICKETS.md` al día; `/cerrar-total`.

---

## Paso 0 — el árbol de decisiones, resuelto antes de escribir código

Modo autónomo: cada rama se auto-contesta hacia **lo más seguro alineado con las Decisiones de Jürgen**,
y lo que la medición cambió respecto al ticket se dice en su sitio.

### D1 · `kind` ausente: ¿qué rutea? — **el comportamiento de HOY, puerta por puerta**

**Medido (2026-09-10):** el Worker **no está desplegado con `kind` en ninguno de los dos entornos**.
Staging: último deploy `2026-08-12T13:05:19Z`. Producción: último deploy `2026-09-10T06:12:16Z`, que es
**anterior** al commit `675aadec` (`2026-09-10 03:31:41 -0500` = `08:31 UTC`) que escribió el campo. ⇒ hoy
`GET /account/exists` contesta `{exists:true}` **sin `kind`** en staging y en producción.

Aplicar `AccountKindLogic.resolve` (→ `groupsOnly`) en el ruteo sería una **regresión medible en
producción**: «Ya tengo cuenta» dejaría de adoptar y quien tiene una cuenta completa entraría a una app
vacía. Y eso **no lo arregla el refresco**, porque lo que no ocurrió es el adopt, no una etiqueta.

La decisión de Jürgen («ausente ⇒ `groups_only`, con corrección al refrescar») gobierna **qué se cree la
app sobre la cuenta activa** —`AccountKindService.current`, que pinta la shell— y su razón declarada
(«equivocarse hacia `complete` = enseñar un Panel y unas cuentas que no son suyas») **no aplica a la
re-entrada**: ahí las cuentas son de quien acaba de firmar, y los datos ajenos ya los cubre el guard
cross-cuenta. ⇒ `kind == nil` degrada a lo que cada puerta hace hoy: la re-entrada adopta, la de grupos
entra solo-grupos. **Sin el dato nuevo, el sistema se comporta como antes del dato nuevo**, que es lo que
hace este PR seguro de mergear antes del deploy del Worker.

### D2 · El componente [I] es un **motor**, no una vista
Lo fija la decisión de Jürgen: «`GroupsSignInView` cambia de motor, no de aspecto». Compartir la vista
cambiaría el aspecto, que es justo lo prohibido.

### D3 · El guard cross-cuenta **no se extrae** de `WelcomeCloudSignInView`
`CrossAccountEntryGuardLogicTests:235-248` hace source-scan de la rama `case .blockedForeignData:`
**dentro de ese fichero** y exige `L10n.Welcome.Cloud.blockedRestoreHint` y `onBack()`. Extraerlo tumba
esa red y contradice el AC «conserva byte-idéntico el guard». El motor cubre «firmar → exists+kind →
destino»; **cada puerta aplica su guard con sus propios inputs**.

### D4 · La puerta 5 (Ajustes → «migrar a la nube»): tabla sí, cableado no
Medido: esa puerta **no consulta `exists`** y su sign-in ocurre **dentro** de `startMigration`; y la celda
«solo grupos → promover **mi asociada**» necesita saber cuál es la asociada, que **hoy no se persiste**
(la puerta de grupos solo escribe `groups.hadSessionEver`). La matriz ya reparte esa fila entre este
ticket, el 10 y el backend. ⇒ sus 3 celdas entran en la tabla (AC de las 15); **el cableado va a ticket**.

### D5 · Sin XCUITest nuevo de [I], y no es pereza
`-uitest-cloud-chooser` existe (`UITestHooks.swift:53`), pero **no hay ningún seam que stubee
`/account/exists`** ni el sign-in real — `WelcomeChooserUITests` declara que el botón de sign-in jamás se
tapea. Llegar a una celda exige red y SIWA reales. La decisión de Jürgen acota los tests a «las 15 celdas
+ los bordes de sesión privada», que es **unit**: eso **deroga** el «XCUITest del chooser» del cuerpo del
ticket. El recorrido va a device/staging-QA.

### D6 · Cero cambios de backend: la cuenta de grupos **ya nace `groups_only`**
Medido: `profiles.kind` es `not null default 'groups_only'` (`qa/cloud/g15_01_account_kind.sql:106`) y la
fila la crean los RPC `create_group`/`join_group` (verificado en sandbox, `:41`). `CloudAccountClient.claim`
**no** tiene parámetro `kind` y la puerta de grupos **no** llama al claim. ⇒ la celda «grupos + nueva»
sigue el recorrido [G] de hoy y la cuenta nace del tipo correcto **sola**. No se toca el claim.

### D7 · `.notFound` conserva su `signOut()`
Dejar la sesión viva haría que un «atrás» + entrada por otra card la reusara (`ensureSignedIn` salta con
`hasSession`) y el usuario entraría con una cuenta que no eligió. El «proveedor ya firmado» de la decisión
se cumple llevando **el proveedor elegido** al alta, no la sesión.

### D8 · El `kind` de la puerta de Grupos se descubre en `AccountKindService.handleSignIn()`
Medido: ese método existe y tiene **cero call-sites** — es el gancho que el paso 2 dejó preparado.

### D9 · «Aterriza en Grupos»: por la cadena que YA es durable
Medido: `reEmitInviteAfterRestore` **no re-emite nada** (solo llama a
`GroupJoinReconciler.reconcile(trigger: .foreground)`) — la premisa del ticket es falsa en su literalidad.
Lo que sí es durable es `PendingJoinStore` (`UserDefaults`, sobrevive al relanzamiento y a XCUITest), y el
reconciler la retoma en el boot. ⇒ la invitación no se pierde sin código nuevo. Cuando el adopt termina
**sin relanzamiento** (`.reentryReady`, que es el caso del móvil limpio con store neutro) se selecciona la
pestaña Grupos en el mismo gesto; con relanzamiento, la invitación se retoma en el arranque y el caso
«organizador» (intent no durable) queda **anotado con ticket** — inventar aquí un testigo durable es
alcance del paso 12.
