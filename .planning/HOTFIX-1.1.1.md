# Hotfix 1.1.1

Correcciones críticas sobre la versión publicada 1.1.
Rama: `1.1.1` (basada en `1.0` / tag `1.1`)

## Tickets

### 🔴 Críticos (afectan usuarios en producción)

#### H1 — Free trial no salta post-onboarding ✅
- **Problema:** 2-3 usuarios nuevos no recibieron el free trial al terminar el onboarding. Validado en producción.
- **Fix:** Esperar bootstrap (max 10s) + siempre mostrar ProTrialOfferSheet para no-Pro (710d678)

#### H2 — Race condition de notificaciones vs splash ✅
- **Problema:** Al tocar una notificación, la sheet se abre bajo el splash y desaparece al cerrar splash.
- **Fix:** SessionState.isSplashDismissed + deferredDeepLink, resuelto en dismissSplash() (710d678)

---

### 🟡 Importantes (UX / costos)

#### H3 — Banner "What's New" 1.1 faltante ✅
- **Problema:** Se olvidó añadir el banner de novedades para la versión 1.1.
- **Fix:** WhatsNewConfig case "1.1" + 3 features (resumen, budget detail, exclude mode) en 6 idiomas (710d678)

#### H4 — Tour se muestra a usuarios que ya tienen datos configurados ✅ (descartado)
- **Problema:** El tour/onboarding se muestra a usuarios que ya tienen cuentas, categorías u otras cosas configuradas.
- **Estado:** Descartado del hotfix — no afecta usuarios en producción.

#### H5 — Insights no diferencian gastos recurrentes vs suscripciones ✅
- **Problema:** El resumen/insights trata igual los gastos recurrentes normales y las suscripciones.
- **Fix:** Commitments split por PaymentCategory, envía subscriptions + recurring_payments al LLM (710d678)

---

### 🟠 Insights en PanelView (optimización + costos)

#### H6 — Insights en PanelView: apagados por defecto ✅
- **Problema:** Los insights en PanelView están activos por defecto, generando llamadas API desde el primer uso.
- **Fix:** Default = off (`panelShowAIInsight = false` en PanelView + WidgetPreferencesView). Solo afecta nuevas instalaciones (3c6e794)

#### H7 — Insights en PanelView: debounce de 10-15 segundos ✅
- **Problema:** Cada cambio de filtro puede disparar una nueva llamada API.
- **Fix:** `Task.sleep(for: .seconds(10))` después de guards en `loadContextualInsight()`. SwiftUI `.task(id:)` cancela el sleep anterior (3c6e794)

#### H8 — Validar eficiencia de insights en PanelView ✅ (resuelto por H6+H7)
- **Problema:** Posible impacto en performance del dashboard por los insights.
- **Estado:** El cálculo local es <50ms, el .task es async. Con H6 (off por defecto) + H7 (debounce), no hay impacto real.

#### H9 — Revisar tasas de actualización de insights ✅ (resuelto por H6+H7)
- **Problema:** Riesgo de consumir demasiadas llamadas API (GPT-4.1 Mini).
- **Estado:** Rate limit 5s + cache 30min ya existen. Costo ~$0.001/llamada. Con H6+H7 las llamadas se reducen drásticamente.

---

## Prioridad de ejecución sugerida

1. **H1** — Free trial (crítico, usuarios afectados ahora)
2. **H2** — Race condition notificaciones (experiencia rota)
3. **H6** — Insights off por defecto (reduce costos inmediatamente)
4. **H7** — Debounce insights (reduce costos)
5. **H9** — Auditar tasas de llamadas (entender el problema)
6. **H8** — Profiling performance insights
7. **H5** — Diferenciar recurrentes vs suscripciones
8. **H3** — Banner What's New
9. **H4** — Tour skip para usuarios con datos

#### H10 — Pagos planificados fantasma reaparecen en Inbox después de aprobar ✅
- **Problema:** Al aprobar drafts de pagos planificados, `processDuePayments()` los recreaba como duplicados al correr de nuevo (bootstrap/handleBecameActive). 3 gaps en deduplicación.
- **Fix:** 5 cambios en `ScheduledPaymentDraftService`: save all mutations, lastPaidDate guard, pending+approved check, remove redundant save, UUID predicate fetch (29611e2)

---

### 🔵 Follow-up técnico (no bloquea hotfix)

#### F1 — `TransactionAssociationSheet` bypassa `handleDraftApproved()`
- **Problema:** No setea `lastPaidDate` ni avanza `nextDueDate` al vincular una transacción existente a un pago planificado.
- **Descubierto en:** análisis del fix H10 (drafts fantasma).

#### F2 — Extraer `Calendar.dayInterval(for:)` en `Calendar+Extensions.swift`
- **Problema:** El patrón `startOfDay` + `date(byAdding: .day, value: 1)` se repite en 6+ sitios: `ScheduledPaymentDraftService`, `InboxDraftEditSheet`, `ExportFiltersStepView`, `PeriodSelectorComponents`.
- **Inconsistencia:** `processDuePayments` usa `bySettingHour: 23:59:59` (pierde 23:59:59.5+), el resto usa `byAdding: .day` (correcto).

#### F3 — Centralizar lógica de recurrencia en `ScheduledPaymentDateCalculator`
- **Problema:** `advanceToNextDueDate()` reimplementa la misma lógica de avance (daily/weekly/monthly con clamping/yearly) que `ScheduledPaymentDateCalculator`. Si la lógica cambia, hay que actualizar ambos.
- **Sugerencia:** Extraer `nextOccurrence(from:recurrence:interval:dayOfMonth:)` en el Calculator.

#### F4 — Optimizar doble fetch en `recreateDraftIfNeeded`
- **Problema:** `hasExistingDraft(for:on:)` hace un fetch por día, luego el bloque de líneas 208-227 hace otro fetch con el mismo predicate base para verificar el mes. Se podría unificar en un solo fetch.
- **Impacto:** Bajo (unskip es una acción rara).

---

## Notas
- Cada fix debe ser un commit atómico verificable
- Todos los fixes deben pasar `/verify-ios` + `/test-smart` antes de commit
- Al completar, merge `1.1.1` → `1.0` y tag `1.1.1`
