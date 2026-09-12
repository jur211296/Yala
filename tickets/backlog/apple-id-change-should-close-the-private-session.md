---
id: apple-id-change-should-close-the-private-session
status: backlog
priority: high
area: "modo-nube, sesiones, swiftdata"
created: 2026-09-12
source: "§6 de shell-derives-from-two-session-axes, sacado a ticket propio por decisión de Jürgen (2026-09-12)"
---

# Cambiar el Apple ID del teléfono con sesión privada debería cerrarla, no avisar

## Por qué está aquí y no dentro del paso 12

Era el punto 6 del alcance de `shell-derives-from-two-session-axes`. **Jürgen lo sacó a ticket propio
el 2026-09-12**, con este motivo: convertir un aviso en un cierre de sesión que borra datos locales es
el cambio de comportamiento más caro de toda la cola del rediseño, y **no comparte una línea de código
con el barrido de flags** del paso 12 — es un objeto distinto que cayó en el mismo sprint. Meterlo en
un PR de ~130 ficheros es donde un error sale más caro y menos se ve.

El paso 9 ya lo había delegado al 12 (`tickets/qa/session-exits-one-verb-per-session.md:78`). Esta es
la misma deuda, con dueño propio.

## Lo medido hoy (2026-09-12, rama `2.1` en `ad2c9d0f`) — el ticket del paso 12 se equivocaba

Su §6 daba `AppBootstrapper.swift:1046` y decía que **las dos** mitades avisan. Las dos cosas son
falsas medidas en este árbol:

| Afirmación del paso 12 | Medido |
|---|---|
| `checkForICloudMismatch` está en `:1046` | está en **`:1114`** |
| `iCloudSyncService.accountDidChange` «reacciona con un aviso» | **no avisa**: hace exactamente dos cosas (`:249-254`), borrar el ancla de export confirmado y `checkAccountStatus()` |
| (no lo menciona) | el observer de `NSUbiquityIdentityDidChange` está en **`:1084-1089`** |
| (no lo menciona) | **hay una SEGUNDA llamada en `:1694`**, dentro de `handleBecameActive` ⇒ esto corre en **cada vuelta a primer plano**, no solo al arrancar |

Quien avisa es el observer de `AppBootstrapper`, vía `RouterEntryGate.shared.submit(.iCloudMismatch)`
(`:1137`), y está gateado por `SwiftDataConfiguration.shouldOfferICloudRestart` (`:1121`).

## El riesgo que hay que respetar

`shouldOfferICloudRestart` tiene tres términos, y **uno de ellos existe para que una sesión solo-grupos
no reciba este aviso NUNCA** (`groupsOnlySessionArmed`). Si el eje nuevo no expresa ese término, vuelve
un aviso perpetuo que además le propone al usuario bajar el iCloud de su Apple ID. Es el modo de fallo
concreto a evitar.

Y el segundo, de la rule de área: una salida que borra lo local con el espejo montado **borra ARCHIVOS
antes del mount, nunca FILAS** — con `NSPersistentCloudKitContainer` montado, borrar filas deja los
deletes en la History y el espejo los exporta, o sea que vaciaría el iCloud de la persona en todos sus
dispositivos. El molde correcto ya existe: `armSignOutWipe` → `performSignOutWipeIfArmed` + relanzar.

## Decisión pendiente de Jürgen

**¿El borrado es silencioso al detectar el cambio, o pasa por confirmación del usuario?** Mueve datos
suyos, así que por el criterio que ya se aplicó en la puerta del invitado lo normal sería preguntar —
pero aquí el usuario que cambió de Apple ID puede no ser el dueño de los datos, que es justo el caso
que el verbo único quiere cerrar. No se implementa hasta que esté contestada.

## Criterios de aceptación

- [ ] Cambiar de Apple ID con sesión privada viva cierra la sesión privada: borra lo local por el
      camino de ARCHIVOS (boot-wipe + relanzamiento) y devuelve la app al neutro.
- [ ] Una sesión solo-grupos **no** recibe el aviso ni el cierre (el término `groupsOnlySessionArmed`
      sobrevive, expresado en el eje nuevo).
- [ ] La segunda llamada de `handleBecameActive` (`:1694`) no dispara el cierre repetidamente ni deja
      un aviso perpetuo.
- [ ] Unit sobre el predicado, con las celdas del ADR como casos.
- [ ] Device-QA: **no es simulable** — hace falta cambiar la cuenta de iCloud del teléfono de verdad.

## Depende de

`shell-derives-from-two-session-axes` — necesita el eje «¿hay sesión privada?» ya escrito, porque el
predicado nuevo se expresa con él.
