---
id: groups-settlement-reminder-discoverability
status: done
priority: medium
area: groups
created: 2026-09-07
updated: 2026-09-16
qa-status: passed
qa-date: 2026-09-16
---

# El recordatorio de deuda no tiene ningún camino de descubrimiento

## Problema

El recordatorio de liquidación (`groups-settlement-reminder`) quedó construido y correcto, pero
**hoy no lo va a recibir prácticamente nadie**, y no por un bug: por la suma de tres decisiones
que por separado son razonables.

1. **`groupSettlementRemindersEnabled` nace en `false`.** Es deliberado y se sostiene: es el
   único aviso de la app que habla del dinero que le debes a otra persona, y encenderlo sin
   pedirlo convertiría una actualización en un cobro sorpresa.
2. **No entra en el primer de notificaciones.** `NotificationPrimerSheet.acceptNotifications()`
   es donde se enciende `budgetAlertsEnabled` —el hermano del que se copió el default— junto con
   todos los `NotificationItem`. El toggle nuevo no está ahí: **se heredó el default de su
   hermano sin heredar su encendido**, y ese es el desequilibrio real.
3. **Hay un segundo interruptor que la tarjeta no menciona.** El servicio exige además el
   `NotificationItem` de tipo `.groups` activo, que también nace apagado. Quien encienda
   «Recordatorios de deudas» con los avisos de Grupos apagados **no recibe nada, en silencio**.
   La subordinación es correcta (quien apaga Grupos espera no recibir avisos de grupo) pero es
   invisible: no hay `.disabled()`, ni nota al pie, ni nada en el hint.

Y el banner in-app dentro del grupo —que el owner marcó como acompañamiento opcional y el ticket
padre descartó para la V1— era la única pieza que lo habría hecho descubrible desde dentro del
producto. No construirlo fue correcto; lo que queda es que **no hay ninguna otra vía**.

## Lo que hace falta decidir (Jürgen)

Tres preguntas, y solo la primera es de producto de verdad:

1. **¿El nudge entra en el primer de notificaciones?** Es decir, ¿cuando alguien acepta recibir
   avisos, acepta también este? A favor: es donde ya está diciendo «sí, avísame», y es lo que
   hace inocuo el default OFF de su hermano. En contra: este habla de deudas con personas, no de
   presupuestos propios, y puede querer un consentimiento aparte.
2. **¿La tarjeta debe deshabilitarse cuando los avisos de Grupos están apagados?**
   (`.disabled(!groupsMasterActive)` + una línea explicándolo), o basta con añadir la
   dependencia al texto del hint. Lo segundo es más barato y toca 16 `.lproj`.
3. **¿Se construye el banner in-app** del ticket padre como complemento, o se deja fuera?

## Acceptance Criteria

- [ ] Existe al menos un camino por el que un usuario con grupos y deudas descubra el feature.
- [ ] Un toggle encendido que no puede entregar nada se lo dice al usuario, o no se puede encender.
- [ ] La decisión queda escrita en el ticket, no solo aplicada en el código.

## Notas

Sale de la review adversarial del 2026-09-07 (lente de producto), no de un fallo funcional: el
feature cumple sus AC y está pinneado. Es una decisión de producto que el ticket padre no
planteó porque el default se copió sin mirar de dónde venía su encendido.


---

## Para decidir — preparado el 2026-09-08

**La pregunta, en una línea:** ¿el recordatorio de deudas entra en el «sí, avísame» general, o pide
un permiso aparte?

### Lo que medí hoy

Las tres premisas del ticket son **exactas**:

1. `AppPreferences.swift:390` — `groupSettlementRemindersEnabled: Bool = false`, `synced: true`.
2. `NotificationPrimerSheet.swift:91-121` — enciende exactamente dos cosas: `isActive = true` para
   **todos** los `NotificationItem` (`:97-100`) y `budgetAlertsEnabled` (`:112-113`).
   `groupSettlementRemindersEnabled` **no aparece**.
3. El segundo interruptor existe: `GroupSettlementReminderService.swift:86` →
   `isGroupsNotificationActive` (`:172-183`), que devuelve **false si el item no existe**. Default del
   item: `NotificationItem.swift:473-474`, `isActive: false`.
4. Y no hay aviso ninguno: `NotificationsSettingsView.swift:244-281` tiene hint (`:262`) y toggle
   (`:270`), **sin `.disabled(...)` y sin mención a Grupos**.

**Un matiz que el ticket no tenía y que reduce el problema:** como el primer pone **todos** los
`NotificationItem` a `true`, quien pasa por el primer ya tiene el maestro de Grupos encendido. El
silencio de la pregunta 2 golpea a quien **no** pasó por el primer, o lo apagó después — no a todo el
mundo. Sigue siendo un estado mentiroso, pero es un borde, no el caso común.

### Las tres preguntas, con coste

**1 · ¿Entra en el primer?** — **1 fichero, 1 línea** (`NotificationPrimerSheet.swift:113`, la misma
llamada a `PreferenceSyncService` que ya enciende `budgetAlertsEnabled`).

**2 · ¿`.disabled` o nota en el hint?**
- **(2a) `.disabled` + explicación** — 2 ficheros (leer el item `.groups` en la vista) + 1 clave × 16
  `.lproj`.
- **(2b) solo una nota en el hint** — 1 fichero + 1 clave × 16 `.lproj`.
- Clave existente a reusar: `notifications.settlementReminders.hint` (`L10n.swift:6526-6527`) ⇒
  `…hintGroupsOff`.

**3 · ¿El banner in-app?** — feature nueva en las vistas de Grupos. Otro orden de magnitud.

### Mi recomendación: **sí a la 1, (2a) en la 2, no a la 3**

**A la 1, sí, y es la que resuelve el ticket.** El argumento en contra —«habla de deudas con
personas, merece consentimiento aparte»— describe bien el **contenido**, pero el primer no es un
permiso de contenido: es el momento en que alguien dice «avísame de lo que pase en la app». Su
hermano `budgetAlertsEnabled` nació con el mismo default `false` **y se enciende ahí**; ese
encendido es justo lo que hace inocuo el default. Copiamos el default sin copiar el encendido, y el
resultado es un feature construido que no recibe nadie. Y el consentimiento sigue siendo real: el
toggle queda visible y apagable en Ajustes.

**A la 2, (2a), porque es literalmente tu segundo criterio de aceptación.** «Un toggle encendido que
no puede entregar nada se lo dice al usuario, **o no se puede encender**.» Una nota al pie cumple la
letra pero deja el estado mentiroso en pie: el usuario lo enciende, ve el verde y no recibe nada. El
fichero extra compra que el estado imposible no exista.

**A la 3, no.** El ticket padre ya la descartó para la V1 con criterio, y con la 1 resuelta deja de
ser «la única vía»: pasa a ser una mejora de descubrimiento dentro del grupo, que es una conversación
distinta y más cara. Si la 1 entra y aun así nadie usa el feature, entonces sí.

### Si eliges esto, el AC es

- [ ] `NotificationPrimerSheet.acceptNotifications()` enciende también
      `groupSettlementRemindersEnabled`, por la misma vía que `budgetAlertsEnabled`.
- [ ] Quien ya pasó por el primer **no** se ve afectado retroactivamente (el primer no se re-ejecuta;
      confirmar que no hay migración que lo encienda a espaldas de nadie).
- [ ] La tarjeta de «Recordatorios de deudas» se deshabilita cuando el maestro de Grupos está
      apagado, con una línea que diga por qué.
- [ ] Clave nueva en las **16** `.lproj` del target app, con el prefijo
      `notifications.settlementReminders.`.
- [ ] La decisión queda escrita aquí, no solo aplicada en el código.

### Decisión de Jürgen

**Sí a la 1, (2a) en la 2, no a la 3.** Contestada el 2026-09-08 e implementada en el mismo PR.

1. **`groupSettlementRemindersEnabled` entra en el primer de notificaciones**, por la misma vía que
   `budgetAlertsEnabled` (`PreferenceSyncService`, no `UserDefaults` en crudo — la key es
   `synced: true` y esto es un punto de intención del usuario). Una línea.
2. **La tarjeta se deshabilita cuando el maestro de Grupos está apagado**, con una línea que dice por
   qué (`notifications.settlementReminders.hintGroupsOff`, en las 16 `.lproj`). El criterio de
   `isGroupsMasterActive` replica el gate del servicio, fail-cerrado incluido: si el servicio no va a
   avisar, la tarjeta no deja encender nada.
3. **El banner in-app no se construye.** Con la 1 resuelta deja de ser «la única vía»; si aun así
   nadie usa el feature, se reabre.

**Un matiz medido que reduce el problema descrito arriba:** el primer pone **todos** los
`NotificationItem` a `true`, así que quien pasa por él ya tenía el maestro de Grupos encendido. El
silencio de la pregunta 2 golpeaba a quien no pasó por el primer o lo apagó después — un borde, no el
caso común. Sigue mereciendo el arreglo: un toggle en verde que no entrega nada es peor que uno
apagado.

**Sin efecto retroactivo:** el primer no se re-ejecuta, así que a quien ya lo pasó no se le enciende
nada a sus espaldas.

## QA Visual · 2026-09-16 — PASS

Simulador iPhone 17 Pro (iOS 26.5), sobre `2.1` @ `bebd57a57`, `Yala Dev`, instalación limpia con seed `minimal`. Las dos decisiones del 2026-09-08, vistas:

**(2a) La tarjeta no se enciende si no puede avisar.** Notificaciones con los avisos de Grupos apagados
→ «Recordatorios de deudas» atenuado, sin interruptor tocable y con la línea **«Para recibirlos, activa
antes los avisos de Grupos»**. Encender Grupos → vuelve «Un aviso amable…». Apagarlo → vuelve la línea.

**(1) El primer la enciende.** Tres registros → «¿Activar notificaciones?» → Activar → Permitir → Grupos
ON, **Recordatorios de deudas ON** y Alertas de presupuesto ON.

Capturas: [atenuada](../../qa/evidencia-barrido-20260916/29-notif-recordatorio-deudas-atenuado-grupos-off.jpg) · [tras el primer](../../qa/evidencia-barrido-20260916/31-notif-tras-primer-recordatorio-deudas-encendido.jpg).
