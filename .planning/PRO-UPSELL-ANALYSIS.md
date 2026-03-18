# Análisis: Sistema de Conversión PRO para usuarios Free

## Objetivo principal
Mostrar el banner/oferta PRO a usuarios Free de forma periódica e inteligente durante el uso de la app, con telemetría completa para medir conversión y optimizar el sistema.

---

## 1. Estado Actual — Qué existe hoy

### Touchpoints implementados

| # | Tipo | Trigger | Frecuencia | Componente | Ubicación |
|---|------|---------|------------|------------|-----------|
| 1 | **Post-Onboarding** | Al cerrar onboarding | 1 sola vez en la vida | `ProTrialOfferSheet` | `ContentView.swift:170-203` |
| 2 | **Feature Gate** | Al tocar feature bloqueada | Cada vez que toca | `UpgradePromptSheet` | PanelView, RecordsStandaloneView, DetailContainerView, InsightsTabView, ProfileView, AppIconSettingsView, ThemeSettingsView |
| 3 | **Limit Banner** | Al alcanzar 2 cuentas / 3 presupuestos | Siempre visible (inline) | `LimitReachedBanner` | AccountsSettingsListView, BudgetsListView |
| 4 | **Downgrade** | Al perder suscripción Pro | 1 vez | `DowngradeResolutionSheet` | ContentView (via AppBootstrapper) |

### Features bloqueadas (5 Pro-only + 2 con límite)

| Feature | Tipo | Free | Pro |
|---------|------|------|-----|
| Cuentas | Límite | 2 | Ilimitadas |
| Presupuestos | Límite | 3 | Ilimitados |
| Voice Input | Bloqueado | No | Sí |
| Image Input | Bloqueado | No | Sí |
| Smart Insights AI | Bloqueado | No | Sí |
| Premium Icons | Bloqueado | No | Sí |
| Pro Themes | Bloqueado | No | Sí |
| Cash Flow Advanced | Bloqueado | No | Sí |

### Telemetría actual

```swift
// AnalyticsEvent enum — eventos que ya existen:
.appLaunched           // Cada apertura de app
.purchaseAttempted     // Con parámetros: productId, result (success/cancelled/pending/error)
.featureGateHit        // Cuando un Free user toca feature bloqueada (trackOnce por sesión)
.onboardingCompleted   // Al terminar onboarding
.transactionSaved      // Cada transacción nueva
// ... 8 eventos más (draftApproved, budgetSaved, etc.)
```

**Problema:** No hay NINGÚN evento de tipo "banner shown", "banner tapped", "banner dismissed", "paywall viewed", ni "trial started". Es imposible medir el funnel de conversión actual.

### Componentes creados pero NO usados

| Componente | Estado | Lo que hace |
|---|---|---|
| `TrialBanner` | Completo, 0 usos | Banner inline con countdown de trial: "Tu prueba termina en X días" + botón "Suscríbete" |
| `StoreKitManager.isTrialExpiringSoon` | Propiedad, 0 consumidores | `true` cuando quedan ≤2 días de trial |
| `StoreKitManager.trialDaysRemaining` | Propiedad, 0 consumidores | Días restantes del trial |
| `UpgradeContext.trialExpired` | Enum case, 0 usos | Contexto "Tu prueba gratuita expiró" para UpgradePromptSheet |

---

## 2. Lo que podemos implementar — Detalle completo

### 2A. Banner PRO periódico en pantalla principal (OBJETIVO PRINCIPAL)

**Objetivo:** Recordar al usuario Free que existe PRO de forma no invasiva, cada X tiempo o X eventos.

**Dónde:** Top de `PanelView` — es la pantalla que ven el 90%+ del tiempo.

**Cuándo aparece (condiciones — TODAS deben cumplirse):**
- Usuario es Free (`!isProUser`)
- NO está en trial (tiene su propio banner, ver 2B)
- Han pasado ≥ N días desde la última vez que se mostró (configurable, sugerido: 5 días)
- No se ha mostrado ya en esta sesión
- No se ha alcanzado el cap mensual (sugerido: 4 veces/mes)
- El usuario no es ex-Pro que canceló voluntariamente (respetar su decisión)

**Comportamiento:**
- Banner inline (no sheet/modal) — no interrumpe el flujo
- Dismissable con X — al cerrar, no reaparece hasta el próximo ciclo
- Al tocar "Desbloquear Pro" → navega a `SubscriptionView`

**Variantes de copy** (rotar para evitar fatiga):
1. "Desbloquea cuentas ilimitadas, voz y más con Pro"
2. "Registra gastos con tu voz — disponible con Pro"
3. "X transacciones este mes — imagina hacerlo por voz"

**Telemetría (funnel completo):**
```
proUpsellShown → proUpsellTapped / proUpsellDismissed → paywallViewed → purchaseAttempted → purchaseCompleted
```

| Evento TelemetryDeck | Parámetros | Pregunta que responde |
|---|---|---|
| `proUpsellShown` | `source: "periodicBanner"`, `variant: "voice"`, `daysSinceInstall: 14` | Cuántas veces mostramos banners / en qué momento del lifecycle |
| `proUpsellTapped` | `source: "periodicBanner"`, `variant: "voice"` | CTR del banner (tapped / shown) |
| `proUpsellDismissed` | `source: "periodicBanner"`, `dismissCount: 3` | Cuántos dismisses antes de convertir (o nunca) |
| `paywallViewed` | `source: "periodicBanner"` | Cuántos llegan al paywall desde el banner |
| `purchaseCompleted` | `source: "periodicBanner"`, `productId`, `hadTrial: false` | Conversión atribuida al banner periódico |

**Métricas derivadas en TelemetryDeck:**
- **CTR banner** = `proUpsellTapped[periodicBanner]` / `proUpsellShown[periodicBanner]`
- **Conversión banner→pago** = `purchaseCompleted[periodicBanner]` / `proUpsellShown[periodicBanner]`
- **Dismiss rate** = `proUpsellDismissed` / `proUpsellShown`
- **Optimal timing** = correlación entre `daysSinceInstall` y `purchaseCompleted`

---

### 2B. Trial Banner durante período de prueba

**Objetivo:** El usuario que aceptó el trial DEBE recordar que tiene tiempo limitado. Crear urgencia natural.

**Dónde:** Top de `PanelView` (mismo slot que el banner periódico, pero tiene prioridad).

**Componente:** `TrialBanner` — **ya existe completo**, solo falta integrarlo.

**Cuándo aparece:**
- `StoreKitManager.isInTrial == true`
- Siempre visible (no dismissable — es información, no publicidad)

**Comportamiento visual (ya implementado en TrialBanner):**
- ≥3 días restantes: fondo azul/info, icono reloj → "Tu prueba Pro termina en X días"
- ≤2 días restantes: fondo naranja/warning, icono alerta → "Tu prueba termina mañana"
- 0 días: "Tu prueba termina hoy"
- Botón "Suscríbete" → navega a `SubscriptionView`

**Telemetría:**

| Evento | Parámetros | Pregunta |
|---|---|---|
| `proUpsellShown` | `source: "trialBanner"`, `daysRemaining: 5` | En qué día del trial se convierte más |
| `proUpsellTapped` | `source: "trialBanner"`, `daysRemaining: 2` | La urgencia funciona? (CTR por días restantes) |
| `trialExpiring` | `daysRemaining: 1` | Cuántos usuarios llegan al final del trial sin convertir |

**Insight clave:** Con `daysRemaining` como parámetro podemos ver exactamente en qué día del trial la gente convierte más. Si el 80% convierte en día 1 o día 6-7, los días intermedios son ruido.

---

### 2C. Sheet de Trial Expirado

**Objetivo:** Capturar al usuario en el momento exacto en que pierde acceso Pro. Momento emocional de pérdida ("loss aversion").

**Trigger:** Primera apertura de app después de que el trial expire.

**Detección:**
```swift
// Nuevo flag en UserDefaults:
"pro.wasInTrial" → true   // Se setea cuando isInTrial == true
// Al abrir app: wasInTrial && !isInTrial && !isProUser → mostrar sheet
```

**Componente:** `UpgradePromptSheet(feature: .voiceInput, context: .trialExpired)` — el context `.trialExpired` **ya existe** con su título, icono y color.

**Frecuencia:** 1 sola vez (al setear flag `pro.trialExpiredSheetShown`).

**Telemetría:**

| Evento | Parámetros | Pregunta |
|---|---|---|
| `proUpsellShown` | `source: "trialExpired"` | Cuántos trials expiran sin convertir |
| `proUpsellTapped` | `source: "trialExpired"` | Tasa de recuperación post-trial |
| `purchaseCompleted` | `source: "trialExpired"` | Usuarios que pagan justo al perder acceso |

---

### 2D. Milestone Upsells — basado en uso

**Objetivo:** Mostrar el valor que el usuario ya obtuvo de Yala y lo que podría obtener con Pro. El timing es cuando el usuario demuestra engagement.

**Triggers (hitos de uso):**

| Milestone | Transacciones | Copy sugerido |
|---|---|---|
| Milestone 1 | 10 | "Ya llevas 10 gastos registrados — con Pro podrías hacerlo por voz" |
| Milestone 2 | 25 | "25 gastos registrados — desbloquea insights AI para entender tus patrones" |
| Milestone 3 | 50 | "Eres usuario frecuente — aprovecha todo Yala con Pro" |
| Milestone 4 | 100 | "100 gastos — mereces la experiencia completa" |

**Mecánica:**
- Contar total de transacciones al guardar cada una (ya tenemos `transactionSaved` event)
- Comparar con milestones, mostrar sheet si no se ha mostrado ese milestone
- Tracking: `"pro.milestone.lastShown"` = 25 → no mostrar 10 ni 25 de nuevo

**Formato:** Sheet (no banner) — es un momento especial, merece más protagonismo.

**Telemetría:**

| Evento | Parámetros | Pregunta |
|---|---|---|
| `proUpsellShown` | `source: "milestone"`, `milestone: 25` | Qué milestone tiene más impacto |
| `proUpsellTapped` | `source: "milestone"`, `milestone: 25` | CTR por milestone |
| `purchaseCompleted` | `source: "milestone"` | Cuántos convierte cada hito |

**Insight clave:** Si milestone 10 convierte 0% pero milestone 50 convierte 5%, podemos eliminar el 10 (ruido) y agregar uno en 40.

---

### 2E. Session Counter Upsell — basado en aperturas

**Objetivo:** Para usuarios que abren la app pero registran pocas transacciones (ej: solo revisan).

**Trigger:** Cada N sesiones (apertura de app). Sugerido: sesión 3, 7, 15, 30.

**Diferencia con banner periódico (2A):**
- 2A es por tiempo (cada 5 días)
- 2E es por aperturas (cada N sesiones)
- Se pueden combinar: el que llegue primero, con cap compartido

**Implementación:**
- `"pro.sessionCount"` se incrementa en `AppBootstrapper.bootstrap()` → `TelemetryService.track(.appLaunched)`
- Si `sessionCount % N == 0` && las condiciones de frequency capping se cumplen → mostrar

**Telemetría:**

| Evento | Parámetros | Pregunta |
|---|---|---|
| `proUpsellShown` | `source: "sessionCounter"`, `sessionNumber: 15` | En qué sesión convierte más |

---

### 2F. Feature Teaser en Insights (siempre visible)

**Objetivo:** Mostrar al usuario Free una preview de lo que AI Insights genera para usuarios Pro. No es un banner temporal — es contenido permanente que muestra valor.

**Dónde:** `InsightsTabView` — después de los insights rule-based (que son Free), mostrar una sección "Insights AI" con 1-2 insights de ejemplo borrosos + badge Pro + CTA.

**Cuándo:** Siempre visible para Free users. No es dismissable. Es parte de la UI.

**Formato:**
```
┌─────────────────────────────┐
│ ✨ Insights AI         PRO  │
│ ┌─────────────────────────┐ │
│ │ ░░░░░░░░░░░░░░░░░░░░░░ │ │  ← blur
│ │ ░░░░░░░░░░░░░░░░░░░░░░ │ │
│ └─────────────────────────┘ │
│    Desbloquear con Pro →    │
└─────────────────────────────┘
```

**Telemetría:**

| Evento | Parámetros | Pregunta |
|---|---|---|
| `proUpsellShown` | `source: "insightsTeaser"` | Cuántos Free users ven Insights |
| `proUpsellTapped` | `source: "insightsTeaser"` | CTR del teaser |

---

### 2G. Post-Export Nudge

**Objetivo:** El usuario acaba de usar una feature significativa (exportar datos) → momento de engagement para sugerir Pro.

**Trigger:** Después de completar un export exitoso (ya tenemos `exportCompleted`).

**Formato:** Inline text debajo del botón de share: "Con Pro puedes registrar gastos con tu voz o cámara" + link a SubscriptionView.

**Esfuerzo:** Mínimo — solo agregar una línea de texto con link.

**Telemetría:** `proUpsellShown` / `proUpsellTapped` con `source: "postExport"`.

---

## 3. Sistema de Telemetría — Diseño Completo

### Nuevos eventos analíticos

```swift
// Agregar al enum AnalyticsEvent:
case proUpsellShown      // Banner/sheet PRO mostrado al usuario
case proUpsellTapped     // Usuario tocó CTA del upsell
case proUpsellDismissed  // Usuario cerró el upsell sin tocar CTA
case paywallViewed       // SubscriptionView se mostró en pantalla
case trialStarted        // Usuario inició trial (nuevo — hoy no se trackea)
case purchaseCompleted   // Compra exitosa (separar de purchaseAttempted)
case trialExpiring       // Trial a punto de expirar (≤2 días)
```

### Parámetros estándar en todos los eventos pro

Siempre incluir estos parámetros para poder segmentar:

```swift
// Parámetros automáticos en cada proUpsell* event:
"source"           // periodicBanner, trialBanner, trialExpired, milestone, sessionCounter, featureGate, insightsTeaser, postExport, limitBanner
"daysSinceInstall" // Días desde primera apertura — para analizar timing óptimo
"sessionNumber"    // Número de sesión — para analizar engagement
"transactionCount" // Total de transacciones — para analizar uso
"hadTrial"         // Si el usuario tuvo/tiene trial — para separar cohortes
```

### Funnel completo que podemos medir

```
                    ┌──────────────┐
                    │ appLaunched  │  ← ya existe
                    └──────┬───────┘
                           │
              ┌────────────┼────────────┐
              │            │            │
     ┌────────▼───┐  ┌────▼─────┐  ┌──▼──────────┐
     │ trialBanner│  │ periodic │  │ featureGate  │  ← proUpsellShown (source)
     └────────┬───┘  └────┬─────┘  └──┬──────────┘
              │            │            │
              └────────────┼────────────┘
                           │
                  ┌────────▼────────┐
                  │ proUpsellTapped │  ← CTR por source
                  └────────┬────────┘
                           │
                  ┌────────▼────────┐
                  │ paywallViewed   │  ← Tasa de llegada al paywall
                  └────────┬────────┘
                           │
              ┌────────────┼────────────┐
              │            │            │
     ┌────────▼──┐  ┌─────▼─────┐  ┌──▼────────┐
     │ cancelled │  │ completed │  │  pending   │  ← purchaseAttempted ya tiene esto
     └───────────┘  └─────┬─────┘  └───────────┘
                          │
                 ┌────────▼────────┐
                 │ 🎉 PRO User 🎉 │
                 └─────────────────┘
```

### Dashboards sugeridos en TelemetryDeck

**Dashboard 1: Funnel de Conversión**
- `proUpsellShown` → `proUpsellTapped` → `paywallViewed` → `purchaseCompleted`
- Agrupado por `source` para comparar qué canal convierte mejor

**Dashboard 2: Timing Óptimo**
- `purchaseCompleted` agrupado por `daysSinceInstall`
- Responde: "En qué día del lifecycle la gente convierte más?"

**Dashboard 3: Eficacia del Trial**
- `trialStarted` → `trialExpiring` → `purchaseCompleted[hadTrial:true]`
- Responde: "Qué % de trials convierten a pago?"

**Dashboard 4: Feature Gate Impact**
- `featureGateHit` agrupado por `feature`
- Responde: "Qué feature bloqueada genera más interés?" → priorizar desarrollo

**Dashboard 5: Banner Fatigue**
- `proUpsellDismissed` con `dismissCount` creciente
- Responde: "Después de cuántos dismisses el usuario deja de interactuar?"

---

## 4. Servicio centralizado: `ProUpsellService`

### Responsabilidades
1. **Decidir** si mostrar un upsell (frequency capping, cooldowns, condiciones)
2. **Elegir** qué tipo de upsell mostrar (prioridad: trial > trialExpired > milestone > periódico)
3. **Trackear** todos los eventos de telemetría de forma consistente
4. **Persistir** estado (last shown, dismiss count, session count, milestones)

### UserDefaults keys

```swift
"pro.upsell.lastShownDate"       // Date — última vez que se mostró cualquier upsell proactivo
"pro.upsell.dismissCount"        // Int — total de dismisses (para detectar fatigue)
"pro.upsell.monthlyShownCount"   // Int — veces mostrado este mes (reset mensual)
"pro.upsell.monthlyResetDate"    // Date — cuándo resetear el counter mensual
"pro.upsell.sessionCount"        // Int — sesiones totales como Free user
"pro.upsell.firstLaunchDate"     // Date — primera apertura (para daysSinceInstall)
"pro.trial.wasInTrial"           // Bool — si alguna vez tuvo trial
"pro.trial.expiredSheetShown"    // Bool — si ya se mostró el sheet de trial expirado
"pro.milestone.lastShown"        // Int — último milestone de transacciones mostrado
"pro.wasVoluntaryChurn"          // Bool — si el usuario fue Pro y canceló voluntariamente
```

### Reglas de frequency capping

| Regla | Valor | Razón |
|---|---|---|
| Max upsells proactivos por sesión | 1 | No saturar en una sola visita |
| Días mínimos entre upsells | 5 | Dar espacio — no ser "esa app" |
| Max upsells proactivos por mes | 4 | ~1 por semana, no más |
| Cooldown post-dismiss | +2 días al intervalo | Respetar señal del usuario |
| Nunca mostrar si... | `wasVoluntaryChurn == true` | Ex-Pro que canceló: ya tomó su decisión |
| Feature gates (reactivos) | Sin cap | El usuario inició la interacción |
| Trial banner | Sin cap | Es info, no publicidad |

### Prioridad de upsells (si varios aplican, ganar el de mayor prioridad)

```
1. TrialBanner         → siempre visible durante trial (inline, no cuenta como upsell)
2. TrialExpiredSheet   → una sola vez al expirar trial (sheet modal)
3. MilestoneSheet      → al alcanzar hito (sheet modal, una vez por hito)
4. PeriodicBanner      → cada N días/sesiones (inline, dismissable)
5. SessionCounterLogic → fusionado con PeriodicBanner (mismas reglas)
```

---

## 5. Lo que ya existe vs lo que hay que crear

| Componente | Estado | Acción |
|---|---|---|
| `TrialBanner` view | Existe completo | Integrar en PanelView |
| `UpgradeContext.trialExpired` | Existe | Conectar trigger en ContentView/AppBootstrapper |
| `StoreKitManager.isInTrial` | Existe | Consumir en PanelView |
| `StoreKitManager.isTrialExpiringSoon` | Existe | Consumir para telemetría |
| `StoreKitManager.trialDaysRemaining` | Existe | Pasar a TrialBanner |
| `TelemetryService.track()` | Existe | Agregar nuevos eventos |
| `TelemetryService.trackOnce()` | Existe | Usar para upsells por sesión |
| `FeatureGateService` | Existe | Agregar tracking mejorado |
| **`ProUpsellService`** | **NO existe** | **Crear — servicio central** |
| **Banner periódico view** | **NO existe** | **Crear — similar a TrialBanner pero para no-trial** |
| **Milestone detection** | **NO existe** | **Crear — hook en transactionSaved** |
| **Nuevos AnalyticsEvent** | **NO existen** | **Agregar 7 eventos nuevos** |
| **Insights teaser view** | **NO existe** | **Crear — blur + badge Pro** |
| **wasInTrial flag** | **NO existe** | **Agregar a UserDefaults** |
| **daysSinceInstall calc** | **Parcial** | **`ReviewPromptService.recordFirstLaunchIfNeeded()` ya guarda fecha** |

---

## 6. Flujo completo del lifecycle Free User

```
DÍA 0 — ONBOARDING
├── Completa onboarding
├── ProTrialOfferSheet se muestra (ya existe)
├── Track: proUpsellShown[source: "onboarding"]
│
├── OPCIÓN A: Acepta trial
│   ├── Track: trialStarted
│   ├── Días 1-5: TrialBanner visible en PanelView (normal, fondo azul)
│   │   └── Track: proUpsellShown[source: "trialBanner", daysRemaining: X]
│   ├── Días 5-7: TrialBanner urgente (fondo naranja)
│   │   └── Track: trialExpiring[daysRemaining: 2]
│   ├── Día 7: Trial expira
│   │   ├── Primera apertura: UpgradePromptSheet(.trialExpired)
│   │   │   └── Track: proUpsellShown[source: "trialExpired"]
│   │   ├── Si convierte: 🎉 Track: purchaseCompleted[source: "trialExpired"]
│   │   └── Si no: entra a ciclo periódico (abajo)
│   │
│   └── Durante trial (cualquier día): si toca "Suscríbete" en TrialBanner
│       └── Track: proUpsellTapped[source: "trialBanner"] → paywallViewed → purchaseCompleted
│
├── OPCIÓN B: "Maybe later" (rechaza trial)
│   └── Entra directamente a ciclo periódico
│
└── CICLO PERIÓDICO (post-trial o sin trial)
    ├── Transacción #10: MilestoneSheet
    │   └── Track: proUpsellShown[source: "milestone", milestone: 10]
    ├── Día ~5: PeriodicBanner en PanelView
    │   └── Track: proUpsellShown[source: "periodicBanner", daysSinceInstall: 5]
    ├── Transacción #25: MilestoneSheet
    ├── Día ~10: PeriodicBanner
    ├── Transacción #50: MilestoneSheet
    ├── Día ~15+: PeriodicBanner cada ~5 días (max 4/mes)
    │
    ├── EN CUALQUIER MOMENTO: Feature gate reactivo
    │   └── Track: proUpsellShown[source: "featureGate", feature: "voiceInput"]
    ├── EN CUALQUIER MOMENTO: Limit banner
    │   └── Track: proUpsellShown[source: "limitBanner", feature: "accounts"]
    └── EN CUALQUIER MOMENTO: Insights teaser siempre visible
        └── Track: proUpsellShown[source: "insightsTeaser"] (una vez por sesión)
```

---

## 7. Implementación por fases

### Fase 1 — Telemetría base + Quick wins (lo primero)
**Sin telemetría todo lo demás es ciego. Esto va primero.**

1. Agregar eventos nuevos a `AnalyticsEvent`: `proUpsellShown`, `proUpsellTapped`, `proUpsellDismissed`, `paywallViewed`, `trialStarted`, `purchaseCompleted`, `trialExpiring`
2. Instrumentar touchpoints que YA existen (feature gates, limit banners, post-onboarding) con los nuevos eventos
3. Agregar `paywallViewed` a `SubscriptionView.onAppear`
4. Separar `purchaseCompleted` de `purchaseAttempted` en StoreKitManager
5. Agregar `trialStarted` cuando `didJustSubscribe && isInTrial`
6. Integrar `TrialBanner` en PanelView (componente ya existe)
7. Agregar `wasInTrial` flag + sheet de trial expirado

### Fase 2 — ProUpsellService + Banner periódico
8. Crear `ProUpsellService` con frequency capping
9. Crear banner periódico (reutilizar diseño de TrialBanner)
10. Hook en `AppBootstrapper.bootstrap()` para incrementar session count
11. Instrumentar con telemetría completa

### Fase 3 — Milestones + Insights teaser
12. Milestone detection en `NewTransactionViewModel.save()`
13. Milestone sheet (reutilizar diseño de UpgradePromptSheet)
14. Insights AI teaser en InsightsTabView
15. Post-export nudge

### Fase 4 — Optimización basada en datos
16. Analizar dashboards TelemetryDeck (2-4 semanas de datos)
17. Ajustar timing (¿5 días es mucho? ¿poco?)
18. Eliminar canales que no convierten
19. Duplicar esfuerzo en canales que sí convierten
20. A/B test de copy variants (via parámetro `variant`)
