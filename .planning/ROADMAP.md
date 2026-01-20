# Roadmap: Neto V1.0

## Overview

App iOS de finanzas personales. V1.0 estabiliza el core, añade automatización, mejora visualizaciones, introduce pagos planificados, registro inteligente con IA, e integración con plataforma iOS.

## Domain Expertise

- ./.claude/skills/expertise/iphone-apps/SKILL.md (si existe)

## Phases

- [x] **Fase 1: Estabilidad Core** - Eliminar bugs críticos antes de construir ✅
- [x] **Fase 2: Periodos y Filtros** - Infraestructura de filtrado para toda la app ✅
- [x] **Fase 3: Gestión Categorías** - Mantenimiento eficiente de categorías ✅
- [x] **Fase 4: Panel y Navegación** - Navegabilidad y widgets del Panel ✅
- [x] **Fase 5: Visualizaciones Categorías** - Comparativas y detalles en gráficas ✅
- [x] **Fase 5.1: Correcciones y Mejoras** - Bugs, UX y tech debt acumulado ✅
- [x] **Fase 6: Pagos Planificados** - Nuevo módulo de suscripciones y pagos futuros ✅
- [ ] **Fase 7: Registro Inteligente** - Entrada de transacciones con IA ← Siguiente
- [ ] **Fase 8: Plataforma y Polish** - Integración iOS y refinamiento final

## Phase Details

### Fase 1: Estabilidad Core
**Goal**: Eliminar bugs críticos que afectan flujos principales
**Depends on**: Nothing (first phase)
**Research**: Unlikely (debugging existing code)
**Plans**: TBD

Incluye:
- Bug tipo de cambio en transferencias (se resetea a 1.000 con teclado)
- Hover CashFlow en Panel/Trends con colores incorrectos

DoD:
- Tipo de cambio persiste correctamente en flujo completo
- Colores hover corresponden a ingreso/gasto

### Fase 2: Periodos y Filtros
**Goal**: Base sólida de filtrado que el resto de la app consumirá
**Depends on**: Fase 1
**Research**: Unlikely (patterns existentes en codebase)
**Plans**: TBD

Incluye:
- Periodo Personalizado en PeriodSelector
- Filtro por nota: chips de búsqueda
- Sincronización de filtros Statistics/Panel
- Filtro categorías aplica a gráficas

DoD:
- Periodo personalizado funcional
- Filtros sincronizados entre vistas
- Gráficas respetan filtro de categorías

### Fase 3: Gestión Categorías
**Goal**: Permitir mantenimiento eficiente de categorías/subcategorías
**Depends on**: Fase 1
**Research**: Unlikely (SwiftData operations)
**Plans**: TBD

Incluye:
- Edición masiva de categorías/subcategorías
- Eliminación sin transacciones
- Transferencia de transacciones al eliminar

DoD:
- Edición múltiple en una operación
- Eliminación segura con transferencia

### Fase 4: Panel y Navegación
**Goal**: Mejorar navegabilidad y completar widgets del Panel
**Depends on**: Fase 2
**Research**: Unlikely (UI patterns existentes)
**Plans**: TBD

Incluye:
- ✅ Chevron en widgets para redirigir a detalle
- ✅ Widget de Presupuestos en PanelView
- ✅ TabView configurable (desde Personalización en Profile)

DoD:
- ✅ Widgets navegan a detalle
- ✅ Widget presupuestos funcional
- ✅ TabView personalizable: usuario elige qué tabs mostrar (min 1 + Más, max 3 + Más)

### Fase 5: Visualizaciones Categorías
**Goal**: Enriquecer CategoriesTabView con comparativas
**Depends on**: Fase 2
**Research**: Unlikely (Charts framework ya usado)
**Plans**: TBD

Incluye:
- Pie de etiquetas en carrusel
- Var% vs periodo anterior en barras
- Carrusel naturaleza compacto con variación

DoD:
- Carrusel incluye pie de etiquetas
- Barras muestran variación porcentual
- Carrusel naturaleza con comparativa

### Fase 5.1: Correcciones y Mejoras
**Goal**: Resolver bugs, mejorar UX y limpiar tech debt antes de nuevas features
**Depends on**: Fase 5
**Research**: Likely (relaciones SwiftData para tags en FavoritePayment)
**Plans**: TBD

Incluye:

**Bugs UI:**
- Etiqueta hover en gráficas se corta en borde superior (TrendChartView)
- Teclado debe cerrarse al tocar fuera en todos los formularios

**Mejoras UX:**
- Filtro Ingresos/Gastos en Statistics filter section (DetailContainerView)
- Importación multimoneda con asignación de cuenta por divisa

**Cambios estructurales:**
- Pagos favoritos con múltiples etiquetas (cambio de relación 1:1 → N:N en FavoritePayment ↔ Tag)

**Tech Debt:**
- Optimizar cálculos en vistas de gráficas (TrendsTabView, CategoriesTabView, PanelView)

DoD:
- Hover labels visibles en todo el rango de la gráfica
- Teclado se cierra consistentemente en formularios
- Filtro ingreso/gasto funcional en Statistics
- Importador soporta múltiples monedas
- FavoritePayment soporta múltiples tags
- Cálculos de variación optimizados y reutilizables

### Fase 6: Pagos Planificados
**Goal**: Nuevo módulo para suscripciones y pagos futuros
**Depends on**: Fase 2, Fase 4, Fase 5.1
**Research**: Likely (nuevo modelo SwiftData, diseño de recurrencia)
**Research topics**: Patrón de recurrencia, modelo ScheduledPayment, integración con widgets
**Plans**: TBD

Incluye:
- Pagos planificados con SegmentedControl (suscripciones vs otros)
- Widget Medium: 3 pagos siguientes
- Widget Large: calendario por periodo

DoD:
- CRUD completo de pagos planificados
- Widgets muestran próximos pagos

### Fase 7: Registro Inteligente
**Goal**: Automatizar entrada de transacciones con IA
**Depends on**: Fase 3
**Research**: Likely (Vision API, Speech Recognition, LLM integration)
**Research topics**: iOS Vision framework, Speech framework, on-device vs cloud AI, duplicate detection
**Plans**: TBD

Incluye:
- Registro por foto con IA
- Registro por audio con IA
- Bandeja de entrada para automatizados
- Validación de repetidos

DoD:
- Transacción desde foto/audio funcional
- Bandeja muestra pendientes
- Detección de duplicados

### Fase 8: Plataforma y Polish
**Goal**: Integración con sistema iOS y refinamiento final
**Depends on**: Todas las fases anteriores
**Research**: Likely (WidgetKit, App Intents, Notifications)
**Research topics**: WidgetKit timeline, App Intents/Shortcuts, UNNotification scheduling, Local Authentication
**Plans**: TBD

Incluye:
- Widgets iOS (general)
- Atajos (Shortcuts)
- Share Sheet
- Notificaciones
- Inicio de sesión (autenticación)
- Textos explicativos en ajustes
- Vaciar datos: preguntar si cargar seed
- **FINAL:** Analizar solo gastos vs todo

DoD:
- Widgets en pantalla de inicio
- Atajos funcionales
- Share Sheet importa datos
- Notificaciones configurables
- Autenticación activa
- Ajustes documentados
- Opción gastos/todo coherente en toda la app

## Progress

| Fase | Nombre | Plans | Status | Completed |
|------|--------|-------|--------|-----------|
| 1 | Estabilidad Core | N/A | ✅ Done | 2026-01-13 |
| 2 | Periodos y Filtros | N/A | ✅ Done | 2026-01-14 |
| 3 | Gestión Categorías | N/A | ✅ Done | 2026-01-14 |
| 4 | Panel y Navegación | N/A | ✅ Done | 2026-01-15 |
| 5 | Visualizaciones Categorías | N/A | ✅ Done | 2026-01-18 |
| 5.1 | Correcciones y Mejoras | N/A | ✅ Done | 2026-01-19 |
| 6 | Pagos Planificados | N/A | ✅ Done | 2026-01-19 |
| 7 | Registro Inteligente | TBD | Not started | - |
| 8 | Plataforma y Polish | TBD | Not started | - |

---

*Actualizar conforme se completen fases*
