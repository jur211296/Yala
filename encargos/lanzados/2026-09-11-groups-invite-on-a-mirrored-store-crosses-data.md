# Implementar ticket: groups-invite-on-a-mirrored-store-crosses-data

## Contexto
Cola autónoma del rediseño (bypass hasta que Jürgen diga lo contrario). Ticket 1 de la cola. Sale de la mitad 2 (#139): la rama CREAR quedó cerrada; la de INVITACIÓN sigue cruzando datos — gastos del invitado al iCloud del dueño si el teléfono ya espeja.

Decisiones/ADR 2026-09-09 mandan: no borrar corpus en boot sin pantalla. Reusar `GroupsOrganizerGateLogic.decide` (`.returnsToNeutral`), step `.groupsGate` del Welcome y `CloudSessionSignOut.signOut(confirmedPath: .privateSignOut, …)`. Construir (a) encaminamiento CON pantalla desde `drive`, (b) durabilidad del intent a través del wipe (key one-shot `{groupID, token}` sin PII, reponer en `PendingJoinStore` después del boot-wipe, como `WelcomePendingDestinationStore`).

MODO AUTÓNOMO HASTA TERMINAR: review adversarial si toca sync/datos, gate, commit, board, actualizar `docs/TICKETS.md`, merge y `/cerrar-total` sin preguntar. Bugs/decisiones nuevas → ticket `--solo-crear` antes de cerrar; si es high que deba adelantarse en la cola, créalo y anótalo en el cierre. Ambigüedad NUEVA: elige lo más seguro alineado con ADR/criterios; regístralo. Device-QA CloudKit → `tickets/qa/`.

Avisos a Frank (webhook Mini): (1) decisión/acceso; (2) PR; (3) `/cerrar-total` con resumen producto; (4) idle — una vez. No avisar por test/build a reintentar ni CI advisory.

No lances el siguiente tú: Frank encadena la cola. No toques marketing/ ni el paso 12 salvo mínimo.

## Que se pide
1. Leer ticket + ADR + lo que dejó mitad 2 / paso 9.
2. Cumplir criterios de aceptación del ticket (neutro con pantalla; intent sobrevive; fresco sin pantallas de más; dueño no pierde lo no subido).
3. Tests unit del encaminamiento y durabilidad del intent; device-QA CloudKit a `tickets/qa/`.
4. PR a `2.1`; board/`TICKETS.md`; `/cerrar-total`.

## Que NO hay que tocar
marketing/. Paso 12 salvo mínimo. Wipe de prod. Borrar corpus en `.boot` del reconciler sin pantalla.

## Como se sabe que esta bien
Criterios del ticket; tests en verde; PR mergeado; board/`TICKETS.md` al día; `/cerrar-total`.

## Paso 0 — decisiones (resueltas en autónomo, bypass)

Cinco nodos. Los tres primeros salen de MEDIR el árbol y contradicen en parte lo que el propio ticket
daba por hecho. El detalle largo, con las coordenadas, está en
`tickets/in-progress/groups-invite-on-a-mirrored-store-crosses-data.md` § «Paso 0».

1. **¿La puerta del invitado reusa `GroupsOrganizerGateLogic.decide`?** → **No.** Le falta un término que
   aquella no necesita: «el onboarding personal no está completado». La del organizador vive DENTRO del
   Welcome y ese contexto se lo da el sitio; ésta corre desde `drive`, al que llama también el reconciler
   en `.boot`, o sea en cualquier estado. Sin ese término le borraría el corpus a quien tiene la sesión
   privada viva, que es lo contrario de lo que manda la fila `C · llega una invitación` de la matriz del
   ADR. ⇒ lógica propia, `GroupInviteNeutralGateLogic`, y la vuelta al neutro solo en A/B/G.

2. **¿Se informa o se pregunta?** → **Se pregunta**, al revés que en la rama CREAR. Allí la decisión de
   Jürgen («se informa, no se pregunta») se apoyaba en un hecho que aquí no existe: la persona acababa de
   tapear «Crear mi primer grupo». La puerta del invitado puede llegar en un arranque en frío sin que
   nadie haya tocado nada, así que informar-y-borrar sería borrar sin gesto — lo que el ADR 2026-09-09
   prohíbe. Con esto, el criterio de aceptación nº 2 se cumple **por construcción**.

3. **¿Antes del sign-in o antes del join?** → **Antes del sign-in.** Medido en `GroupsGateLogic.nextStep`:
   el orden es sign-in → consent → hoja, así que interponer tras el «sí» de la hoja dejaría que el cierre
   privado deshiciera la sesión recién creada y el invitado repitiera las dos pantallas tras el
   relanzamiento. Antes del switch no se escribe nada que el cierre vaya a tirar.

4. **¿Pantalla nueva o el step que ya existe?** → **El step `.groupsGate`, con un `Purpose`.** Duplicar el
   motor de `WelcomeGroupsGateView` (celda de cierre, espera del export, bloqueo por grupos sin subir)
   crearía dos verdades sobre el mismo borrado.

5. **¿Cómo sobrevive la invitación al wipe?** → **Dos piezas, no una.** `hasShownWelcomeChooser` SÍ está en
   `DataWipeService.removeUserPreferenceKeys` (medido), así que hace falta un destino pendiente
   (`Destination.groupsInvite`, añadido al final del enum) además de la key one-shot `{groupID, token}`
   sin PII que repone `PendingJoinStore` después del boot-wipe.
