---
id: cloud-signout-collapses-every-groups-transient-into-permanent
status: qa
priority: high
area: "modo-nube, groups, sesión"
created: 2026-09-14
updated: 2026-09-14
source: "review adversarial de `groups-sync-treats-an-infra-403-as-an-account-verdict`, lente de sync"
---

# Cerrar sesión en la nube culpa a tu conexión de cualquier fallo de grupos

## El problema, en lenguaje de usuario

Tengo una cuenta en la nube con grupos y cambios de grupos sin subir. Pulso «Cerrar sesión». Falla algo
del lado del servidor —un corte de red, un 5xx, un cortafuegos que devuelve 403— y la app me dice
siempre lo mismo: **«Hay cambios sin subir a la nube. Revisa tu conexión e inténtalo de nuevo.»**

Cuando el problema es mi conexión, el aviso acierta. Cuando no lo es —que es la mayoría de las veces que
esto se ve—, me manda a buscar un fallo que no existe, y no me dice lo único cierto: que espere y lo
vuelva a intentar.

## Lo medido (2026-09-14)

`Yala/Services/CloudSync/CloudSessionSignOut.swift:779-784`, paso 2 de `performCloudSecureSignOut`:

```swift
case .blocked(let pending, let reason):
    phase = .blocked(pendingCount: pending,
                     reason: reason == .channelPaused ? .channelPaused : .permanent)
```

**Todo lo que no sea `.channelPaused` se convierte en `.permanent`**, incluido `.transient`. El comentario
de encima lo dice y lo justifica: la excepción del kill-switch se abrió el 2026-09-13 «y los otros motivos
se quedan porque su alert en este camino es una decisión propia y nadie ha pedido cambiarla».

Consecuencias en cadena, todas medidas:

- `.permanent` → `ProfileView.swift:153` → `showSignOutBlockedAlert` con
  `L10n.Settings.signOutBlockedMessage` («revisa tu conexión»).
- ~~**El reintento interno se pierde.**~~ **FALSO, medido el 2026-09-14 al implementarlo:** este camino
  **nunca** consulta `GroupsSignOutRetryDecision`. El paso 2 llama a `pushAllPendingGroupsForSignOut`
  **directo**; quien tiene el presupuesto de 45 s es `pushGroupsForSignOut`, que usan los otros tres
  caminos (`CloudSessionSignOut.swift:214`, `:505`, `:630`) y no éste. O sea que aquí no había reintento
  que perder ni presupuesto que gastar: lo único roto era el aviso.
- La celda hermana **sí** lo hace bien: el cierre de la sesión SOLO-GRUPOS
  (`attemptGroupsOnlyClose`) propaga el motivo tal cual, así que ahí un transitorio se anuncia como
  transitorio y se reintenta.

## Por qué no se arregló de paso

Salió midiendo el cierre de `groups-sync-treats-an-infra-403-as-an-account-verdict`, que llevó el 403 de
infraestructura de `.accountUnavailable` a `.transient`. Ese arreglo cierra el sellado del canal y la
celda solo-grupos, pero **aquí no llega**: el 403 de infra entra en este ternario como `.transient`
indistinguible de una red caída, y sale como `.permanent` igual que antes.

Cambiar el ternario no es tocar el 403: es cambiar el aviso de **todos** los transitorios de este camino
—red caída, 5xx, decode fallido, tope de iteraciones—, que es otro objeto y una decisión de producto.

## Lo que hay que decidir

1. **Propagar `.transient` tal cual**, como ya hace la celda solo-grupos. El aviso pasa a «un momento
   más» y el gesto reintenta 45 s. Coste: ~22 peticiones contra un servidor que quizá esté bloqueando, y
   45 s de espera antes de decir nada.
2. **Propagarlo pero sin reintentar**, con su propio motivo: aviso inmediato y honesto («no pudimos
   subir tus cambios ahora, inténtalo en un rato») sin gastar el presupuesto.
3. **Dejarlo como está** y documentar que en este camino el aviso es deliberadamente conservador.

La 2 es la que más se parece a lo que se decidió para `.channelPaused` el 2026-09-13, y por eso va
primera; pero es una decisión de Jürgen, no una tarea.

## Relación con otros tickets

- `groups-sync-treats-an-infra-403-as-an-account-verdict` — el arreglo que dejó esta celda al descubierto.
- `groups-killswitch-403-blocks-detach-forever` — el que abrió la única excepción que hoy existe aquí.


---

## Cerrado el 2026-09-14 — opción 2

**Decisión de Jürgen (overnight):** aviso inmediato y honesto **sin** gastar presupuesto de reintento,
el mismo criterio que `.channelPaused` el 2026-09-13. Y medido arriba: en este camino no había
presupuesto, así que la opción 2 era lo único que faltaba decir bien.

**Qué se hizo.**

- `BlockReason.uploadRetryLater`, motivo nuevo **al final del enum** (un case intercalado cambia el
  número del alert que se usa para diagnosticar).
- `CloudSignOutFlowLogic.cloudSignOutGroupsBlockReason(_:)`: función pura y **`switch` exhaustivo sin
  `default`**, en lugar del ternario. Ahora el compilador obliga a pronunciarse sobre cada motivo nuevo
  — el ternario no obligaba a nada, y por eso el bug pudo nacer en silencio.
- El aviso sale por el **mismo alert** que `.channelPaused` («No pudimos cerrar tu sesión»), con copy
  propio en 16 locales: «Los últimos cambios de tus grupos no llegaron al servidor. Siguen guardados en
  este teléfono y no se pierden; inténtalo de nuevo en un rato.» No por el alert de `.transient`, cuyo
  título promete «un momento más» sobre algo que nadie ha reintentado.
- Cada motivo gana `breadcrumbSlug` y el paso 2 emite `CloudSyncBreadcrumb.signOutGroupsBlocked(reason:)`:
  sin él, los tres desenlaces del bloqueo dejaban el mismo rastro y en campo no se podía saber qué vio
  la persona.
- `.channelPaused` viaja igual y el kill deliberado del canal no se toca.

**Cómo se verificó.** `CloudSignOutGroupsReasonTests` (tabla exhaustiva por `allCases` + slugs únicos) y
`PausedChannelReasonWiringTests` (el paso 2 delega, lo traducido alimenta la fase, el breadcrumb se emite,
y el aviso sale por el alert del bloqueo **con su cuerpo**). **8 mutantes compilados y corridos, 8
muertos.** Los dos primeros los cazó la review adversarial dentro de mis propios tests: un `#require` que
fijaba la etiqueta del `case` y no su cuerpo —el mutante mandaba los cuatro motivos al alert equivocado y
pasaba verde— y una aserción tautológica que comparaba dos `lowerBound` de literales distintos. Y un
tercer mutante sobrevivió a la primera: borrar el breadcrumb entero no rompía nada; ahora sí.

## Device-QA — NO simulable

**Guion (requiere provocar un fallo real del servidor):**

1. Cuenta **en la nube** con al menos un grupo y un gasto de grupo sin subir (el outbox personal tiene
   que estar vacío: si quedan filas personales pendientes, bloquea el paso 1 y sale el aviso genérico —
   eso es el ticket `cloud-signout-collapses-the-personal-push-all-reason-into-permanent`).
2. Hacer que `/groups/push` falle de forma **pasajera**: 5xx del gateway, o un proxy que devuelva 403
   sin ser el kill-switch.
3. Ajustes → «Cerrar sesión».
4. **Esperado:** el aviso aparece **al momento** (sin 45 s de espera) y dice «Los últimos cambios de tus
   grupos no llegaron al servidor…», no «Revisa tu conexión».
5. Con el kill-switch bajado (`GROUPS_BACKEND_ROLLOUT_PERCENT`), el aviso sigue siendo el de
   `.channelPaused`.

**Por qué no se simula:** no hay seam que provoque un fallo del canal de grupos ni que pueble su outbox
en una sesión `.cloud` (`grep '"-uitest'` sobre `Yala/`: 34 seams, ninguno de los dos), y el encargo
prohíbe inventar uno.

## Lo que este PR NO cierra, con ticket propio

- `cloud-signout-collapses-a-groups-session-expiry-into-permanent` — `.sessionExpired` sigue colapsado en
  este mismo paso 2. Su copy manda a «volver a iniciar sesión» a quien acaba de pedir lo contrario: es
  una decisión de producto, no una tarea.
- `cloud-signout-collapses-the-personal-push-all-reason-into-permanent` — el paso 1 ni siquiera lee el
  motivo (`case .blocked(let pending, _)`), y es el que dispara primero ante un corte de red.
- `signout-blocked-alert-button-has-no-test-identifier` — el botón del aviso es el único de la cadena de
  cierre sin identificador.
