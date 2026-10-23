---
id: groups-notifications-permission-skipped-when-the-group-arrives-another-way
status: qa
area: groups
priority: medium
created: 2026-10-21
updated: 2026-10-23
source: review adversarial del lote decidido 2.2 · 14 (L12-8)
---

# El permiso de avisos de grupo ya no se pide a quien llega a su primer grupo por otro camino

## Qué pasa

Desde L12-8 (decisión B de Jürgen) el permiso de los avisos de grupo se pide dentro de «“X” está listo»,
«Ya estás en «X»» y «Solicitud enviada», y la alerta suelta de la pestaña Grupos se retiró. El aviso de grupos
(`NotificationItem` «groups») nace apagado, así que quien no pasa por ninguna de esas tres pantallas no recibe
nunca avisos locales de grupo, tampoco «Ya estás en «X»» (L12-20):

- Quien crea su primer grupo desde el botón «Grupo» del Panel para apuntar un gasto (L13-8): el formulario de
  gasto sustituye a «está listo».
- Quien cierra la hoja de invitación en «Está tardando» y entra después en segundo plano.
- Quien recibe sus grupos por sincronización (segundo dispositivo, reinstalación, tras «Vaciar datos»).

Antes la alerta les salía a todos al ver el primer grupo en la lista.

## Opciones

- A. Dejarlo: el aviso se activa en Ajustes › Notificaciones.
- B. La misma tarjeta de avisos en el formulario de gasto de L13-8 y como aviso único en la lista para quien tiene
  grupos y nunca vio la tarjeta (sin alerta suelta).

Necesita decisión de Jürgen (toca dónde se pide un permiso).

## Decisión (Jürgen, 2026-10-23)

**B.** La misma tarjeta de avisos en el formulario de gasto de L13-8 y, una sola vez, arriba de la lista de Grupos para
quien tiene grupos y nunca la vio. Sin alerta suelta.

## Hecho (2026-10-23, sesión «Pendientes de Jürgen 2.2»)

- `GroupExpenseFormView`: con el aviso «Ahora apunta el gasto» (solo tras crear el grupo para este gasto) sale debajo la
  `GroupNotificationsOptInCard`.
- `GroupsContainerView`: la lista monta `GroupNotificationsOptInCard(onlyIfNeverSeen: true)` sobre las tarjetas de grupo,
  salvo con el formulario de la bienvenida abierto o la hoja «está listo» a punto de salir.
- «Nunca la vio» = `AppPreferences.hasSeenGroupsNotificationPrompt` (el flag de la alerta retirada en L12-8). La tarjeta
  lo marca en cuanto sale en CUALQUIER pantalla, así que la lista no la repite.
- Unit: `PendientesJurgen22Tests` (`GroupNotificationsOtherPathsTests`).

## Guion de QA (iPhone, ~5 min, Yala Dev)

1. Ajustes del iPhone › Notificaciones › Yala Dev: apágalas, o borra y reinstala Yala Dev para que iOS vuelva a preguntar.
2. Sin grupos, toca el botón + del Panel › «Grupo» › «Crear grupo», ponle nombre y guárdalo.
3. En el formulario de gasto que sale: debajo de «Ahora apunta el gasto» tiene que verse la tarjeta «Avisos del grupo».
   Toca «Activar avisos» y acepta el permiso: la tarjeta pasa a «Avisos activados».
4. Para la lista: en otro iPhone o tras «Vaciar datos» con tus grupos en la nube, entra a la pestaña Grupos cuando
   lleguen. La tarjeta sale UNA vez arriba de la lista; sal de la pestaña y vuelve: ya no está.
