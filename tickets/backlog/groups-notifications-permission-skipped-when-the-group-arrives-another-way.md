---
id: groups-notifications-permission-skipped-when-the-group-arrives-another-way
status: backlog
area: groups
priority: medium
created: 2026-10-21
updated: 2026-10-21
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
