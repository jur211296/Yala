# Roadmap: Neto

## Overview

App iOS de finanzas personales. Registrar y entender gastos, cuentas, presupuestos y reportes con claridad.

### V1.0 (Release actual)
Features completas + preparación para beta pública en TestFlight.

### V1.1 (Siguiente release)
Registro inteligente con IA, widgets iOS, notificaciones y polish final.

## Domain Expertise

- ./.claude/skills/expertise/iphone-apps/SKILL.md (si existe)

## Phases

### V1.0
- [x] **Fase 1: Estabilidad Core** - Eliminar bugs críticos antes de construir ✅
- [x] **Fase 2: Periodos y Filtros** - Infraestructura de filtrado para toda la app ✅
- [x] **Fase 3: Gestión Categorías** - Mantenimiento eficiente de categorías ✅
- [x] **Fase 4: Panel y Navegación** - Navegabilidad y widgets del Panel ✅
- [x] **Fase 5: Visualizaciones Categorías** - Comparativas y detalles en gráficas ✅
- [x] **Fase 5.1: Correcciones y Mejoras** - Bugs, UX y tech debt acumulado ✅
- [x] **Fase 6: Pagos Planificados** - Nuevo módulo de suscripciones y pagos futuros ✅
- [ ] **Fase 7: Beta Preparation** - Code quality, testing, UX y preparación App Store ← Siguiente

### V1.1
- [ ] **Fase 8: Registro Inteligente** - Entrada de transacciones con IA
- [ ] **Fase 9: Plataforma y Polish** - Widgets iOS, notificaciones, atajos, autenticación

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

### Fase 7: Beta Preparation
**Goal**: Preparar V1.0 para release público en TestFlight
**Depends on**: Fase 6
**Research**: Unlikely
**Spec**: .planning/PHASE7-BETAPREP-SPEC.md
**Plans**: TBD

Subfases:

**7.1: Code Quality & Cleanup**
- Revisar TODOs/FIXMEs en el código
- Eliminar código muerto o comentado
- Consistencia en naming conventions
- Imports no usados
- Warnings del compilador a cero

**7.2: Performance & Optimización**
- Profiling con Instruments (vistas principales)
- Revisar memory leaks
- Lazy loading donde aplique
- Verificar que no haya N+1 queries restantes

**7.3: Localizaciones y Monedas**
- Auditoría de strings hardcodeados
- Verificar todas las keys en 6 idiomas
- Formato de números/fechas por locale
- Pluralizaciones correctas
- Añadir monedas: MXN, COP, BRL, GBP

**7.4: Testing & QA**
- Documento de escenarios de prueba (manual)
- Revisar cobertura de unit tests existentes
- Casos edge: datos vacíos, muchos datos, valores extremos
- Flujos completos end-to-end documentados

**7.5: UX para Nuevos Usuarios**
- Empty states informativos en todas las vistas
- Textos de ayuda/explicación en Settings
- Tooltips en vistas complejas (gráficas, filtros)

**7.6: Preparación App Store**
- Screenshots para todos los tamaños
- Descripción de la app (6 idiomas)
- Keywords y metadata
- Privacy policy URL

**7.7: Estabilidad Pre-Release**
- Error handling consistente
- Validaciones de entrada de datos
- Comportamiento offline graceful
- Migración de datos robusta

**7.8: Primer Uso y Onboarding**
- Detección de idioma del sistema
- Sugerencia de moneda según región
- Onboarding básico (nombre + moneda)
- Defaults sensatos

DoD:
- Cero warnings en build
- Documento de QA con escenarios de prueba
- Localizaciones auditadas (0 hardcodes)
- Performance validada con Instruments
- Assets de App Store listos
- App estable para beta testers externos

---

### Fase 8: Registro Inteligente
**Goal**: Automatizar entrada de transacciones con IA
**Depends on**: Fase 7
**Research**: Done
**Spec**: .planning/PHASE8-REGISTRO-SPEC.md
**Plans**: TBD

Subfases:
- 8.1: Infraestructura Base (InboxDraft model, vista bandeja, navegación)
- 8.2: Edición y Aprobación (sheet edición, validación, acciones lote)
- 8.3: Voz MVP (OpenAI SDK, STT, LLM parser)
- 8.4: Imágenes MVP (OCR Vision, clasificación, extractores)
- 8.5: Merchant Memory (canonicalización, sugerencias)
- 8.6: Refinamiento (sistema confianza, fallbacks)
- 8.7: Cloud Fallback (opcional, AWS/GCP para recibos)

DoD:
- Bandeja de entrada funcional con drafts pendientes
- Voz → draft con monto/fecha/nota
- Imagen → draft(s) según tipo
- Aprobación → TransactionItem
- Merchant Memory sugiere subcategorías

### Fase 9: Plataforma y Polish
**Goal**: Integración con sistema iOS y refinamiento final
**Depends on**: Fase 8
**Research**: Likely (WidgetKit, App Intents, Notifications)
**Research topics**: WidgetKit timeline, App Intents/Shortcuts, UNNotification scheduling, Local Authentication
**Plans**: TBD

Incluye:
- Widgets iOS (WidgetKit en pantalla inicio)
- Notificaciones (UNNotificationCenter)
- Atajos (App Intents / Shortcuts)
- Share Sheet (importar datos)
- Autenticación (Face ID / Touch ID)
- Onboarding completo para nuevos usuarios
- Vaciar datos: preguntar si cargar seed

DoD:
- Widgets en pantalla de inicio
- Atajos funcionales
- Share Sheet importa datos
- Notificaciones configurables
- Autenticación activa
- Onboarding guiado funcionando

## Progress

### V1.0
| Fase | Nombre | Status | Completed |
|------|--------|--------|-----------|
| 1 | Estabilidad Core | ✅ Done | 2026-01-13 |
| 2 | Periodos y Filtros | ✅ Done | 2026-01-14 |
| 3 | Gestión Categorías | ✅ Done | 2026-01-14 |
| 4 | Panel y Navegación | ✅ Done | 2026-01-15 |
| 5 | Visualizaciones Categorías | ✅ Done | 2026-01-18 |
| 5.1 | Correcciones y Mejoras | ✅ Done | 2026-01-19 |
| 6 | Pagos Planificados | ✅ Done | 2026-01-19 |
| 7 | Beta Preparation | Not started | - |

### V1.1
| Fase | Nombre | Status | Completed |
|------|--------|--------|-----------|
| 8 | Registro Inteligente | Not started | - |
| 9 | Plataforma y Polish | Not started | - |

---

*Actualizar conforme se completen fases*
