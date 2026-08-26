---
id: scheduled-payments-notif-dedup
status: qa
created: 2026-07-22
updated: 2026-08-26
source: YalaWiki/Bugs/qa_pagos-planificados-notifs-incoherentes-y-dedup-sin-entrega.md
---


# Pagos planificados: una sola notificación a las 8am, bandeja tardía, y el resto del día jamás notifica

## Síntoma reportado (device, varios pagos el mismo día, notificación configurada 9am)

Abrió la app ~8am → saltó UNA notificación de UN pago. Bandeja vacía. Más tarde: bandeja con TODOS los pagos del día MENOS el notificado. Ninguna notificación del resto en todo el día.

## Hecho de diseño clave (contexto para todo lo demás)

**NO existen notificaciones de pagos planificados agendadas en iOS.** `scheduledPayments` es tipo dinámico (`NotificationItem.swift:128-136`) ⇒ `NotificationService.scheduleNotification` las cancela y no programa (`NotificationService.swift:114-128`); el BG task solo cubre reportes/widget (`BackgroundTaskManager.swift:188-238`). Todo se envía como banner inmediato **al abrir la app** (boot/foreground → `ensureNotificationsScheduled`, `AppBootstrapper.swift:2225-2256`), con la "hora 9am" actuando solo como COMPUERTA (`isWithinNotificationWindow`, `ScheduledPaymentNotificationService.swift:153-184`). Usuario que no abre la app = cero recordatorios. Este diseño oportunista es la fragilidad de fondo.

## Causas identificadas

**1. BUG CONFIRMADO EN CÓDIGO — dedup sin entrega:** en las 3 ramas del notificador el patrón es `await sendPaymentNotification(...)` seguido de `tracker.markNotified(...)` **INCONDICIONAL** (`ScheduledPaymentNotificationService.swift:79-80, 112-113, 140-141`). Pero `NotificationService.sendNotification` puede NO entregar y retornar `Void` en silencio: `guard authorized else { return }` (:223), guard de wipe armado (:226), y el `notificationCenter.add` con catch que traga el error (:246-255 — throttling iOS, límite 64 pendientes). ⇒ Un pago queda marcado `scheduledPaymentNotif_<UUID>_<YYYYMMDD>_<type>` para TODO el día sin banner entregado; `hasNotifiedForDate` suprime cualquier reintento posterior. **Explica "el resto nunca notificó".**

**2. CANDIDATA — gate horario falla-abierto:** `isWithinNotificationWindow` retorna `true` si el `NotificationItem` de scheduledPayments está inactivo, ausente o el fetch falla (`return true` en :169, :172, :181; el predicate exige `isActive` :159). Si eso pasó, a las 8am la ventana estaba abierta, el loop corrió, entregó una (app al background a mitad del loop `await` / throttle) y MARCÓ todas (bug 1). **Alternativa para la notif de las 8am:** fue el recordatorio de TARJETA (`checkAndNotifyCreditCardPayments`, :226-248) que NO tiene gate horario, es una por tarjeta y no crea draft — distinguible por deep link `accounts` (:244) vs `scheduledPayments` (:219).

**3. Bandeja tardía — gate de QUIESCENCIA, no horario:** `ScheduledPaymentDraftService.processDuePayments:24` difiere si `!isImportQuiescent` (cold launch de la mañana = import CloudKit en curso ⇒ bandeja vacía a las 8am; al reabrir con import asentado, materializa todos). Comportamiento correcto por sí solo, pero **las notificaciones no comparten ese gate** ⇒ dos compuertas independientes = estados incoherentes bandeja↔notificación (se puede notificar un pago que aún no está en bandeja).

**4. CANDIDATA — el notificado sin draft (anti-correlación):** notificar NO bloquea el draft (verificado: solo `markNotified` + `lastNotifiedDate`, `:80-81`; nada de eso lo lee `processDuePayments`). La divergencia es de FUENTES DE FECHA: el notificador usa `ScheduledPaymentDateCalculator` (ocurrencia del mes por regla, :64-69) y el draft usa solo `nextDueDate <= endOfToday` (`ScheduledPaymentDraftService.swift:33-37`). Un `nextDueDate` ya avanzado (aprobación/skip previo, o `advanceToNextDueDate` en el mismo arranque) ⇒ el calculador dice "due hoy" y notifica, el draft service lo salta. Alternativa: draft `pending` preexistente ⇒ `hasExistingDraft` (:84, :137) bloquea el nuevo.

Descartados: colisión de identifiers (`"notification-\(UUID())"` único por envío, `NotificationService.swift:241`), `cleanupOldEntries` (solo >30 días), tope (solo vencidos, max 5 — due-today sin tope).

## Fix conceptual (por capas)

1. **markNotified solo con entrega confirmada**: `sendNotification` debe reportar éxito (Bool/throws) y el tracker marcar solo entonces. Es el fix de mayor impacto.
2. **Gate horario fail-closed** (o al menos coherente): decidir qué significa item inactivo/ausente — hoy abre la ventana a cualquier hora.
3. **Unificar las fuentes de fecha** notificador↔draft (o notificar A PARTIR del draft materializado, lo que además alinea los gates).
4. **(Decisión de producto)** considerar migrar a notificaciones programadas de verdad (contenido estático "Tienes N pagos hoy" con `UNCalendarNotificationTrigger`) para que el recordatorio no dependa de abrir la app.

## Verificación en device pendiente (owner)

- Console: logs `NotifService` (`NotificationService.swift:221, 249, 253` — authStatus / add OK/error).
- Deep link de la notif de las 8am: `accounts` (tarjeta) vs `scheduledPayments` (desambigua causa 2).
- Estado del `NotificationItem` scheduledPayments (`isActive`, hora real).
- Del pago notificado: `nextDueDate`, `lastNotifiedDate`, `skippedDatesRaw`, ¿draft pending previo?
- Keys `scheduledPaymentNotif_*` de ese día: marcas sin banner = evidencia directa del bug 1.

## Nota de relación

El fix reciente `9f16ce58` (2026-07-21) tocó estas keys pero SOLO para el wipe de sign-out (barrido por prefijo + key de tarjeta por shortcutID) — no toca ninguna de estas causas. Coordinar para no pisarse si van en paralelo.

## Implementación

### 2026-07-22 — commits `3d9ddf6a` + `797de21f` (branch 2.0.5)

**Resumen (lenguaje de usuario):** los recordatorios de pagos ya no se "queman" sin llegar (si iOS no pudo entregar el aviso, se reintenta al volver a abrir la app); el toggle "Pagos planificados" de Ajustes ahora manda de verdad (OFF = silencio, ON = avisos a la hora configurada — y nace ON); y lo más grande: llega una notificación REAL a la hora configurada con "Tienes N pagos planificados para hoy 📅" **sin necesidad de abrir la app** (canal agendado, decisión owner D1 — híbrido ratificado como el más robusto: vencidos/próximos siguen siendo oportunistas porque agendarlos garantizaría falsos positivos).

**Las 4 causas del ticket — las 4 confirmadas y cerradas:**
1. `markNotified` incondicional → `sendNotification` ahora retorna `Bool` (`@discardableResult`, source-compatible con TODOS los call-sites incl. grupos) y pagos+tarjeta marcan el dedup SOLO con `add` exitoso.
2. Gate horario falla-abierto → `ScheduledPaymentNotificationGateLogic` (pura): inactive/ausente = silencio, fetch-error = diferir sin marcar. Hallazgo extra: el default de fábrica era `isActive: false` y AUN ASÍ notificaba a cualquier hora ⇒ flip one-shot activa el item a usuarios existentes (sentinel local + espejo iKV — reinstalar no re-enciende un OFF deliberado; con 0 items el one-shot queda abierto), seed default y onboarding pasan a ON. La tarjeta comparte la ventana horaria con item activo (la notif "de las 8am") pero conserva su opt-in per-account con toggle OFF.
3. Compuertas independientes → `checkAllPaymentNotifications` gatea por quiescencia (misma compuerta que `processDuePayments`) + re-check adyacente al save.
4. Fuentes de fecha divergentes → dueToday re-sourceada desde los `InboxDraft` pending materializados (se notifica EXACTAMENTE lo que está en la bandeja); pagado por-ocurrencia (no por-mes) en dueToday.

**Canal agendado (commit 2):** `ScheduledPaymentSummaryPlanner` (puro, ventana 14 días multi-mes, ocurrencias consumidas fuera por `nextDueDate`) + `spDailySummary_<yyyyMMdd>` one-shot CON year + verificación post-add contra pending (límite 64 silencioso de iOS) + marcas con instante de agendado (la oportunista suprime solo pagos que existían al agendarse) + replan single-flight con 9 hooks (boot/foreground, editor, delete, skip/unskip, aprobaciones, asociar/desvincular TX, toggle/hora, cambio de idioma). `rescheduleAllNotifications` ya NO barre las summaries. l10n: key plural en 12 `.stringsdict` (traducción nativa por workflow, auditor 0 defectos) + flat count-neutral en las 4 variantes.

**Método:** investigación → 2 AskUserQuestion (D1 híbrido ratificado / D2 toggle honesto / D3 alcance) → Plan Mode + /review-plan (8 problemas folded) → impl → review adversarial en workflow (6 lentes + refutación por hallazgo: 28 crudos → 27 confirmados, todos aplicados) → /refine (3 agentes, 6 mejoras) → gates.

**Gates:** builds Yala + Yala Dev sin warnings nuevos · 145/145 en 11 suites parallel OFF · 6 mutantes verificados (falla-abierto, markNotified incondicional, sentinel pre-quiescencia, skipped-filter, cleanup parse, reconcile-hoy) · LocalizationParity · validate-coverage OK · QA visual sim (toggle ON de fábrica en Ajustes).

**Residuales documentados:** multi-device deja el conteo del summary stale hasta el próximo foreground; summary agendada ≠ entrega garantizada; overdue/upcoming conservan el isPaid mensual histórico; reportes/presupuestos con la misma clase de marca-sin-entrega → chip aparte.

## Guion device-QA (owner)

Prerequisitos: build con el fix instalada por cable (Yala Dev), permisos de notificaciones CONCEDIDOS, ≥2 pagos planificados activos con vencimiento HOY y 1 mañana, item "Pagos planificados" en Ajustes → Notificaciones ACTIVO con hora ~10 min en el futuro.

## Fase 1 — Flip one-shot (primera apertura post-update)
1. Abrir la app. Ajustes → Notificaciones → "Pagos planificados" debe aparecer **ON** sin haberlo tocado (si estaba OFF de fábrica).
2. Console.app (stream ANTES de abrir): buscar `flipMasterToggle` en SaveBreadcrumb si hubo restore en curso.

## Fase 2 — Resumen agendado SIN abrir la app (la prueba reina)
1. Con la hora configurada a T+10 min, cerrar la app (kill) y bloquear el device.
2. A la hora T: debe llegar UNA notificación "Pagos planificados / Tienes N pagos planificados para hoy 📅" con N correcto. Tap → abre la pantalla de pagos planificados.
3. Verificar que al abrir la app DESPUÉS no llega una segunda tanda dueToday de los mismos pagos (supresión por summary).

## Fase 3 — Dedup solo con entrega (causa 1 del ticket)
1. Revocar permisos de notifs en Ajustes de iOS con la app cerrada.
2. Abrir la app pasada la hora configurada → no llega nada (correcto).
3. Re-conceder permisos, reabrir la app → los recordatorios del día SÍ llegan (antes: quedaban quemados para todo el día).

## Fase 4 — Gate horario + tarjeta
1. Con hora configurada 9am, abrir la app a las 8am → NO debe llegar ninguna notif de pagos NI de tarjeta (la tarjeta ahora respeta la ventana con item activo).
2. Reabrir después de las 9am → llegan.
3. Toggle maestro OFF → ninguna notif de pagos en todo el día (la tarjeta SÍ conserva su recordatorio per-account).

## Fase 5 — Desambiguación pendiente del ticket original
- Si se reproduce la notif temprana: mirar el deep link (tap): `accounts` = tarjeta (explicaba la de las 8am), `scheduledPayments` = pagos.

## Fase 6 — Throttle iOS (opcional)
- Con >5 pagos vencidos acumulados: verificar que los overdue llegan (cap 5 por sesión) y que ninguno queda deduplicado sin banner (Console: `NotifService[#16-debug]` add OK/error).

## QA Visual

### 2026-08-14 — simulador · **CHECK A verde; el resto NO EJECUTABLE con las herramientas de automatización**

**Setup:** Yala Dev · Debug-Dev · iPhone 17 Pro · `-uitest -uitest-reset -uitest-skip-onboarding -uitest-seed minimal`
· 13:45 hora local (**precondición 1 cumplida**: después de las 09:00) · **app DESINSTALADA y reinstalada
antes de empezar** (precondición 2), lo que se confirmó porque el alert del sistema «Yala Dev quiere
enviarte notificaciones» **sí apareció** — si no hubiera aparecido, todo el CHECK B sería mudo por la razón
equivocada.

**CHECK A — PASS, y con control.** En Perfil → Notificaciones, «Pagos planificados» aparece **encendido
(valor 1) sin haberlo tocado**, y es **el único**: los otros cinco (Cierre del día, Hora de comer, Resumen
del día, Resumen semanal, Resumen mensual) están todos en 0. Que los demás estén apagados es lo que
convierte esto en una aserción: no es que «todo venga encendido».
![[qa-notifs-check-a-toggle-on-de-fabrica-20260814-135250.png]]

**Se ejecutó además, sin incidencias:** apagar el interruptor, volver a encenderlo (aparece el alert del
sistema → «Permitir») y dejarlo apagado. Ese es el estado bajo prueba del CHECK B: **permiso concedido +
interruptor maestro apagado**.

### 🔴 Dos correcciones al guion, medidas

**1. «No tocar la fecha» es un error del guion: el pago que se crea así NO vence hoy.** El editor trae
`paymentDate` = hoy (`ScheduledPaymentEditorView.swift:66`) — hasta ahí el guion acierta — **pero también
`dayOfMonth = 1` (`:67`) y la recurrencia por defecto es mensual**, así que la pantalla lista literalmente:

> Fecha de inicio: **14 ago. 2026** · Día del mes: **1** · Próximas fechas: **Martes, 1 de setiembre de
> 2026** (#1) · **Jueves, 1 de octubre de 2026** (#2)

⇒ el pago «QA Hoy» creado según el guion vencería el **1 de septiembre**. El CHECK B (no llega nada con el
interruptor apagado) saldría **verde por la razón equivocada**, y el CHECK C (sí llega al encenderlo)
saldría **rojo sin que haya bug**. Es una séptima trampa de falso verde que el guion no listaba.
![[qa-notifs-proximas-fechas-1-set-20260814-135250.png]]

**2. Y la corrección no se puede aplicar por automatización.** Para que venza hoy hay que elegir «Una sola
vez» en el segmentado de Recurrencia, o poner «Día del mes» = 14. **Ninguno de los dos controles aparece en
el árbol de accesibilidad como elemento tapeable** (`snapshot_ui` solo enumera tappables, texto y
scroll-views; el segmentado y el `Picker` salen como TEXTO), y las herramientas de XcodeBuildMCP solo
permiten tapear por `elementRef`, no por coordenadas. Se verificó el árbol tras varios refrescos.

**Estado: los CHECK B, B2 y C quedan SIN EJECUTAR.** No es un FAIL —no se observó ningún comportamiento
incorrecto— sino un escenario bloqueado.

**Qué desbloquearía esto (cualquiera de los tres):**

- un `accessibilityIdentifier` en el segmentado «Una sola vez / Repetición» y/o en el picker «Día del mes»
  del editor de pagos planificados (lo más barato, y de paso hace el escenario automatizable como XCUITest);
- un seam de seed que cree un pago planificado **que venza hoy**;
- ejecutarlo a mano en el simulador o en device (el owner), tocando la recurrencia con el dedo.

**Nota adicional ya conocida y confirmada:** aunque se ejecutara entero, este guion **no** cubre la causa 1
del ticket (`markNotified` solo con `add` OK) —sus caminos reales (throttle de iOS, límite de 64 pendientes,
wipe armado) no se reproducen en simulador— ni el titular «llega sin abrir la app» del canal agendado.

### 2026-08-14 (tarde) — se marcaron los controles, y la medición corrige lo que yo mismo escribí arriba

Se aplicó el desbloqueo propuesto (`54a65b19`): `scheduled_recurrence_picker` en el segmentado
«Una sola vez / Repetición» y `scheduled_day_of_month_picker` en el de «Día del mes». **No bastó, y
la razón importa más que el intento:**

- **MEDIDO:** con el segmentado **visible en pantalla** y el identificador puesto, `snapshot_ui` (el
  árbol rs/1 de XcodeBuildMCP) **sigue sin enumerarlo**. Los `Picker` segmentado y `.menu` no salen
  como elementos tapeables, y esa herramienta solo tapea por `elementRef` ⇒ **el QA visual de este
  ticket sigue bloqueado para la automatización por referencia de elemento.**
- **MEDIDO también:** los identificadores **sí** funcionan desde **XCUITest**, que llega por otra API
  (`app.segmentedControls["scheduled_recurrence_picker"]`). Lo prueba
  `YalaUITests/Flows/ScheduledPaymentRecurrenceA11yUITests` (`a7cf78f8`), verde en 26,7 s, que además
  afirma el EFECTO del tap (al elegir «Una sola vez» el bloque mensual se desmonta) y no solo su
  existencia. **Mutación verificada a exit 65** quitando el id del segmentado.

⇒ **Corrección de la propuesta que hice esta mañana:** «un `accessibilityIdentifier` desbloquea esto»
era verdad a medias. Desbloquea la vía XCUITest; no desbloquea la mía.

**Se comprobó además la otra salida y tampoco sirve:** con el seed `minimal` **ningún pago planificado
vence hoy** — la Bandeja solo trae los dos borradores de gasto («Taxi aeropuerto», «Almuerzo equipo»),
así que no hay forma de montar el escenario sin tocar la recurrencia.

**Las dos vías que quedan, en orden de coste:**

1. **Escribir el escenario completo como XCUITest** (crear el pago «Una sola vez» con fecha de hoy,
   apagar el interruptor, comprobar silencio, encenderlo y comprobar la entrega). Los identificadores
   ya están puestos y pinneados, así que el camino está abierto. Ojo con lo que el guion ya advierte:
   la entrega real de notificaciones locales dentro de XCUITest es su propio problema.
2. **A mano en el simulador o en device** (owner), tocando la recurrencia con el dedo.

**Y una lección de herramienta que vale para futuros QA:** cuando un control se ve en pantalla pero no
aparece en el árbol de accesibilidad, ponerle un identificador **no** garantiza que aparezca — depende
de la API con la que lo mires. Antes de pedir un cambio de código para desbloquear un QA, conviene
verificar que ese cambio desbloquea **la herramienta que vas a usar**.

migrated from YalaWiki Bugs/qa_pagos-planificados-notifs-incoherentes-y-dedup-sin-entrega.md @ 1934e8ad
