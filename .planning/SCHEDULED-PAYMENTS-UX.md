# Mejoras UX Pagos Planificados (Pre-Release)

**Prioridad:** Pre-release V1.0
**Estado:** Documentado — pendiente planificación
**Fecha:** 2026-02-18

## Contexto

La vista Planificación > Pagos Planificados necesita mejoras significativas de UX antes del lanzamiento. Actualmente muestra un mes estático con navegación limitada, el calendario tiene problemas de legibilidad, y falta funcionalidad clave para asociar pagos a transacciones existentes.

## Archivos Principales

| Archivo | Propósito |
|---------|-----------|
| `App/Views/Planning/ScheduledPaymentsView.swift` | Contenedor principal con tabs |
| `App/Views/Planning/ScheduledPaymentsListView.swift` | Vista lista/calendario |
| `App/Views/Planning/ScheduledPaymentRowView.swift` | Card de pago individual |
| `App/Views/Planning/ScheduledPaymentDetailView.swift` | Detalle con historial |
| `App/ViewModels/ScheduledPaymentsViewModel.swift` | Lógica de negocio |
| `Models/ScheduledPayment.swift` | Modelo (`createdAt`, `nextDueDate`, `lastPaidDate`) |

## Mejoras Requeridas

### M1: Selector de Mes (como Presupuestos)

**Problema:** La vista muestra un mes estático. El usuario no puede navegar entre meses fácilmente.

**Solución:** Implementar selector de mes idéntico al de Planificación > Presupuestos, permitiendo elegir qué mes visualizar.

**Reglas:**
- Cada mes muestra **solo** los pagos de ese mes
- NO mostrar pagos que se paguen en meses futuros
- NO mostrar pagos que se pagaron en meses anteriores
- El summary card debe reflejar solo los totales del mes seleccionado

### M2: Estado "Pagado" por Mes

**Problema:** El estado pagado necesita contextualizarse por mes.

**Reglas:**
- Si una suscripción se pagó (desde la transacción de bandeja de entrada creada automáticamente), aparece como **"Pagada"** en el mes correspondiente
- En el siguiente mes, esa misma suscripción aparece como **"En X días"** normal
- El estado pagado se determina por `lastPaidDate` dentro del rango del mes visualizado

### M3: Asociar Transacción Manual a Pago Planificado

**Problema:** El usuario crea manualmente la transacción correspondiente a una suscripción y rechaza la de bandeja de entrada para no duplicar. No tiene forma de marcar el pago como pagado.

**Solución:** Al hacer clic en un pago planificado en la lista, permitir seleccionar una transacción existente y asociarla.

**Flujo propuesto:**
1. Usuario toca pago planificado en la lista del mes
2. Se abre opción "Asociar transacción"
3. Se muestra lista de transacciones del mes filtradas (mismo monto aprox, misma subcategoría, misma cuenta)
4. Usuario selecciona la transacción
5. El pago se marca como "Pagado" para ese mes

**Validaciones necesarias:**
- La transacción debe ser del mismo mes
- Verificar monto (match exacto o rango razonable)
- Verificar que la transacción no esté ya asociada a otro pago planificado
- Confirmar antes de asociar

### M4: No Propagar Pagos hacia Atrás

**Problema:** Los pagos planificados no deben aparecer en meses anteriores a su creación.

**Reglas:**
- Un pago planificado aparece desde el mes de su `createdAt` en adelante
- NO se propaga hacia meses anteriores a la fecha de creación
- Si el usuario va a meses pasados, puede asociar pagos planificados a transacciones manualmente → en ese caso SÍ aparecerían como pagados
- Investigar: ¿Es suficiente usar `createdAt` como límite inferior? El modelo ya tiene `createdAt: Date` con `default: Date()`

**Nota técnica:** `getPaymentDatesInMonth(payment:month:)` en ScheduledPaymentsViewModel (líneas 386-472) calcula fechas hacia atrás indefinidamente. Debe incorporar `createdAt` como límite inferior.

### M5: Indicador "Pagado" en Vista Calendario

**Problema:** En la vista calendario, las transacciones listadas debajo no distinguen entre pagadas y pendientes.

**Solución:**
- Marcar como **"Pagado"** las transacciones ya pagadas en la lista debajo del calendario (igual que en vista lista)
- Facilitar identificación visual de lo que falta por pagar

### M6: Resumen Pagado/Pendiente en Parte Superior

**Propuesta:** En alguna parte superior de la vista, permitir filtrar o ver totales separados:
- **Total pagado** del mes
- **Total pendiente** del mes
- Toggle o tabs para filtrar: "Pagados" / "Pendientes" / "Todos"

Esto permite al usuario ver rápidamente cuánto ya pagó y cuánto falta.

### M7: Rediseño UX del Calendario

**Problema:** El espacio horizontal del calendario es muy reducido. Con 7 columnas, los nombres de suscripciones son ilegibles (se cortan). Actualmente muestra hasta 2 "pills" por día con "+N" si hay más.

**Opciones a evaluar:**
1. **Solo indicadores de color** — Reemplazar pills de texto por dots de color (como el calendario de iOS). Al tocar un día, se expande lista debajo.
2. **Calendario compacto + lista expandida** — Calendario solo muestra dots/badges numéricos. La lista debajo del calendario muestra los pagos del día/semana seleccionada con toda la información.
3. **Vista semanal como alternativa** — Permitir toggle mes/semana. Vista semanal tiene más espacio horizontal para nombres.
4. **Heatmap estilo GitHub** — Intensidad de color según cantidad/monto de pagos en el día.

**Recomendación:** Evaluar en planificación cuál se adapta mejor. La opción 2 (dots + lista expandida) parece la más pragmática y consistente con patrones iOS.

## Dependencias

- Modelo `ScheduledPayment` ya tiene `createdAt` — verificar que se persiste correctamente en todos los flujos de creación
- `isPaidForCurrentCycle` necesita generalizarse a `isPaid(for month: Date)` para soportar navegación por mes
- La asociación de transacciones (M3) requiere nuevo campo o relación: `ScheduledPayment` ↔ `TransactionItem` (o almacenar `associatedTransactionId` por período)

## Escenarios QA (borrador)

1. Navegar mes a mes y verificar que solo se ven pagos de ese mes
2. Pago creado en febrero no aparece en enero
3. Suscripción pagada desde inbox aparece como "Pagada" en su mes
4. Suscripción pagada en febrero aparece como "En X días" en marzo
5. Asociar transacción manual a pago planificado → se marca como pagado
6. Intentar asociar transacción ya asociada → error
7. Calendario muestra indicador pagado/pendiente claro
8. Totales superiores reflejan pagado vs pendiente correctamente
9. Meses anteriores a creación del pago no muestran ese pago
