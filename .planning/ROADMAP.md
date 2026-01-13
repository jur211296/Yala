# Roadmap V1.0

**Creado:** 2026-01-13
**Milestone:** V1.0

---

## Fase 1: Estabilidad Core

**Objetivo:** Eliminar bugs críticos que afectan flujos principales antes de construir encima.

**Incluye:**
- Bug tipo de cambio en transferencias (se resetea a 1.000 con teclado)
- Hover CashFlow en Panel/Trends con colores incorrectos

**Criterio de salida:**
- Tipo de cambio persiste correctamente en flujo completo de transferencia
- Colores de hover en CashFlow corresponden a ingreso/gasto

---

## Fase 2: Infraestructura de Periodos y Filtros

**Objetivo:** Establecer base sólida de filtrado que el resto de la app consumirá.

**Incluye:**
- Periodo Personalizado en PeriodSelector
- Filtro por nota: chips de búsqueda
- Sincronización de filtros entre Statistics y Panel
- Filtro de categorías aplica a gráficas

**Criterio de salida:**
- Periodo personalizado seleccionable y funcional
- Filtros sincronizados entre vistas
- Gráficas respetan filtro de categorías

---

## Fase 3: Gestión de Categorías

**Objetivo:** Permitir mantenimiento eficiente de categorías/subcategorías.

**Incluye:**
- Edición masiva de categorías/subcategorías
- Eliminación de categorías/subcategorías sin transacciones
- Transferencia de transacciones al eliminar categorías con datos

**Criterio de salida:**
- Usuario puede editar múltiples categorías en una operación
- Eliminación segura con opción de transferir transacciones

---

## Fase 4: Panel y Navegación

**Objetivo:** Mejorar navegabilidad y completar widgets del Panel.

**Incluye:**
- Chevron en widgets de PanelView para redirigir a detalle
- Widget de Presupuestos en PanelView
- Home configurable (botones del TabView desde personalización)

**Criterio de salida:**
- Widgets navegan a su vista de detalle
- Widget de presupuestos muestra estado actual
- Usuario puede personalizar tabs visibles

---

## Fase 5: Visualizaciones de Categorías

**Objetivo:** Enriquecer CategoriesTabView con comparativas y detalles.

**Incluye:**
- Pie de etiquetas en carrusel de pies
- Var% vs periodo anterior en barras (excepto "Todo el tiempo")
- Carrusel de naturaleza compacto con variación vs periodo anterior

**Criterio de salida:**
- Carrusel incluye pie de etiquetas
- Barras muestran variación porcentual cuando aplica
- Carrusel de naturaleza muestra comparativa temporal

---

## Fase 6: Pagos Planificados

**Objetivo:** Nuevo módulo para gestionar suscripciones y pagos futuros.

**Incluye:**
- Pagos planificados con SegmentedControl (suscripciones vs otros)
- Widget Medium: 3 pagos siguientes
- Widget Large: calendario por periodo

**Criterio de salida:**
- CRUD completo de pagos planificados
- Widgets muestran próximos pagos correctamente

---

## Fase 7: Registro Inteligente

**Objetivo:** Automatizar y simplificar entrada de transacciones.

**Incluye:**
- Nuevo registro por foto con IA
- Nuevo registro por audio con IA
- Bandeja de entrada para transacciones automatizadas
- Validación de repetidos en automatizados

**Criterio de salida:**
- Usuario puede crear transacción desde foto o audio
- Bandeja muestra pendientes de confirmar
- Sistema detecta posibles duplicados

---

## Fase 8: Plataforma y Polish

**Objetivo:** Integración con sistema iOS y refinamiento final.

**Incluye:**
- Widgets iOS (general)
- Atajos (Shortcuts)
- Share Sheet
- Notificaciones
- Inicio de sesión (autenticación)
- Textos explicativos en ajustes
- Vaciar datos: preguntar si cargar seed
- **FINAL:** Analizar solo gastos vs todo (ingresos + gastos)

**Criterio de salida:**
- Widgets disponibles en pantalla de inicio
- Atajos funcionales
- Share Sheet permite importar datos
- Notificaciones configurables
- App protegida con autenticación
- Ajustes documentados
- Opción gastos/todo implementada y coherente en toda la app

---

## Resumen

| Fase | Nombre | Dependencias |
|------|--------|--------------|
| 1 | Estabilidad Core | - |
| 2 | Periodos y Filtros | 1 |
| 3 | Gestión Categorías | 1 |
| 4 | Panel y Navegación | 2 |
| 5 | Visualizaciones Categorías | 2 |
| 6 | Pagos Planificados | 2, 4 |
| 7 | Registro Inteligente | 3 |
| 8 | Plataforma y Polish | Todas |

---

*Actualizar conforme se completen fases*
