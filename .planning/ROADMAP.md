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
- [x] **Fase 7: Beta Preparation** - Code quality, testing, UX y preparación App Store ✅
- [x] **Fase 7.1: Acciones Rápidas en Transacciones** - Botones de acción en NewTransactionView ✅
- [x] **Fase 9: Settings & Pre-Release** - Face ID, suscripción Pro, legal, páginas informativas ✅

### V1.1
- [x] **Fase 8: Registro Inteligente** - Entrada de transacciones con IA ✅
- [ ] **Fase 10: Refinamiento & Notificaciones** - Modo solo gastos, notificaciones, permisos, correcciones

### V1.2
- [ ] **Fase 11: Plataforma Avanzada** - Widgets, Smart Insights, Watch, iPad, reportes

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

### Fase 7.1: Acciones Rápidas en Transacciones
**Goal:** Mejorar productividad con acciones rápidas en NewTransactionView
**Depends on:** Fase 7
**Research:** Unlikely
**Plans:** TBD

Incrementos:
- UI Base: Barra de acciones debajo del monto (4 botones con iconos)
- Duplicar: Crea copia de transacción actual (solo edición)
- Eliminar: Elimina con confirmación (solo edición)
- Guardar como favorito: Crea FavoritePayment desde transacción
- Guardar como recurrente: Crea ScheduledPayment desde transacción

DoD:
- 4 acciones funcionales en NewTransactionView
- Botones contextuales (algunos solo en modo edición)
- Localizaciones en 6 idiomas

---

### Fase 8: Registro Inteligente ✅
**Goal**: Automatizar entrada de transacciones con IA
**Depends on**: Fase 7
**Research**: Done
**Spec**: .planning/PHASE8-REGISTRO-SPEC.md

Subfases:
- [x] 8.1: Infraestructura Base (InboxDraft model, vista bandeja, navegación) ✅
- [x] 8.2: Edición y Aprobación (sheet edición, validación, acciones lote) ✅
- [x] 8.3: Voz MVP (OpenAI SDK, STT, LLM parser) ✅
- [x] 8.4: Imágenes MVP (OCR Vision, clasificación, extractores) ✅
- [x] 8.5: Merchant Memory (canonicalización, sugerencias) ✅
- ~~8.6: Refinamiento~~ (descartada — sin valor incremental)
- ~~8.7: Cloud Fallback~~ (descartada — sin valor incremental)

DoD: ✅
- Bandeja de entrada funcional con drafts pendientes
- Voz → draft con monto/fecha/nota
- Imagen → draft(s) según tipo
- Aprobación → TransactionItem
- Merchant Memory sugiere subcategorías

---

### Fase 9: Settings & Pre-Release
**Goal**: Completar pantallas de Settings, suscripción y legal para V1.0
**Depends on**: Fase 8
**Research**: Likely (StoreKit 2, Local Authentication)
**Plans**: TBD

Incluye:
- [x] Face ID / Touch ID con tiempo de bloqueo configurable ✅
- [x] Permisos → redirige a Settings del sistema ✅
- [x] Contacta con nosotros → mail draft a admin@yala-app.pe ✅
- [x] Valorar en App Store → SKStoreReviewController ✅
- [x] Política de privacidad → redirige a web ✅
- [x] Sistema de suscripción Pro (StoreKit 2) ✅
- [x] Página de administrar suscripción ✅ (integrada en SubscriptionView)
- [x] Consejos y trucos (página informativa) ✅
- [x] Preguntas frecuentes (página informativa) ✅
- [x] Términos de uso → redirige a web ✅

DoD:
- Face ID funcional con opciones de tiempo de bloqueo
- Suscripción Pro configurada y funcional
- Todas las páginas de Settings conectadas y navegables
- Links legales redirigen a web correctamente

---

### Fase 10: Refinamiento & Notificaciones
**Goal**: Modo solo gastos, correcciones de registro inteligente y notificaciones
**Depends on**: Fase 9
**Research**: Likely (UNNotificationCenter, permisos iOS)
**Plans**: TBD

Incluye:
- [ ] Modo "Solo gastos" — ocultar todo rastro de ingresos y saldos en toda la app
- [ ] Notificaciones: recordatorio de registro, reporte semanal/mensual, pagos planificados, anuncios y ofertas
- [ ] Pagos planificados crean transacción en bandeja de entrada
- [ ] Integración Share Sheet para enviar imágenes directamente
- [ ] Integración con atajos y automatización con Apple Pay
- [x] Revisar prompts voz: tildes crean etiquetas duplicadas en vez de reusar existentes ✅ (669b537)
- [x] FAB fuera de PanelView no tiene opción de registro de imagen ✅ (669b537)
- [x] Pedir permiso de micrófono al activar toggle ✅ (12e054f)
- [x] Pedir permiso de fotos al activar toggle ✅ (12e054f)
- [ ] Mejorar onboarding: preguntar si cargar seed de categorías predeterminadas
- [ ] Vaciar datos: preguntar si cargar seed de categorías predeterminadas

DoD:
- Modo solo gastos oculta ingresos/saldos globalmente
- Notificaciones configurables por tipo
- Pagos planificados generan drafts automáticamente
- Share Sheet e imagen accesible desde cualquier FAB
- Permisos se solicitan en el momento correcto
- Onboarding y data wipe ofrecen carga de categorías seed

---

### Fase 11: Plataforma Avanzada
**Goal**: Widgets, insights, Watch y plataformas extendidas
**Depends on**: Fase 10
**Research**: Likely (WidgetKit, WatchKit, App Intents, ML/heurísticas)
**Plans**: TBD

Incluye:
- [ ] Acciones rápidas en centro de control y pantalla de bloqueo
- [ ] Widgets iOS (WidgetKit)
- [ ] Predicciones de saldo en gráficas de tendencia
- [ ] Integración con Apple Watch
- [ ] Refinamiento versión iPad
- [ ] Vista de Smart Insights
- [ ] Integrar Smart Insights a lo largo de la app
- [ ] Vista de reporte financiero

DoD:
- Widgets funcionales en pantalla de inicio
- Insights visibles en contexto relevante
- App funcional en Watch y iPad
- Reportes financieros exportables

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
| 7 | Beta Preparation | ✅ Done | 2026-01-21 |
| 7.1 | Acciones Rápidas en Transacciones | ✅ Done | 2026-01-21 |
| 9 | Settings & Pre-Release | ✅ Done | 2026-01-27 |

### V1.1
| Fase | Nombre | Status | Completed |
|------|--------|--------|-----------|
| 8 | Registro Inteligente | ✅ Done | 2026-01-27 |
| 10 | Refinamiento & Notificaciones | Not started | - |

### V1.2
| Fase | Nombre | Status | Completed |
|------|--------|--------|-----------|
| 11 | Plataforma Avanzada | Not started | - |

---

*Actualizar conforme se completen fases*
