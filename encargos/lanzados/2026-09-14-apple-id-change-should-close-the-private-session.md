# Implementar ticket: apple-id-change-should-close-the-private-session

## Contexto
Cola autónoma bypass. Tras #158. Cambiar el Apple ID del teléfono con sesión privada viva debe cerrarla (wipe por ARCHIVOS + relanzar al neutro), no solo avisar. Solo-grupos NO recibe aviso ni cierre.

## Decisión de Jürgen (2026-09-14)
**1B:** el borrado pasa por **confirmación del usuario** antes de cerrar (no silencioso).

Respetar: `groupsOnlySessionArmed` / eje privado — solo-grupos nunca ve esto. Wipe = armSignOutWipe / archivos antes del mount, nunca filas con espejo montado. `handleBecameActive` no debe disparar cierre repetido ni aviso perpetuo.

MODO AUTÓNOMO HASTA TERMINAR: review adversarial, gate, commit, board, `docs/TICKETS.md`, merge, `/cerrar-total`. Bugs nuevos → ticket `--solo-crear`. Device-QA (cambio real de Apple ID) → `tickets/qa/`.

Avisos a Frank: (1) bloqueo acceso; (2) PR; (3) `/cerrar-total` resumen producto; (4) idle una vez.

No lances el siguiente: Frank encadena. No marketing/. No el high activation-discard sin decisión de Jürgen.

## Que se pide
1. Leer ticket + eje PrivateSessionMark + checkForICloudMismatch / shouldOfferICloudRestart.
2. Implementar cierre con confirmación (1B); criterios del ticket.
3. Unit del predicado; PR a `2.1`; board/`TICKETS.md`; `/cerrar-total`.

## Que NO hay que tocar
marketing/. Cierre silencioso. Solo-grupos. Wipe por filas con espejo montado.

## Como se sabe que esta bien
Criterios del ticket; tests; PR mergeado; `/cerrar-total`.

---

## Paso 0 — árbol de decisiones (auto-contestado, 2026-09-14)

### La premisa del ticket NO se sostiene: no hay nada que «alinear»

El ticket dice «hoy `checkForICloudMismatch` avisa; alinear con el verbo único». Medido en este árbol:

| Afirmación | Medido |
|---|---|
| El aviso de hoy reacciona al cambio de Apple ID | **No.** `shouldOfferICloudRestart` (`SwiftDataConfiguration.swift:972`) es «monté sin espejo y **ahora hay** iCloud». Ni mira identidad ni puede |
| Coordenadas `:1046` / `:1084-1089` / `:1694` | hoy `:1148` / `:1118-1123` / `:1722` |
| `iCloudSyncService.accountDidChange` avisa | no avisa: borra el ancla del export y `checkAccountStatus()` (`:249-254`) |
| (no lo dice) | **la app no guarda ningún testigo del Apple ID con el que montó** — no hay con qué comparar |

⇒ el trabajo no es convertir un aviso en un cierre. Es **construir la detección** y luego el cierre.

### D1 · ¿Con qué se detecta que el Apple ID cambió?

`ubiquityIdentityToken` **NO** como veredicto: la rule de área (`swiftdata-cloudkit.md` L199) lo mide —
es iCloud **Drive**, no CloudKit. Con Drive apagado y la sesión viva vale `nil` mientras CloudKit
funciona, así que apagar Drive sin cambiar de cuenta se leería como «cambió de Apple ID» y **borraría
los datos**. Es el mismo predicado que ya reintrodujo el bug del paso 4.

**Elegido:** `CKContainer(identifier: cloudKitContainerIdentifier).userRecordID().recordName` del
contenedor **PERSONAL**, persistido como testigo. Patrón ya probado en el repo
(`GroupICloudIdentitySeed`), pero ése usa el contenedor de **Grupos**, que tiene fecha de caducidad
escrita (la Fase 4 le retira el entitlement) — no se reusa, se espeja.

Descartado también `CKIdentityCapture`: su `ownerName` cae a `CKCurrentUserDefaultName`, un literal, no
la identidad de la cuenta.

### D2 · ¿Qué lectura del eje 1?

`confirmedPrivateSession` (ausente ⇒ `false`), **no** `hasPrivateSession`, y cumple su criterio escrito:
«hacia `true` se destruye, hacia `false` solo se conserva de más». Con la lectura ancha, un dispositivo
sin marca escrita se borraría solo.

**Aporta DOS lecturas de la estricta, no una** —el pre-filtro y la re-lectura tras el `await`—, así que
el conteo de `PrivateSessionMarkTests` sube de 3 a 5. Y **una de la ancha**, en el tap del aviso: ahí la
celda se resuelve con `CloudSignOutFlowLogic.path`, donde el `false` de más resolvería
`.groupsOnlySignOut` y borraría también el store de grupos — la dirección contraria. Ese conteo sube de
16 a 17. Los dos números los obliga un test, que es como se descubrió.

### D3 · ¿Cuándo se comprueba? — y por qué NO en cada foreground

**Arranque (una vez por proceso) + observer de `NSUbiquityIdentityDidChange`.** La notificación es el
**disparador** (uso legítimo del token), nunca el veredicto.

**No cuelga de `handleBecameActive`:** ahí no hay señal de cambio y sería una ida a CloudKit por cada
vuelta a primer plano. Con esto el 3.er criterio del ticket se cumple *por construcción*, no por un
guard que haya que recordar.

### D4 · La confirmación (1B de Jürgen) — y qué pasa si dice «ahora no»

Dos salidas: **«Cerrar sesión»** (destructiva, ejecuta) y **«Ahora no»**.

«Ahora no» no borra y el aviso **no se repite en esta sesión de la app**; vuelve en el arranque
siguiente. No es un nag perpetuo: si la persona vuelve a su Apple ID anterior, el predicado deja de
disparar **solo**. Y la salida existe porque el caso real que protege es «me equivoqué de cuenta»:
borrar en silencio le quita la copia local antes de poder deshacerlo.

### D5 · No se espera al export de iCloud, y es lo contrario de lo que hace «Cerrar sesión»

El cierre privado normal espera a que lo último llegue a iCloud (`confirmExportOrBlock`). Aquí la cuenta
destino **ya no está**: el ancla la acaba de invalidar `accountDidChange` y el export a la cuenta vieja
es imposible. Esperar sería 45 s para acabar en `.blocked(.exportUnconfirmed)` con la sesión abierta.
⇒ se entra con `confirmedWithoutICloudCopy: true`, y **el alert lo dice con esas palabras** — la
confirmación del usuario ES ese segundo gesto, no un flag heredado en silencio.

### D6 · El testigo muere donde mueren los ejes

En `performSignOutWipeIfArmed`, junto a `PrivateSessionMark.clear()`. Sin eso, el arranque de después
del cierre compararía el Apple ID nuevo contra el testigo viejo y volvería a disparar.

### Fuera de alcance (dicho, no omitido)

- El aviso que ya existe (`shouldOfferICloudRestart`) **se queda como está**: contesta otra pregunta.
- `marketing/`. Cierre silencioso. Solo-grupos (lo corta `groupsOnlySessionArmed`, término conservado).
- Device-QA: no es simulable (hace falta cambiar la cuenta de iCloud de un teléfono real) → `tickets/qa/`.
