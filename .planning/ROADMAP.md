# Roadmap: Neto

## Overview

App iOS de finanzas personales. Registrar y entender gastos, cuentas, presupuestos y reportes con claridad.

### V1.0 (Release actual)
Features completas + preparación para beta pública en TestFlight.

### V1.1 (En desarrollo)
Registro inteligente con IA, iCloud Sync, Widgets iOS, modo Solo Gastos, modelo Pro/Free.

### V1.2 (App Store Release)
Watch, iPad/Mac, Smart Insights y reportes financieros.

### V2.0 (Futuro)
Splitwise, predicciones de saldo, perfiles de usuario y metas de ahorro.

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
- [x] **Fase 10: Refinamiento & Polish** - Bugs críticos, widgets, consistencia visual, UX (21 items UAT) ✅
- [ ] **Fase 10.5: Mejoras Pre-Release** - iCloud Sync, Widgets iOS, modo Solo Gastos, modelo Pro/Free

### V1.2 (App Store Release)
- [ ] **Fase 11: Plataforma Extendida** - Watch, iPad/Mac, Smart Insights, reportes

### V2.0
- [ ] **Fase 12: Features Avanzadas** - Splitwise, predicciones, perfiles, metas de ahorro

### Futuro
- [ ] **Multiplataforma** - Integración opcional Android/Web

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

### Fase 10: Refinamiento & Polish
**Goal**: Corregir bugs, mejorar widgets, consistencia visual y UX antes de V1.2
**Depends on**: Fase 9
**Research**: Unlikely
**Plans**: TBD

**Completados:**
- [x] Pagos planificados crean transacción en bandeja de entrada ✅
- [x] Integración Share Sheet ✅
- [x] Prompts voz sin duplicar tags ✅
- [x] FAB imagen en todas las vistas ✅
- [x] Permisos micrófono/fotos al activar toggle ✅
- [x] Onboarding seed de categorías ✅
- [x] Notificaciones configurables ✅
- [x] Atajos Siri/Shortcuts ✅
- [x] Automatización Apple Pay ✅
- [x] Automatización externa ✅

**Completados (21/21 items UAT 2026-01-30):** ✅

**10.A: Bugs Críticos (4)** ✅
- [x] A.1: PanelView no reacciona inmediatamente (crear cuenta/importar/crear registros)
- [x] A.2: Filtro texto SearchBar no se quita/propaga correctamente
- [x] A.3: FAB no se cierra al navegar a otra pestaña
- [x] A.4: Vista FaceID bloqueado no aparece desde sheet perfil

**10.B: Lógica de Negocio (3)** ✅
- [x] B.1: Definir comportamiento transacciones futuras
- [x] B.2: Orden registros mismo día por creación/aprobación
- [x] B.3: Widget pagos planificados solo gastos (no ingresos)

**10.C: Widgets (4)** ✅
- [x] C.1: Hover widget presupuestos no fuerza vista correcta
- [x] C.2: Widget Presupuestos usa divisa correcta del presupuesto
- [x] C.3: Iconos informativos en pieCategories/pieSubcategories
- [x] C.4: Posición icono informativo en Pagos planificados

**10.D: Consistencia Visual (5)** ✅
- [x] D.1: Label "hoy" no sobrepasa eje Y en tendencias
- [x] D.2: Iconos toolbar no filled (outline)
- [x] D.3: Indicador filtros en TrendsTabView/CategoriesTabView
- [x] D.4: Icono informativo CashFlow en título único
- [x] D.5: Botones capsule (onboarding, FaceID, auditar todos)

**10.E: Settings y Preferencias (4)** ✅
- [x] E.1: Alineación derecha selectores Recurrencia
- [x] E.2: Tema Sistema fuerza sheet correctamente
- [x] E.3: Reordenar Preferencias + renombrar registros
- [x] E.4: Listas expansibles para divisas

**10.F: Desarrollo (1)** ✅
- [x] F.1: Seed Dev completa para pruebas (solo bundle dev)

DoD:
- 0 bugs críticos (sección A completa)
- Widgets muestran datos correctos
- UI consistente en toda la app
- Settings reorganizado y usable

---

### Fase 10.5: Mejoras Pre-Release
**Goal**: Completar V1.1 con sync, widgets, personalización y modelo de suscripción
**Depends on**: Fase 10
**Research**: Likely (CloudKit, WidgetKit, Control Center APIs)
**Plans**: TBD

**10.5.A: Bugs Críticos** ✅
- [x] A.1: Share Sheet envía imagen a app incorrecta → App Group dinámico
- [x] A.2: Atajo de automatización no lee JSON → DecodingError detallado
- [x] A.3: Notificación in-app no aparece con sheet → fullScreenCover
- [x] A.4: Cambio de tema no se aplica → themeRefreshKey

**10.5.B: Consistencia Visual** ✅
- [x] B.1: UI de Pagos Planificados alineada con Presupuestos

**10.5.C: UX y Personalización** ✅
- [x] C.1: Ejemplo voz usa moneda preferida (shortPluralName)
- [x] C.2: Filtro monedas solo con transacciones
- [x] C.3: Onboarding divisas por continente con recomendada
- [x] C.4: Settings divisas secundarias con continentes + recomendadas (USD, EUR, GBP)

**10.5.D: Features** ✅
- [x] D.1: Notificaciones de presupuestos (umbrales configurables)
- [x] D.2: Toggle global en Notificaciones para alertas de presupuestos

**10.5.E: Aislamiento Yala/Dev** ✅
- [x] E.1: SwiftData aislado (YalaModel vs YalaModel-Dev)

**10.5.F: Modal Unificado Inbox** ✅
- [x] F.1: Modal para pagos planificados/suscripciones/automatizaciones

**10.5.G: Sincronización y Widgets** ✅
- [x] G.1: iCloud Sync (CloudKit private database)
- [x] G.2: Widgets iOS (WidgetKit) — balance, gastos del día/semana, próximos pagos
- [x] G.3: Atajos en centro de control y acciones rápidas en pantalla de bloqueo

**10.5.H: Navegación y UI**
- [ ] H.1: Crear tab propia de Registros (separar de Statistics)
- [ ] H.2: Animaciones nivel app (estilo FAB) y haptic feedback en botones importantes

**10.5.I: Personalización**
- [ ] I.1: Opción para ocultar variaciones (chips de %)
- [ ] I.2: Reorganizar Personalización por secciones lógicas
- [ ] I.3: Definir defaults sensatos para todas las preferencias

**10.5.J: Suscripción Pro**
- [ ] J.1: Separar funcionalidades Pro vs Free (definir matriz)
- [ ] J.2: Configurar planes Pro con 7 días gratis de prueba

**10.5.K: Modo Solo Gastos**
- [ ] K.1: Implementar modo "Solo gastos" (ocultar ingresos y saldos globalmente)
- [ ] K.2: Toggle en Personalización
- [ ] K.3: Opción en Onboarding

DoD:
- iCloud Sync funcional con datos privados
- Widgets en pantalla de inicio con datos actualizados
- Atajos accesibles desde centro de control
- Tab de Registros independiente
- Animaciones y haptics consistentes
- Personalización reorganizada con defaults sensatos
- Modelo Pro/Free claramente definido
- Modo Solo Gastos oculta ingresos/saldos en toda la app

---

### Fase 11: Plataforma Extendida (V1.2 - App Store)
**Goal**: Watch, iPad/Mac, Smart Insights y reportes
**Depends on**: Fase 10.5
**Research**: Likely (WatchKit, iPadOS/macOS adaptations, ML/heurísticas)
**Plans**: TBD

Incluye:
- [ ] Integración con Apple Watch (registro rápido, balance, widgets)
- [ ] Refinamiento versión iPad/Mac (layouts adaptados, sidebar)
- [ ] Vista de Smart Insights (patrones de gasto, alertas inteligentes)
- [ ] Integrar Smart Insights a lo largo de la app (contextuales)
- [ ] Vista de reporte financiero (exportable PDF/Excel)
- [ ] Filtros avanzados: excluir/incluir en DetailContainerView

DoD:
- App funcional en Watch con registro y balance
- Layouts optimizados para iPad y Mac
- Insights visibles en contexto relevante
- Reportes financieros exportables
- Filtros con exclusión/inclusión

---

### Fase 12: Features Avanzadas (V2.0)
**Goal**: Splitwise, predicciones y perfiles de usuario
**Depends on**: Fase 11
**Research**: Likely (APIs Splitwise, ML para predicciones)
**Plans**: TBD

Incluye:
- [ ] Splitwise integrado (gastos compartidos, deudas)
- [ ] Predicción de saldo en gráficas de tendencia
- [ ] Integración BD multiplataforma para Splitwise (sin exponer datos innecesarios)
- [ ] Perfil para Smart Insights: ahorrador, justo, sobrado
- [ ] Visualizador de ahorros (metas amarradas a cuentas de ahorro)
- [ ] Split de transacción (dividir en múltiples partes/personas)

DoD:
- Splitwise sincronizado con gastos compartidos
- Predicciones de saldo visibles en tendencias
- Perfiles de usuario influyen en insights
- Metas de ahorro con progreso visual

---

### Futuro (Post V2.0)

Ideas capturadas para evaluación posterior:
- [ ] Integración multiplataforma opcional (Android, Web) — sync completo para usuarios que lo deseen

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
| 10 | Refinamiento & Polish | ✅ Done | 2026-01-30 |
| 10.5 | Mejoras Pre-Release | In progress | - |

### V1.2 (App Store)
| Fase | Nombre | Status | Completed |
|------|--------|--------|-----------|
| 11 | Plataforma Extendida | Not started | - |

### V2.0
| Fase | Nombre | Status | Completed |
|------|--------|--------|-----------|
| 12 | Features Avanzadas | Not started | - |

### Futuro
| Tema | Status |
|------|--------|
| Multiplataforma opcional | Backlog |

---

*Actualizar conforme se completen fases*
