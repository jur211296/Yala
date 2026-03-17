# Chat Assistant — Documento de Diseño

## 1. Visión general

**"Pregúntale a Yala"** — asistente financiero conversacional que responde preguntas específicas sobre los datos del usuario. A diferencia de Smart Insights (proactivo, panorámico), el Chat Assistant es **reactivo y específico**: el usuario pregunta, Yala responde con datos reales.

**Modelo:** GPT-4.1-nano (OpenAI) — mismo proveedor que Insights, Voice e Image.
**Scope:** Single Q&A con memoria de 1 turno para follow-ups naturales.
**Gating:** Pro only.
**Límite:** 30 preguntas/día, rate limit 5s entre preguntas.

---

## 2. Principio de privacidad: "Relevante y enriquecido, no exhaustivo"

El LLM **nunca** recibe el historial completo de transacciones. El pipeline es:

```
Pregunta del usuario
    ↓
[GPT-4.1-nano] Clasifica la pregunta → function_call
    ↓
[SwiftData local] Ejecuta query + computa contexto enriquecido
    ↓
[GPT-4.1-nano] Recibe solo el resultado relevante → respuesta natural
```

### Qué se envía a OpenAI

| Dato | ¿Se envía? | Cuándo |
|------|-----------|--------|
| Pregunta del usuario | Sí | Siempre (unavoidable) |
| Nombres de categorías/subcategorías | Sí | Paso 1, para mapear lenguaje natural → categoría |
| Merchants frecuentes (nombres) | Sí | Paso 1, para resolución de merchants |
| Transacciones del resultado | Sí | Paso 2, solo las que matchean la consulta |
| Montos y fechas del resultado | Sí | Paso 2, del subset consultado |
| Comparación vs período anterior | Sí | Paso 2, como contexto enriquecido |
| Estado de presupuesto relacionado | Sí | Paso 2, si la categoría tiene budget |
| % del gasto total | Sí | Paso 2, contextualiza el resultado |

### Qué NUNCA se envía

| Dato | Motivo |
|------|--------|
| Historial completo de transacciones | Solo se envía el subset de la consulta |
| Notas personales de transacciones | Se excluyen del payload |
| Nombres de cuentas bancarias | Se excluyen del payload |
| Transacciones no relacionadas | El query local las filtra |
| Datos de ingresos (si preguntó por gastos) | Se excluye lo no pedido |
| Balance total de cuentas | No es relevante para consultas específicas |

---

## 3. Tools (Function Calling)

5 tools ricas en contexto. Cada tool ejecuta localmente y retorna datos enriquecidos.

### 3.1 `search_transactions`

**Propósito:** Buscar transacciones por merchant, categoría o período.

```json
{
  "name": "search_transactions",
  "parameters": {
    "merchant": "string? — nombre del merchant",
    "category": "string? — nombre de categoría o subcategoría",
    "date_range": "string — this_week, last_week, this_month, last_month, this_year, last_N_days, custom",
    "date_from": "string? — YYYY-MM-DD (si custom)",
    "date_to": "string? — YYYY-MM-DD (si custom)",
    "type": "string? — expense | income | all",
    "currency": "string? — código de moneda (USD, PEN, etc.)",
    "limit": "int? — máximo de resultados (default 20)"
  }
}
```

**Retorna (computado localmente):**
```json
{
  "transactions": [
    { "date": "2026-03-15", "weekday": "sáb", "amount": 15.00, "currency": "PEN", "merchant": "Starbucks", "subcategory": "Cafeterías" }
  ],
  "summary": { "count": 3, "total": 45.50, "avg": 15.17, "min": 12.00, "max": 18.50 },
  "comparison": {
    "prev_period": { "count": 1, "total": 14.00, "change_pct": 225 }
  },
  "budget_context": {
    "category": "Restaurantes", "spent": 800, "limit": 1000, "pct": 80, "days_remaining": 14
  },
  "share": { "of_category_pct": 5.7, "of_total_expense_pct": 1.8 },
  "pattern": { "most_common_weekday": "jueves", "avg_per_week": 2.5 }
}
```

**Campos excluidos del resultado:** `note` raw (notas personales), `account` (nombre de cuenta).

**Importante — merchant vs note:** Las transacciones en Yala no tienen campo `merchant` separado; el nombre del comercio vive en el campo `note`. El `ChatToolExecutor` DEBE usar `MerchantCanonicalizer` para extraer solo el nombre del comercio (ej: "Starbucks") y NUNCA enviar el `note` completo (que podría contener "Café con Juan en Starbucks"). Si el canonicalizer no puede extraer un merchant claro, el campo se omite.

### 3.2 `spending_summary`

**Propósito:** Resumen de gastos agrupado.

```json
{
  "name": "spending_summary",
  "parameters": {
    "date_range": "string",
    "group_by": "string — category | subcategory | merchant | weekday | week | month",
    "type": "string? — expense | income | all",
    "limit": "int? — top N grupos (default 10)"
  }
}
```

**Retorna:**
```json
{
  "groups": [
    { "name": "Restaurantes", "total": 800, "count": 25, "pct_of_total": 32, "change_vs_prev": 15 }
  ],
  "total": 2500,
  "period_label": "Marzo 2026",
  "comparison": { "prev_period_total": 2100, "change_pct": 19 },
  "daily_avg": 83.33,
  "projection_end_of_month": 2580
}
```

### 3.3 `budget_status`

**Propósito:** Estado de presupuestos.

```json
{
  "name": "budget_status",
  "parameters": {
    "category": "string? — si null, retorna todos los presupuestos activos"
  }
}
```

**Retorna:**
```json
{
  "budgets": [
    {
      "category": "Restaurantes",
      "limit": 1000, "spent": 800, "remaining": 200, "pct": 80,
      "days_elapsed": 17, "days_remaining": 14,
      "daily_pace": 47.06, "safe_daily_pace": 14.29,
      "projection_end_of_month": 1460,
      "status": "at_risk",
      "prev_month_spent": 920
    }
  ],
  "summary": { "total_budgeted": 3000, "total_spent": 2100, "overall_pct": 70 }
}
```

### 3.4 `compare_periods`

**Propósito:** Comparar dos períodos.

```json
{
  "name": "compare_periods",
  "parameters": {
    "metric": "string — total_expense | total_income | category_expense | merchant_expense | transaction_count",
    "period_a": "string — this_month, last_month, this_week, etc.",
    "period_b": "string — prev_month, same_month_last_year, etc.",
    "category": "string?",
    "merchant": "string?"
  }
}
```

**Retorna:**
```json
{
  "period_a": { "label": "Marzo 2026", "value": 2500, "count": 45 },
  "period_b": { "label": "Febrero 2026", "value": 2100, "count": 38 },
  "change": { "absolute": 400, "pct": 19.0, "direction": "up" },
  "breakdown": [
    { "name": "Restaurantes", "a": 800, "b": 650, "change_pct": 23 },
    { "name": "Transporte", "a": 400, "b": 450, "change_pct": -11 }
  ]
}
```

### 3.5 `financial_overview`

**Propósito:** Vista general para preguntas abiertas ("¿cómo voy este mes?").

```json
{
  "name": "financial_overview",
  "parameters": {
    "date_range": "string"
  }
}
```

**Retorna:**
```json
{
  "income": 5000, "expense": 2500, "balance": 2500,
  "expense_change_vs_prev_pct": 19,
  "top_categories": [
    { "name": "Restaurantes", "total": 800, "pct": 32 },
    { "name": "Transporte", "total": 400, "pct": 16 }
  ],
  "top_merchants": [
    { "name": "Uber", "total": 280, "count": 14 },
    { "name": "Starbucks", "total": 180, "count": 12 }
  ],
  "budgets_at_risk": [
    { "category": "Restaurantes", "pct": 80, "projection": 1460, "limit": 1000 }
  ],
  "need_distribution": {
    "essential": { "pct": 55, "total": 1375 },
    "priority": { "pct": 25, "total": 625 },
    "optional": { "pct": 20, "total": 500 }
  },
  "daily_avg": 83.33,
  "projection_end_of_month": 2580,
  "savings_rate_pct": 50
}
```

---

## 4. System Prompt

```
Eres el asistente financiero de Yala. Ayudas al usuario a entender sus
finanzas respondiendo preguntas específicas sobre sus gastos, ingresos,
presupuestos y patrones.

REGLAS CRÍTICAS:
1. SOLO usa datos que las tools te devuelvan. NUNCA inventes cifras.
2. Si una tool no retorna datos suficientes, dilo honestamente.
3. Responde en el idioma del usuario: {language}.
4. Usa el formato de moneda del usuario: {currency_symbol} antes del monto.
5. Negritas para cifras importantes (**S/45.50**).
6. Máximo 3-4 oraciones. Sé conciso pero informativo.
7. Si detectas algo notable (aumento inusual, presupuesto en riesgo),
   menciónalo brevemente al final.
8. NUNCA des consejos de inversión ni recomendaciones de productos financieros.
9. Registro: {register} (ej: ES→tuteo, DE→du, FR→tu, EN→informal you)
10. Tono: {tone} (normal | considerate | sarcastic)
11. Si la pregunta NO es sobre finanzas personales, responde amablemente
    que solo puedes ayudar con temas financieros. NO llames ninguna tool.

CONTEXTO:
- Moneda principal: {currency}
- Formato: {currency_format}
- Idioma: {language}
- Hoy: {today}
- País: {country}
```

El tono se toma de la misma preferencia de Smart Insights (`insightsTone`).

---

## 5. Memoria de 1 turno (follow-ups)

Cada pregunta nueva se envía con el contexto de la Q&A anterior (si existe y tiene < 5 minutos):

```
[System prompt + tools]
[Previous Q: "¿Cuántas veces fui a Starbucks?"]
[Previous tool result: {count: 3, total: 45.50...}]
[Previous A: "Fuiste 3 veces..."]
[Current Q: "¿Y cuántas fueron en USD?"]
```

**Reglas de la memoria:**
- Se conserva **solo 1 Q&A anterior** (no acumulativo)
- Expira a los **5 minutos** de la última interacción
- Se resetea al cerrar el sheet
- Costo adicional: ~500 tokens (~$0.00003 con nano)
- Un follow-up **SÍ cuenta** como pregunta para el límite diario (cada interacción = 1 pregunta)

---

## 6. Ubicación en la UI

### Entry point: AI FAB (sobre el transaction FAB)

El asistente se accede mediante un **segundo FAB dedicado** posicionado encima del FAB de transacciones existente. Aparece en las **3 pantallas** donde existe el FAB actual.

```
                          [✨]  ← AI FAB (44pt, sparkles)
                              ↕ DS.Spacing.md
                          [＋]  ← Transaction FAB (56pt, actual)
```

**Pantallas con AI FAB:**
1. PanelView (Home)
2. DetailContainerView (Statistics drill-down)
3. RecordsStandaloneView (Records standalone)

**Especificaciones del AI FAB:**

| Propiedad | Valor |
|-----------|-------|
| Tamaño | 44pt (vs 56pt del transaction FAB) |
| Icono | `sparkles` (SF Symbol) |
| Efecto | `.glassEffect(.regular.interactive())` |
| Sombra | `.dsFloatingShadow()` |
| Color | `theme.accent` (mismo que transaction FAB) |
| Separación | `DS.Spacing.md` sobre el transaction FAB |

**Comportamiento con el transaction FAB:**
- Cuando el transaction FAB se **expande** (menú voz/imagen/manual): AI FAB se **oculta con fade** (evita clutter)
- Cuando el transaction FAB está **cerrado**: AI FAB visible normalmente
- Animación: `.opacity` transition coordinada con el menú del FAB

**Pro gate visual:**
- Si no es Pro: AI FAB muestra candado sutil, tap → UpgradePromptSheet
- Si es Pro sin consent: tap → muestra consent alert del chat
- Si es Pro con consent: tap → abre chat sheet

**Future vision (fuera de scope v1):**
- Badge dot en el AI FAB cuando hay insight proactivo pendiente
- Tap abre sheet con recomendación pre-cargada en vez de estado vacío

**Nota de implementación:** El FAB actual está duplicado en 3 archivos (~130 líneas × 3). Se recomienda extraer a un componente compartido `FABStackView` que incluya ambos FABs, eliminando la duplicación.

### Sheet (presentación)

- **Detent inicial:** `.medium` (media pantalla)
- **Se expande a:** `.large` cuando hay respuesta
- **Dismiss:** Swipe down o botón [✕]
- **Persistencia:** Al cerrar, conserva la última Q&A por 5 minutos. Pasado ese tiempo → reset a estado vacío

### Estado vacío del sheet

```
┌──────────────────────────────────────┐
│       Pregúntale a Yala         [✕]  │
│──────────────────────────────────────│
│                                      │
│        (ilustración sutil)           │
│                                      │
│  Sugerencias:                        │
│  ┌─────────────┐ ┌────────────────┐ │
│  │ ¿Cómo voy   │ │ ¿En qué gasté │ │
│  │ este mes?    │ │ más?          │ │
│  └─────────────┘ └────────────────┘ │
│  ┌─────────────┐ ┌────────────────┐ │
│  │ ¿Cómo va mi │ │ ¿Cuánto llevo │ │
│  │ presupuesto?│ │ en [merchant]? │ │
│  └─────────────┘ └────────────────┘ │
│                                      │
│  ┌──────────────────────────────┐   │
│  │ Escribe tu pregunta...    [→]│   │
│  └──────────────────────────────┘   │
└──────────────────────────────────────┘
```

Las sugerencias rápidas se personalizan: el [merchant] más frecuente del mes, la categoría top, etc.

### Estado con respuesta

```
┌──────────────────────────────────────┐
│       Pregúntale a Yala         [✕]  │
│──────────────────────────────────────│
│                                      │
│  ┌─ Tú ──────────────────────────┐  │
│  │ ¿Cuántas veces fui a          │  │
│  │ Starbucks esta semana?        │  │
│  └────────────────────────────────┘  │
│                                      │
│  ┌─ Yala ────────────────────────┐  │
│  │ Fuiste **3 veces** a Starbucks│  │
│  │ esta semana, gastando          │  │
│  │ **S/45.50** — el triple que   │  │
│  │ la semana pasada. Tu gasto    │  │
│  │ promedio por visita es         │  │
│  │ **S/15.17**.                   │  │
│  │                                │  │
│  │ Tu presupuesto de Restaurantes│  │
│  │ va al 80% y quedan 2 semanas. │  │
│  └────────────────────────────────┘  │
│                                      │
│  ┌──────────────────────────────┐   │
│  │ Pregunta de seguimiento... [→]│  │
│  └──────────────────────────────┘   │
└──────────────────────────────────────┘
```

### Loading state

```
┌─ Yala ────────────────────────┐
│ ● ● ●  Consultando...         │
└────────────────────────────────┘
```

Animación de 3 dots pulsantes. Timeout: 15 segundos → "No pude obtener una respuesta. Intenta de nuevo."

---

## 7. Límites y control de costos

### Costos estimados

| Concepto | Tokens | Costo (nano) |
|----------|--------|-------------|
| Llamada 1 (intent + tools) | ~800 in / ~50 out | $0.00005 |
| Llamada 2 (resultado → respuesta) | ~500 in / ~100 out | $0.00005 |
| **Total por pregunta** | **~1,350** | **~$0.0001** |
| Follow-up (con memoria 1 turno) | ~1,850 | ~$0.00013 |

### Límites por usuario

| Parámetro | Valor | Motivo |
|-----------|-------|--------|
| Preguntas/día | 30 | Previene abuso, suficiente para uso real |
| Segundos entre preguntas | 5 | Rate limiting (mismo patrón que Insights) |
| Caracteres máx por pregunta | 500 | Previene prompt injection largo |
| Tokens máx por request | 4,000 | Cap de seguridad |
| Timeout | 15 segundos | UX — no dejar al usuario esperando |

### Peor caso de costo

- Power user: 30 preguntas/día × 30 días = 900/mes
- 900 × $0.0001 = **$0.09/mes** (nano)
- 900 × $0.0004 = **$0.36/mes** (mini, si escalamos)

### Contadores

- `chatQuestionsToday: Int` en UserDefaults, reset a medianoche
- `lastChatQuestionDate: Date` para rate limiting
- El counter se muestra **solo cuando `questionsUsedToday >= 25`**:
  - 25-29: texto sutil debajo del input → "Te quedan N preguntas hoy"
  - 30: input deshabilitado → "Has usado tus preguntas de hoy. ¡Vuelve mañana!"
  - < 25: **no se muestra nada** (la mayoría de usuarios nunca lo verán)

---

## 8. Consent y legal

### Estrategia: 3 consents separados (máximo control al usuario)

Los consents existentes se mantienen. Se añade uno nuevo para el chat.
Cada consent corresponde a un **nivel de granularidad diferente** de datos compartidos:

| Consent | Key | Datos que salen | Granularidad |
|---------|-----|-----------------|-------------|
| Voz + Imagen | `aiDataConsentAccepted` | Audio, foto (para procesamiento) | Media solo para transcribir/extraer |
| Smart Insights | `aiInsightsConsentAccepted` | Totales, %, tendencias (agregados) | Baja, nunca transacciones individuales |
| **Chat Assistant** | **`aiChatConsentAccepted`** | **Merchants, montos, fechas de transacciones específicas** | **Alta (datos puntuales de la consulta)** |

**Razón de separarlos:** Un usuario puede estar cómodo con que Yala envíe "Restaurantes: 32% del gasto" (insights) pero NO con "Starbucks: S/15 el jueves, S/18.50 el sábado" (chat). Cada usuario decide su nivel de comodidad.

### Texto del consent del chat (nuevo)

**Título:** `L10n.AIConsent.chatTitle` → "Asistente Financiero"

**Mensaje ES:** `L10n.AIConsent.chatMessage`
```
Esta función envía datos específicos de tu consulta a OpenAI para
responder tus preguntas: nombres de comercios, montos y fechas de
las transacciones relevantes, y estado de presupuestos relacionados.

Tu historial completo, notas personales y nombres de cuentas nunca
se comparten. OpenAI no usa estos datos para entrenar sus modelos.
```

**Mensaje EN:** `L10n.AIConsent.chatMessage`
```
This feature sends data specific to your query to OpenAI to answer
your questions: merchant names, amounts and dates of relevant
transactions, and related budget status.

Your full history, personal notes, and account names are never
shared. OpenAI does not use this data to train its models.
```

**Botones del alert** (mismo patrón que los otros consents):
- "Aceptar y activar" → `aiChatConsentAccepted = true`
- "Política de privacidad" → `openURL(AppConstants.privacyURL)`
- "Cancelar" (role: .cancel)

### Toggle en ProfileView

```
SectionBox(title: L10n.Settings.aiFeatures)
├── voiceInputRow           → consent: aiDataConsentAccepted
├── SubsectionDivider()
├── imageInputRow           → consent: aiDataConsentAccepted
├── SubsectionDivider()
├── smartInsightsToggleRow  → consent: aiInsightsConsentAccepted
├── SubsectionDivider()
├── chatAssistantRow        → consent: aiChatConsentAccepted    ← NUEVO
└── Inline Hint (conditional)
```

**Icono y color del toggle:**

| Feature | Icono | Color |
|---------|-------|-------|
| Voice | `waveform.badge.mic` | `.hotPink` |
| Image | `photo.on.rectangle` | `.teal` |
| Insights | `sparkles` | `.purple` |
| **Chat** | **`bubble.left.and.text.bubble.right`** | **`.electricIndigo`** |

**Estado:** `@AppStorage("chatAssistantEnabled")` + `@AppStorage("aiChatConsentAccepted")`

### Inline hint post-consent

Actualizar la lógica del hint contextual en ProfileView:

```swift
let hasProcessing = aiDataConsentAccepted && (voiceInputEnabled || imageInputEnabled)
let hasInsights = aiInsightsConsentAccepted
let hasChat = aiChatConsentAccepted && chatAssistantEnabled  // NUEVO

// Lógica de hint (simplificada):
if hasProcessing || hasInsights || hasChat {
    // Si hay múltiples activos → hint genérico
    // Si solo uno → hint específico
}
```

| Combinación | Hint |
|-------------|------|
| Solo voz/imagen | "Tus datos de voz e imagen se procesan con OpenAI. No se almacenan." |
| Solo insights | "Solo totales y tendencias se envían a OpenAI. No se almacenan." |
| Solo chat | "Los datos de tu consulta se procesan con OpenAI. No se almacenan." |
| Múltiples | "Tus datos se procesan con OpenAI según la función utilizada. No se almacenan." |

### Actualizaciones en Web

#### Privacy Policy — `privacy_content.md` (ES)

**Sección 4 actual:**
```
Cuando usas entrada por voz, escaneo de imágenes o el resumen inteligente
(funciones Pro), tus datos se procesan con **OpenAI**:

- **Voz:** tu grabación de audio y el texto transcrito
- **Imágenes:** la foto que seleccionas (comprimida, sin metadatos)
- **Contexto:** los nombres de tus categorías para clasificar mejor
- **Resumen:** totales, porcentajes y tendencias de tus gastos (datos
  agregados, nunca transacciones individuales)

No se envían montos, historial de gastos ni información personal. [...]
```

**Sección 4 nueva:**
```
Cuando usas entrada por voz, escaneo de imágenes, el resumen inteligente
o el asistente financiero (funciones Pro), tus datos se procesan con
**OpenAI**:

- **Voz:** tu grabación de audio y el texto transcrito
- **Imágenes:** la foto que seleccionas (comprimida, sin metadatos)
- **Contexto:** los nombres de tus categorías para clasificar mejor
- **Resumen:** totales, porcentajes y tendencias de tus gastos (datos
  agregados, nunca transacciones individuales)
- **Asistente:** cuando haces una pregunta, se envían los datos
  relevantes a tu consulta: nombres de comercios, montos y fechas de
  transacciones específicas, y estado de presupuestos relacionados.
  Nunca se envía tu historial completo ni notas personales.

Tu historial completo, notas personales y nombres de cuentas nunca se
comparten. OpenAI **no usa datos enviados por API para entrenar sus
modelos**. El procesamiento es puntual y no se almacena permanentemente.
Estas funciones son opcionales y solo se activan cuando tú las inicias.

Para tipos de cambio, consultamos exchangerate.host — solo se envían
códigos de divisa (ej: USD, PEN), nunca tus montos.
```

**Cambios concretos:**
1. Párrafo intro: añadir "o el asistente financiero"
2. Nuevo bullet: "Asistente" con descripción
3. Párrafo de cierre: cambiar "No se envían montos, historial de gastos ni información personal" → "Tu historial completo, notas personales y nombres de cuentas nunca se comparten" (más preciso, porque el chat SÍ envía montos específicos de la consulta)

#### Privacy Policy — `translations.ts` → `privacyProText` (EN)

**Nuevo valor:**
```
When you use voice input, image scanning, the smart overview, or the
financial assistant (Pro features), your data is processed by **OpenAI**:

• **Voice:** your audio recording and the transcribed text
• **Images:** the photo you select (compressed, without metadata)
• **Context:** your category names for better classification
• **Overview:** totals, percentages, and spending trends (aggregated
  data, never individual transactions)
• **Assistant:** when you ask a question, only data relevant to your
  query is sent: merchant names, amounts and dates of specific
  transactions, and related budget status. Your full history and
  personal notes are never shared.

Your full history, personal notes, and account names are never shared.
OpenAI **does not use API data to train its models**. Processing is
one-time and not stored permanently. These features are optional and
only activate when you initiate them.

For exchange rates, we query exchangerate.host — only currency codes
are sent (e.g., USD, EUR), never your amounts.
```

**Mismos cambios para los otros 4 idiomas** (DE, FR, IT, PT) en `translations.ts`.

#### Terms of Service — `translations.ts` → `termsDataText`

**ES actual:**
```
Tus datos financieros se guardan en tu dispositivo y se sincronizan con
tu iCloud personal (si lo tienes activo). Las funciones Pro de voz e
imagen procesan datos puntualmente mediante un servicio externo de IA.
Nosotros no tenemos acceso a tus datos.
```

**ES nuevo:**
```
Tus datos financieros se guardan en tu dispositivo y se sincronizan con
tu iCloud personal (si lo tienes activo). Las funciones Pro de voz,
imagen, resumen inteligente y asistente procesan datos puntualmente
mediante un servicio externo de IA. Nosotros no tenemos acceso a tus
datos. Para más detalles, consulta nuestra Política de Privacidad.
```

**EN actual:**
```
Your financial data is stored on your device and syncs with your
personal iCloud (if enabled). Pro voice and image features process
data one-time through an external AI service.
```

**EN nuevo:**
```
Your financial data is stored on your device and syncs with your
personal iCloud (if enabled). Pro voice, image, smart overview, and
assistant features process data one-time through an external AI
service. We do not have access to your data.
```

**Mismos cambios para los otros 4 idiomas** (DE, FR, IT, PT).

**Nota:** `termsServiceText` no cambia — ya dice "no como asesoría financiera" lo cual cubre al asistente.

---

## 9. Relación con Smart Insights

Son features **independientes pero complementarias**:

| | Smart Insights | Chat Assistant |
|---|---|---|
| **Iniciativa** | Proactivo (Yala habla) | Reactivo (usuario pregunta) |
| **Profundidad** | Panorámica | Específica |
| **Datos al LLM** | Solo agregados | Datos de la consulta específica |
| **Modelo** | GPT-4.1-mini | GPT-4.1-nano |
| **Caché** | 5 min / 30 min | Sin caché |
| **Tono** | Compartido (insightsTone) | Compartido (insightsTone) |
| **Servicio** | InsightsLLMService | ChatAssistantService (nuevo) |

### Código compartido (reutilizable)

- `InsightsCalculator` — para agregar datos del overview
- `FilterService` — para filtrar transacciones
- `CurrencyConverter` — para normalizar monedas
- `DateContextProvider` — para resolver "esta semana", "ayer", etc.
- `APIKeyService` — para acceso al API key
- `NetworkMonitor` — para verificar conectividad
- Preferencias de tono/foco

### Código nuevo (no reutilizable de Insights)

- `ChatAssistantService` — servicio principal con function calling
- `ChatAssistantViewModel` — maneja estado del chat
- `ChatAssistantView` — sheet con UI de conversación
- `ChatToolExecutor` — ejecuta tools localmente contra SwiftData
- Definiciones de tools (JSON schemas para function calling)

---

## 10. Arquitectura técnica

### Servicios nuevos

```
ChatAssistantService (@MainActor @Observable)
├── generateResponse(question: String, previousQA: QAPair?) async throws → ChatResponse
├── classifyIntent(question: String) async throws → ToolCall
└── formatResponse(question: String, toolResult: ToolResult) async throws → String

ChatToolExecutor (@MainActor)
├── execute(toolCall: ToolCall, context: ModelContext) → ToolResult
├── searchTransactions(...) → SearchResult
├── spendingSummary(...) → SummaryResult
├── budgetStatus(...) → BudgetResult
├── comparePeriods(...) → CompareResult
└── financialOverview(...) → OverviewResult

ChatAssistantViewModel (@MainActor @Observable)
├── question: String
├── response: ChatResponse?
├── previousQA: QAPair?
├── isLoading: Bool
├── questionsRemaining: Int
├── ask() async
└── reset()
```

### Modelos de datos (structs, no SwiftData)

```swift
struct QAPair {
    let question: String
    let toolResult: ToolResult
    let response: String
    let timestamp: Date
}

struct ChatResponse {
    let text: String           // Respuesta formateada con markdown
    let toolUsed: String       // Nombre del tool que se ejecutó
    let tokensUsed: Int        // Para tracking interno
}

enum ToolResult {
    case search(SearchResult)
    case summary(SummaryResult)
    case budget(BudgetResult)
    case compare(CompareResult)
    case overview(OverviewResult)
}
```

### Flujo completo

```
1. Usuario escribe pregunta
2. ChatAssistantViewModel.ask()
3. Validar: Pro? Consent? Online? Dentro del límite? ≤500 chars?
4. ChatAssistantService.classifyIntent(question)
   → API call #1: system prompt + tools + pregunta (+ previousQA si existe)
   → Respuesta: function_call con nombre + argumentos
5. ¿El LLM devolvió un function_call?
   → SÍ: continuar a paso 6
   → NO: el LLM respondió directamente (pregunta no financiera, saludo, etc.)
         → Usar la respuesta directa como texto final → saltar a paso 8
6. ChatToolExecutor.execute(toolCall, modelContext)
   → SwiftData query local
   → Normalizar monedas con CurrencyConverter a moneda principal
   → Extraer merchants con MerchantCanonicalizer (nunca note raw)
   → Computa contexto enriquecido
   → Retorna ToolResult
7. ChatAssistantService.formatResponse(question, toolResult, previousQA?)
   → API call #2: pregunta + resultado + (contexto previo opcional)
   → Respuesta: texto natural
8. Mostrar respuesta en UI (renderizar markdown con AttributedString)
9. Guardar QAPair como previousQA (para posible follow-up)
10. Incrementar contador diario
```

---

## 11. Sugerencias rápidas (personalizadas)

Las sugerencias del estado vacío se generan **localmente** sin API:

```swift
func generateSuggestions(context: ModelContext) -> [String] {
    // Top merchant del mes
    "¿Cuánto llevo en {topMerchant}?"
    // Categoría más grande
    "¿En qué gasté más este mes?"
    // Si hay presupuesto activo
    "¿Cómo va mi presupuesto de {budgetCategory}?"
    // Comparación temporal
    "¿Gasté más este mes que el anterior?"
    // Genérica
    "¿Cómo voy este mes?"
}
```

Se muestran 4 sugerencias como chips tocables con `.glassEffect()`. Se recalculan cada vez que se abre el sheet.

**Localización:** Las sugerencias usan L10n con placeholders para merchants/categorías dinámicos. Templates base localizados en 6 idiomas (ej: `L10n.Chat.Suggestion.topMerchant` → "¿Cuánto llevo en %@?").

---

## 12. Edge cases y manejo de errores

| Caso | Comportamiento |
|------|---------------|
| Sin API key | Feature no visible (mismo patrón que Insights) |
| Sin internet | Mensaje: "Necesitas conexión para usar el asistente" |
| Sin transacciones | Mensaje: "Todavía no tienes gastos registrados. ¡Empieza a registrar!" |
| Pregunta no financiera | El LLM responde cortésmente que solo puede ayudar con finanzas |
| Pregunta muy larga (>500 chars) | Truncar con aviso: "Tu pregunta es muy larga. Intenta ser más conciso." |
| Límite diario alcanzado | "Has usado tus 30 preguntas de hoy. ¡Vuelve mañana!" |
| Tool no retorna datos | "No encontré datos para esa consulta. ¿Puedes ser más específico?" |
| Timeout (>15s) | "No pude obtener una respuesta. Intenta de nuevo." |
| Error de API | "Hubo un problema. Intenta de nuevo en unos segundos." |
| Prompt injection | System prompt instruye ignorar instrucciones del usuario que intenten modificar comportamiento |
| Multi-moneda | CurrencyConverter normaliza todos los montos a la moneda principal del usuario |
| Solo ingresos (sin gastos) | Sugerencias se adaptan: "¿De dónde vienen mis ingresos?" en vez de "¿En qué gasté más?" |
| Datos fuera de rango temporal | "No encontré datos para ese período. Tu primer registro es de {fecha}." |
| Respuesta directa del LLM (sin tool call) | Mostrar respuesta directa — no forzar tool execution |

---

## 13. Métricas (TelemetryDeck)

| Evento | Propiedades |
|--------|------------|
| `chatQuestionAsked` | `tool_used`, `had_followup` |
| `chatSuggestionTapped` | `suggestion_index` |
| `chatErrorOccurred` | `error_type` (timeout, api, no_data, limit) |
| `chatSheetOpened` | `source_screen` (panel, statistics, records) |
| `chatSheetDismissed` | `had_interaction` (bool) |
| `chatDailyLimitReached` | — (para evaluar si 30/día es suficiente) |

---

## 14. Feature gate

```swift
enum ProFeature: String, CaseIterable {
    // ... existentes ...
    case chatAssistant    // ← NUEVO
}
```

Requiere (los 3):
- `FeatureGateService.canAccess(.chatAssistant)` → true (Pro)
- `aiChatConsentAccepted` → true (consent separado del chat)
- `NetworkMonitor.shared.isConnected` → true

---

## 15. Archivos a crear

| Archivo | Propósito |
|---------|-----------|
| `Services/ChatAssistantService.swift` | Servicio principal (API calls + function calling) |
| `Services/ChatToolExecutor.swift` | Ejecutor local de tools contra SwiftData |
| `App/ViewModels/ChatAssistantViewModel.swift` | Estado del chat |
| `App/Views/Chat/ChatAssistantView.swift` | Sheet principal |
| `App/Views/Chat/ChatMessageBubble.swift` | Burbuja de mensaje |
| `App/Views/Chat/ChatSuggestionsView.swift` | Chips de sugerencias |
| `App/Views/Chat/ChatInputBar.swift` | Barra de input |
| `App/Views/Shared/FABStackView.swift` | Componente compartido: AI FAB + Transaction FAB |

### Archivos a modificar (app)

| Archivo | Cambio |
|---------|--------|
| `App/Views/Panel/PanelView.swift` | Reemplazar FAB inline por `FABStackView` + sheet del chat |
| `App/Views/Statistics/DetailContainerView.swift` | Reemplazar FAB inline por `FABStackView` + sheet del chat |
| `App/Views/Records/RecordsStandaloneView.swift` | Reemplazar FAB inline por `FABStackView` + sheet del chat |
| `App/Views/Profile/ProfileView.swift` | Nuevo toggle chatAssistantRow + consent alert + inline hint |
| `App/Services/FeatureGateService.swift` | Añadir `.chatAssistant` |
| `App/Views/Settings/SubscriptionView.swift` | Añadir feature IA en lista de Pro (ver sección 18) |
| `App/Views/Subscription/ProTrialOfferSheet.swift` | Añadir feature IA en lista de Pro (ver sección 18) |
| `App/Views/Subscription/SubscriptionSuccessView.swift` | Añadir feature IA en lista de checkmarks |
| `Resources/*/Localizable.strings` | Strings del chat + consent + subscription features (6 idiomas) |

### Archivos a modificar (web)

| Archivo | Cambio |
|---------|--------|
| `Web/src/pages/privacy_content.md` | Añadir bullet "Asistente" + ajustar párrafo cierre |
| `Web/src/i18n/translations.ts` | `privacyProText`, `termsDataText`, `heroSubtitle`, `pricingPro8`, `faq7A`, `faq8Q/A`, `feature10Title/Desc` (×6 idiomas) |
| `Web/src/components/HomePage.astro` | Añadir feature10 card + pricingPro8 bullet + faq8 item |

---

## 16. Fuera de scope (v1)

- Conversación multi-turno completa (solo 1 follow-up)
- Acciones desde el chat (crear transacción, modificar presupuesto)
- Exportar respuestas
- Historial de conversaciones pasadas
- Modo offline con modelo local
- Personalización de sugerencias por hora del día
- Integración con Siri/App Intents
- Badge proactivo en AI FAB (análisis diario automático)
- Recomendaciones proactivas (nuevos presupuestos, reducir pagos)

---

## 17. Cambios en suscripción Pro (in-app)

### Problema actual

Las vistas de suscripción listan **6 features Pro** pero **ninguna menciona IA**:

```
Actual:
1. Cuentas ilimitadas        (building.columns.fill, blue)
2. Presupuestos ilimitados   (chart.pie.fill, purple)
3. Entrada por voz           (waveform.badge.mic, hotPink)
4. Escaneo de recibos        (photo.on.rectangle, teal)
5. Temas personalizados      (paintpalette.fill, orange)
6. Iconos premium            (app.fill, pink)
```

Smart Insights AI ya existe como ProFeature pero **no aparece en el paywall**. El chatbot es la oportunidad de añadir IA como selling point.

### Propuesta: Añadir feature 7 (IA)

```
Nuevo:
7. Asistente financiero con IA  (sparkles, electricIndigo)
```

**Texto localizado:**
```
ES: "Asistente financiero con IA"
EN: "AI financial assistant"
DE: "KI-Finanzassistent"
FR: "Assistant financier IA"
IT: "Assistente finanziario IA"
PT: "Assistente financeiro com IA"
```

**Icono:** `sparkles` | **Color:** `.electricIndigo`

Este feature combina conceptualmente el resumen inteligente (insights) y el asistente (chat) en un solo bullet de venta. No es necesario listar ambos por separado — "Asistente financiero con IA" engloba la propuesta de valor completa.

### Vistas a modificar

#### SubscriptionView.swift (paywall principal)

Añadir 7ma feature en el grid:
```swift
SubscriptionFeatureRow(
    icon: "sparkles",
    color: .electricIndigo,
    title: L10n.Subscription.Feature.aiAssistant
)
```

#### ProTrialOfferSheet.swift (oferta trial post-onboarding)

Misma adición — comparte la misma lista de features.

#### SubscriptionSuccessView.swift (post-compra)

Añadir 7mo checkmark:
```swift
UnlockedFeatureRow(
    icon: "sparkles",
    color: .electricIndigo,
    title: L10n.Subscription.Feature.aiAssistant
)
```

#### UpgradePromptSheet.swift

Cuando el usuario Free toque el AI FAB:
```swift
UpgradePromptSheet(
    feature: .chatAssistant,
    context: .proFeature
)
```

El `featureGate.chatAssistant` string localizado se mostrará en el prompt.

---

## 18. Cambios en landing web

### 18.1 Hero subtitle

**Actual (ES):** "Con Pro, también fotos y voz. Yala lo ordena."
**Nuevo (ES):** "Con Pro, también fotos, voz y un asistente con IA. Yala lo ordena."

**Actual (EN):** "With Pro, also photos and voice. Yala organizes."
**Nuevo (EN):** "With Pro, also photos, voice, and an AI assistant. Yala organizes."

Key: `heroSubtitle` (×6 idiomas en translations.ts)

### 18.2 Nueva feature card (feature10)

**ES:**
```
Title: "Asistente financiero · Pro"
Desc:  "Pregúntale lo que quieras sobre tus finanzas. Respuestas con tus datos reales."
```

**EN:**
```
Title: "Financial assistant · Pro"
Desc:  "Ask anything about your finances. Answers powered by your real data."
```

Key: `feature10Title`, `feature10Desc` (×6 idiomas)
HTML: Nuevo card en HomePage.astro, misma estructura que feature1-9.

### 18.3 Pricing Pro — nuevo bullet

**ES:** `pricingPro8`: "Pregúntale a Yala con IA"
**EN:** `pricingPro8`: "Ask Yala with AI"

Key: `pricingPro8` (×6 idiomas)
HTML: Nuevo `<li>` en la sección Pro de pricing en HomePage.astro.

### 18.4 FAQ 7 — actualizar Free vs Pro

**Actual (ES):** "Pro desbloquea cuentas ilimitadas, fotos, voz y reportes avanzados."
**Nuevo (ES):** "Pro desbloquea cuentas ilimitadas, fotos, voz, asistente con IA y reportes avanzados."

**Actual (EN):** "Pro unlocks unlimited accounts, photos, voice and advanced reports."
**Nuevo (EN):** "Pro unlocks unlimited accounts, photos, voice, an AI assistant, and advanced reports."

Key: `faq7A` (×6 idiomas)

### 18.5 Nueva FAQ 8 — IA

**ES:**
```
Q: "¿Qué puede hacer la IA de Yala?"
A: "Con Yala Pro, la IA potencia varias funciones: captura de recibos con la
   cámara, dictado por voz, auto-categorización de comercios, un resumen
   inteligente de tus finanzas y un asistente al que puedes preguntarle cosas
   como '¿cuánto gasté en Uber este mes?'. Tus datos se procesan con OpenAI
   de forma puntual y no se almacenan."
```

**EN:**
```
Q: "What can Yala's AI do?"
A: "With Yala Pro, AI powers several features: receipt scanning with your camera,
   voice dictation, automatic merchant categorization, a smart financial overview,
   and an assistant you can ask things like 'How much did I spend on Uber this
   month?'. Your data is processed through OpenAI on a one-time basis and is
   not stored."
```

Key: `faq8Q`, `faq8A` (×6 idiomas)
HTML: Nuevo item FAQ en HomePage.astro.

### 18.6 Privacy y Terms (ya documentados en sección 8)

- `privacyProText`: Añadir bullet "Asistente" (×6 idiomas)
- `termsDataText`: Añadir "resumen inteligente y asistente" (×6 idiomas)
- `privacy_content.md`: Actualizar sección 4

### 18.7 Resumen de keys nuevas en translations.ts

| Key | Tipo | Idiomas |
|-----|------|---------|
| `heroSubtitle` | Modificar | ×6 |
| `feature10Title` | Nuevo | ×6 |
| `feature10Desc` | Nuevo | ×6 |
| `pricingPro8` | Nuevo | ×6 |
| `faq7A` | Modificar | ×6 |
| `faq8Q` | Nuevo | ×6 |
| `faq8A` | Nuevo | ×6 |
| `privacyProText` | Modificar | ×6 |
| `termsDataText` | Modificar | ×6 |
| **Total** | | **54 strings** |

---

## 19. Criterios de aceptación

### Core
- [ ] AI FAB visible en las 3 pantallas (Panel, Statistics, Records)
- [ ] AI FAB se oculta cuando transaction FAB se expande
- [ ] AI FAB muestra candado si no es Pro → UpgradePromptSheet
- [ ] Tap en AI FAB abre chat sheet (medium detent)
- [ ] Sugerencias rápidas personalizadas aparecen al abrir
- [ ] Pregunta se procesa con function calling (2 API calls)
- [ ] Respuesta incluye datos reales computados localmente con contexto enriquecido
- [ ] Follow-up funciona con contexto de 1 turno (expira a 5 min)
- [ ] Tono respeta preferencia del usuario (normal/considerate/sarcastic)

### Límites
- [ ] Límite de 30 preguntas/día se respeta
- [ ] Counter visible solo a partir de 25 preguntas usadas
- [ ] Rate limit de 5s entre preguntas
- [ ] Input deshabilitado al alcanzar límite con mensaje amable

### Privacidad y legal
- [ ] Consent separado `aiChatConsentAccepted` (no reutiliza insights ni voz/imagen)
- [ ] Toggle en ProfileView debajo de Smart Insights
- [ ] Consent alert con texto específico del chat
- [ ] Inline hint actualizado para incluir caso del chat
- [ ] Notas personales y nombres de cuentas NUNCA se envían a OpenAI
- [ ] Privacy policy actualizada (ES + EN + DE + FR + IT + PT)
- [ ] Terms of service actualizados (6 idiomas)

### UI y UX
- [ ] Loading state con animación de dots pulsantes
- [ ] Error states manejados (offline, timeout, sin datos, límite, sin consent)
- [ ] Sheet se expande a large cuando hay respuesta
- [ ] Sheet conserva última Q&A por 5 min al cerrar

### Suscripción Pro (in-app)
- [ ] Feature "Asistente financiero con IA" en SubscriptionView (paywall)
- [ ] Feature "Asistente financiero con IA" en ProTrialOfferSheet (trial)
- [ ] Feature "Asistente financiero con IA" en SubscriptionSuccessView (post-compra)
- [ ] UpgradePromptSheet funciona al tocar AI FAB siendo Free
- [ ] Strings localizados (6 idiomas)

### Landing web
- [ ] Hero subtitle actualizado (6 idiomas)
- [ ] Nueva feature card (feature10) con asistente
- [ ] Nuevo bullet Pro en pricing (pricingPro8)
- [ ] FAQ 7 actualizado con mención a IA
- [ ] Nueva FAQ 8 sobre IA
- [ ] Privacy policy actualizada (privacyProText, 6 idiomas)
- [ ] Terms actualizados (termsDataText, 6 idiomas)
- [ ] privacy_content.md actualizado

### Infra
- [ ] FAB extraído a componente compartido `FABStackView`
- [ ] Métricas enviadas a TelemetryDeck
- [ ] Feature gate `.chatAssistant` en FeatureGateService
- [ ] ChatAssistantService inicializado en AppBootstrapper
- [ ] QA scenarios documentados en QA-SCENARIOS.md antes del commit

---

## 20. Testing

### Tests unitarios esperados

| Suite | Tests clave |
|-------|------------|
| `ChatToolExecutorTests` | search con filtros, spending summary agrupado, budget status, compare periods, financial overview, multi-moneda, merchant canonicalization, exclusión de notas |
| `ChatAssistantViewModelTests` | ask() flow completo, rate limiting, daily limit, follow-up con contexto, reset, validación de inputs, estados (loading, error, success) |
| `ChatAssistantServiceTests` | intent classification mock, format response mock, timeout handling, no-tool-call handling |

### QA Scenarios (para QA-SCENARIOS.md)

Documentar antes del commit:
1. Pregunta simple → respuesta con datos reales
2. Follow-up que referencia pregunta anterior
3. Pregunta en inglés siendo la app en español
4. Pregunta no financiera → rechazo amable
5. Sin internet → mensaje de error
6. 30 preguntas → límite alcanzado, input deshabilitado
7. Pregunta sobre merchant con nota personal → nota no aparece en respuesta
8. Pregunta sobre período sin datos → mensaje informativo
9. Free user tap AI FAB → upgrade prompt
10. Pro user sin consent tap AI FAB → consent alert
11. Cerrar y reabrir sheet en <5 min → mantiene Q&A anterior
12. Cerrar y reabrir sheet en >5 min → estado vacío
